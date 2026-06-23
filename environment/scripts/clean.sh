#!/usr/bin/env bash
# clean.sh — Remove cluster resources created by apply.sh.
#
# Removes the Secrets that apply.sh pushed to the cluster. Does NOT restore
# the original pull secret — if you overwrote the cluster pull secret, you
# will need to restore it manually (see note below).
#
# Safe to run multiple times (--ignore-not-found throughout).
#
# Usage:
#   bash environment/scripts/clean.sh
#   make env-clean
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$(dirname "$SCRIPT_DIR")"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

_ok()   { printf "  ${GREEN}[OK]${RESET}    %s\n" "$*"; }
_skip() { printf "  ${CYAN}[SKIP]${RESET}  %s\n" "$*"; }
_warn() { printf "  ${YELLOW}[WARN]${RESET}  %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Source env.sh if present
# ---------------------------------------------------------------------------
ENV_FILE="${ENV_DIR}/env.sh"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

# ---------------------------------------------------------------------------
# Verify cluster connectivity
# ---------------------------------------------------------------------------
if ! oc whoami &>/dev/null 2>&1; then
  echo ""
  echo "  ERROR: Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

echo ""
echo -e "${BOLD}==> Cleaning environment from cluster${RESET}"
echo ""
echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# ---------------------------------------------------------------------------
# SSH key secrets
# ---------------------------------------------------------------------------
# echo -e "${BOLD}--- SSH key secrets ---${RESET}"
# echo ""

# if oc get secret qs-ssh-public-key -n openshift-config &>/dev/null 2>&1; then
#   oc delete secret qs-ssh-public-key -n openshift-config --ignore-not-found
#   _ok "Deleted secret: openshift-config/qs-ssh-public-key"
# else
#   _skip "Secret not found: openshift-config/qs-ssh-public-key"
# fi

# if oc get secret qs-ssh-private-key -n openshift-config &>/dev/null 2>&1; then
#   oc delete secret qs-ssh-private-key -n openshift-config --ignore-not-found
#   _ok "Deleted secret: openshift-config/qs-ssh-private-key"
# else
#   _skip "Secret not found: openshift-config/qs-ssh-private-key"
# fi

# echo ""

# ---------------------------------------------------------------------------
# Cloud credentials secret
# ---------------------------------------------------------------------------
# echo -e "${BOLD}--- Cloud credentials secret ---${RESET}"
# echo ""

# if oc get secret qs-cloud-credentials -n kube-system &>/dev/null 2>&1; then
#   oc delete secret qs-cloud-credentials -n kube-system --ignore-not-found
#   _ok "Deleted secret: kube-system/qs-cloud-credentials"
# else
#   _skip "Secret not found: kube-system/qs-cloud-credentials"
# fi

# echo ""

# ---------------------------------------------------------------------------
# Pull secret — warn only, never auto-restore
# ---------------------------------------------------------------------------
# echo -e "${BOLD}--- Pull secret ---${RESET}"
# echo ""

# _warn "The global pull secret (openshift-config/pull-secret) is NOT restored automatically."
# echo ""
# echo "          If you need to restore the original pull secret:"
# echo "          1. Download the original from https://console.redhat.com"
# echo "          2. Run: oc set data secret/pull-secret -n openshift-config \\"
# echo "                    --from-file=.dockerconfigjson=<original-pull-secret.json>"
# echo ""

echo "========================================"
echo ""
echo -e "${GREEN}==> Environment clean complete.${RESET}"
echo ""
