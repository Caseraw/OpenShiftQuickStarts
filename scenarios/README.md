# Authoring Quick Starts

## Scenario structure

Each scenario is a fully self-contained folder that can be deployed, reset, and removed without relying on any root-level configuration:

```
scenarios/my-scenario/
├── README.md               # Scenario description, overview, and script documentation
├── kustomization.yaml      # Standalone Kustomize entry point — oc apply -k scenarios/my-scenario/
├── quickstart.yaml         # ConsoleQuickStart custom resource
└── scripts/
    ├── prepare.sh          # Create prerequisites (namespaces, operators, supporting resources)
    ├── deploy.sh           # Apply the ConsoleQuickStart using the scenario's kustomization.yaml
    ├── reset.sh            # Remove task-created resources for a clean re-run
    └── cleanup.sh          # Remove everything, including the ConsoleQuickStart resource
```

**Standalone requirement:** each scenario must work independently. Running `scripts/prepare.sh` then `scripts/deploy.sh` must be sufficient to get the tutorial working — no dependency on another scenario's scripts or shared state.

### kustomization.yaml

A minimal Kustomize file that references `quickstart.yaml`. Enables the scenario to be applied standalone:

```bash
oc apply -k scenarios/my-scenario/
```

The root repository no longer contains a `kustomization.yaml`. The `make apply` aggregate target calls each scenario's `deploy.sh` instead.

### scripts/prepare.sh

Run once before presenting or attempting the quick start. Creates anything the scenario needs: a namespace, operator subscription, ConfigMap, sample application, etc. Should be idempotent (safe to run multiple times).

