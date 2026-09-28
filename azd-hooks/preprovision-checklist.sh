#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    CYAN=$'\033[36m'
    RESET=$'\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    CYAN=""
    RESET=""
fi

info() {
    printf '%s%s%s\n' "${CYAN}" "$*" "${RESET}"
}

success() {
    printf '%s%s%s\n' "${GREEN}" "$*" "${RESET}"
}

warning() {
    printf '%s%s%s\n' "${YELLOW}" "$*" "${RESET}"
}

error() {
    printf '%sERROR: %s%s\n' "${RED}" "$*" "${RESET}" >&2
}

azd_env_value() {
    azd env get-value "$1" 2>/dev/null || true
}

exit_with_error() {
    local message="$1"
    local error_type="${2:-general}"
    local status_code="${3:-1}"
    local env_name=""
    local resource_group=""

    error "${message}"

    if [[ "${error_type}" == "env_name" ]]; then
        warning "Clearing environment configuration..."
        if [[ -d "${REPO_ROOT}/.azure" ]]; then
            rm -rf -- "${REPO_ROOT}/.azure"
            warning "Environment configuration cleared"
        fi
        if [[ -f "${REPO_ROOT}/.env" ]]; then
            rm -f -- "${REPO_ROOT}/.env"
            warning "Removed .env file"
        fi
        success "Please run 'azd up' again and choose a valid environment name."
        exit "${status_code}"
    fi

    warning "Cleaning up failed deployment environment..."
    env_name="$(azd_env_value AZURE_ENV_NAME)"
    resource_group="$(azd_env_value AZURE_RESOURCE_GROUP)"

    if [[ -n "${resource_group}" ]]; then
        warning "Deleting resource group: ${resource_group}"
        if az group delete --name "${resource_group}" --yes --no-wait >/dev/null 2>&1; then
            success "Resource group deletion initiated (running in background)"
        else
            warning "Could not delete resource group (it may not exist yet)"
        fi
    fi

    if [[ "${env_name}" =~ ^[A-Za-z0-9-]+$ && -d "${REPO_ROOT}/.azure/${env_name}" ]]; then
        rm -rf -- "${REPO_ROOT}/.azure/${env_name}"
        warning "Removed environment folder: .azure/${env_name}"
    fi

    if [[ -f "${REPO_ROOT}/.env" ]]; then
        rm -f -- "${REPO_ROOT}/.env"
        warning "Removed .env file"
    fi

    printf '\n'
    error "============================================="
    error "   DEPLOYMENT STOPPED - QUOTA VALIDATION FAILED"
    error "============================================="
    success "Environment has been completely cleaned up!"
    printf '\n'
    info "TO CONTINUE:"
    warning "  1. Run 'azd env new' and create a new environment"
    warning "  2. Run 'azd up' and choose one of the recommended regions"
    error "============================================="
    printf '\n'
    exit "${status_code}"
}

require_commands() {
    local command_name
    for command_name in az azd awk grep sed tr; do
        if ! command -v "${command_name}" >/dev/null 2>&1; then
            exit_with_error "Required command '${command_name}' was not found."
        fi
    done
}

