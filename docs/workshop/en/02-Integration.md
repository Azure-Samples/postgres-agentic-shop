# Integration of AI, Vector, and Graph Features into Azure Database for PostgreSQL

By utilizing Azure Database for PostgreSQL not just as a relational database, but as a platform integrating **AI (Artificial Intelligence), Machine Learning (ML), Vector Search, and Graph Data**, more advanced data search and analysis become possible. This section explains the reasons for this and provides an overview and activation procedures for the various extensions used in this hands-on.

## Overview of Extensions: azure_ai, pgvector, Apache AGE

- **azure_ai extension (preview)**: This is a new feature provided for Azure Database for PostgreSQL's Flexible Server, which allows you to directly call various Azure AI services (such as Azure OpenAI and Azure Cognitive Services) from within the database. This allows you to generate embedded vectors of text, generate and summarize sentences with LLM, and analyze text (such as sentiment analysis and key phrase extraction) within SQL queries. In other words, it is an extension that seamlessly integrates Azure's powerful AI models into PostgreSQL, enabling the **database to directly utilize AI functions**. When you install the azure_ai extension, dedicated schemas (`azure_ai`, `azure_openai`, `azure_cognitive`) are created in the database, and functions to call various AI services are provided there. For example, you can generate embedded vectors with `azure_openai.create_embeddings()`, generate text with LLM with `azure_ai.generate()`, and evaluate the relevance of sentences (re-ranking) with `azure_ai.rank()`.

- **pgvector extension**: This is an extension that adds **vector similarity search functionality** to PostgreSQL as an open source. It allows you to store feature vectors generated from text, images, etc. directly in the database and perform fast Approximate Nearest Neighbor (ANN) searches. With pgvector, you can store and search for embedded vectors in PostgreSQL without using a dedicated vector database product, and it becomes easier to query in combination with other relational data in the RDB. For example, you can use the special operator `<=>` in SQL to calculate the distance (similarity) between vectors, and you can easily write operations such as retrieving the top N records that are closest in distance (i.e., similar in content) to a certain query vector. Azure Database for PostgreSQL supports the pgvector extension, and you can implement the RAG (Retrieval Augmented Generation) pattern with a combination of embedded vectors and Azure OpenAI.

- **Apache AGE extension**: This is an extension that adds graph database functionality to PostgreSQL, called **Apache AGE (Apache Graph Extension)**. By introducing Apache AGE, you can represent and store graph structures consisting of nodes and edges on PostgreSQL, and query graphs using the **openCypher query language**. This allows you to analyze complex relationships that traditionally required a dedicated graph DB like Neo4j, all within a single PostgreSQL. For example, if you register products, users, and reviews as nodes and model relationships (such as "a user purchased a product" or "a review mentioned a product") as edges, you can write advanced queries such as searching for products with features highly rated by a certain user via the graph. With the introduction of Apache AGE to Azure Database for PostgreSQL, **integration of relational and graph data** becomes easier, and the cost of using additional services can be reduced.

By combining these three extensions, Azure Database for PostgreSQL has the following powerful features:

- You can ask LLM questions directly in SQL, generate sentences, and get text analysis results (azure_ai).
- By handling embedded vectors, semantic-based search (search considering synonyms and related contexts) becomes possible (pgvector).
- In addition to traditional row and column data, you can hold data in node and edge format and execute relationship queries such as path search (AGE).

In the scenario of this hands-on (shopping site), we realize all the flow of **vectorizing product descriptions and reviews** for use in search, **re-ranking and summarizing search results using LLM**, and **graphing products, reviews, and feature keywords** to answer complex questions, all on PostgreSQL. The point is that all data is contained within the same PostgreSQL, and AI inference calls can be made at the database layer, resulting in a simple and consistent application configuration.

## Procedure to Enable Extensions

Now, let's outline the procedure to make the above extensions available in Azure Database for PostgreSQL. Each requires **activation (installation) of the extension** on the PostgreSQL server side.

### Procedure to Enable azure_ai Extension

1. **Adding to the Extension Whitelist**: In Azure Database for PostgreSQL, when using custom extensions, you need to register the extension name in the server parameter `azure.extensions`. Using the Azure Portal's "Server Parameters" settings screen or Azure CLI, add `azure_ai` to the whitelist of the PostgreSQL server in question. After adding, check with the `SHOW azure.extensions;` command to see if it has been reflected.

