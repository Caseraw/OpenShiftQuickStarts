# Credentials

This directory holds operator-supplied credential files. **Nothing in this
directory (except `*.example` files) is tracked by Git.**

## Setup

Copy each example file you need, remove the `.example` suffix, and fill in
real values:

```bash
cp pull-secret.json.example        pull-secret.json
cp ssh-public-key.example          ssh-public-key
cp ssh-private-key.example         ssh-private-key
cp cloud-credentials.env.example   cloud-credentials.env
```

Then run `make env-check` to validate your setup before touching the cluster.

## Files

| Example file | Real file | Required for |
|--------------|-----------|-------------|
| `pull-secret.json.example` | `pull-secret.json` | Any operator that pulls from Red Hat registries (RHACM, Pipelines, etc.) |
| `ssh-public-key.example` | `ssh-public-key` | Node access, Git repo authentication |
| `ssh-private-key.example` | `ssh-private-key` | Node access, Git repo authentication |
| `cloud-credentials.env.example` | `cloud-credentials.env` | Cloud provider API access (AWS / Azure / GCP) |

## How to get your Red Hat pull secret

1. Log in to [console.redhat.com](https://console.redhat.com)
2. Go to **OpenShift → Downloads → Pull secret**
3. Click **Download pull secret** and save it as `pull-secret.json`

## Security reminders

- Never commit real credential files. The `.gitignore` in this directory
  blocks all files except `*.example`, `README.md`, and `.gitignore` itself.
- Never log or echo credential file contents in scripts.
- Rotate credentials that are accidentally exposed immediately.