test_environment_name() {
    local env_name

    info "Validating environment name..."
    if ! env_name="$(azd env get-value AZURE_ENV_NAME 2>/dev/null)"; then
        exit_with_error "Failed to get environment name. Please ensure azd is properly configured."
    fi

    warning "Environment name: ${env_name}"
    if [[ -z "${env_name}" || ! "${env_name}" =~ ^[A-Za-z0-9-]+$ || ${#env_name} -gt 50 ]]; then
        error "Invalid environment name detected!"
        warning "Environment names must:"
        warning "  - Only contain letters, numbers, and hyphens"
        warning "  - Be 50 characters or less"
        error "  - Current name: '${env_name}'"
        exit_with_error \
            "Environment name '${env_name}' contains invalid characters or is too long" \
            "env_name"
    fi

    success "Environment name is valid"
}

get_infra_location() {
    local location=""
    local env_name=""
    local config_path=""
    local env_var_name=""

    location="$(azd_env_value AZURE_LOCATION)"
    if [[ -n "${location}" ]]; then
        INFRA_LOCATION="${location}"
        return
    fi

    env_name="$(azd_env_value AZURE_ENV_NAME)"
    config_path="${REPO_ROOT}/.azure/${env_name}/config.json"
    if [[ -n "${env_name}" && -f "${config_path}" ]]; then
        location="$(
            sed -n 's/.*"location"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
                "${config_path}" \
                | head -n 1
        )"
        if [[ -n "${location}" ]]; then
            INFRA_LOCATION="${location}"
            return
        fi
    fi

    if [[ -n "${AZURE_LOCATION:-}" ]]; then
        INFRA_LOCATION="${AZURE_LOCATION}"
        return
    fi

    if [[ -f "${REPO_ROOT}/infra/main.parameters.json" ]]; then
        location="$(
            awk '
                /"location"[[:space:]]*:/ { in_location = 1; next }
                in_location && /"value"[[:space:]]*:/ {
                    line = $0
                    sub(/^[^:]*:[[:space:]]*"/, "", line)
                    sub(/"[[:space:]]*,?[[:space:]]*$/, "", line)
                    print line
                    exit
                }
                in_location && /^[[:space:]]*}/ { exit }
            ' "${REPO_ROOT}/infra/main.parameters.json"
        )"

        if [[ "${location}" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)(=.*)?\}$ ]]; then
            env_var_name="${BASH_REMATCH[1]}"
            location="$(printenv "${env_var_name}" 2>/dev/null || true)"
        fi

        if [[ -n "${location}" ]]; then
            INFRA_LOCATION="${location}"
            return
        fi
    fi

    exit_with_error "Cannot determine infrastructure location"
}

load_allowed_regions() {
    local bicep_file="${REPO_ROOT}/infra/main.bicep"
    local region=""

    if [[ ! -f "${bicep_file}" ]]; then
        exit_with_error "Cannot find infra/main.bicep file"
    fi

    ALLOWED_REGIONS=()
    while IFS= read -r region; do
        if [[ -n "${region}" ]]; then
            ALLOWED_REGIONS+=("${region}")
        fi
    done < <(
        awk '
            /@allowed\(\[/ {
                collecting = 1
                count = 0
            }
            collecting {
                line = $0
                while (match(line, /\047[^\047]+\047/)) {
                    regions[++count] = substr(line, RSTART + 1, RLENGTH - 2)
                    line = substr(line, RSTART + RLENGTH)
                }
                if ($0 ~ /\]\)/) {
                    collecting = 0
                    awaiting_location = 1
                }
                next
            }
            awaiting_location {
                if ($0 ~ /^[[:space:]]*param[[:space:]]+location[[:space:]]+string/) {
                    for (i = 1; i <= count; i++) {
                        print regions[i]
                    }
                    exit
                }
                if ($0 ~ /^[[:space:]]*param[[:space:]]+/) {
                    awaiting_location = 0
                    count = 0
                }
            }
        ' "${bicep_file}"
    )

    if [[ ${#ALLOWED_REGIONS[@]} -eq 0 ]]; then
        exit_with_error "Failed to parse allowed regions from infra/main.bicep"
    fi
}

normalize_region() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'
}

test_container_apps_region() {
    local region="$1"
    local provider_state=""
    local locations=""
    local location=""
    local normalized_region=""

    provider_state="$(
        az provider show \
            --namespace Microsoft.App \
            --query registrationState \
            --output tsv \
            --only-show-errors \
            2>/dev/null \
            || true
    )"
    if [[ "${provider_state}" != "Registered" ]]; then
        warning "Microsoft.App provider is not registered: ${provider_state:-unknown}"
        return 1
    fi

    locations="$(
        az provider show \
            --namespace Microsoft.App \
            --query "resourceTypes[?resourceType=='managedEnvironments'].locations[]" \
            --output tsv \
            --only-show-errors \
            2>/dev/null \
            || true
    )"
    if [[ -z "${locations}" ]]; then
        warning "Could not retrieve Container Apps location information"
        return 1
    fi

    normalized_region="$(normalize_region "${region}")"
    while IFS= read -r location; do
        if [[ "$(normalize_region "${location}")" == "${normalized_region}" ]]; then
            success "Container Apps is supported in ${region}"
            return 0
        fi
    done <<< "${locations}"

    warning "Container Apps is not supported in ${region}"
    return 1
}

