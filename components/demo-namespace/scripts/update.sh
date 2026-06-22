#!/usr/bin/env bash
# update.sh — Re-apply the "demo-namespace" component manifests to pick up definition changes.
#
# Re-applies the Kustomize resources. Existing workloads inside the namespace
# are not affected. Safe to run while the namespace is in use.
#
# Usage (from the component directory):
#   bash scripts/update.sh
#
# or via Makefile (from the repo root):
#   make component-update COMPONENT=components/demo-namespace
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="qs-demo"

echo "==> Updating component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

oc apply -k "$COMPONENT_DIR"
echo ""

echo "==> Component update complete."
echo "  Namespace '$NAMESPACE' updated with latest quota and limit range definitions."
