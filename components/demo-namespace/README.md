# demo-namespace

Creates the shared `qs-demo` OpenShift project (namespace) with a `ResourceQuota`
and a `LimitRange`. Scenarios that need a pre-existing namespace can declare a
dependency on this component instead of each managing their own namespace.

## What this component creates

| Resource | Kind | Namespace | Purpose |
|----------|------|-----------|---------|
| `qs-demo` | `Namespace` | — | Shared project for Quick Start demo workloads |
| `qs-demo-quota` | `ResourceQuota` | `qs-demo` | Caps total CPU (4 cores), memory (4 GiB), pods (20), services (10), PVCs (5) |
| `qs-demo-limits` | `LimitRange` | `qs-demo` | Sets default container requests (100m CPU / 128Mi RAM) and limits (250m CPU / 256Mi RAM) |

## Prerequisites

- OpenShift Container Platform 4.7 or later
- Cluster administrator privileges
- `oc` CLI configured for your cluster

## Usage

### Deploy

```bash
make component-deploy COMPONENT=components/demo-namespace
# or directly:
bash components/demo-namespace/scripts/deploy.sh
```

### Reset (re-run ready)

Removes workloads created by scenarios during tutorial tasks, leaving the
namespace, quota, and limit range intact:

```bash
make component-reset COMPONENT=components/demo-namespace
```

### Update

Re-applies the Kustomize manifests to pick up quota or limit range changes:

```bash
make component-update COMPONENT=components/demo-namespace
```

### Remove

```bash
make component-cleanup COMPONENT=components/demo-namespace
```

## Using this component from a scenario

In the scenario's `scripts/prepare.sh`, locate the repo root and call this
component's `deploy.sh`:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/demo-namespace/scripts/deploy.sh"
```

In the scenario's `scripts/reset.sh`, call the component's reset to clean up
any workloads the scenario created inside `qs-demo`:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/demo-namespace/scripts/reset.sh"
```

## Scripts

| Script | What it does |
|--------|-------------|
| `scripts/deploy.sh` | Creates `qs-demo` namespace, `qs-demo-quota` ResourceQuota, and `qs-demo-limits` LimitRange via `oc apply -k` |
| `scripts/reset.sh` | Deletes scenario-created workloads from `qs-demo`; preserves the namespace and quota/limit resources |
| `scripts/update.sh` | Re-applies `oc apply -k` to update quota/limit definitions without touching workloads |
| `scripts/cleanup.sh` | Deletes the `qs-demo` namespace and everything inside it |