If the prerequisite is reusable across scenarios, put it in a **component** under `components/` and call the component's `deploy.sh` from here instead of duplicating the setup:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT/components/demo-namespace/scripts/deploy.sh"
```

See [components/README.md](../components/README.md) for the full authoring guide.

### scripts/deploy.sh

Applies the ConsoleQuickStart to the cluster using the scenario's own `kustomization.yaml`, then verifies the resource exists. Should be called after `prepare.sh`. Update the `QS_NAME` variable at the top of this script to match `metadata.name` in `quickstart.yaml`.

### scripts/reset.sh

Removes only the resources created during the quick start tasks, leaving the namespace and operator installations in place. Lets a user or presenter re-run the tutorial without full teardown and re-preparation.

### scripts/cleanup.sh

Removes everything created by the scenario — workloads, namespace, and the `ConsoleQuickStart` resource. Should use `--ignore-not-found` on all deletes so it is safe to run multiple times.

Copy the template to start:

```bash
cp -r scenarios/_template scenarios/my-new-scenario
```

## Naming conventions

| Item | Convention | Example |
|------|------------|---------|
| Scenario folder | kebab-case, descriptive | `deploy-from-git/` |
| `metadata.name` | kebab-case, should match folder name | `deploy-from-git` |
| Filename | always `quickstart.yaml` | — |
| `nextQuickStart` links | use `metadata.name`, not `displayName` | `deploy-from-git` |

Matching `metadata.name` to the folder name is a strong convention, not a hard requirement, but it makes resources easy to locate from the cluster.

## Resource name stability

**Never rename `metadata.name` on an existing quick start.**

The name is the cluster-wide identity of the resource. Renaming it causes duplicates because the old resource is not automatically removed. If a rename is unavoidable, explicitly delete the old resource first and document the step clearly in your pull request. See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

## Required fields

At the resource level:

- `metadata.name` — unique identifier (kebab-case)
- `spec.displayName` — title shown in the console
- `spec.description` — short summary (markdown)
- `spec.introduction` — longer intro (markdown)
- `spec.durationMinutes` — estimated completion time in minutes
- `spec.tasks` — array of task steps (at least one)

Each task requires:

- `title` — step heading
- `description` — instructions (markdown)
- `review.instructions` — "Check your work" prompt
- `review.failedTaskHelp` — help when the user answers "No"
- `summary.success` — message on success
- `summary.failed` — message on failure

## Optional fields

- `spec.icon` — base64-encoded SVG (`data:image/svg+xml;base64,...`), 40×40 px recommended
- `spec.tags` — search/filter tags (see tagging conventions below)
- `spec.prerequisites` — prerequisites shown in the intro panel (markdown)
- `spec.conclusion` — wrap-up text shown after the last task (markdown)
- `spec.nextQuickStart` — list of `metadata.name` values for follow-on quick starts
- `spec.accessReviewResources` — RBAC checks; quick start is hidden if any check fails

## Interactive console features

Quick start markdown supports two interactive mechanisms that allow the tutorial panel to directly interact with the console UI: element highlighting and code snippets.

### Highlighting console elements

The `{{highlight <token>}}` syntax turns any link text into a clickable hint that **animates and pulses a specific UI element** in the console when the user clicks it. This is the primary way to guide users to the right place without telling them to look left or right.

```markdown
Click [Home]{{highlight qs-nav-home}} and select **Projects**.
```

When the user clicks the link, the matching element in the console gets a pulsing animation to draw attention to it. The link text can be anything — write it naturally as part of the instruction.

#### Complete token reference

**Perspective switcher (masthead)**

| Token | Element |
|-------|---------|
| `qs-perspective-switcher` | Perspective dropdown in the masthead |

**Administrator perspective navigation**

| Token | Element |
|-------|---------|
| `qs-nav-home` | Home |
| `qs-nav-operators` | Operators |
| `qs-nav-workloads` | Workloads |
| `qs-nav-serverless` | Serverless |
| `qs-nav-networking` | Networking |
| `qs-nav-storage` | Storage |
| `qs-nav-servicecatalog` | Service catalog |
| `qs-nav-compute` | Compute |
| `qs-nav-usermanagement` | User management |
| `qs-nav-administration` | Administration |

**Developer perspective navigation**

| Token | Element |
|-------|---------|
| `qs-nav-add` | +Add |
| `qs-nav-topology` | Topology |
| `qs-nav-search` | Search |
| `qs-nav-project` | Project |
| `qs-nav-helm` | Helm |

**Shared navigation (both perspectives)**

| Token | Element |
|-------|---------|
| `qs-nav-builds` | Builds |
| `qs-nav-pipelines` | Pipelines |
| `qs-nav-monitoring` | Monitoring / Observe |

**Masthead links**

| Token | Element |
|-------|---------|
| `qs-masthead-cloudshell` | Web Terminal (Cloud Shell) button |
| `qs-masthead-utilitymenu` | Utility menu |
| `qs-masthead-usermenu` | User menu (top-right account menu) |
| `qs-masthead-applications` | Application launcher (grid icon) |
| `qs-masthead-import` | Import (+) button |
| `qs-masthead-help` | Help (?) menu |
| `qs-masthead-notifications` | Notifications bell |

### Code snippets — copy and execute

You can attach a **Copy to clipboard** button or a **Run in Web Terminal** button to any inline or multi-line code block. This lets users run commands directly from the quick start panel without switching context.

#### Syntax

Append `{{copy}}` or `{{execute}}` immediately after the closing backtick(s) — no space.

**Inline snippets:**

```plaintext
`oc get pods -n my-namespace`{{copy}}
`oc get pods -n my-namespace`{{execute}}
```

**Multi-line snippets:**

````plaintext
```
oc new-project my-project
oc new-app nodejs~https://github.com/example/app
```{{copy}}

```
oc new-project my-project
oc new-app nodejs~https://github.com/example/app
```{{execute}}
````

#### Behaviour

| Annotation | Copy button | Execute button | Requires |
|------------|-------------|----------------|----------|
| `{{copy}}` | Yes | No | Nothing |
| `{{execute}}` | Yes | Yes | [Web Terminal Operator](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/web_console/creating-quick-start-tutorials#web-console-creating-quick-start-tutorials-code-snippets_web-console-creating-quick-start-tutorials) |

- `{{copy}}` always works and adds a single **Copy to clipboard** action.
- `{{execute}}` adds both a **Copy to clipboard** and a **Run in Web Terminal** action. The execute button is only visible when the Web Terminal Operator is installed; the copy button is always visible.
- Use `{{copy}}` for commands the user runs locally (e.g. `oc login`).
- Use `{{execute}}` for commands that are safe and useful to run directly in the in-browser terminal.

#### Example task step combining both features

```yaml
tasks:
  - title: Create a project
    description: |-
      1. In the [Administrator perspective]{{highlight qs-perspective-switcher}}, open [Home]{{highlight qs-nav-home}} and click **Projects**.

      1. Click **Create Project**, enter a name, and click **Create**.

      1. Alternatively, create the project from the terminal:

         `oc new-project my-project`{{execute}}
