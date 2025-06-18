# Preparations and Requirements

This section explains the environment and points to check before starting the hands-on. It is assumed that participants have **basic knowledge of PostgreSQL** and **experience in AI application development on Azure**. With that in mind, let's complete the installation of necessary software and the setting of Azure subscription in advance.

## What you need for the hands-on
- **Azure Subscription**: You need a valid Azure subscription (with owner or resource creation rights). To use the Azure OpenAI service, make sure that access to this service is included in your subscription (application may be required depending on the case).
- **CloudShell**: If it is difficult to prepare a development machine, you can also execute the hands-on in the CloudShell of the Azure portal. Please execute `az extension add --name rdbms-connect` in advance.
- **Development machine and internet connection**: You need a PC (Windows, macOS, Linux are all acceptable) to conduct the hands-on and a stable internet connection. Make sure that a terminal/command prompt is available in your local environment for using Azure CLI, etc.

## Software to install in advance

If you are using a development machine instead of CloudShell, please install the following software in advance. We recommend the latest stable version as much as possible.

- **Azure Developer CLI (`azd`)**: This is a CLI tool for Azure developers. For installation instructions, please refer to [How to Install Azure Developer CLI](https://learn.microsoft.com/ja-jp/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-linux).

- **Azure CLI**: This is a command line tool for Azure. For installation instructions, please refer to [How to Install Azure CLI](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli?view=azure-cli-latest). If you have already installed it, check the version (`az --version`) and update it if necessary.

- **Azure CLI Extension (rdbms-connect)**: This is an extension that adds temporary tunneling connections to PostgreSQL servers, etc., to Azure CLI. Install it with `az extension add --name rdbms-connect`. After installation, confirm that it is enabled with `az extension list`.

- **PowerShell Core (Windows users only)**: This is necessary when running Linux-oriented scripts on Windows. Please install [PowerShell 7.x (Core)](https://learn.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5) in advance.
After installation, execute the following command to confirm that bash is working.
```sh
bash --version
```
If an error occurs, please set up an environment where bash can work, such as installing WSL.
```sh
wsl --install
```

After installation, make sure that each command is in the path. For example, if you execute `azd version` or `az --version` and the version information is displayed, you are ready.

## Criteria for selecting Azure region

The resources to be deployed in this hands-on include Azure Database for PostgreSQL and Azure OpenAI services. It is important to select a region where **Azure OpenAI** is available, as the regions where this service can be used are limited. Also, some extensions in **Azure Database for PostgreSQL (such as Apache AGE mentioned later)** are preview features supported on newly created servers. When executing Azure Developer CLI (`azd`), you will be asked for two regions: one for infrastructure resources and one for Azure OpenAI. As a rule, choose a region that meets the following conditions.

- **Azure OpenAI compatible region**: Specify a region where you can create Azure OpenAI resources, such as East US, South Central US, West Europe, Japan East, etc. Please check in advance whether your subscription allows the creation of OpenAI services in the region.

- **Location close to the database**: From a performance perspective, it is desirable to choose a region for Azure OpenAI that is physically close to the region where Azure Database for PostgreSQL is located. For example, if you create a DB in the Japan East region, you will choose Azure OpenAI in the Japan East or a nearby region (however, compromises may be necessary because the OpenAI service is limited).

- **Regions confirmed to work with CloudShell**: The following regions have been confirmed to work by deploying with CloudShell.
 - Japan East (took 30 mins)
 - Australia East (took 15 mins)
 - South India (took 16 mins)
 - Korea Central (Failed due to lack of text-embedding-ada-002)

- **Use of preview features**: The Apache AGE extension is available on newly created PostgreSQL servers and cannot be enabled on existing servers. `azd up` automatically creates a new PostgreSQL server, but for peace of mind, check the Azure Portal for any mention of using preview features.

## Check quota

To use the Azure OpenAI service, a usage limit (quota) for each model must be allocated to your subscription. In particular, the **GPT-4o** model and **Embedding** model used in this hands-on require relatively large request quotas. The default configuration requires the following throughput.

- **GPT-4o model**: Processing capacity of about 150k tokens per minute (150K TPM). The "Model Usage Limit (Requests per minute)" of Azure OpenAI must meet this requirement.

- **text-embedding-ada-002 (embedding model)**: About 120k tokens per minute (120K TPM).

You can check the OpenAI quota of your Azure subscription on the "Quota + Limit" page of the Azure Portal or with the `az openai admin quota show` command. If you are short, please request a limit increase when creating the Azure OpenAI resource.

> [!NOTE] Note
> The deploy capacity (default value) of the above models is also set as a parameter in the prompt at the time of `azd up` execution. If necessary, you can adjust the deploy scale of GPT-4o and the embedding model by editing `infra/main.parameters.json` in the repository (e.g., lowering TPS to save quota).

[Previous](01-Introduction.md) | [Next](03-Integration.md)
