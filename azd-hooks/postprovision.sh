#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v azd >/dev/null 2>&1; then
    echo "ERROR: Azure Developer CLI (azd) is required." >&2
    exit 1
fi

deploy_apps="$(azd env get-value DEPLOY_AZURE_CONTAINERAPPS)"
if [[ "${deploy_apps}" == "true" ]]; then
    echo "Deploying apps..."
    azd deploy
else
    echo "Skipping application deployment as DEPLOY_AZURE_CONTAINERAPPS is set to 'false'."
fi

echo "Skipping extension creation in postprovision (handled by backend container startup)."

db_host="$(azd env get-value POSTGRES_HOST)"
db_user="$(azd env get-value POSTGRES_USERNAME)"
db_password="$(azd env get-value POSTGRES_PASSWORD)"
db_name="$(azd env get-value POSTGRES_DATABASE)"
llm_api_key="$(azd env get-value AZURE_OPENAI_KEY)"
llm_endpoint="$(azd env get-value AZURE_OPENAI_ENDPOINT)"
llm_api_version="$(azd env get-value AZURE_OPENAI_API_VERSION)"
embed_api_version="$(azd env get-value AZURE_OPENAI_API_VERSION_EMBED)"
arize_db_url="$(azd env get-value ARIZE_SQL_URI)"

umask 077
{
    printf 'DB_HOST=%s\n' "${db_host}"
    printf 'DB_USER=%s\n' "${db_user}"
    printf 'DB_PASSWORD=%s\n' "${db_password}"
    printf 'DB_NAME=%s\n' "${db_name}"
    printf 'AZURE_API_VERSION_LLM=%s\n' "${llm_api_version}"
    printf 'AZURE_API_VERSION_EMBEDDING_MODEL=%s\n' "${embed_api_version}"
    printf 'AZURE_OPENAI_API_KEY=%s\n' "${llm_api_key}"
    printf 'AZURE_OPENAI_ENDPOINT=%s\n' "${llm_endpoint}"
    printf 'PHOENIX_SQL_DATABASE_URL=%s\n' "${arize_db_url}"
} > .env
