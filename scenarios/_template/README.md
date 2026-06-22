# Scenario Name

One-paragraph description of what this scenario teaches and why it is useful.

## Overview

| | |
|---|---|
| **Quick start name** | `my-scenario-name` |
| **Duration** | ~10 minutes |
| **Difficulty** | Beginner / Intermediate / Advanced |
| **Tags** | `my-product`, `getting-started` |

## What the user will learn

- Learning outcome one
- Learning outcome two
- Learning outcome three

## Prerequisites

- OpenShift Container Platform 4.x or later
- Cluster administrator privileges
- Any other specific prerequisites

## Scenario tasks

1. **First task** — Brief description of what the user does
2. **Second task** — Brief description of what the user does

## Usage

### 1. Prepare

Run once before presenting or attempting this quick start. Creates any required namespaces, installs operators, or applies supporting resources.

```bash
bash scripts/prepare.sh
```

### 2. Deploy the quick start

```bash
make deploy SCENARIO=scenarios/my-scenario-name
# or directly: oc apply -k scenarios/my-scenario-name/
```

### 3. Run the quick start

Open the OpenShift web console → **Help → Quick Starts** → find and launch this quick start.

### 4. Reset (optional)

Removes resources created during the quick start tasks, but keeps the namespace and any operator installations intact. Use this to re-run the tutorial without full teardown and re-preparation.

```bash
bash scripts/reset.sh
```

### 5. Clean up

Removes all resources created by this scenario, including the ConsoleQuickStart resource.

```bash
make cleanup SCENARIO=scenarios/my-scenario-name
# or directly: bash scripts/cleanup.sh
```

## Standalone use

This scenario is fully self-contained. It ships with its own `kustomization.yaml` and can be deployed without any root-level configuration:

```bash
bash scripts/prepare.sh
oc apply -k .     # run from the scenario directory
```

It does not depend on any other scenario in this repository.

## Troubleshooting

Document known issues, common failure points, and how to recover.

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| Quick start not visible in console | Not applied, or insufficient RBAC | `oc get consolequickstart my-scenario-name` to verify; check `accessReviewResources` |
| Prepare script fails | Not logged in | Run `oc whoami` to verify cluster connectivity |
