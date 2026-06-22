# Environment

The environment layer sits below components and scenarios. It manages
**operator-supplied credentials and cluster-level configuration** that must
exist before any component can be deployed.

```
scenarios/      ← layer 3: what the user learns (ConsoleQuickStart)
components/     ← layer 2: reusable cluster assets (operators, namespaces)
environment/    ← layer 1: BYO credentials + cluster identity  ← this folder
```

## Quick start

```bash
# 1. Copy the env template and fill in your values
cp environment/env.sh.example environment/env.sh
# edit environment/env.sh

# 2. Copy the credential examples you need and fill in real values
cp environment/credentials/pull-secret.json.example \
   environment/credentials/pull-secret.json
# (repeat for any other credentials you need)

# 3. Validate everything before touching the cluster
make env-check

# 4. Push credentials to the cluster
make env-apply

# 5. Now deploy components and scenarios
make component-deploy COMPONENT=components/rhacm
make prepare deploy SCENARIO=scenarios/...
```

## Directory layout

```
environment/
├── README.md
├── env.sh.example          # Committed — shape + descriptions of all env vars
├── env.sh                  # Gitignored — your actual values
├── credentials/
│   ├── README.md
│   ├── .gitignore          # Blocks all files except *.example and README
│   ├── pull-secret.json.example
│   ├── ssh-public-key.example
│   ├── ssh-private-key.example
│   └── cloud-credentials.env.example
└── scripts/
    ├── check.sh            # Pre-flight validator — never modifies the cluster
    ├── apply.sh            # Pushes credentials/config to the cluster
    └── clean.sh            # Removes env-applied cluster resources
```

## The BYO credentials model

Credentials **never** enter the Git repository. The guarantee is enforced at
two levels:

1. `environment/env.sh` is listed in the root `.gitignore`.
2. `environment/credentials/.gitignore` blanket-ignores every file except
   `*.example` files, `README.md`, and itself.

The `*.example` files are the contract: they document the exact shape and
format of each credential so a new operator can onboard without needing
out-of-band documentation.

## `env.sh` — environment variables

`env.sh` is the single source of truth for all runtime configuration. Scripts
source it automatically when present; if it is absent, they fall back to
auto-detecting values from the live cluster (`oc whoami`, `oc get
infrastructure cluster`, etc.).

```bash
cp environment/env.sh.example environment/env.sh
# Edit environment/env.sh with your cluster details
```

## Credential files

| File | Purpose | Required for |
|------|---------|-------------|
| `pull-secret.json` | Red Hat registry auth | Any Red Hat operator |
| `ssh-public-key` | Node / Git repo access | SSH-based workflows |
| `ssh-private-key` | Node / Git repo access | SSH-based workflows |
| `cloud-credentials.env` | Cloud provider API access | Cloud-specific components |

See `credentials/README.md` for setup instructions and links.

## Makefile targets

```bash
make env-check   # Pre-flight validation — safe, never modifies cluster
make env-apply   # Push credentials/config to cluster (idempotent)
make env-clean   # Remove env-applied cluster resources
```

## Credential → cluster resource mapping

`apply.sh` creates the following cluster resources from your local files:

| Local file | Cluster resource | Namespace |
|------------|-----------------|-----------|
| `pull-secret.json` | `Secret/pull-secret` (patched) | `openshift-config` |
| `ssh-public-key` | `Secret/qs-ssh-public-key` | `openshift-config` |
| `ssh-private-key` | `Secret/qs-ssh-private-key` | `openshift-config` |
| `cloud-credentials.env` (AWS) | `Secret/qs-cloud-credentials` | `kube-system` |
| `cloud-credentials.env` (Azure) | `Secret/qs-cloud-credentials` | `kube-system` |
| `cloud-credentials.env` (GCP) | `Secret/qs-cloud-credentials` | `kube-system` |

Components and scenarios consume these cluster-side Secrets — they never read
local credential files directly.

## How components and scenarios use environment

Components and scenarios reference cluster Secrets (created by `apply.sh`)
rather than reading local files:

```bash
# In a component's deploy.sh, reference the cluster secret:
oc get secret qs-ssh-public-key -n openshift-config -o jsonpath='{.data.ssh-publickey}' | base64 -d
```

This keeps credential-handling logic in one place and means components work
correctly regardless of where or how the cluster was set up.

## Security checklist

- [ ] `environment/env.sh` is gitignored (verify with `git status`)
- [ ] No real credential files appear in `git status` output
- [ ] SSH private key has permissions `600` (`chmod 600 credentials/ssh-private-key`)
- [ ] Pull secret has been downloaded from your Red Hat account (not shared)
- [ ] Credentials are rotated on a regular schedule
