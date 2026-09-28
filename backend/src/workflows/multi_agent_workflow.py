from __future__ import annotations

import asyncio
import textwrap
from typing import Optional

import json5
from llama_index.core.agent.types import BaseAgent
from llama_index.core.workflow import (
    Context,
    Event,
    StartEvent,
    StopEvent,
    Workflow,
    step,
)
from llama_index.core.workflow.errors import WorkflowTimeoutError
from mem0 import AsyncMemory
from openinference.instrumentation.llama_index import get_current_span
from src.agents.prompts import SELF_REFLECTION_PROMPT
from src.config.config import settings
from src.database import Session
from src.logging import logger
from src.repository import (
    PersonalizedProductRepository,
    ProductRepository,
    UserRepository,
    VariantRepository,
)
from src.schemas.enums import EventType
from src.schemas.personalization import PersonalizationSection
from src.utils.utils import (
    convert_trace_id_to_hex,
    extract_json_blocks,
    format_variants,
)
from src.workflows.schemas import ProductSchema, UserSchema
from src.workflows.utils import send_stream_event


class ProductPersonalizationEvent(Event):
    pass


class ProductPersonalizationCompletedEvent(Event):
    result: str


class ReviewsEvent(Event):
    self_reflection: Optional[str] = None
    prev_result: Optional[str] = None


class ReviewsCompletedEvent(Event):
    result: str


class EvaluationEvent(Event):
    result: str


class InventoryEvent(Event):
    pass


class InventoryCompletedEvent(Event):
    result: str


