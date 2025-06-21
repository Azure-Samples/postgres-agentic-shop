# AgenticShop: re-Imagined Shopping Experience for the Era of AI Agents
This repository showcases the power of agentic flow with llama index leveraging the functionality of multi-agent workflow. The solution has been developed to experience the enhanced shopping experience for individuals having keen interest in purchasing electronic gadgets. It is a one-click solution which is easy to test and deploy with the help of Azure developer cli. Refer to the architecture diagram for complete layout:

- [Key Features](#key-features)
- [Architecture Diagram](#architecture-Diagram)
- [Solution Accelerator Deployment](#solution-accelerator-deployment)
- [Tear Down](#tear-down)
- [Development Methods](#development-methods)

## Key Features
Retail solution accelerator provides the following features:
- Personalized product details based on user profile
- Elevated user experience
- Multi Agent Workflows allows seamless handling of multiple tasks
- Debug panel using Arize Phoenix tracing for agent triggers and tracking

## Architecture Diagram
![AZURE ARCHITECTURE](https://github.com/user-attachments/assets/f3ca0e0d-0c93-4c0f-be5d-958eace3a138)

## Solution Accelerator Deployment

### CloudShell
This solution is designed to be deployable via CloudShell. If you prefer to deploy from your local development machine, please follow the steps below.

### Prerequisites
The following serve as prerequisites for deployment of this solution:
1. [Azure Developer Cli](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-linux)
2. [Azure Cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
3. [Azure Cli extension](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview) `rdbms-connect`
4. An Azure account with an active subscription.
5. [Python 3.8+](https://www.python.org/downloads/)
6. [Powershell Core](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5) (for windows users only)

### Deployment Steps
Note: This version of the infrastructure works and successfully deploys the working solution. However, certain modules are still in progress such as Azure Key Vault, Azure App Config etc as well as some best practices.
These modules and best practices will be finalized and implemented soon.

### Clone Repository
Clone the repository. Once done, navigate to the repository
```sh
git clone https://github.com/EmumbaOrg/retail-solution-accelerator.git
cd retail-solution-accelerator
```

### Login to your Azure account
To login to azure cli, use the following command:
```sh
az login
```
To login to azure developer cli, use this command:
```sh
azd auth login
```
If the above command fails, use the following flag:
```sh
azd auth login --use-device-code
```

### Create new azure developer environment
Initialize and create a new `azd` environment. Provide a name for your `azd` environment
```sh
azd init
```

### Grant permissions to azd hooks scripts
If you are deploying the solution on Windows OS, grant the following permissions to the current session to execute `pwsh` scripts
```sh
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
If you are deploying a unix-like environment on windows OS (for instance cygwin, minGW), grant the following permissions to the current session to execute `pwsh` scripts
```sh
pwsh -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass"
```

### Solution Deployment
Run the following command to provision the resources.
```sh
azd up
```

Once this command is executed, the prompt asks for subscription for deployment, two locations i.e. one for location of solution accelerator resources and other for location of Azure OpenAI models and the resource group to create.
Make sure that you have enough Azure OpenAI model quota in the region of deployment. The Azure OpenAI quota required for this solution is listed below. This configuration can be changed from `main.parameters.json` file in `infra` directory using following parameters. The deployment might take some time and will provide progress of deployment in terminal as well as on Azure Portal.
- **GPT-4o:** 150K TPM - `AZURE_OPENAI_CHAT_DEPLOYMENT_CAPACITY`
- **text-embedding-ada-002:** 120K TPM - `AZURE_OPENAI_EMBED_DEPLOYMENT_CAPACITY`

### Troubleshooting
1. Troubleshooting guide for `azd cli` is [here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/troubleshoot?tabs=Browser).
2. Validation error occurs when unsupported characters are used while initializing or creating a new env.
3. Scope error occurs when user does not have appropriate permissions when running `azd cli`. Update user permissions to subscription level.
4. When `The resource entity provisioning state is not terminal` error occurs, restart the deployment using `azd up` command.

## Tear Down
To destroy all the resources that have been created in the step above as well as remove any accounts deployed by the solution accelerator, use the following command:
```sh
azd down --purge
```
The purge flag deletes all the accounts permanently.

### Personalization Workflow
Following is the LlamaIndex workflow generated via it's visualization tool:
![Screenshot](./workflow.png)
