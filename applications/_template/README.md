# Application: <name>

> Replace this with a one-line description of what this application demonstrates.

---

## Overview

| | |
|---|---|
| **Purpose** | _What concept or pattern does this application illustrate?_ |
| **Stack** | _e.g. single container, frontend + backend, stateful workload_ |
| **Namespace** | _Target namespace on the cluster_ |

---

## What gets deployed

> List the Kubernetes resources this application creates (Deployments, Services,
> Routes, ConfigMaps, PVCs, etc.).

---

## Prerequisites

> List any operators, namespaces, or cluster capabilities that must be present
> before deploying this application.

---

## Lifecycle

```bash
# Deploy
bash applications/<name>/scripts/deploy.sh

# Reset (remove runtime state, keep app installed)
bash applications/<name>/scripts/reset.sh

# Update (re-apply manifests after changes)
bash applications/<name>/scripts/update.sh

# Remove completely
bash applications/<name>/scripts/cleanup.sh
```