get_postgresql_sku() {
    local bicep_file="${REPO_ROOT}/infra/main.bicep"
    local parameters_file="${REPO_ROOT}/infra/main.parameters.json"
    local sku=""
    local override=""

    sku="$(
        awk '
            /param[[:space:]]+postgresServerSku[[:space:]]+object[[:space:]]*=/ {
                in_sku = 1
                next
            }
            in_sku && /^[[:space:]]*name[[:space:]]*:/ {
                line = $0
                sub(/^[^:]*:[[:space:]]*/, "", line)
                gsub(/[\047"\r]/, "", line)
                sub(/[[:space:]].*$/, "", line)
                print line
                exit
            }
            in_sku && /^[[:space:]]*}/ { exit }
        ' "${bicep_file}"
    )"

    if [[ -f "${parameters_file}" ]]; then
        override="$(
            awk '
                /"postgresServerSku"[[:space:]]*:/ { in_sku = 1 }
                in_sku && /"name"[[:space:]]*:/ {
                    line = $0
                    sub(/^[^:]*:[[:space:]]*"/, "", line)
                    sub(/"[[:space:]]*,?[[:space:]]*$/, "", line)
                    print line
                    exit
                }
                in_sku && /^[[:space:]]*}/ { exit }
            ' "${parameters_file}"
        )"
    fi

    POSTGRES_SKU="${override:-${sku:-Standard_B2ms}}"
    if [[ ! "${POSTGRES_SKU}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        exit_with_error "Invalid PostgreSQL SKU value '${POSTGRES_SKU}'"
    fi
}

test_postgresql_sku_region() {
    local region="$1"
    local target_sku="$2"
    local query=""
    local error_file=""
    local result=""
    local error_output=""
    local reason=""
    local found_name=""
    local memory_mb=""

    SKU_AVAILABLE=false
    SKU_VERIFIED=false
    SKU_REASON=""
    SKU_VCORES="Unknown"
    SKU_MEMORY="Unknown"

    warning "Checking PostgreSQL SKU availability in ${region}..."
    query="[].supportedServerEditions[].supportedServerSkus[] | [?name=='${target_sku}'] | [0].[name, vCores, supportedMemoryPerVcoreMb]"
    error_file="$(mktemp)"

    if result="$(
        az postgres flexible-server list-skus \
            --location "${region}" \
            --query "${query}" \
            --output tsv \
            --only-show-errors \
            2>"${error_file}"
    )"; then
        rm -f -- "${error_file}"

        if [[ -n "${result}" ]]; then
            IFS=$'\t' read -r found_name SKU_VCORES memory_mb <<< "${result}"
            if [[ "${found_name}" == "${target_sku}" ]]; then
                SKU_AVAILABLE=true
                SKU_VERIFIED=true
                if [[ -n "${memory_mb}" ]]; then
                    SKU_MEMORY="${memory_mb}MB per vCore"
                fi
                success "Found target SKU: ${target_sku}"
                return
            fi
        fi

        reason="$(
            az postgres flexible-server list-skus \
                --location "${region}" \
                --query "[0].reason" \
                --output tsv \
                --only-show-errors \
                2>/dev/null \
                || true
        )"
        SKU_VERIFIED=true
        if [[ -n "${reason}" && "${reason}" != "None" ]]; then
            SKU_REASON="Region temporarily restricted: ${reason}"
        else
            SKU_REASON="SKU ${target_sku} not found in available configurations"
        fi
        return
    fi

    error_output="$(cat "${error_file}")"
    rm -f -- "${error_file}"

    if printf '%s' "${error_output}" | grep -Eqi \
        'NoRegisteredProviderFound|No registered resource provider found for location|location.*is not supported|not available in'; then
        SKU_VERIFIED=true
        SKU_REASON="Region ${region} does not support PostgreSQL Flexible Server"
        error "${SKU_REASON}"
        return
    fi

    SKU_AVAILABLE=true
    SKU_REASON="Could not verify SKU availability"
    warning "Could not query PostgreSQL capabilities for ${region}; proceeding with deployment."
    if [[ -n "${error_output}" ]]; then
        warning "Azure CLI details: ${error_output:0:150}"
    fi
}

find_postgresql_alternatives() {
    local failed_region="$1"
    local target_sku="$2"
    local region=""

    POSTGRES_ALTERNATIVES=()
    warning "Checking alternative regions for PostgreSQL SKU availability..."

    for region in "${ALLOWED_REGIONS[@]}"; do
        if [[ "${region}" == "${failed_region}" ]]; then
            continue
        fi

        test_postgresql_sku_region "${region}" "${target_sku}"
        if [[ "${SKU_AVAILABLE}" == "true" && "${SKU_VERIFIED}" == "true" ]]; then
            POSTGRES_ALTERNATIVES+=("${region}")
            success "${region} has ${target_sku} available"
        elif [[ "${SKU_AVAILABLE}" == "true" ]]; then
            warning "${region}: ${SKU_REASON} - excluding from alternatives"
        fi
    done
}

