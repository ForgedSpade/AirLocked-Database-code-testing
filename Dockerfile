# syntax=docker/dockerfile:1.7

FROM python:3.12-slim

# Pull uv from its official image (multi-stage trick — keeps base small).
COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /uvx /usr/local/bin/

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# Project metadata + source. README is needed by hatchling at install
# time. Layering: change anything in src/ and we rebuild only the
# install layer; deps stay cached until pyproject.toml changes.
COPY pyproject.toml README.md ./
COPY src ./src
COPY config ./config
COPY alembic.ini ./

# Resolve + install (runtime deps only — dev tools belong in CI).
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-dev

# Drop privileges.
RUN useradd --create-home --uid 1000 polyroute && \
    chown -R polyroute:polyroute /app
USER polyroute

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)" || exit 1

CMD ["uvicorn", "polyroute.main:app", "--host", "0.0.0.0", "--port", "8000"]
