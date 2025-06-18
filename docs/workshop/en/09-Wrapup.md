# Deleting Provisioned Resources

Once the hands-on is over, be sure to delete any resources that are no longer needed. Leaving resources created on Azure could potentially incur unexpected costs. Here, we introduce a cleanup procedure using Azure Developer CLI.

## Procedure for Deleting Resources

In Azure Developer CLI, there is a command to delete the deployed environment in bulk. Especially in cases like this time where resources are created by resource group, you can delete the resource group and all resources in it together.

- **Execution of the delete command**: In the project directory (`postgres-agentic-shop`), execute the following command.

```sh
azd down --purge
```

This will delete all resources created by `azd up`. By adding the `--purge` option, all resources, including "account" resources like Azure OpenAI, will be completely deleted. While a normal `azd down` only deletes within the resource group, adding `--purge` will undeploy the model from OpenAI resources and then delete the resources. It may take a few minutes to delete, but when it's done, a message like "Delete Successful" will be displayed.

- **Confirmation of deletion results**: Just to be sure, check the list of resource groups on the Azure portal and confirm that the relevant resource group has disappeared. The `azd` environment is also recorded locally, but if you don't reuse it, you can delete the `.azure` directory.

- **Alternative method**: If you do not use Azure Developer CLI, you can manually delete the resource group from the Azure portal. In that case, only the Azure OpenAI resource may exist outside the resource group, but this time it should be created in the same RG, so you can expect to delete it in bulk. When deleting a resource group from the portal, there is a confirmation of the resource group name, so please follow the instructions.

> [!CAUTION] Warning
> Once you delete, all data in the database, connection information, logs, etc. will be lost. If you have any deliverables (e.g., exported feature data or analysis results) during the hands-on, please back them up in advance. However, there is no data to be retained in this hands-on, so you can delete it as it is.

With this, the cleanup is complete. The habit of not leaving unnecessary resources on Azure is very important for cost management, so be sure to perform this procedure at the end of the hands-on.

This concludes all the steps of the AI integrated application development hands-on on Azure using the GitHub repository postgres-agentic-shop.

Good job!

As you learned this time, by combining AI extensions, `pgvector`, and Apache AGE with Azure Database for PostgreSQL, you can build a simple yet powerful AI application platform. Please try to apply it in your actual projects. If you want to dig deeper into the technical elements touched on in each section, referring to official documents and related blog articles will deepen your understanding.

[Back](08-GraphRAG.md)