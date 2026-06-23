#!/usr/bin/env bash
# components/gitops/scripts/update.sh
# Re-applies all GitOps manifests via Kustomize, picking up any changes to
# ApplicationSet definitions (new scenarios, updated repo URLs, revised
# Placement rules, etc.).
#
# Usage (from the component directory):
#   bash scripts/update.sh
#
# or via Makefile (from the repo root):
#   make component-update COMPONENT=components/gitops
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo -e "${BOLD}==> Updating component: gitops${NC}"
echo ""

if ! oc whoami &>/dev/null; then
  error "Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

echo -e "${CYAN}── Re-applying manifests (kustomize) ──${NC}"
echo ""

oc apply -k "${COMPONENT_DIR}"

echo ""
success "GitOps manifests updated."
echo ""
echo -e "${BOLD}==> Component update complete.${NC}"
echo ""
