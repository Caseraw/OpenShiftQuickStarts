# Scenarios

Scenarios are self-contained, guided tutorials delivered as
[`ConsoleQuickStart`](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/console_apis/consolequickstart-console-openshift-io-v1)
resources. They appear under **Help → Quick Starts** in the OpenShift web console
and walk participants through tasks using interactive checklists — without leaving
the browser.

---

## Available scenarios

| Scenario | Display name | Description | Duration |
|---|---|---|---|
| `example-get-started` | Example — Get started with OpenShift | Basic console navigation and project creation | 5 min |
| `openshift-dashboard-overview` | Tour the OpenShift Console Overview Dashboard | Walkthrough of the Overview page: Details, Status, Utilization, and Activity panels | 10 min |

!!! note "More scenarios coming"
    Additional scenarios will be added as the workshop content evolves.
    Each new scenario gets its own page here with a full walkthrough, objectives,
    and any prerequisites.

---

## How a scenario works

```
Participant opens the OpenShift console
        │
        ▼
  Help → Quick Starts
        │
        ▼
  Selects a scenario  ──►  Interactive task checklist
        │                        │
        │                  Inline hints & highlights
        │                  Console element navigation
        │                  Copy/execute code snippets
        ▼
  Marks tasks complete  ──►  Scenario marked as finished
```

Each scenario is made up of one or more **tasks**, and each task contains a
series of **steps**. The console tracks completion state per user, so participants
can pause and resume at any point.

---

## Interactive console features

Quick start content supports two special link patterns that make the tutorial
panel interact with the console UI directly:

| Feature | Syntax | Effect |
|---|---|---|
| **Highlight** | `[text]{{highlight <token>}}` | Animates a pulsing highlight on a specific console UI element |
| **Copy snippet** | `` `command`{{copy}} `` | Adds a **Copy to clipboard** button next to the code |
| **Execute snippet** | `` `command`{{execute}} `` | Adds **Copy** + **Run in Web Terminal** buttons (requires Web Terminal Operator) |

**Example:**

```markdown
1. Click [Administrator]{{highlight qs-perspective-switcher}} to switch perspective.

2. To create a project from the terminal:

   `oc new-project my-project`{{execute}}
```

---

## Adding a new scenario

1. Copy the template:

    ```bash
    cp -r scenarios/_template scenarios/<scenario-name>
    ```

2. Edit `quickstart.yaml` with your scenario content and task steps.

3. Fill in `README.md` with the scenario overview.

4. Implement the lifecycle scripts:
   - `scripts/prepare.sh` — create prerequisites
   - `scripts/deploy.sh` — apply the `ConsoleQuickStart`
   - `scripts/reset.sh` — clean up task-created resources
   - `scripts/cleanup.sh` — remove everything

5. Validate and test:

    ```bash
    make validate
    make prepare deploy SCENARIO=scenarios/<scenario-name>
    ```

6. Open a pull request — once merged to `main`, the scenario is deployed
   automatically to all clusters via GitOps.
