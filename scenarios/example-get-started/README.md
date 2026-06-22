# Example — Get started with OpenShift

An introductory quick start that walks a new OpenShift user through basic web console navigation and project creation. This scenario is intentionally minimal — it requires no operator installations, no pre-created resources, and no cluster-level preparation beyond being logged in.

## Overview

| | |
|---|---|
| **Quick start name** | `example-get-started` |
| **Duration** | ~5 minutes |
| **Difficulty** | Beginner |
| **Tags** | `example`, `getting-started` |

## What the user will learn

- How to navigate to the Projects page in the OpenShift web console
- How to create a new project
- How to view project details

## Prerequisites

- Access to an OpenShift web console
- Permissions to create a project (`oc new-project` or `self-provisioner` cluster role)

## Scenario tasks

1. **Create a project** — Navigate to Home → Projects and create a new project named `my-example-project`
2. **View project details** — Open the project and review its Details, YAML, and Access tabs

## Usage

### 1. Prepare

Verifies cluster connectivity. No resources need to be created for this scenario.

```bash
bash scripts/prepare.sh
```

### 2. Deploy the quick start

```bash
make deploy SCENARIO=scenarios/example-get-started
# or directly: oc apply -k scenarios/example-get-started/
```

### 3. Run the quick start

Open the OpenShift web console → **Help → Quick Starts** → **Example — Get started with OpenShift**.

### 4. Reset (optional)

Deletes the `my-example-project` project so the quick start tasks can be repeated from scratch.

```bash
bash scripts/reset.sh
```

### 5. Clean up

Removes the `my-example-project` project and the ConsoleQuickStart resource from the cluster.

```bash
bash scripts/cleanup.sh
```

## Standalone use

This scenario ships with its own `kustomization.yaml` and can be deployed without any root-level configuration:

```bash
bash scripts/prepare.sh
oc apply -k .     # run from this scenario directory
```

It has no dependency on any other scenario in this repository.

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| Quick start not visible in console | Resource not applied | Run `oc get consolequickstart example-get-started` to verify |
| "Create Project" button missing | User lacks `self-provisioner` role | A cluster admin must grant the role or create the project on behalf of the user |
| Project name already exists | A previous run was not reset | Run `bash scripts/reset.sh` to remove it |
