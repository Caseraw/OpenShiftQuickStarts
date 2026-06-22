# Red Hat OpenShift Quick Starts

Curated [OpenShift Console Quick Starts](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/web_console/creating-quick-start-tutorials) — guided, step-by-step tutorials that appear in the web console under **Help → Quick Starts**.

Each scenario is fully self-contained: it ships with its own `kustomization.yaml`, a `quickstart.yaml` resource, a `README.md`, and shell scripts for preparation, deployment, reset, and cleanup. A scenario can be deployed independently without any root-level configuration.

## Scenarios

| Scenario | Display name | Description | Duration |
|----------|-------------|-------------|----------|
| [example-get-started](scenarios/example-get-started/) | Example — Get started with OpenShift | Basic console navigation and project creation | 5 min |
| [openshift-dashboard-overview](scenarios/openshift-dashboard-overview/) | Tour the OpenShift Console Overview Dashboard | Walkthrough of the Overview page: Details, Status, Utilization, and Activity panels | 10 min |

## Prerequisites

- OpenShift Container Platform 4.7 or later
- Cluster administrator privileges (required to create `ConsoleQuickStart` resources)
- [`oc`](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/cli_tools/openshift-cli-oc) CLI configured for your cluster

## Environment setup (first-time)

Before deploying components or scenarios on a new cluster, set up your local
environment and push credentials to the cluster:

```bash
# 1. Copy the env template and fill in your cluster details
cp environment/env.sh.example environment/env.sh
# edit environment/env.sh

# 2. Copy and fill in the credentials you need
cp environment/credentials/pull-secret.json.example \
   environment/credentials/pull-secret.json
# edit environment/credentials/pull-secret.json

# 3. Validate your setup (safe — never modifies the cluster)
make env-check

# 4. Push credentials to the cluster
make env-apply
```

Credentials are **never committed to Git**. See [environment/README.md](environment/README.md)
for the full guide including SSH keys and cloud provider credentials.

## Deploy a single scenario

Each scenario deploys independently using its own scripts and kustomization:

```bash
# 1. Set up cluster prerequisites (namespaces, operators, etc.)
make prepare SCENARIO=scenarios/example-get-started

# 2. Apply the ConsoleQuickStart to the cluster
make deploy  SCENARIO=scenarios/example-get-started

# 3. Open the web console → Help → Quick Starts
```

Or directly without make:

```bash
bash scenarios/example-get-started/scripts/prepare.sh
oc apply -k scenarios/example-get-started/
```

## Deploy all scenarios at once

```bash
make apply
```

This loops through every scenario and runs its `deploy.sh`.

## Manage quick starts

Compare project scenarios against what is deployed on the cluster:

```bash
make status
```

List scenarios in this project:

```bash
make list
```

List all quick starts on the cluster (including built-in OpenShift ones):

```bash
make list-cluster
# Filter to project-managed resources only:
make list-cluster LABEL_SELECTOR=app.kubernetes.io/part-of=openshift-quickstarts
```

Reset a scenario for a clean re-run:

```bash
make reset SCENARIO=scenarios/example-get-started
```

Remove a single scenario:

```bash
make cleanup SCENARIO=scenarios/example-get-started
```

Remove all scenarios:

```bash
make delete
```

## Per-scenario scripts

| Script | Purpose |
|--------|---------|
| `scripts/prepare.sh` | Create namespaces, install operators, apply supporting resources |
| `scripts/deploy.sh` | Apply the `ConsoleQuickStart` resource using the scenario's `kustomization.yaml` |
| `scripts/reset.sh` | Remove task-created resources so the tutorial can be repeated |
| `scripts/cleanup.sh` | Remove everything, including the `ConsoleQuickStart` resource |

Each scenario's `README.md` documents exactly what the scripts do for that scenario.

## Repository layout

