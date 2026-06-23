# Application: hello-openshift

A minimal Python Flask web application that demonstrates the basics of building
and running a container workload on OpenShift using **Source-to-Image (S2I)**.

The app displays a "Hello, OpenShift!" page showing live pod information —
pod name, namespace, node, and IP — injected at runtime via the Kubernetes
Downward API. This makes it ideal for demonstrating scaling: spin up more
replicas and refresh the page to see different pods respond.

---

## Overview

| | |
|---|---|
| **Purpose** | Demonstrate S2I builds and basic application deployment |
| **Stack** | Python 3.11 · Flask 3 · Gunicorn · S2I (ubi9) |
| **Namespace** | `hello-openshift` |
| **Source dir** | `applications/hello-openshift/src/` |
| **Build type** | OpenShift Source strategy (S2I) — no local Docker required |

---

## What gets deployed

| Resource | Name | Purpose |
|---|---|---|
| `Namespace` | `hello-openshift` | Isolated namespace for the app |
| `ImageStream` | `hello-openshift` | Tracks built image tags |
| `BuildConfig` | `hello-openshift` | S2I build from this Git repo (`contextDir: applications/hello-openshift/src`) |
| `Deployment` | `hello-openshift` | Runs the app; auto-updates when a new image is built |
| `Service` | `hello-openshift` | Internal ClusterIP on port 8080 |
| `Route` | `hello-openshift` | TLS edge-terminated external URL |

---

## Prerequisites

- OpenShift 4.14 or later
- `python:3.11-ubi9` ImageStreamTag present in the `openshift` namespace
  (available by default on all OCP clusters)
- Cluster internet access to reach `github.com` (for the S2I Git clone)

---

## Deploy

Apply all manifests with Kustomize from the repo root:

```bash
oc apply -k applications/hello-openshift/
```

To remove the application, delete the namespace:

```bash
oc delete namespace hello-openshift
```

---

## How the build works

```
GitHub repo (main branch)
  └─ applications/hello-openshift/src/   ← contextDir
       ├─ app.py
       ├─ requirements.txt
       └─ templates/index.html
          │
          ▼  OpenShift S2I (python:3.11-ubi9)
          │  pip install -r requirements.txt
          │  assemble → image
          ▼
     ImageStream: hello-openshift:latest
          │
          ▼  image.openshift.io/triggers annotation
     Deployment rollout
```
