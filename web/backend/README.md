# SchoNavi Web Backend

FastAPI adapter for the recommendation agent in `../backend_agent`.

## Development

```bash
doppler run -- uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API falls back to local mock data when the agent, database, vector index, or LLM configuration is unavailable.

Do not create local `.env` files. Add new keys to `.env.example`, then store real values in Doppler.

