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

## Deploy

```bash
# Deploy
oc apply -k applications/<name>/

# Remove completely
oc delete namespace <namespace>
```