2. **Extension Installation (per DB)**: After setting the whitelist, connect to the target PostgreSQL database and execute the following SQL.

```sql
CREATE EXTENSION IF NOT EXISTS azure_ai;
```

You need to execute the above command for each database (if you want to use it in multiple databases, execute it in each one).

3. **Setting Authentication Information**: Once the `azure_ai` extension is installed, you can use a set of functions to set the endpoint URL and API key for calling Azure OpenAI and Cognitive Services. For example, for Azure OpenAI, you register your Azure OpenAI resource's HTTP endpoint and API key in the database with commands like `azure_openai.set_openai_endpoint('endpoint URL')` and `azure_openai.set_openai_key('key')`. These settings are encrypted and stored in a table in the database, and the various functions of the extension use these settings to call Azure services.

> [!NOTE] Note
> In the deployment script of this repository, after creating the Azure OpenAI resource, the above setting functions are automatically executed and the endpoint and key are registered in PostgreSQL (you do not need to set them manually).

### Procedure to Enable pgvector Extension

1. **Check/Add to Extension Whitelist**: The pgvector extension is an extension derived from the PostgreSQL community. In Azure Database for PostgreSQL, it is often allowed by default, but just in case, check with `SHOW azure.extensions;` to see if the `vector` (※explained later) extension is included. If it is not included, add `vector` to the whitelist in the same way as `azure_ai`.

> [!NOTE] Note
> The extension name is treated as `vector`, not `pgvector`. Please note that you should write `CREATE EXTENSION vector;` on PostgreSQL as well.

2. **Extension Installation**: Connect to the database and execute the following SQL.

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

This will enable the use of `pgvector`. After installation, you can use the vector type (by default, a type specified by the dimension number, such as `vector(1536)`) in the table, and the `<=>` operator becomes available.

3. **Using Vector Similarity Search**: For example, you can write a query to calculate the distance between a vector generated from a user's query sentence and a column storing vectors generated from product descriptions (e.g., `description_emb vector(1536)`). The distance calculation uses the `<=>` operator, with smaller values indicating higher similarity. Detailed usage will be explained in the "Queries for Vectors" section later.### Enabling Apache AGE Extension

1. **Confirming it's a new server**: As mentioned earlier, the Apache AGE extension cannot be installed on existing Azure Database for PostgreSQL servers, and can only be previewed on newly created PG 13-16 compatible servers. No special operation is required for deployment with `azd` as server creation is done automatically, but if you want to manually install it on an existing server, you need to recreate the server.

2. **Adding to the extension whitelist**: Add `age` to the server parameter whitelist. In the Portal, you may be able to switch ON/OFF with a notation like "`AGE (preview)`".

3. **Installing the extension**: Execute the following SQL in the database.

```sql
CREATE EXTENSION IF NOT EXISTS age CASCADE;
```

The `CASCADE` option will also create dependent `ag_catalog` schemas, etc. Once installed successfully, you will be able to use a set of functions for graph operations, especially the `cypher()` function.

4. **Creating a graph**: In AGE, you create a graph within the database and then add nodes and edges. A graph is a logical container name, for example:

```sql
SELECT * FROM ag_catalog.create_graph('shop_graph');
```

You can create a graph named `shop_graph` by calling a function from SQL like this. Then you specify this graph name to create and query nodes and edges.

5. **Executing openCypher queries**: In the AGE extension, you execute Cypher queries with a function call like `cypher('graph name', $$ <Cypher query> $$)`. We will show examples in the later section "Querying Graph Data", but you can call Cypher as a subquery in an SQL statement and handle the result like a table. This makes it easy to join the results of graph queries with relational tables.

By following these steps, you will be able to use AI, vector, and graph functions on Azure Database for PostgreSQL. In this hands-on deployment script, the process to automatically execute these extension activation SQLs at deployment time (`azd-hooks` pre-deployment script) is built in, so participants do not need to manually execute SQL. However, to understand the mechanism, it would be good to check that the `azure.extensions` parameter of the target server is set in the Portal, etc., the extension is installed, and the `azure_ai` and `age` schemas are created in the database.

[Previous](01-Introduction.md) | [Next](03-Repository.md)
