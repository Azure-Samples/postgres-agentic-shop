#!/bin/sh

RESOURCE_GROUP=$(azd env get-value AZURE_RESOURCE_GROUP)
POSTGRES_NAME=$(azd env get-value POSTGRES_NAME)
POSTGRES_USERNAME=$(azd env get-value POSTGRES_USERNAME)
POSTGRES_DATABASE=$(azd env get-value POSTGRES_DATABASE)
POSTGRES_PASSWORD=$(azd env get-value POSTGRES_PASSWORD)

az postgres flexible-server execute \
        --admin-user "$POSTGRES_USERNAME" \
        --admin-password "$POSTGRES_PASSWORD" \
        --name "$POSTGRES_NAME" \
        --database-name "$POSTGRES_DATABASE" \
        --file-path "../scripts/create-extension.sql"
