#!/usr/bin/env bash
# components/gitops/scripts/cleanup.sh
# Removes all GitOps manifests declared in the Kustomization. Applications
# managed by the ApplicationSets are pruned automatically by ArgoCD after
# the ApplicationSet is deleted.
#
# Usage (from the component directory):
#   bash scripts/cleanup.sh
#
# or via Makefile (from the repo root):
#   make component-cleanup COMPONENT=components/gitops
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo -e "${BOLD}==> Cleaning up component: gitops${NC}"
echo ""

if ! oc whoami &>/dev/null; then
  error "Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

oc delete -k "${COMPONENT_DIR}" --ignore-not-found

echo ""
success "GitOps manifests removed."
echo ""
echo -e "${BOLD}==> Component cleanup complete.${NC}"
echo ""
