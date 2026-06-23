---
hide:
  - navigation
  - toc
---

# OpenShift Quick Starts — Workshop Guide

<div class="grid cards" markdown>

-   :material-clock-fast:{ .lg .middle } **Self-paced scenarios**

    ---

    Each scenario is a fully guided, step-by-step tutorial that runs directly
    inside the OpenShift web console — no extra tooling or browser extensions
    required.

    [:octicons-arrow-right-24: Browse scenarios](scenarios/index.md)

-   :material-console:{ .lg .middle } **In-console experience**

    ---

    Scenarios appear under **Help → Quick Starts** in every target cluster.
    Participants follow interactive task checklists without leaving the console.

-   :material-git:{ .lg .middle } **GitOps-driven deployment**

    ---

    Scenarios and supporting components are deployed fleet-wide via ArgoCD
    ApplicationSets managed by RHACM — one push to `main` reaches every cluster.

    [:octicons-arrow-right-24: Getting started](getting-started.md)

-   :material-shield-check:{ .lg .middle } **Production-grade foundations**

    ---

    The workshop infrastructure runs on a full RHACM multi-cluster setup with
    OpenShift Logging, Network Observability, and GitOps pre-installed as fleet
    policies — giving participants a realistic, feature-rich environment.

</div>

---

## What this workshop covers

This workshop introduces participants to key Red Hat OpenShift capabilities through
hands-on, in-console tutorials. Each scenario is short (5–15 minutes), opinionated,
and designed to showcase one specific platform feature in isolation.

The scenarios are deployed automatically to all workshop clusters using GitOps.
Participants only need a browser and their cluster credentials to get started.

---

## Workshop architecture

```
                ┌─────────────────────────────────┐
                │          Hub Cluster             │
                │   RHACM · GitOps · Observability │
                └────────────┬────────────────────┘
                             │ fleet policies + ApplicationSets
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │  Spoke 1 │  │  Spoke 2 │  │  Spoke N │
        │ Quick    │  │ Quick    │  │ Quick    │
        │ Starts   │  │ Starts   │  │ Starts   │
        └──────────┘  └──────────┘  └──────────┘
```

Each **Spoke cluster** receives the same set of `ConsoleQuickStart` resources, 
deployed automatically whenever a scenario is merged to `main`.

---

## Quick navigation

| | |
|---|---|
| [:material-play-circle: Get up and running](getting-started.md) | Prerequisites, environment setup, and first deployment |
| [:material-view-list: Scenarios](scenarios/index.md) | All available workshop scenarios |
