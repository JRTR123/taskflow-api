# taskflow-api

A small task-tracking REST API (Node.js 20 / Express / PostgreSQL) — the case study used
throughout the Jenkins CI/CD Pipeline Lab (Labs 01–10).

## Endpoints

| Method | Path             | Description                  |
|--------|------------------|-------------------------------|
| GET    | `/health`        | Health check                  |
| GET    | `/api/tasks`     | List all tasks                |
| POST   | `/api/tasks`     | Create a task                 |
| GET    | `/api/tasks/:id` | Get one task                  |
| PUT    | `/api/tasks/:id` | Update a task (e.g. status)   |
| DELETE | `/api/tasks/:id` | Delete a task                 |

## Run locally (in-memory store, no database needed)

```bash
npm install
npm start
```

## Run with real PostgreSQL

```bash
docker compose up -d --build
```

## Test & lint

```bash
npm test
npm run lint
```

## Notes for the pipeline labs

- Without `DATABASE_URL` set, the app uses an in-memory store — this is what unit tests
  (`npm test`) and early labs (01–04) run against, so no database container is required yet.
- `docker-compose.yml` brings up Postgres + the API together — used from Lab 05's E2E stage
  onward, and for the Docker/Kubernetes work in Labs 07–10.
- `migrations/init.sql` creates the `tasks` table automatically when the `db` container starts.
