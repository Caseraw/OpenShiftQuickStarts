# todo-app

A 2-tier web application — **Flask frontend** backed by **PostgreSQL** — used to demonstrate multi-namespace deployments, inter-service communication, and on-cluster builds on OpenShift.

The app is called **Sweep Dreams**: a simple todo / chore tracker. It supports creating, completing, and deleting tasks, with all data persisted in PostgreSQL.

## What it deploys

| Tier | Namespace | Resources |
|---|---|---|
| PostgreSQL | `todo-postgresql` | Namespace, Secret, PVC, ImageStream, BuildConfig, Deployment, Service |
| Frontend | `todo-frontend` | Namespace, ConfigMap, Secret, ImageStream, BuildConfig, Deployment, Service, Route |

### Architecture

```
User → Route (HTTPS) → Frontend (Flask/gunicorn)
                              ↓
                  todo-postgresql.todo-postgresql.svc.cluster.local:5432
                              ↓
                        PostgreSQL (port 5432)
                              ↓
                         PVC (1Gi, Ceph RBD)
```

## Prerequisites

- Logged into the target cluster (Spoke 1)
- ODF storage class `ocs-storagecluster-ceph-rbd` available (for the PostgreSQL PVC)
- Internet access from the cluster nodes (to pull UBI base images and the upstream `postgres:16` image during build)

## Directory structure

```
todo-app/
├── kustomization.yaml          # Top-level entry point — references both tiers
├── kustomize/
│   ├── frontend/               # Frontend Kustomization (namespace: todo-frontend)
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml      # DB connection settings (host, port, name, user)
│   │   ├── secret.yaml         # DB_PASSWORD (change-me placeholder)
│   │   ├── imagestream.yaml
│   │   ├── buildconfig.yaml    # Docker strategy — builds from src/frontend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── route.yaml          # HTTPS edge-terminated Route
│   └── postgresql/             # PostgreSQL Kustomization (namespace: todo-postgresql)
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── secret.yaml         # POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
│       ├── pvc.yaml            # 1Gi Ceph RBD PVC for PGDATA
│       ├── imagestream.yaml
│       ├── buildconfig.yaml    # Docker strategy — builds from src/postgresql/
│       ├── deployment.yaml
│       └── service.yaml
├── src/
│   ├── frontend/
│   │   ├── Containerfile       # ubi9/python-311 image
│   │   ├── app.py              # Flask REST API + HTML serving
│   │   ├── requirements.txt    # Flask, gunicorn, psycopg2-binary
│   │   └── templates/
│   │       └── index.html      # Single-page todo UI
│   └── postgresql/
│       ├── Containerfile       # postgres:16 + init scripts
│       └── init/
│           ├── 01-schema.sql   # Creates the todos table
│           └── 02-seed.sql     # Inserts sample data
└── scripts/
    ├── deploy.sh               # Full deploy: build → wait → rollout
    ├── reset.sh                # Truncate todos table and re-seed
    ├── update.sh               # Trigger new builds and wait for rollout
    └── cleanup.sh              # Delete both namespaces
```

## Lifecycle

### Deploy

Applies both tiers in order, waits for builds, and waits for rollouts:

```bash
bash scripts/deploy.sh
```

Or via Kustomize directly (builds trigger automatically, deployments roll out via ImageStream):

```bash
oc apply -k .
```

### Reset

Truncates the `todos` table and re-inserts seed data. The application keeps running:

```bash
bash scripts/reset.sh
```

### Update

Triggers new image builds for both tiers and waits for rolling deployments:

```bash
bash scripts/update.sh
```

### Cleanup

Deletes both namespaces and all resources within them:

```bash
bash scripts/cleanup.sh
```

## Credentials

The default `DB_PASSWORD` in `kustomize/frontend/secret.yaml` and `POSTGRES_PASSWORD` in `kustomize/postgresql/secret.yaml` are set to `change-me`. For a workshop environment this is acceptable, but you should change both values (keeping them in sync) before any production use.

## Frontend API

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Serve the UI |
| `GET` | `/health` | Liveness probe — always `{"status":"ok"}` |
| `GET` | `/ready` | Readiness probe — checks DB connectivity |
| `GET` | `/api/todos` | List all todos |
| `POST` | `/api/todos` | Create a todo (`{"title":"..."}`) |
| `PUT` | `/api/todos/<id>` | Update title and/or done status |
| `DELETE` | `/api/todos/<id>` | Delete a todo |
