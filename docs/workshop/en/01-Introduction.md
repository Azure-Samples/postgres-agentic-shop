# Introduction

**AgenticShop** is a solution accelerator that demonstrates a multi-agent retail experience utilizing Azure Database for PostgreSQL. The application in this repository is a demo that enhances the shopping experience for electronic gadgetry with AI, positioned as hands-on material that can be deployed with one click on Azure. The term "Agentic" in the application name refers to applications where multiple AI agents interact and collaborate to accomplish tasks. Agents using Large Language Models (LLMs) autonomously plan and meet user demands while using tools such as databases and APIs as needed.

An explanation of this solution accelerator is [available in video](https://build.microsoft.com/en-US/sessions/BRK211).

## Application Architecture

The overall architecture of this solution consists of a frontend, backend, database, and AI services. The frontend provides a shopping UI to the user, and the backend executes the AI agent's workflow. In the backend, a Python-based agent orchestrator (using the LlamaIndex library) operates, and multiple tasks such as data retrieval from Azure Database for PostgreSQL and inquiries to Azure OpenAI service are processed sequentially by the agent. In addition, a tracing feature called **Arize Phoenix** is incorporated for debugging and analysis of the application, allowing visualization of the internal operation of the agent (what queries were issued and what answers were obtained). Azure Database for PostgreSQL plays a crucial role in performing **intelligent query processing** using extensions (AI, vector, graph features) beyond just being a data store.

## Features and Implementation of Agentic Applications

The biggest feature of this application is that multiple AI agents collaborate to provide personalized shopping information to the user. For example, one agent selects products that seem to match the user's profile, another agent performs database searches for product information (converting natural language queries to SQL and performing vector searches), and yet another agent handles review summaries and feature extraction. This multi-agent workflow enables personalized product detail presentation and advanced user experience. The mediation between agents and the flow of tasks are controlled by LlamaIndex, and the LLM is implemented to select the appropriate action (inquiries to the database or handovers to other agents) at each step. Overall, AgenticShop is an example of a next-generation application construction method where AI agents operate autonomously in the backend, and it is built and experienced on Azure.

## Key Features

This solution accelerator has the following features:
- **Product detail presentation based on user profiles**: Relevant product information and descriptions are automatically generated and displayed according to each user's attributes and preferences.
- **Improved user experience**: Provides a richer experience than traditional online shopping sites through AI-powered chatbot-like interactions, summary displays, and recommendations.
- **Multi-agent workflow**: Multiple agents collaborate to perform multiple tasks such as search, summary, and recommendation, achieving seamless processing.
- **Visualization with a debug panel**: There is a trace function for agent operation using Arize Phoenix, and you can check how the agent was triggered and what response it generated.

That's an overview. In this hands-on, we will deploy the AgenticShop application with the above features on Azure, and while experiencing its functions, we will learn about the internal processes.

[Previous](00-Prerequisites.md)
