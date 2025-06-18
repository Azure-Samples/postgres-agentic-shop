# Points to Check After Provisioning

Once the deployment is complete, check that the built resources and applications are working correctly. This section explains the **main resources to check on the Azure portal**, their **roles**, and **how to check the operation of the application**.

## Main Azure Resources and Their Roles

Within the deployed resource group, there should be major components as follows. Understand the role of each resource and its role in this hands-on application.

- **Azure Database for PostgreSQL (Flexible Server)**:
Role: Data store for the application. It stores relational data (users, products, reviews, etc.) and performs AI processing, vector search, and graph analysis using `azure_ai`, `pgvector`, and `Apache AGE` extensions.

What to check: In the "Azure Database for PostgreSQL" section of the Azure portal, confirm that a new server has been created. In Settings -> Server Parameters, check that `azure.extensions` includes `azure_ai`, `vector`, and `age`, and that the connection information (hostname, username, etc.) is as expected. The database should be loaded with initial data such as product and review information (external service connection information such as Arize may also be included in the table).

- **Azure OpenAI Resource**:
Role: A cognitive services resource that hosts models such as GPT-4. It responds to calls via `azure_ai` from PostgreSQL and API calls from backend code.

What to check: Open the relevant resource from "Azure OpenAI" on the portal and check the deployment status of the model (in the "Model Deployment" menu, it's okay if, for example, `gpt-4o` or `text-embedding-ada-002` is in Deploy state). Also, you can later verify that the key and endpoint URI match those set on the PostgreSQL side.

- **Backend App (Container Apps)**:
Role: A hosting environment where Python application logic is deployed. It receives requests from users (e.g., product search queries), queries the database as needed, and launches LLM agents to generate responses. It is the central entity where multi-agent orchestration takes place.

What to check: Check the Container Apps on the portal and look for the newly created resource. Enabling "Log Stream" is also useful to see if logs are output during the app test mentioned later.

- **Frontend App (Container Apps)**:
Role: Hosts the user interface. Users enter search queries and view results through this frontend. Calls to the backend API from the frontend also take place here.

What to check: In the case of Static Web Apps, open the target resource on the portal and check the "URL". This URL will be the URL of the web app used in the operation check mentioned later. In the case of static site hosting on a Storage account, the endpoint domain is displayed. Try accessing these to see if the page is displayed.

The application will only work when all of these resources are in place. Understanding each role makes it easier to decide which component to investigate if a problem occurs.

## Checking the Operation of the Application

Once the resource deployment is complete, let's check if the application (AgenticShop) is working as expected. I will explain the points to check in order.

1. **Access to the frontend**: Open the frontend URL (e.g., `https://rt-frontend.<random name>.japaneast.azurecontainerapps.io`) in your browser. The top page of AgenticShop should be displayed. The screen has a search bar and a chatbot-like UI. The design is modeled after an electronics gadget shopping site.

> [!NOTE] Note
> If the backend does not switch from the connecting display even when accessing the frontend, the backend may not be starting up properly. In this case, stopping and restarting the backend should make it work properly.

2. **Display of product information**: Try some operations on the app. For example, select a product category and check if the product list and recommended products for that category are displayed. AgenticShop has a personalization feature based on user profiles.

3. **Search and AI response**: Try entering a question in the search bar (e.g., "Do you have headphones with good sound quality and long battery life?"). When you enter and send, the LLM agent operates in the backend, retrieves products and reviews with vector search from PostgreSQL, and generates a summary/response with Azure OpenAI, executing a series of flows. As a result, a list of relevant products and descriptions should be displayed on the screen, and you should get output like "The recommended headphones are ○○. It is... (reason)" as a chatbot response. Let's also check the effect of reranking. When you ask the same question, verify whether more relevant results are obtained compared to simply keyword searching (for example, whether mentions of noise cancellation are properly evaluated).

4. **Verification of graph function**: Try some complex questions. For example, "Are there headphones that are light, have a waterproof function, and have high sound quality review ratings?" This question combines product spec features (lightweight = design feature, waterproof = functional feature) and review content (highly rated for sound quality). In AgenticShop, to answer such questions in the database, product and review features are graphed, and the results are narrowed down with the addition of LLM's judgment. On the screen, you would expect the top 3 relevant products to be listed, with a summary of each product's features and a summary of reviews. If you actually get such results, it's proof that Graph + AI is working correctly.

5. **Checking the debug panel (optional)**: If the Arize Phoenix debug panel function is included, there may be buttons or links such as "Debug" or "Trace" on the UI. Opening it may allow you to list the internal operation logs of the agent (for example, what kind of query was issued at each step, what kind of response was obtained, how confident it was, etc.). If this panel is available, it will make it easier for hands-on participants to follow the flow of the agent, so please check it together.

In this way, test each function while actually operating the application to see if it is working as expected. In particular, whether the role of the database is being properly fulfilled (whether the vector search results are reasonable, whether graph queries are being used) can be confirmed by looking at the "Query Performance Insight" on the Azure Portal or the `pg_stat_statements` extension. If you're interested, also take a look at the backend logs (for example, Log Stream or Application Insights logs if you're using App Service). The prompts and responses thrown to Azure OpenAI, any errors and their contents, etc., should be recorded.

[Back](05-Provisioning.md) | [Next](07-WhyPostgreSQL.md)