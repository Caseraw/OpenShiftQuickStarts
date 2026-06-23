# Component: gitops

Deploys and manages the ArgoCD **ApplicationSets** that automate scenario delivery
to all managed clusters.

Once deployed, any `ConsoleQuickStart` scenario merged to `main` is picked up
within 30 seconds and applied to every OpenShift cluster registered in RHACM —
no manual `oc apply` required.

---

## What this component creates

| Resource | Namespace | Purpose |
|---|---|---|
| `ApplicationSet/quickstarts` | `openshift-gitops` | Deploys scenarios to all spoke clusters via the RHACM cluster-proxy |
| `ApplicationSet/quickstarts-hub` | `openshift-gitops` | Deploys scenarios to the hub cluster via the direct in-cluster endpoint |

---

## Prerequisites

- `components/rhacm` deployed and `MultiClusterHub` in `Running` phase
- `components/rhacm-policies` deployed (installs the OpenShift GitOps operator fleet-wide)
- ArgoCD instance (`openshift-gitops`) available on the hub

---

## Lifecycle

```bash
# Deploy
make component-deploy COMPONENT=components/gitops

# Update (re-apply after changing ApplicationSet definitions)
make component-update COMPONENT=components/gitops

# Reset (no-op — ApplicationSets are stateless)
make component-reset COMPONENT=components/gitops

# Remove all ApplicationSets (ArgoCD prunes managed Applications automatically)
make component-cleanup COMPONENT=components/gitops
```

---

## Adding a new ApplicationSet

1. Add the YAML file to `components/gitops/applicationsets/`
2. Reference it in `components/gitops/kustomization.yaml`
3. Run `make component-update COMPONENT=components/gitops`

---

## Architecture

The two ApplicationSets use different cluster endpoints to avoid the
`cluster-proxy` limitation on the hub:

```
quickstarts         →  RHACM Placement (excludes local-cluster)
                        └─ spoke clusters via cluster-proxy addon

quickstarts-hub     →  hub cluster only (https://kubernetes.default.svc)
                        └─ bypasses cluster-proxy (not available on local-cluster)
```
