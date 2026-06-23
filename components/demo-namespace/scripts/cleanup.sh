#!/usr/bin/env bash
# cleanup.sh — Delete the "qs-demo" namespace and all resources inside it.
#
# Removes everything this component created. Safe to run multiple times
# because every delete uses --ignore-not-found.
#
# WARNING: This deletes the entire qs-demo namespace, including any workloads
#          deployed by scenarios that use this component. Run scenario cleanup
#          scripts before running this if you want to clean up in stages.
#
# Usage (from the component directory):
#   bash scripts/cleanup.sh
#
# or via Makefile (from the repo root):
#   make component-cleanup COMPONENT=components/demo-namespace
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="qs-demo"

echo "==> Cleaning up component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

oc delete project "$NAMESPACE" --ignore-not-found
echo "  Deleted namespace: $NAMESPACE"

echo ""
echo "==> Component cleanup complete."
