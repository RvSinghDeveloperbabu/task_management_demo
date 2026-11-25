# Task Queue Demo: practice app for learning DevOps tools

A small but realistic 3-tier app, built so you can practice **Docker, Kubernetes,
Helm, Terraform, AWS (ECR/EKS/RDS/ElastiCache), and CI/CD** on something that
actually has moving parts.

```
Browser -> frontend (React, served by nginx :8080)
              | /api/*
              v
          backend (Rails API / Puma :3000)  --enqueue-->  Redis  <--  sidekiq (worker)
              |                                                           |
              +------------------------ Postgres <-----------------------+
```

You add a task in the UI. Rails saves it as `pending` and enqueues a Sidekiq
job. A worker marks it `processing`, sleeps 5 seconds, then marks it `done`
and records **which worker pod handled it**. The UI polls and shows the status
change live.

## USE AWS ECR

```bash
REGISTRY=1231231231231321.dkr.ecr.ap-southeast-2.amazonaws.com
docker build -t $REGISTRY/task-app-backend:$TAG ./backend
docker push $REGISTRY/task-app-backend:$TAG
```

## Run it locally

```bash
docker compose up --build
```

Then open http://localhost:8080. Add a few tasks and watch them move from
`pending` to `processing` to `done`.

Useful checks:

```bash
curl localhost:3000/health      # liveness
curl localhost:3000/ready       # readiness (checks Postgres + Redis)
curl localhost:3000/api/info    # pod name + Sidekiq stats
docker compose up --scale sidekiq=3   # more workers, see pod names differ
```

## Run without Docker (development)

```bash
# backend (needs Ruby 3.3, Postgres, Redis running locally)
cd backend && bundle install
bin/rails db:prepare
bin/rails server                          # terminal 1
bundle exec sidekiq -C config/sidekiq.yml # terminal 2

# frontend
cd frontend && npm install && npm run dev   # http://localhost:5173
```

## What each piece is (what you'll translate into DevOps files)

| Component | Image / command | Port | Kubernetes resource |
|-----------|-----------------|------|---------------------|
| frontend  | `frontend/Dockerfile` (nginx) | 8080 | Deployment + Service (+ Ingress) |
| backend   | `backend/Dockerfile`, default CMD (Puma) | 3000 | Deployment + Service |
| sidekiq   | same backend image, command `bundle exec sidekiq -C config/sidekiq.yml` | none | Deployment (no Service) |
| migrate   | same backend image, command `bundle exec rails db:prepare` | none | Job, Helm pre-install/upgrade hook, or initContainer |
| postgres  | `postgres:16-alpine` | 5432 | StatefulSet locally, **RDS** on AWS |
| redis     | `redis:7-alpine` | 6379 | Deployment locally, **ElastiCache** on AWS |

Both app images run as a **non-root user** (UID 1000 for Rails, nginx-unprivileged for the frontend).

## Environment variables

| Variable | Used by | Notes |
|----------|---------|-------|
| `DATABASE_URL` | backend, sidekiq, migrate | `postgres://user:pass@host:5432/dbname`, put in a **Secret** |
| `REDIS_URL` | backend, sidekiq | e.g. `redis://redis:6379/0` |
| `SECRET_KEY_BASE` | backend, sidekiq, migrate | **Secret**; generate with `openssl rand -hex 64` |
| `RAILS_ENV` | backend, sidekiq, migrate | `production` (already the image default) |
| `RAILS_LOG_LEVEL` | backend, sidekiq | `info` / `debug` |
| `RAILS_MAX_THREADS` | backend | Puma threads (default 5) |
| `DB_POOL` | backend, sidekiq | Postgres pool size (default 10) |
| `TASK_PROCESSING_SECONDS` | sidekiq | Fake job duration (default 5), raise it to demo scaling |
| `CORS_ORIGINS` | backend | Only needed if the browser calls the API cross-origin |
| `BACKEND_URL` | frontend | e.g. `http://backend:3000`, in K8s use the backend **Service** name |

## Probes and ports (for your Deployments)

- **backend liveness:** `GET /health` on 3000 (always 200 if the process is up)
- **backend readiness:** `GET /ready` on 3000 (503 if Postgres or Redis is down)
- **frontend:** `GET /healthz` on 8080
- **sidekiq:** no HTTP port, use an `exec` probe or none to start
- Sidekiq finishes in-flight jobs on SIGTERM (default 25s), so set `terminationGracePeriodSeconds: 30` or more

## Learning exercises

1. **Docker:** build both images, run with compose, shrink the image size.
2. **ECR:** create two repos, tag and push `task-app-backend` and `task-app-frontend`.
3. **Kubernetes:** write Deployments, Services, ConfigMap, Secret, Ingress, and a migration Job. Try `kubectl scale deployment sidekiq --replicas=3` and watch worker pod names change in the UI.
4. **Probes:** break Redis and watch `/ready` flip to 503 and the pod drop out of the Service.
5. **Helm:** package it all as a chart with `values.yaml` for image tags, replicas, env.
6. **Terraform:** VPC, EKS, RDS Postgres, ElastiCache Redis, ECR repos.
7. **CI/CD:** GitHub Actions or GitLab CI that builds, pushes to ECR, and deploys.
8. **Autoscaling:** add an HPA for the backend and a KEDA/queue-based scaler for Sidekiq.

## Notes

- There is no `Gemfile.lock` in the repo. The first `bundle install` (or Docker build) creates one. Commit it afterwards for reproducible builds.
- `SECRET_KEY_BASE` in `docker-compose.yml` is a local placeholder only. Use a real Secret everywhere else.
- nginx resolves `BACKEND_URL` at startup, so the backend Service must exist when the frontend pod starts.
