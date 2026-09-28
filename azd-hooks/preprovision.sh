#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v azd >/dev/null 2>&1; then
    echo "ERROR: Azure Developer CLI (azd) is required." >&2
    exit 1
fi

while true; do
    printf "Do you want to deploy Azure Container Apps? (y/n): "
    if ! IFS= read -r answer; then
        echo "ERROR: Unable to read deployment selection." >&2
        exit 1
    fi

    answer="$(printf '%s' "${answer}" | tr '[:upper:]' '[:lower:]')"
    case "${answer}" in
        y|yes)
            deploy_apps=true
            break
            ;;
        n|no)
            deploy_apps=false
            break
            ;;
        *)
            echo "Invalid input. Please enter 'y', 'yes', 'n', or 'no'."
            ;;
    esac
done

azd env set DEPLOY_AZURE_CONTAINERAPPS "${deploy_apps}"

if [[ "${deploy_apps}" == "false" ]]; then
    user_output="$(azd auth login --check-status)"
    email="$(
        printf '%s\n' "${user_output}" \
            | grep -Eo '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]+' \
            | head -n 1 \
            || true
    )"

    if [[ -z "${email}" ]]; then
        echo "ERROR: No email address found in azd auth output." >&2
        exit 1
    fi

    export AZURE_PRINCIPAL_NAME="${email}"
    echo "Extracted email: ${AZURE_PRINCIPAL_NAME}"
    azd env set AZURE_PRINCIPAL_NAME "${AZURE_PRINCIPAL_NAME}"
    echo "User Principal Name Set: ${AZURE_PRINCIPAL_NAME}"
fi
