#!/bin/bash

alembic upgrade head

# Default to development if not set
ENV=${ENVIRONMENT:-dev}

if [ "$ENV" = "prod" ]; then
  echo "Starting in production mode..."
  uvicorn src.main:app \
    --host 0.0.0.0 \
    --port 80 \
    --access-log \
    --log-config logging_config.yaml \
    --workers 8
else
  echo "Starting in development mode..."
  uvicorn src.main:app \
    --host 0.0.0.0 \
    --port 80 \
    --reload \
    --access-log \
    --log-config logging_config.yaml
fi
