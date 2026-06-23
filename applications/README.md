# Applications

Sample applications used as hands-on material across workshop scenarios. Each
application is fully self-contained: it ships with its own Kubernetes manifests
(managed by Kustomize), a `README.md`, and lifecycle scripts for deploying,
updating, resetting, and removing it.

Applications are intentionally kept simple and focused — each one exists to
illustrate a specific concept or pattern within a scenario.

---

## Directory layout

```
applications/
├── README.md                  # This file
├── _template/                 # Copy this to create a new application
│   ├── README.md
│   ├── kustomization.yaml
│   └── scripts/
│       ├── deploy.sh
│       ├── reset.sh
│       ├── update.sh
│       └── cleanup.sh
└── <application-name>/        # A concrete sample application
    ├── README.md
    ├── kustomization.yaml
    └── scripts/
        ├── deploy.sh
        ├── reset.sh
        ├── update.sh
        └── cleanup.sh
```

---

## Lifecycle scripts

Each application exposes four operations:

| Script | Purpose |
|--------|---------|
| `scripts/deploy.sh` | Apply the application manifests to the cluster |
| `scripts/reset.sh` | Remove any runtime state created during the scenario (keeps the app installed) |
| `scripts/update.sh` | Re-apply manifests to pick up definition changes |
| `scripts/cleanup.sh` | Remove the application and all its resources from the cluster |

---

## Add a new application

1. Copy the template:

    ```bash
    cp -r applications/_template applications/<application-name>
    ```

2. Add your Kubernetes manifests (Deployment, Service, Route, etc.) to the directory.

3. Reference them in `kustomization.yaml`.

4. Implement the lifecycle scripts.

5. Document the application in `README.md`.