```

## Writing good "Check your work" questions

The `review.instructions` field is the most important UX element in a quick start. Follow these rules:

- **Ask about an observable state, not an action.** The user answers yes or no based on what they can see in the console right now — not whether they performed a step.
  - Good: "Do you see a **my-project** project listed on the Projects page?"
  - Avoid: "Did you complete the steps above?"
- **Keep it to one or two verifiable observations.** If you need more, split the task.
- **Phrase it so a successful outcome is an obvious "Yes".** The user should be able to answer without leaving the quick start panel.
- **`review.failedTaskHelp`** should direct the user back to the specific step that most commonly fails, not just say "try again".

## Tagging conventions

Tags drive the filter sidebar in the Quick Starts catalog. Use a consistent set so filters are useful:

- **Product/technology tag** — the primary technology (e.g. `openshift`, `pipelines`, `serverless`, `helm`, `gitops`)
- **Topic tag** — the workflow category (e.g. `getting-started`, `deploy`, `monitoring`, `security`, `configuration`)
- Lowercase, hyphenated, no spaces

Example:

```yaml
tags:
  - pipelines
  - getting-started
```

## Access control

Restrict a quick start to users who can install Operators:

```yaml
accessReviewResources:
  - group: operators.coreos.com
    resource: operatorgroups
    verb: list
  - group: packages.operators.coreos.com
    resource: packagemanifests
    verb: list
```

The quick start is hidden from any user who fails any of the listed checks. Always test with a user lacking the required permissions to confirm the check works.

## Chaining quick starts

Link to a follow-on scenario using `metadata.name` (not `displayName`):

```yaml
nextQuickStart:
  - deploy-from-git
```

## Duration guidance

Set `durationMinutes` to a realistic estimate. Official quick starts typically range from **5 to 15 minutes**. Overestimating is better than underestimating — users who finish early are pleased; users who run over time are frustrated.

## Content guidelines

Follow the [OpenShift quick start writing guidelines](https://openshift.github.io/openshift-origin-design/conventions/documentation/quick-starts.html):

- Use clear, action-oriented task titles (start with a verb: "Create a project", "Deploy an application")
- Number steps within task descriptions using `1.` for each (the console auto-increments)
- Use `**bold**` for UI element names (buttons, tabs, fields, menu items)
- Use `code` formatting for values the user types or copies
- Keep each task focused on a single goal; split if a task has more than ~6 steps

## Supported markdown

The console renders a subset of markdown: `b`, `i`, `li`, `code`, `pre`, `button`, and others. Full list in the [official documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/web_console/creating-quick-start-tutorials#web-console-creating-quick-start-tutorials-supported-tags_web-console-creating-quick-start-tutorials).

## Useful commands

Explore the API without a browser:

```bash
oc explain consolequickstarts
oc explain consolequickstarts.spec
oc explain consolequickstarts.spec.tasks
```

Export an existing quick start for reference:

```bash
oc get -o yaml consolequickstart <name>
```

## What not to include

Do **not** add OpenShift release annotations (`include.release.openshift.io/*`) — those are only for quick starts bundled into the platform release via `console-operator`.

## Create a new scenario

```bash
cp -r scenarios/_template scenarios/my-new-scenario
# Edit scenarios/my-new-scenario/quickstart.yaml
# Add to kustomization.yaml
make validate
make apply-one SCENARIO=scenarios/my-new-scenario/quickstart.yaml
```
