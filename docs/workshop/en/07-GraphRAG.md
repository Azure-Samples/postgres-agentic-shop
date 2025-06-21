# GraphRAG Integration

## Knowledge Graph Construction with GraphRAG (Graph Extraction)

As part of GraphRAG, the backend of AgenticShop constructs a knowledge graph from product reviews. Specifically, we introduce the Apache AGE extension to PostgreSQL, and construct a graph that represents products and their features (functions) as nodes, and the relationships mentioned in reviews as edges. This process is executed in create_apache_age_graph.py, where the create_graph function of AGE is used on PostgreSQL to generate a graph (creating a graph schema for retail). In addition, generate_sentiments_for_reviews.py analyzes positive/negative mentions for specific features in each review, and stores this in the database in a form that can be utilized as edge information in the graph. In other words, we assign attributes such as the number of times a feature is mentioned in a review and the sentiment (positive/negative) to the edges connecting the product nodes and feature nodes, and construct a knowledge graph of product-feature relationships within the database. Through this graph extraction process, we extract relationships between products (common features and review ratings) from unstructured text as structured data. This allows the backend to use PostgreSQL as both a relational DB and a graph DB, enabling complex relationship queries.

## Graph Integration and Cypher Query with Apache AGE

Through the Apache AGE extension, the backend can execute Cypher queries (OpenCypher language) on PostgreSQL. In Alembic migrations, we execute CREATE EXTENSION age and SELECT * FROM create_graph('graph_name') to create a graph schema within PostgreSQL. Also, product/feature node and edge insertions are executed from SQL. For example, from the feature list (features.csv) and the analysis results of reviews, we insert edges that represent "Feature X was mentioned positively" for each product using the MATCH ... CREATE statement. Apache AGE allows hybrid queries that call Cypher queries in the FROM clause of SQL, and we are utilizing this in this project. In fact, with the integration of PostgreSQL and AGE, we can issue queries that combine traditional SQL filters and graph queries. For example, we can execute a process like "Find products with many positive mentions about a certain feature from a specific group of products" in a single SQL+Cypher hybrid query. The advantage of Apache AGE integration is that it is not necessary to place the knowledge graph for LLM in another graph DB, and we can consistently operate relational data and graph data within PostgreSQL.

Specifically, we execute SQL with Cypher functions in the service layer of the backend. For example, in product filtering based on features and sentiments, we construct a query internally as follows (pseudo code):

```sql
SELECT p.id, g.count
FROM products p
JOIN LATERAL cypher('retail_graph', $$
  MATCH (p:Product)-[m:MENTION {sentiment: "positive"}]->(f:Feature {name: "<feature name>"})
  RETURN COUNT(m) as count
$$) AS g(count)
ON g.count > 0
WHERE p.category = '<category>'
ORDER BY g.count DESC;
```

As shown above, we incorporate cypher('graph_name', $$ ... $$) into the SQL statement of PostgreSQL, calculate the number of edges in the graph, and incorporate the results into the relational query. This combination of OpenCypher queries and SQL allows for searches that consider both normal filters (e.g., category) and indicators on the graph structure (e.g., mention count) at the same time.

## Utilization of GraphRAG at Runtime (Graph Query Generation)

When there are questions or requests from end users, the backend generates graph queries and conducts information retrieval using the knowledge graph. In the GraphRAG algorithm, this corresponds to the step of "generating a graph query and using it as context information for LLM". AgenticShop issues appropriate graph queries according to the content of the user's query and profile. For example, when a user asks "Which smartphone has high ratings for battery life?", the UserQueryAgent in the backend performs the following process.
1. Retrieve product candidates in the relevant category using vector search (similarity search using pgvector).
2. Graph query generation: For the candidate product group, construct a Cypher query that calculates the "number of positive reviews for the specified feature". This is implemented in a function called fetch_product_with_feature_and_sentiment_count, which takes a list of product IDs, sentiment type, and feature name as arguments and executes the graph query. This function issues Cypher+SQL as mentioned above and retrieves the number of positive mentions for that feature for each product.
3. Ranking of results: Based on the mention count for each product, rearrange the product list (the more mentions, the higher the ranking as a product with high ratings for that feature). The aim of GraphRAG is to improve search accuracy by utilizing the signal of **"prominence"** (importance) on the graph, and in this case, the "number of positive reviews" serves as a prominence indicator.
4. Providing context to LLM: Finally, select the top N products and generate a text summarizing the review content related to each product (see the agent workflow below). At this time, the products and reviews with high importance selected by GraphRAG are given to LLM as context, making it easier to obtain accurate answers that align with the user's question intent.

In the code, you can check the above logic in the UserQueryAgent.query_reviews_with_sentiment method. The following is an excerpt from it, showing the part where the graph query function is called when a feature is specified.

