#!/usr/bin/env bash
# deploy.sh — Create the shared "qs-demo" namespace with resource quota and limit range.
#
# Usage (from the component directory):
#   bash scripts/deploy.sh
#
# or via Makefile (from the repo root):
#   make component-deploy COMPONENT=components/demo-namespace
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="qs-demo"

echo "==> Deploying component: $COMPONENT_NAME"
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

# Verify the namespace exists and is active.
STATUS=$(oc get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || true)
if [ "$STATUS" = "Active" ]; then
  echo "  Namespace '$NAMESPACE' is Active."
else
  echo "  ERROR: Namespace '$NAMESPACE' did not become Active (status: ${STATUS:-not found})."
  exit 1
fi

echo ""
echo "==> Component deployed."
echo ""
echo "  Namespace:      $NAMESPACE"
echo "  Resource quota: qs-demo-quota"
echo "  Limit range:    qs-demo-limits"
