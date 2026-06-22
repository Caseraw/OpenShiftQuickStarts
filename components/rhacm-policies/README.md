# Component: rhacm-policies

Deploys and manages RHACM governance policies across three scoped namespaces,
each bound to the `global` ManagedClusterSet so that Placements can select
clusters by label.

## Namespaces

| Namespace | Scope | Placement target |
|---|---|---|
| `acm-default-fleet-policies` | All clusters | No predicates — hub + all spokes |
| `acm-default-hub-policies` | Hub only | `local-cluster=true` |
| `acm-default-spoke-policies` | Spokes only | `local-cluster != true` |

Each namespace gets a `ManagedClusterSetBinding` pointing at the built-in
`global` set, which always contains every managed cluster.

## Prerequisites

- The `rhacm` component must be deployed and its `MultiClusterHub` must be in
  `Running` state before running `deploy.sh`.

## Directory layout

```
components/rhacm-policies/
├── ns-fleet.yaml                   # Namespace + ManagedClusterSetBinding (fleet)
├── ns-hub.yaml                     # Namespace + ManagedClusterSetBinding (hub)
├── ns-spoke.yaml                   # Namespace + ManagedClusterSetBinding (spoke)
├── kustomization.yaml              # Applies the three ns-*.yaml files
├── policies/
│   ├── fleet/                      # Policies that target every cluster
│   │   └── _template.yaml
│   ├── hub/                        # Policies that target the hub only
│   │   └── _template.yaml
│   └── spoke/                      # Policies that target spoke clusters only
│       └── _template.yaml
├── scripts/
│   ├── deploy.sh
│   ├── reset.sh
│   ├── update.sh
│   └── cleanup.sh
└── README.md
```

## Lifecycle scripts

| Script | Action |
|---|---|
| `deploy.sh` | Creates namespaces + ManagedClusterSetBindings, then applies all non-template `*.yaml` in `policies/fleet|hub|spoke/` |
| `reset.sh` | Removes all Policy / Placement / PlacementBinding resources (preserving namespaces), then re-deploys |
| `update.sh` | Re-applies all policy files (idempotent, same as deploy) |
| `cleanup.sh` | Deletes everything: policies, bindings, and all three namespaces |

## Adding a new policy

1. **Choose a scope** — `fleet`, `hub`, or `spoke`.
2. **Copy the matching template:**

   ```bash
   cp policies/fleet/_template.yaml  policies/fleet/security-require-namespace-labels.yaml
   ```

3. **Replace all `<placeholder>` values** in your copy.
4. **Deploy:**

   ```bash
   # Apply only the new file immediately:
   oc apply -f policies/fleet/security-require-namespace-labels.yaml \
     -n acm-default-fleet-policies

   # Or re-run the full deploy:
   make component-deploy COMPONENT=rhacm-policies
   ```

## Policy naming convention

```
<category>-<description>.yaml

Examples:
  security-require-namespace-labels.yaml
  compliance-restrict-privileged-containers.yaml
  configuration-enforce-resource-limits.yaml
```

## Placement selectors

| Scope | Placement spec |
|---|---|
| **fleet** | `predicates: []` — all clusters |
| **hub** | `matchLabels: { local-cluster: "true" }` |
| **spoke** | `matchExpressions: [ { key: local-cluster, operator: NotIn, values: ["true"] } ]` |

## Remediation actions

Set `remediationAction` to one of:

- `inform` — Report compliance violations without making changes (safe for audit)
- `enforce` — Automatically remediate non-compliant resources (use with caution)

The action can be set at both the `Policy` level (global default) and per
`ConfigurationPolicy` (override for individual checks).

## ManagedClusterSetBinding

Each namespace is pre-bound to the `global` ManagedClusterSet, which
automatically includes all managed clusters. If you later create custom
`ManagedClusterSet` resources (e.g., a dedicated `spoke` set), add
additional `ManagedClusterSetBinding` resources to the relevant namespace
and update your Placement `clusterSets` field accordingly.