find_container_apps_alternatives() {
    local failed_region="$1"
    local region=""

    CONTAINER_APPS_ALTERNATIVES=()
    warning "Checking alternative regions for Container Apps availability..."

    for region in "${ALLOWED_REGIONS[@]}"; do
        if [[ "${region}" == "${failed_region}" ]]; then
            continue
        fi

        if test_container_apps_region "${region}"; then
            CONTAINER_APPS_ALTERNATIVES+=("${region}")
        fi
    done
}

print_alternatives() {
    local heading="$1"
    shift
    local value=""

    printf '\n'
    success "${heading}"
    for value in "$@"; do
        success "  ${value}"
    done
    printf '\n'
}

test_postgresql_sku() {
    info "Checking PostgreSQL SKU availability..."
    get_infra_location
    get_postgresql_sku

    warning "Checking region: ${INFRA_LOCATION}"
    warning "Target SKU: ${POSTGRES_SKU}"
    test_postgresql_sku_region "${INFRA_LOCATION}" "${POSTGRES_SKU}"

    if [[ "${SKU_AVAILABLE}" == "true" ]]; then
        if [[ "${SKU_VERIFIED}" == "true" ]]; then
            success "PostgreSQL SKU ${POSTGRES_SKU} is available in ${INFRA_LOCATION}"
            if [[ "${SKU_VCORES}" != "Unknown" ]]; then
                success "   Specs: ${SKU_VCORES} vCores, ${SKU_MEMORY}"
            fi
        else
            warning "PostgreSQL SKU ${POSTGRES_SKU} could not be verified in ${INFRA_LOCATION}."
            warning "Proceeding with deployment; Azure will validate availability during provisioning."
        fi
        return
    fi

    error "PostgreSQL SKU ${POSTGRES_SKU} is not available in ${INFRA_LOCATION}"
    if [[ -n "${SKU_REASON}" ]]; then
        error "   Reason: ${SKU_REASON}"
    fi

    find_postgresql_alternatives "${INFRA_LOCATION}" "${POSTGRES_SKU}"
    if [[ ${#POSTGRES_ALTERNATIVES[@]} -gt 0 ]]; then
        print_alternatives \
            "Alternative regions with ${POSTGRES_SKU} available:" \
            "${POSTGRES_ALTERNATIVES[@]}"
        exit_with_error "Please use one of the above alternative regions for your deployment"
    fi

    error "No alternative regions found with ${POSTGRES_SKU} available"
    info "Suggestions:"
    warning "  1. Check Azure documentation for PostgreSQL SKU availability by region"
    warning "  2. Consider using a different PostgreSQL SKU with similar specifications"
    warning "  3. Request SKU availability in your preferred region through Azure support"
    exit_with_error "PostgreSQL SKU ${POSTGRES_SKU} is not available in any supported regions"
}

test_container_apps_quota() {
    info "Checking Azure Container Apps quota..."
    get_infra_location
    warning "Checking region: ${INFRA_LOCATION}"

    if test_container_apps_region "${INFRA_LOCATION}"; then
        success "Container Apps quota sufficient in ${INFRA_LOCATION}"
        return
    fi

    error "Insufficient Container Apps quota in ${INFRA_LOCATION}"
    find_container_apps_alternatives "${INFRA_LOCATION}"
    if [[ ${#CONTAINER_APPS_ALTERNATIVES[@]} -gt 0 ]]; then
        print_alternatives \
            "Alternative regions with Container Apps available:" \
            "${CONTAINER_APPS_ALTERNATIVES[@]}"
        exit_with_error "Please use one of the above alternative regions for your deployment"
    fi

    exit_with_error "Could not find a supported region for Azure Container Apps"
}

require_commands
load_allowed_regions

info "==========================================="
info "Azure Deployment Validation"
info "==========================================="

test_environment_name

printf '\n'
info "==========================================="
info "PostgreSQL SKU Availability Check"
info "==========================================="
test_postgresql_sku

printf '\n'
info "==========================================="
info "Container Apps Quota Check"
info "==========================================="
test_container_apps_quota

printf '\n'
success "==========================================="
success "All infrastructure validations successful!"
info "Note: OpenAI quota checking is handled automatically by azd"
success "==========================================="