```python
if feature:
    product_ids_for_query = [product.id for product in results]
    product_ids_with_count = await self.fetch_product_with_feature_and_sentiment_count(
        product_ids_for_query, sentiment, feature[0]
    )
    # (Filter/sort the product list using the returned product_ids_with_count)
```

Here, feature[0] indicates the feature name (e.g., "battery"), and product_ids_for_query is a list of target product IDs. This function call aggregates the mention count of the specified feature for the relevant product group on the graph database, and the result is stored in product_ids_with_count. In the subsequent process, this information is used to rearrange the product objects in results and determine the top products for the answer.

## Utilization of Graph in Multi-Agent Workflow

AgenticShop adopts a multi-agent flow based on LlamaIndex, and also utilizes the results of GraphRAG for post-processing of search results and summary generation. In the backend's multi_agent_workflow.py, the function run_workflows_in_background launches additional processing by agents as a background task. In this workflow, based on user-specific profile information and knowledge obtained from graph queries, LLM generates detailed descriptions of each product and summary of reviews. Specifically:
- Personalized summary: According to the user's preferences (features and points of interest in the profile), it extracts and summarizes relevant points from the reviews of each product. The product-feature graph constructed with GraphRAG serves as a guide to which products are highly rated for the user's interest features. Using this guide, the agent finds relevant reviews from vector search (vector_store_reviews_embeddings) and the graph, and passes them to LLM. For example, for a user who values "battery life", the workflow identifies products with many positive reviews for that feature via the graph, and focuses on summarizing the content of those reviews.- Instructions in the prompt: If you look at backend/src/agents/prompts.py, it contains instructions to the agent such as "Summarize insights from the review most relevant to the user's preferences". Furthermore, it includes detailed guidelines to improve output quality, such as "Do not summarize the user's preferences themselves, but rather mention the product" and "Ignore preferences unrelated to the product category". These are prompts designed for the LLM to appropriately select and discard information, based on the graph structure obtained from GraphRAG. For example, features determined to be irrelevant on the graph (e.g., sound quality is irrelevant to a smartwatch) are instructed not to be included in the summary.

As such, the graph structure is utilized in both information retrieval and summarization. In the search stage, candidates are ranked based on scores obtained from the graph (e.g., mention count of features), and in the summarization stage, relevant review content is extracted according to the relevance indicated by the graph.

## Role and Advantages of GraphRAG in the Architecture

In AgenticShop, GraphRAG functions as a core technology to sophisticate the backend information retrieval pipeline. Its roles and benefits are as follows.
- Improvement in accuracy and ranking enhancement: Simple vector search only evaluates text similarity, but with GraphRAG, relationships on the knowledge graph can be considered. For example, information such as "many reviews" and "highly rated for a certain feature" are important signals obtained from the graph. In the case of Legal Copilot, the number of times a precedent was cited was used as a prominence indicator to improve accuracy, while in AgenticShop, the number of positive reviews for a feature is reflected in the ranking as a similar indicator. This ensures that more appropriate products (superior from the user's perspective) rank higher in response to user queries. In fact, it has been reported that the introduction of GraphRAG has dramatically improved the accuracy of the information retrieval pipeline (such as improved recall).
- Fusion of relational data and graph data: Since GraphRAG operates within PostgreSQL, it can handle relational information such as user profiles and product masters, and graph information derived from reviews in a unified manner. This simplifies the system configuration and eliminates the need to synchronize with an external graph DB. In the architecture of AgenticShop, Azure Database for PostgreSQL alone handles vector search (pgvector), full-text search, and graph search, offering significant advantages in terms of data consistency and manageability.
- Improvement in LLM response quality: The context provided by GraphRAG (context based on the knowledge graph) makes the LLM's response content more reliable. For example, for product features of interest to the user, the LLM can generate specific and valid responses by presenting "substantiated information (review ratings and frequently mentioned benefits)" obtained from the graph. This directly connects to the purpose of RAG, which is to suppress hallucinations and improve accuracy. In AgenticShop, the agent collects information across multiple knowledge sources (vector DB, graph DB) to provide useful responses (product recommendations and explanations) that better match user intent.

In summary, the concept of GraphRAG is technically incorporated into the backend directory of the AgenticShop backend, and by building a knowledge graph with Apache AGE and utilizing Cypher queries, and supplying graph information to the LLM agent, it significantly improves the accuracy of multi-agent AI responses and user experience. GraphRAG is the keystone of this solution architecture, providing a foundation for easy advanced search and inference using graph data in future expansions. This approach of utilizing graphs that model various retail domain-specific relationships (product-feature-review-user preference) brings out insights that could not be obtained with traditional RAG methods, and ultimately enhances the quality of responses to end users.

[Previous](06-WhyPostgreSQL.md) | [Next](08-Wrapup.md)
