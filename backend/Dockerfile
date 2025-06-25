FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm


ENV POETRY_VERSION=1.8.2 \
    POETRY_VIRTUALENVS_CREATE=false \
    PATH="/root/.local/bin:$PATH"

# System Dependcies
RUN apt-get update \
    && apt-get install --no-install-recommends -y curl \
    # Installing `poetry` package manager:
    # https://github.com/python-poetry/poetry
    && curl https://install.python-poetry.org | python \
    && poetry --version \
    # Cleaning cache
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY poetry.lock pyproject.toml ./
RUN poetry install --no-interaction --no-ansi
ADD . ./

EXPOSE 80

RUN chmod +x ./startup.sh
CMD ["./startup.sh"]

