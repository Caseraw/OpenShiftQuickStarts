# my-component-name

<!-- Replace this section with a one-paragraph description of what this component
     installs or configures and why it exists as a shared component. -->

This component installs **_description_** on the cluster. It is used as a shared
prerequisite by the following scenarios:

- _(list scenario names here)_

## What this component creates

<!-- List every cluster resource created by deploy.sh. -->

| Resource | Kind | Namespace | Purpose |
|----------|------|-----------|---------|
| `example-name` | `Namespace` | — | Description |

## Prerequisites

- OpenShift Container Platform 4.7 or later
- Cluster administrator privileges
- `oc` CLI configured for your cluster

## Usage

### Deploy

```bash
make component-deploy COMPONENT=components/my-component-name
# or directly:
bash components/my-component-name/scripts/deploy.sh
```

### Reset (re-run ready)

Removes runtime state created during tutorial tasks; leaves the component itself installed:

```bash
make component-reset COMPONENT=components/my-component-name
```

### Update

Re-applies the component's manifests to pick up any definition changes:

```bash
make component-update COMPONENT=components/my-component-name
```

### Remove

```bash
make component-cleanup COMPONENT=components/my-component-name
```

## Using this component from a scenario

Call `deploy.sh` from the scenario's `prepare.sh`:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
bash "$ROOT/components/my-component-name/scripts/deploy.sh"
```

Call `reset.sh` from the scenario's `reset.sh` for any state this component owns:

```bash
bash "$ROOT/components/my-component-name/scripts/reset.sh"
```

## Scripts

| Script | What it does |
|--------|-------------|
| `scripts/deploy.sh` | _Describe what deploy creates_ |
| `scripts/reset.sh` | _Describe what reset removes_ |
| `scripts/update.sh` | _Describe how update behaves_ |
| `scripts/cleanup.sh` | _Describe what cleanup removes_ |