```
OpenShiftQuickStarts/
├── README.md
├── CONTRIBUTING.md
├── LICENSE
├── Makefile
├── .github/
│   └── workflows/
│       └── validate.yml              # CI: validates scenario YAML and components on push/PR
├── environment/                      # Layer 1 — BYO credentials and cluster config
│   ├── README.md
│   ├── env.sh.example                # Committed template (copy to env.sh — gitignored)
│   ├── credentials/
│   │   ├── .gitignore                # Blocks all credential files from Git
│   │   ├── pull-secret.json.example
│   │   ├── ssh-public-key.example
│   │   ├── ssh-private-key.example
│   │   └── cloud-credentials.env.example
│   └── scripts/
│       ├── check.sh                  # Pre-flight validator (read-only)
│       ├── apply.sh                  # Push credentials to cluster
│       └── clean.sh                  # Remove env-applied cluster resources
├── components/                       # Layer 2 — reusable cluster assets
│   ├── README.md
│   ├── _template/                    # Copy this to create a new component
│   │   ├── README.md
│   │   ├── kustomization.yaml
│   │   └── scripts/
│   │       ├── deploy.sh
│   │       ├── reset.sh
│   │       ├── update.sh
│   │       └── cleanup.sh
│   └── demo-namespace/               # Example — shared qs-demo namespace
│       └── ...
├── scenarios/                        # Layer 3 — ConsoleQuickStart tutorials
│   ├── README.md
│   ├── _template/
│   │   └── ...
│   └── example-get-started/
│       └── ...
└── scripts/
    └── validate.sh                   # YAML syntax + required field + component validation
```

## Interactive features in scenario content

Quick start markdown supports two mechanisms that let the tutorial panel interact with the console UI directly — no browser extensions or plugins required.

| Feature | Syntax | What it does |
|---------|--------|--------------|
| **Element highlight** | `[link text]{{highlight <token>}}` | Clicking the link animates a specific UI element (nav item, masthead button, etc.) with a pulsing highlight |
| **Copy snippet** | `` `command`{{copy}} `` | Adds a **Copy to clipboard** button next to the code |
| **Execute snippet** | `` `command`{{execute}} `` | Adds **Copy** + **Run in Web Terminal** buttons (Web Terminal Operator required for execute) |

Example — navigating to a page and running a command:

```markdown
1. Click [Home]{{highlight qs-nav-home}} and select **Projects**.

1. To create the project from the terminal instead:

   `oc new-project my-project`{{execute}}
```

See [scenarios/README.md](scenarios/README.md) for the full token reference and code snippet syntax.

## Components

Components are reusable, self-contained cluster assets — namespaces, operator
installations, Helm charts, sample applications — that one or more scenarios can
depend on. A component exposes a consistent four-script interface:

| Script | Purpose |
|--------|---------|
| `scripts/deploy.sh` | Install the component on the cluster (idempotent) |
| `scripts/reset.sh` | Remove runtime state; keep the component installed |
| `scripts/update.sh` | Re-apply / upgrade to the latest definition |
| `scripts/cleanup.sh` | Remove the component and everything it created |

### Use a component from a scenario

Call the component's `deploy.sh` from the scenario's `prepare.sh`:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/demo-namespace/scripts/deploy.sh"
```

### Manage components

```bash
make component-list
make component-deploy  COMPONENT=components/demo-namespace
make component-reset   COMPONENT=components/demo-namespace
make component-update  COMPONENT=components/demo-namespace
make component-cleanup COMPONENT=components/demo-namespace

# All components at once:
make components-deploy
make components-cleanup
```

See [components/README.md](components/README.md) for the full authoring guide.

## Add a new scenario

1. Copy `scenarios/_template/` to `scenarios/<scenario-name>/`
2. Edit `quickstart.yaml` following the [authoring guide](scenarios/README.md)
3. Fill in `README.md` with the scenario overview and script documentation
4. Implement `scripts/prepare.sh`, `scripts/deploy.sh`, `scripts/reset.sh`, and `scripts/cleanup.sh`
5. Update `QS_NAME` in `scripts/deploy.sh` to match `metadata.name` in `quickstart.yaml`
6. Validate: `make validate`
7. Test end-to-end: `make prepare deploy SCENARIO=scenarios/<scenario-name>`

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contribution process.

## Add a new component

1. Copy `components/_template/` to `components/<component-name>/`
2. Add manifest files and wire them into `kustomization.yaml`
3. Implement the four scripts following the [authoring guide](components/README.md)
4. Fill in `README.md` documenting what the component creates and how to use it
5. Validate: `make validate`
6. Test the full lifecycle: `make component-deploy component-reset component-update component-cleanup COMPONENT=components/<component-name>`

## Documentation

- [Creating quick start tutorials (OCP 4.22)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/web_console/creating-quick-start-tutorials)
- [ConsoleQuickStart API reference](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/console_apis/consolequickstart-console-openshift-io-v1)
- [Quick start writing guidelines](https://openshift.github.io/openshift-origin-design/conventions/documentation/quick-starts.html)
- [Out-of-the-box examples](https://github.com/openshift/console-operator/tree/main/quickstarts)

## License

This project is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE).
