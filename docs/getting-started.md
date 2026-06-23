# Getting Started

This page covers everything you need to run the workshop — whether you are a
participant joining an existing environment or an instructor setting one up from
scratch.

---

## For participants

If an instructor has already deployed the workshop for you, all you need is:

- A modern web browser
- The URL and credentials for your assigned OpenShift cluster

Once you log in, navigate to **Help (? icon) → Quick Starts** in the top-right
corner of the console to see all available scenarios.

---

## For instructors / operators

### Prerequisites

| Requirement | Details |
|---|---|
| OpenShift Container Platform | 4.14 or later |
| Cluster administrator access | Required to create `ConsoleQuickStart` resources and install operators |
| [`oc` CLI](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/cli_tools/openshift-cli-oc) | Configured and authenticated against your cluster |
| `make` | Standard GNU Make (pre-installed on most Linux/macOS systems) |
| `bash` | 4.0 or later |

---

### Environment setup

Before deploying to a new cluster you need to supply your cluster credentials.
These are **never committed to Git** — they live only in your local working copy.

```bash
# 1. Copy the environment template
cp environment/env.sh.example environment/env.sh

# 2. Fill in your cluster details (API URL, username, password)
#    Open environment/env.sh in your editor and set the values
```

Then copy and fill in any credentials you need:

```bash
# Pull secret (required for authenticated registry access)
cp environment/credentials/pull-secret.json.example \
   environment/credentials/pull-secret.json

# SSH keys (optional — needed for machine config scenarios)
cp environment/credentials/ssh-public-key.example \
   environment/credentials/ssh-public-key

cp environment/credentials/ssh-private-key.example \
   environment/credentials/ssh-private-key
```

---

### Validate your setup

Run the pre-flight check to verify your credentials and cluster connectivity
**without making any changes to the cluster**:

```bash
make env-check
```

---

### Push credentials to the cluster

Once validation passes, apply the credentials:

```bash
make env-apply
```

---

### Deploy components

Components are reusable cluster assets (operators, namespaces, RHACM policies)
that scenarios depend on. Deploy all components at once:

```bash
make env-deploy
```

This installs everything in the correct order:

1. RHACM (`components/rhacm`)
2. RHACM Policies (`components/rhacm-policies`)
3. RHACM Observability (`components/rhacm-observability`)
4. GitOps ApplicationSets (`components/gitops`)

---

### Deploy scenarios

Scenarios are deployed automatically by the ArgoCD ApplicationSets installed in
the previous step. Once the GitOps component is running, any scenario merged to
the `main` branch is picked up within 30 seconds and deployed to all managed
clusters.

To deploy a single scenario manually (e.g. for testing):

```bash
make deploy SCENARIO=scenarios/example-get-started
```

To deploy all scenarios at once:

```bash
make apply
```

---

### Verify deployment

Check which scenarios are active on your cluster:

```bash
make status
```

List all quick starts, including built-in OpenShift ones:

```bash
make list-cluster
```

Filter to project-managed quick starts only:

```bash
make list-cluster LABEL_SELECTOR=app.kubernetes.io/part-of=openshift-quickstarts
```

---

## Scenario lifecycle

Each scenario exposes four operations via `make`:

| Command | What it does |
|---|---|
| `make prepare SCENARIO=<path>` | Create namespaces, install operators, apply supporting resources |
| `make deploy SCENARIO=<path>` | Apply the `ConsoleQuickStart` resource to the cluster |
| `make reset SCENARIO=<path>` | Remove task-created resources so the tutorial can be repeated |
| `make cleanup SCENARIO=<path>` | Remove everything, including the `ConsoleQuickStart` resource |

---

## Repository layout

```
OpenShiftQuickStarts/
├── docs/                             # This workshop guide (MkDocs source)
├── environment/                      # Cluster credentials and config (gitignored)
│   ├── env.sh.example                # Template — copy to env.sh
│   └── credentials/                  # Secrets — all gitignored
├── components/                       # Reusable cluster assets
│   ├── rhacm/                        # RHACM installation
│   ├── rhacm-policies/               # Fleet-wide governance policies
│   ├── rhacm-observability/          # MultiCluster Observability
│   └── gitops/                       # ArgoCD ApplicationSets
└── scenarios/                        # ConsoleQuickStart tutorials
    ├── example-get-started/
    └── openshift-dashboard-overview/
```

---

## Troubleshooting

!!! tip "Quick start not appearing in the console?"
    Run `make status` to confirm the `ConsoleQuickStart` resource exists on the
    cluster. If it does, try clearing your browser cache — the console caches the
    quick start list for a few minutes.

!!! tip "ArgoCD application stuck in `OutOfSync`?"
    Check that the `gitops` component was deployed successfully with
    `make component-deploy COMPONENT=components/gitops`.  
    Then verify the RHACM `GitOpsCluster` and `Placement` resources are healthy
    in the RHACM console under **Applications → Argo CD**.

!!! tip "Credential errors during `make env-apply`?"
    Re-check `environment/env.sh` and ensure all required fields are set. Run
    `make env-check` first — it will report exactly which checks fail.
