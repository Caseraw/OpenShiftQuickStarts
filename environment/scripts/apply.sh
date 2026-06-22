#!/usr/bin/env bash
# apply.sh — Push environment credentials and configuration to the cluster.
#
# Reads local credential files and creates or updates the corresponding
# cluster-side Secrets and configuration. Components and scenarios never read
# credential files directly — they only consume the cluster resources this
# script creates.
#
# Each credential section is independent and skipped with a clear message if
# the source file is absent. Re-running is always safe (idempotent).
#
# Credential → cluster resource mapping:
#   pull-secret.json          → Secret/pull-secret in openshift-config
#   ssh-public-key            → Secret/qs-ssh-public-key in openshift-config
#   ssh-private-key           → Secret/qs-ssh-private-key in openshift-config
#   cloud-credentials.env     → cloud-provider-specific Secret (see below)
#
# Usage:
#   bash environment/scripts/apply.sh
#   make env-apply
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$ENV_DIR")"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

_ok()   { printf "  ${GREEN}[OK]${RESET}    %s\n" "$*"; }
_skip() { printf "  ${CYAN}[SKIP]${RESET}  %s\n" "$*"; }
_warn() { printf "  ${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
_err()  { printf "  ${RED}[ERROR]${RESET} %s\n" "$*"; }
_info() { printf "          %s\n" "$*"; }

APPLIED=0; SKIPPED=0; ERRORS=0

# ---------------------------------------------------------------------------
# Source env.sh if present
# ---------------------------------------------------------------------------
ENV_FILE="${ENV_DIR}/env.sh"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

CRED_DIR="${CREDENTIALS_DIR:-${ENV_DIR}/credentials}"

# ---------------------------------------------------------------------------
# Verify cluster connectivity
# ---------------------------------------------------------------------------
if ! oc whoami &>/dev/null 2>&1; then
  echo ""
  _err "Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

echo ""
echo -e "${BOLD}==> Applying environment to cluster${RESET}"
echo ""
echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# ---------------------------------------------------------------------------
# Section 1 — Pull secret
# ---------------------------------------------------------------------------
# echo -e "${BOLD}--- Pull secret ---${RESET}"
# echo ""

# PULL_FILE="${PULL_SECRET_FILE:-${CRED_DIR}/pull-secret.json}"
# if [ -f "$PULL_FILE" ]; then
#   # Validate JSON before touching the cluster.
#   if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PULL_FILE" 2>/dev/null; then
#     _err "Pull secret file is not valid JSON: $PULL_FILE"
#     _info "Compare with: environment/credentials/pull-secret.json.example"
#     ERRORS=$((ERRORS+1))
#   else
#     echo "  Patching global pull secret in openshift-config..."
#     oc set data secret/pull-secret \
#       -n openshift-config \
#       --from-file=.dockerconfigjson="$PULL_FILE"
#     _ok "Global pull secret updated (openshift-config/pull-secret)"
#     _info "Note: nodes will roll to pick up the new secret — this may take a few minutes."
#     APPLIED=$((APPLIED+1))
#   fi
# else
#   _skip "Pull secret file not found: $PULL_FILE"
#   _info "Copy environment/credentials/pull-secret.json.example → pull-secret.json"
#   SKIPPED=$((SKIPPED+1))
# fi

# echo ""

# ---------------------------------------------------------------------------
# Section 2 — SSH keys
# ---------------------------------------------------------------------------
# echo -e "${BOLD}--- SSH keys ---${RESET}"
# echo ""

# SSH_PUB_FILE="${SSH_PUBLIC_KEY_FILE:-${CRED_DIR}/ssh-public-key}"
# if [ -f "$SSH_PUB_FILE" ]; then
#   oc create secret generic qs-ssh-public-key \
#     -n openshift-config \
#     --from-file=ssh-publickey="$SSH_PUB_FILE" \
#     --dry-run=client -o yaml | oc apply -f -
#   _ok "SSH public key secret applied (openshift-config/qs-ssh-public-key)"
#   APPLIED=$((APPLIED+1))
# else
#   _skip "SSH public key not found: $SSH_PUB_FILE (optional)"
#   SKIPPED=$((SKIPPED+1))
# fi

# SSH_PRIV_FILE="${SSH_PRIVATE_KEY_FILE:-${CRED_DIR}/ssh-private-key}"
# if [ -f "$SSH_PRIV_FILE" ]; then
#   oc create secret generic qs-ssh-private-key \
#     -n openshift-config \
#     --from-file=ssh-privatekey="$SSH_PRIV_FILE" \
#     --dry-run=client -o yaml | oc apply -f -
#   _ok "SSH private key secret applied (openshift-config/qs-ssh-private-key)"
#   APPLIED=$((APPLIED+1))
# else
#   _skip "SSH private key not found: $SSH_PRIV_FILE (optional)"
#   SKIPPED=$((SKIPPED+1))
# fi

# echo ""

# ---------------------------------------------------------------------------
# Section 3 — Cloud credentials
# ---------------------------------------------------------------------------
# echo -e "${BOLD}--- Cloud credentials ---${RESET}"
# echo ""

# CLOUD_CRED_FILE="${CLOUD_CREDENTIALS_FILE:-${CRED_DIR}/cloud-credentials.env}"
# if [ -f "$CLOUD_CRED_FILE" ]; then
#   # shellcheck source=/dev/null
#   source "$CLOUD_CRED_FILE"

#   PROVIDER="${CLOUD_PROVIDER:-}"
#   if [ -z "$PROVIDER" ]; then
#     PROVIDER=$(oc get infrastructure cluster \
#       -o jsonpath='{.spec.platformSpec.type}' 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
#   fi

#   case "${PROVIDER,,}" in
#     aws)
#       if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
#         oc create secret generic qs-cloud-credentials \
#           -n kube-system \
#           --from-literal=aws_access_key_id="${AWS_ACCESS_KEY_ID}" \
#           --from-literal=aws_secret_access_key="${AWS_SECRET_ACCESS_KEY}" \
#           --from-literal=aws_default_region="${AWS_DEFAULT_REGION:-us-east-1}" \
#           --dry-run=client -o yaml | oc apply -f -
#         _ok "AWS credentials applied (kube-system/qs-cloud-credentials)"
#         APPLIED=$((APPLIED+1))
#       else
#         _warn "cloud-credentials.env found but AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY are not set"
#         ERRORS=$((ERRORS+1))
#       fi
#       ;;
#     azure)
#       if [ -n "${AZURE_CLIENT_ID:-}" ] && [ -n "${AZURE_CLIENT_SECRET:-}" ]; then
#         oc create secret generic qs-cloud-credentials \
#           -n kube-system \
#           --from-literal=azure_subscription_id="${AZURE_SUBSCRIPTION_ID:-}" \
#           --from-literal=azure_tenant_id="${AZURE_TENANT_ID:-}" \
#           --from-literal=azure_client_id="${AZURE_CLIENT_ID}" \
#           --from-literal=azure_client_secret="${AZURE_CLIENT_SECRET}" \
#           --from-literal=azure_resource_group="${AZURE_RESOURCE_GROUP:-}" \
#           --from-literal=azure_region="${AZURE_REGION:-eastus}" \
#           --dry-run=client -o yaml | oc apply -f -
#         _ok "Azure credentials applied (kube-system/qs-cloud-credentials)"
#         APPLIED=$((APPLIED+1))
#       else
#         _warn "cloud-credentials.env found but AZURE_CLIENT_ID / AZURE_CLIENT_SECRET are not set"
#         ERRORS=$((ERRORS+1))
#       fi
#       ;;
#     gcp)
#       GCP_KEY="${GCP_SERVICE_ACCOUNT_KEY_FILE:-}"
#       if [ -n "$GCP_KEY" ] && [ -f "$GCP_KEY" ]; then
#         oc create secret generic qs-cloud-credentials \
#           -n kube-system \
#           --from-file=service_account.json="$GCP_KEY" \
#           --from-literal=gcp_project_id="${GCP_PROJECT_ID:-}" \
#           --from-literal=gcp_region="${GCP_REGION:-us-central1}" \
#           --dry-run=client -o yaml | oc apply -f -
#         _ok "GCP credentials applied (kube-system/qs-cloud-credentials)"
#         APPLIED=$((APPLIED+1))
#       else
#         _warn "cloud-credentials.env found but GCP_SERVICE_ACCOUNT_KEY_FILE is not set or missing"
#         ERRORS=$((ERRORS+1))
#       fi
#       ;;
#     baremetal|none|"")
#       _skip "Cloud provider is '${PROVIDER:-unset}' — skipping cloud credentials"
#       SKIPPED=$((SKIPPED+1))
#       ;;
#     *)
#       _warn "Unknown cloud provider '${PROVIDER}' — skipping cloud credentials"
#       _info "Supported: aws | azure | gcp | baremetal | none"
#       SKIPPED=$((SKIPPED+1))
#       ;;
#   esac
# else
#   _skip "Cloud credentials file not found: $CLOUD_CRED_FILE (optional)"
#   SKIPPED=$((SKIPPED+1))
# fi

# echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================"
echo ""
echo "  Applied: $APPLIED   Skipped: $SKIPPED   Errors: $ERRORS"
echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}==> Apply completed with errors — review the output above.${RESET}"
  echo ""
  exit 1
fi

echo -e "${GREEN}==> Environment applied successfully.${RESET}"
echo ""
echo "  Run 'make env-check' to verify the cluster state."
echo ""
