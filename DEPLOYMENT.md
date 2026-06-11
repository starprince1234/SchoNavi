# SchoNavi Deployment

## Backend

The backend source is uploaded by `.github/workflows/deploy-backend.yml` and the Docker image is built on the server. This avoids pulling the application image from GHCR during production deploys.

The workflow uploads backend and backend agent source on each deploy, but raw source data and generated runtime data stay on the server:

```text
/opt/schonavi/backend_agent
/opt/schonavi/backend_agent/data/app.db
/opt/schonavi/backend_agent/data/chroma
/opt/schonavi/backend_agent/raw_data/*.db
```

Run production compose only through Doppler:

```bash
doppler run --project schonavi --config prd -- docker compose -f docker-compose.prod.yml up -d
```

Do not create `.env` files.

Production builds default to a Docker Hub mirror for the Python base image and a domestic pip index:

```text
PYTHON_BASE_IMAGE=m.daocloud.io/docker.io/library/python:3.12-slim
PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn
```

Override these values in Doppler `prd` only if the mirror becomes unavailable.

Raw SQLite source files are not uploaded by GitHub Actions. Put them on the server manually:

```text
/opt/schonavi/backend_agent/raw_data
```

After adding or replacing raw DB files, rebuild the backend agent database, graph, and Chroma vector index on the server:

```bash
cd /opt/schonavi
./scripts/rebuild_backend_agent_indexes.sh
```

This script does not require you to type a Doppler token. It reuses the already-running backend container, which was started by the deployment workflow with Doppler-injected production environment variables.

The rebuild script is incremental for vectors: unchanged items keep their existing `vector_id`; new or changed items are upserted into Chroma.

Every backend deploy runs `scripts/deploy_backend_agent.sh`, which syncs backend agent source while preserving server-side `raw_data/` and `data/`.

To restart the backend without rebuilding indexes:

```bash
doppler run --project schonavi --config prd -- docker compose -f docker-compose.prod.yml up -d --no-build
```

## Frontend

Vercel settings:

```text
Root Directory: web/frontend
Build Command: npm run build
Output Directory: dist
```

Set `VITE_API_BASE_URL` in Vercel to the public backend origin, for example:

```text
https://api.example.com
```
