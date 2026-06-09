# SchoNavi Deployment

## Backend

The backend image is built from `web/backend` and pushed to GHCR by `.github/workflows/deploy-backend.yml`.

The workflow uploads backend agent source on each deploy, but runtime data stays outside Git:

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

Raw SQLite source files are not committed. Put or sync them into:

```text
/opt/schonavi/backend_agent/raw_data
```

For automatic raw data updates, store a command in Doppler `RAW_DATA_SYNC_COMMAND`.
Examples:

```bash
aws s3 sync s3://your-bucket/schonavi/raw_data /opt/schonavi/backend_agent/raw_data
rclone sync schonavi-raw:/ /opt/schonavi/backend_agent/raw_data
```

Every backend deploy runs `scripts/deploy_backend_agent.sh`, which syncs agent source. After the container is up, the workflow rebuilds data inside the backend container:

```bash
doppler run --project schonavi --config prd -- docker compose -f docker-compose.prod.yml exec -T backend sh -lc 'cd "$BACKEND_AGENT_PATH" && python -m app.jobs.rebuild_all'
```

Set `SKIP_AGENT_REBUILD=true` in Doppler if you want deploys to skip data/vector rebuilds.

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
