# PolyRoute

> **Status:** Phase 1 in progress. This README is a placeholder; the
> portfolio-grade version (with headline metrics, quickstart, and
> architecture diagram) ships in phase 10. See
> [`PolyRoute_Build_Spec.md`](PolyRoute_Build_Spec.md) for the
> authoritative spec and [`CLAUDE.md`](CLAUDE.md) for the agent-facing
> overview.

PolyRoute is a self-hosted gateway that sits between an application and
multiple LLM providers (Anthropic, OpenAI, Google). It exposes a single
OpenAI-compatible API while routing each request to the cheapest
capable model, with automatic failover, semantic caching, and full
cost/latency observability.

## Quickstart (target — not yet runnable)

```bash
docker compose up
# Point any OpenAI-compatible client at http://localhost:8000/v1
```

## Development

```bash
uv sync
uv run uvicorn src.polyroute.main:app --reload --port 8000
uv run pytest
uv run ruff check .
uv run mypy src/
```