class MultiAgentFlow(Workflow):

    def __init__(
        self,
        product_personalization_agent: BaseAgent,
        inventory_agent: BaseAgent,
        reviews_agent: BaseAgent,
        presentation_agent: BaseAgent,
        planning_agent: BaseAgent,
        evaluation_agent: BaseAgent,
        memory: AsyncMemory,
        message_queue: Optional[asyncio.Queue] = None,
        fault_correction: bool = False,
        **kwargs,
    ):
        self.product_personalization_agent = product_personalization_agent
        self.reviews_agent = reviews_agent
        self.inventory_agent = inventory_agent
        self.presentation_agent = presentation_agent
        self.planning_agent = planning_agent
        self.evaluation_agent = evaluation_agent
        self.memory = memory
        self.message_queue = message_queue
        self.fault_correction = fault_correction

        super().__init__(**kwargs)

    @step
    async def planning(
        self,
        ctx: Context,
        ev: StartEvent,
    ) -> ProductPersonalizationEvent | ReviewsEvent | InventoryEvent:

        if not ev.product_id:
            raise ValueError("Product ID is required for personalization.")

        logger.info(
            "Starting workflow. product_id=%s, user_id=%s",
            ev.product_id,
            ev.user_id,
        )
        await self._setup_workflow_context(ctx, ev)

        user_profile = await ctx.store.get("user_profile")
        planning_agent_query = (
            f"Generate an execution plan based on the following user profile\n \
            user={user_profile} \n"
        )

        if hasattr(ev, "user_msg") and ev.user_msg:
            planning_agent_query += f"\n and user query={ev.user_msg}"

        planner_response = await self.planning_agent.run(planning_agent_query)

        logger.info("Planning Result: %s", planner_response)

        agents_to_call = extract_json_blocks(str(planner_response))
        agents_to_call = json5.loads(agents_to_call[0]) if agents_to_call else []

        # To showcase fault correction, we need to call the reviews agent
        # even if it is not in the planner response
        if self.fault_correction and "reviews" not in agents_to_call:
            agents_to_call.append("reviews")

        triggered_agents = []

        if "product_personalization" in agents_to_call:
            ctx.send_event(ProductPersonalizationEvent())
            triggered_agents.append(ProductPersonalizationCompletedEvent)
        if "reviews" in agents_to_call:
            ctx.send_event(ReviewsEvent())
            triggered_agents.append(ReviewsCompletedEvent)
        if "inventory" in agents_to_call:
            ctx.send_event(InventoryEvent())
            triggered_agents.append(InventoryCompletedEvent)

        await ctx.store.set("triggered_agents", triggered_agents)

    @step
    async def personalize_product(
        self,
        ctx: Context,
        ev: ProductPersonalizationEvent,
    ) -> ProductPersonalizationCompletedEvent:
        user_info = await ctx.store.get("user_profile")
        product_info = await ctx.store.get("product_information")
        vaiants_info = await ctx.store.get("product_variants")

        try:
            result = await self.product_personalization_agent.run(
                f"""Personalize the product for user: {user_info},
                product: {product_info}, product variants: {vaiants_info}""",
                timeout=settings.PRODUCT_PERSONALIZATION_AGENT_TIMEOUT,
            )
        except WorkflowTimeoutError:
            logger.info("Personalization Agent has timed out.")
            result = "Personalization agent timed out. No response"

        return ProductPersonalizationCompletedEvent(result=str(result))

    @step
    async def review(
        self,
        ctx: Context,
        ev: ReviewsEvent,
    ) -> ReviewsCompletedEvent | EvaluationEvent:

        user_info = await ctx.store.get("user_profile")
        user_message = await ctx.store.get("user_msg")

        self_reflection_prompt = ""
        generate_error_prompt = ""

        if self.fault_correction and not ev.self_reflection:
            # To mock faulty output...
            # Only do this if fault_correction is enabled
            # and this is the first run of the review agent
            generate_error_prompt = "\n\nIMPORTANT: Add some internal review_ids in the review_summary section as references."

        if ev.self_reflection:
            self_reflection_prompt = SELF_REFLECTION_PROMPT.format(
                wrong_answer=ev.prev_result,
                error=ev.self_reflection,
            )

        try:
            prompt = textwrap.dedent(
                f"""
                {self_reflection_prompt}
                Generate a summary of relevant reviews of the product based on the
                user's preferences: {user_info['user_preferences']}
                and the optional user query: {user_message}.
                {generate_error_prompt}
            """,
            )

            logger.debug("Review Prompt: %s", prompt)

            result = await self.reviews_agent.run(
                prompt,
                timeout=settings.REVIEW_AGENT_TIMEOUT,
            )

        except WorkflowTimeoutError:
            logger.info("Review Agent has timed out.")
            result = "Review agent timed out. No response"

        if self.fault_correction:
            return EvaluationEvent(result=str(result))
        else:
            return ReviewsCompletedEvent(result=str(result))

    @step
    async def evaluate_output(
        self,
        ctx: Context,
        ev: EvaluationEvent,
    ) -> ReviewsCompletedEvent | ReviewsEvent:

        agent_output = ev.result

        try:
            result = await self.evaluation_agent.run(
                f"Review the following output: \
                output={agent_output}",
            )

            logger.info("Evaluation Result: %s", result)

            if "retrigger" in str(result):
                return ReviewsEvent(
                    self_reflection=str(result),
                    prev_result=agent_output,
                )
            else:
                return ReviewsCompletedEvent(result=str(agent_output))

        except WorkflowTimeoutError:
            logger.info("Evaluation Agent has timed out.")

        return ReviewsCompletedEvent(result=str(agent_output))

    @step
    async def inventory_analysis(
        self,
        ctx: Context,
        ev: InventoryEvent,
    ) -> InventoryCompletedEvent:
        product_id = await ctx.store.get("product_id")
        user_info = await ctx.store.get("user_profile")

        try:
            result = await self.inventory_agent.run(
                textwrap.dedent(
                    f"""
                    Perform the inventory analysis for the following user profile and the product:
                    User Profile: {user_info}
                    Product id: {product_id}
                    """,
                ),
                timeout=settings.INVENTORY_AGENT_TIMEOUT,
            )
        except WorkflowTimeoutError:
            logger.info("Inventory Agent has timed out.")
            result = "Inventory agent timed out. No response"

        return InventoryCompletedEvent(result=str(result))

    @step
    async def presentation(
        self,
        ctx: Context,
        ev: (
            ProductPersonalizationCompletedEvent
            | ReviewsCompletedEvent
            | InventoryCompletedEvent
        ),
    ) -> StopEvent:

        trace_id = get_current_span().get_span_context().trace_id

        triggered_agents = await ctx.store.get("triggered_agents")
        result_current_agents = ctx.collect_events(
            ev,
            triggered_agents,
        )
        if result_current_agents is None:
            return None

        events_response = self._structure_events_response(result_current_agents)
        existing_personalized_section = await self._get_existing_personalized_section(
            ctx,
        )

        user_msg = await ctx.store.get("user_msg")

        result = await self.presentation_agent.run(
            textwrap.dedent(
                f"""
                Here is the previous response and the current response. Synthesize and merge the
                information intelligently.
                previous_response={existing_personalized_section}
                current_response={events_response}
                user_query={user_msg}""",
            ),
        )

        extracted_json = extract_json_blocks(str(result))
        extracted_json = json5.loads(extracted_json[0]) if extracted_json else {}

        response = PersonalizationSection(**extracted_json)

        personalization_response = await self._normalize_workflow_response(
            ctx,
            response,
            trace_id,
        )

        return StopEvent(result=personalization_response)

    def _structure_events_response(self, events):
        """
        Structure the event responses into a dictionary.
        """
        return {event.__class__.__name__: event.result for event in events}

    async def _setup_workflow_context(self, ctx: Context, ev: StartEvent):
        async with Session() as db:
            user = await UserRepository(db).get_by_id(ev.user_id)
            product = await ProductRepository(db).get_by_id(ev.product_id)
            variants = await VariantRepository(db).get_variants_by_product_id(
                ev.product_id,
            )

        if hasattr(ev, "user_msg") and ev.user_msg:
            await self._update_user_memory(ev.product_id, ev.user_id, ev.user_msg)
        user_preferences = await self._get_user_preferences_from_memory(ev.user_id)

        user_info = UserSchema(**user.to_dict()).model_dump()
        user_info["user_preferences"] = user_preferences
        product_info = ProductSchema(**product.to_dict()).model_dump()
        variants_info = format_variants(variants)

        await ctx.store.set("user_id", ev.user_id)
        await ctx.store.set("product_id", ev.product_id)
        await ctx.store.set("user_msg", ev.user_msg)
        await ctx.store.set("user_profile", user_info)
        await ctx.store.set("product_information", product_info)
        await ctx.store.set("product_variants", variants_info)

    async def _get_user_preferences_from_memory(self, user_id: int) -> list[str]:

        search_results = await self.memory.search(
            query="User's specific preferences, likes, dislikes, past interactions, and shopping behavior patterns?",
            filters={"user_id": str(user_id)},
        )

        user_preferences_messages = search_results.get("results", [])

        user_preferences = [
            message.get("memory") for message in user_preferences_messages
        ]
        logger.info("Fetch user preferences: %s", user_preferences)
        return user_preferences

    async def _update_user_memory(self, product_id: int, user_id: int, user_msg: str):
        results = await self.memory.add(messages=user_msg, user_id=str(user_id))
        logger.info("Update user memory: %s", results)
        if len(results.get("results", [])) > 0 and self.message_queue:
            await send_stream_event(
                {"message": "Memory updated!"},
                EventType.MEMORY.value,
                product_id,
                self.message_queue,
            )
            logger.info("Memory Updated")

    async def _get_existing_personalized_section(self, ctx) -> Optional[dict]:
        user_id = await ctx.store.get("user_id")
        product_id = await ctx.store.get("product_id")
        existing_personalized_section = None

        async with Session() as db:
            pp_repository = PersonalizedProductRepository(db)
            try:
                existing_personalized_section = await pp_repository.get_by_id(
                    id=(product_id, user_id),
                )
                if existing_personalized_section:
                    existing_personalized_section = (
                        existing_personalized_section.to_dict().get("personalization")
                    )
            except Exception as e:
                logger.error(
                    "Error fetching existing personalized section: %s",
                    str(e),
                )

        return existing_personalized_section

    async def _normalize_workflow_response(
        self,
        ctx: Context,
        agent_response: PersonalizationSection,
        trace_id,
    ) -> dict:

        agent_response = {
            "personalization": agent_response.model_dump().get(
                "personalization",
                {"personalization": []},
            ),
            "trace_id": convert_trace_id_to_hex(
                trace_id,
            ),
        }
        return agent_response
