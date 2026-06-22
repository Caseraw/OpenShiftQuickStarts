# rhacm

Installs and configures **Red Hat Advanced Cluster Management (RHACM) 2.17** on
an OpenShift cluster. Creates the `open-cluster-management` namespace, installs
the RHACM operator via OLM, and provisions a `MultiClusterHub` instance.

Scenarios that teach cluster fleet management, policy enforcement, application
delivery, or observability across clusters depend on this component.

## What this component creates

| Resource | Kind | Namespace | Purpose |
|----------|------|-----------|---------|
| `open-cluster-management` | `Namespace` | — | Dedicated namespace for the RHACM operator and hub |
| `open-cluster-management` | `OperatorGroup` | `open-cluster-management` | Scopes the OLM install to the hub namespace |
| `advanced-cluster-management` | `Subscription` | `open-cluster-management` | Installs RHACM from `redhat-operators`, channel `release-2.17` |
| `advanced-cluster-management.v2.17.0` | `ClusterServiceVersion` | `open-cluster-management` | Created by OLM automatically |
| `multiclusterhub` | `MultiClusterHub` | `open-cluster-management` | The RHACM hub instance |

## Prerequisites

- OpenShift Container Platform 4.14 or later (RHACM 2.17 requirement)
- Cluster administrator privileges
- `oc` CLI configured for your cluster
- Access to `redhat-operators` CatalogSource (requires a valid pull secret)

## Deploy

Installation runs in two phases and typically takes **10–20 minutes**:

1. **Operator phase** — applies the namespace, OperatorGroup, and Subscription,
   then waits for the operator CSV to reach `Succeeded` (~3–5 minutes).
2. **Hub phase** — applies the `MultiClusterHub` CR and waits for it to reach
   `Running` (~10–15 minutes for a first install).

```bash
make component-deploy COMPONENT=components/rhacm
# or directly:
bash components/rhacm/scripts/deploy.sh
```

Monitor progress in a separate terminal while the deploy runs:

```bash
# Watch operator installation
oc get csv -n open-cluster-management -w

# Watch MultiClusterHub phases
oc get multiclusterhub -n open-cluster-management -w

# Watch pods come up
oc get pods -n open-cluster-management -w
```

## Reset

Removes tutorial-created RHACM objects (ManagedClusters, Policies, Applications,
etc.) labelled with `app.kubernetes.io/part-of: openshift-quickstarts`. The hub
itself, its operator, and the local-cluster registration are preserved.

```bash
make component-reset COMPONENT=components/rhacm
```

Scenario resources must carry the label for reset to find them:

```yaml
metadata:
  labels:
    app.kubernetes.io/part-of: openshift-quickstarts
```

## Update

Re-applies the Subscription and MultiClusterHub manifests. To upgrade to a new
RHACM release, edit `spec.channel` in `subscription.yaml` first:

```bash
# Edit subscription.yaml: change channel to e.g. release-2.18
make component-update COMPONENT=components/rhacm
```

OLM handles the operator upgrade automatically (`installPlanApproval: Automatic`).
The script waits for the new CSV to succeed before exiting.

```bash
make component-update COMPONENT=components/rhacm
```

## Remove

Full uninstall. Order of operations: detach managed clusters → delete
MultiClusterHub (waits for finalizer) → delete Subscription → delete CSV →
delete OperatorGroup → delete namespace → remove cluster-scoped CRs.

Expect this to take **5–10 minutes**.

```bash
make component-cleanup COMPONENT=components/rhacm
```

## Using this component from a scenario

Call `deploy.sh` from the scenario's `prepare.sh`:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/rhacm/scripts/deploy.sh"
```

Call `reset.sh` from the scenario's `reset.sh`:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/rhacm/scripts/reset.sh"
```

Call `cleanup.sh` from the scenario's `cleanup.sh` (only if the scenario owns RHACM):

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/rhacm/scripts/cleanup.sh"
```

## Changing the RHACM version / channel

Edit `subscription.yaml` and update `spec.channel`:

```yaml
spec:
  channel: release-2.18   # change from release-2.17
```

Then run `make component-update COMPONENT=components/rhacm`.

Available channels (as of OCP 4.21):

| Channel | RHACM Version |
|---------|--------------|
| `release-2.15` | 2.15.x |
| `release-2.16` | 2.16.x |
| `release-2.17` | 2.17.x (default) |

## Scripts

| Script | What it does |
|--------|-------------|
| `scripts/deploy.sh` | Phase 1: applies namespace/OperatorGroup/Subscription, waits for CSV. Phase 2: creates MultiClusterHub, waits for Running phase |
| `scripts/reset.sh` | Deletes scenario-labelled ManagedClusters, Policies, Applications, and other RHACM objects; preserves the hub |
| `scripts/update.sh` | Re-applies Subscription and MultiClusterHub; waits for CSV when a channel change triggers an upgrade |
| `scripts/cleanup.sh` | Full uninstall in correct order: detach clusters → delete hub (with finalizer wait) → delete OLM resources → delete namespace → clean cluster-scoped CRs |

## Troubleshooting

**CSV stuck in `Installing`:**

```bash
oc get installplan -n open-cluster-management
oc describe csv advanced-cluster-management.v2.17.0 -n open-cluster-management
```

**MultiClusterHub stuck in `Installing`:**

```bash
oc get multiclusterhub -n open-cluster-management -o yaml | grep -A 20 status
oc get pods -n open-cluster-management | grep -v Running
```

**Cleanup namespace stuck in `Terminating`:**

The namespace can hang if CRD finalizers are not cleared. Run:

```bash
oc get namespace open-cluster-management -o json | \
  python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" | \
  oc replace --raw /api/v1/namespaces/open-cluster-management/finalize -f -
```
