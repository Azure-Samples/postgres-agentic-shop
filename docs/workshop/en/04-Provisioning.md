# Resource Provisioning with Azure Developer CLI

The repository cloned locally contains settings for deploying infrastructure and application code on Azure. Here, we will use the **Azure Developer CLI (azd)** to provision the necessary Azure resources and deploy the application. The process takes approximately 20-30 minutes, but this may vary depending on the status of Azure resource creation.

## Provisioning with the `azd up` command

With the Azure Developer CLI, you can execute everything from infrastructure construction to deployment with a single command. Let's proceed with the following steps.

1. **Confirm login to Azure CLI (not necessary in CloudShell)**: You have already installed Azure CLI in the preliminary preparation, but check the login status just in case. Run `az account show` on the terminal, and if the subscription information is displayed, you are logged in. If you are not logged in, execute `az login` and complete browser authentication. In addition, `azd` itself also requires authentication to Azure, so execute `azd auth login` (the browser will automatically start and the Azure authentication screen will be displayed. If it does not work, use `azd auth login --use-device-code`).

2. **Grant execution rights to the shell script**: When deploying on Windows, you may get an error about the script execution policy in PowerShell. You can temporarily bypass this with the following command.

```sh
PowerShell -ExecutionPolicy Bypass -Scope Process
```

3. **Execute deployment**: Once prepared, finally execute the `azd up` command. This command automatically performs the following processes.

- Create a resource group and various necessary resources on Azure using the Bicep template (inside the `infra` directory).
- Execute the post-deploy script (`azd-hooks/predeploy.sh`) for the created resources, enabling database extensions and writing Azure OpenAI settings.
- Build the application code (backend/API and frontend) and deploy it to the specified Azure services (e.g., App Service, Static Web Apps, etc.).

4. **Input to the prompt**: When you execute `azd up`, you will be asked for some inputs at first. Specifically, these are "Azure subscription to deploy to", "Azure region (location) to deploy to", "Deployment region for Azure OpenAI model", etc. Here, please select the region you considered in the previous section. For Azure OpenAI, only available regions will be candidates. You may also be asked for the name of the resource group to be created. Please enter as appropriate.

> [!CAUTION] Warning
> A warning about the OpenAI model quota may be displayed. If you get a message like "There is not enough GPT-4o TPM in the specified region", you need to change the settings or the region to meet the quota conditions mentioned above.

5. **Monitor deployment progress**: When you execute the command, the progress of each step is displayed on the terminal. Internally, resources are built sequentially while tracking the state like Terraform. In particular, it takes several minutes to build Azure Database for PostgreSQL and Azure OpenAI resources. Please wait patiently. If you open the Azure Portal and check the resource group, you can confirm that the resources are increasing in real time.

6. **Confirm deployment completion**: When all processes are completed, `azd` displays an overview of the deployment results. If successful, the endpoint URLs and names of the deployed services should be listed (for example, the URL of the web application).

## Description of the main resources created by provisioning and each step

Here is a brief explanation of the main Azure resources that are automatically built and deployed by `azd up`, and each step within the provisioning process.

- **Resource Group**: A new one is created with the specified name. It is a container that groups all the resources for the entire hands-on.

- **Azure Database for PostgreSQL – Flexible Server**: A PostgreSQL database server is created. This is the core database of this project, storing table data such as product information and reviews, as well as vector and graph data by extensions. The SKU, storage size, admin username, etc. are defined in the Bicep template (the default should be a cheap plan).

- **Azure OpenAI Service**: An Azure OpenAI resource for using GPT-4 and Embedding models is created. The model name and SKU are also automatically set at deployment. For example, GPT-4o and text-embedding-ada-002 are deployed. This allows you to send requests from the database to Azure OpenAI.

- **Container Apps**: Compute resources for hosting the backend application code are created. There are APIs written in Python (agent orchestration logic) and frontends written in TypeScript/JavaScript. Azure Developer CLI builds and deploys the appropriate hosting destination based on the service definition written in `azure.yaml`.

- **Connection settings & secrets**: Connection information between the built resources (for example, the database connection string, OpenAI API key, etc.) is incorporated into the application settings by Azure Developer CLI. If you want to further enhance security, consider using Azure Key Vault.

- **Extension setup**: After the PostgreSQL server starts, the `azd-hooks/predeploy.sh` script is executed. In this script, the execution of the `CREATE EXTENSION` statement mentioned in the previous section and the registration of the Azure OpenAI endpoint and key in the database by calling the `azure_ai.set_setting` function are performed. The `rdbms-connect` extension of Azure CLI plays an active role here, connecting to PostgreSQL and executing SQL in the script with the `az postgres flexible-server connect` command.

- **Post-deployment processing**: When the infrastructure construction and application placement are finished, Azure Developer CLI displays endpoint information as "Deployment completed". For example, "Web app URL: ...", "Azure OpenAI resource name: ..." etc. are output. These are items defined as `output` in `azure.yaml`. Participants can note this information or use it directly in the next verification procedure.

If an error occurs during provisioning, please check the error message. Common problems include validation errors due to unusable characters in the environment name, resource creation being denied due to insufficient Azure permissions, and conflicts with existing resource names. In that case, follow the message or retry by re-executing `azd up`.

> [!NOTE] Troubleshooting
> For general troubleshooting related to Azure Developer CLI, please refer to the [official documentation](https://github.com/Azure-Samples/postgres-agentic-shop).

[Previous](03-Repository.md) | [Next](05-Post-provisioning.md)
