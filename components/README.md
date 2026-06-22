# Components

Components are **reusable, self-contained cluster assets** that one or more
scenarios can depend on. A component encapsulates a single installation or
configuration unit — a namespace, an operator subscription, a Helm chart, a
sample application — and exposes a consistent four-script interface for
deploying, resetting, updating, and cleaning it up.

Keeping shared prerequisites in components means each scenario only calls the
component scripts it needs rather than duplicating cluster setup code.

## Directory layout

```
components/
├── README.md                      # This file — authoring guide
├── _template/                     # Copy this to start a new component
│   ├── README.md
│   ├── kustomization.yaml         # Optional Kustomize entry point
│   └── scripts/
│       ├── deploy.sh              # Install the component
│       ├── reset.sh               # Remove runtime state; keep component installed
│       ├── update.sh              # Re-apply / upgrade the component
│       └── cleanup.sh             # Remove everything
└── demo-namespace/                # Example — shared qs-demo namespace
    ├── README.md
    ├── kustomization.yaml
    ├── namespace.yaml
    ├── resource-quota.yaml
    ├── limit-range.yaml
    └── scripts/
        ├── deploy.sh
        ├── reset.sh
        ├── update.sh
        └── cleanup.sh
```

## Component anatomy

Every component lives in its own folder under `components/` and must be
**fully self-contained** — it must not depend on another component's scripts
or on shared cluster state outside what it creates itself.

| File / Folder | Required | Purpose |
|---------------|----------|---------|
| `README.md` | Yes | What the component installs, what it creates, how to use it from a scenario |
| `scripts/deploy.sh` | Yes | Install the component on a cluster (idempotent) |
| `scripts/reset.sh` | Yes | Remove runtime state, leave the component installed |
| `scripts/update.sh` | Yes | Re-apply / upgrade to the latest definition |
| `scripts/cleanup.sh` | Yes | Remove everything the component created |
| `kustomization.yaml` | Recommended | Standalone Kustomize entry point for manifest resources |
| Manifests (`*.yaml`) | As needed | Namespace, Subscription, Helm values, etc. |

A component may also include Helm chart directories, Ansible playbooks, or any
other assets required by its scripts.

## Scripts contract

### `deploy.sh`

- Creates every cluster resource the component requires.
- **Must be idempotent** — running it twice must not cause errors or duplicate
  resources (use `oc apply`, `helm upgrade --install`, or guard with existence
  checks).
- Should verify the component is healthy before exiting (e.g. `oc rollout
  status`, `oc wait --for=condition=Available`).

### `reset.sh`

- Removes only the **runtime state** introduced by tutorial tasks (sample
  workloads, user-created objects, changed config values).
- **Must not** remove the component itself, its namespace, operator
  installations, or any base resources.
- Must be idempotent (use `--ignore-not-found`).

### `update.sh`

- Re-applies manifests or upgrades Helm/OLM releases to the latest version
  defined in this repository.
- Must handle the case where an older version is already installed.
- Must be idempotent.

### `cleanup.sh`

- Removes **everything** the component created — namespaces, operators, Helm
  releases, cluster-scoped objects.
- Must be idempotent — use `--ignore-not-found` on every delete.
- Remove resources in reverse order of creation (workloads → namespaces →
  cluster-scoped resources).

## Naming conventions

| Item | Convention | Example |
|------|------------|---------|
| Component folder | kebab-case, descriptive noun | `openshift-pipelines/` |
| Manifest filenames | resource-kind in kebab-case | `namespace.yaml`, `subscription.yaml` |
| Namespace created by component | `qs-<component-name>` (recommended) | `qs-demo` |
| Label on all resources | `app.kubernetes.io/component: <component-name>` | `app.kubernetes.io/component: demo-namespace` |

All resources created by a component should carry:

```yaml
labels:
  app.kubernetes.io/part-of: openshift-quickstarts
  app.kubernetes.io/managed-by: openshift-quickstarts
  app.kubernetes.io/component: <component-name>
```

## Using a component from a scenario

Call the component's scripts from the scenario's corresponding scripts.
Resolve the repo root relative to the script's own location:

```bash
# In scenarios/my-scenario/scripts/prepare.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/demo-namespace/scripts/deploy.sh"
```

| Scenario script | Component script to call |
|-----------------|--------------------------|
| `prepare.sh` | `deploy.sh` — install the component before the tutorial |
| `reset.sh` | `reset.sh` — reset component state so the tutorial can be re-run |
| `cleanup.sh` | `cleanup.sh` — remove the component when tearing down the scenario |

Document component dependencies in the scenario's `README.md` so it is clear
what a presenter must have installed before running the tutorial.

## Makefile targets

### Single component

```bash
make component-deploy  COMPONENT=components/demo-namespace
make component-reset   COMPONENT=components/demo-namespace
make component-update  COMPONENT=components/demo-namespace
make component-cleanup COMPONENT=components/demo-namespace
```

### All components

```bash
make components-deploy   # deploy every non-template component
make components-cleanup  # remove every non-template component
```

### List

```bash
make component-list      # list components and their one-line descriptions
```

## Create a new component

1. Copy the template:

   ```bash
   cp -r components/_template components/my-component
   ```

2. Edit `kustomization.yaml` and add your manifest files.

3. Implement the four scripts following the contract above.

4. Fill in `README.md` with:
   - What the component installs
   - A table of every resource it creates
   - How to call it from a scenario
   - What each script does

5. Validate that required scripts exist:

   ```bash
   make validate
   ```

6. Test the full lifecycle on a live cluster:

   ```bash
   make component-deploy  COMPONENT=components/my-component
   # verify resources on cluster
   make component-reset   COMPONENT=components/my-component
   # verify runtime state removed, component still installed
   make component-update  COMPONENT=components/my-component
   # verify idempotent re-apply works
   make component-cleanup COMPONENT=components/my-component
   # verify everything removed; run twice to confirm idempotency
   make component-cleanup COMPONENT=components/my-component
   ```
