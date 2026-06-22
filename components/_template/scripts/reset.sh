#!/usr/bin/env bash
# reset.sh — Reset the "my-component-name" component to its post-deploy state.
#
# Removes any runtime state introduced while a scenario was running (sample
# workloads, user-created objects, changed config) but leaves the component
# itself installed. Use this to prepare the cluster for a clean tutorial re-run
# without having to tear the component down and redeploy it.
#
# Usage (from the component directory):
#   bash scripts/reset.sh
#
# or via Makefile (from the repo root):
#   make component-reset COMPONENT=components/my-component-name
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Sufficient privileges to delete the resources being reset
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"

echo "==> Resetting component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

# ---------------------------------------------------------------------------
# Add reset steps below. Remove only objects created during tutorial tasks;
# keep the namespace, operators, and any base component resources.
#
# Always use --ignore-not-found so the script is safe to run multiple times.
#
# Examples:
#
# Delete workloads created during the tutorial tasks:
#
#   oc delete deployment,service,route -l app=my-app \
#     -n <namespace> --ignore-not-found
#
# Restore a ConfigMap to its original state:
#
#   oc apply -f "$COMPONENT_DIR/base/configmap.yaml" -n <namespace>
# ---------------------------------------------------------------------------

echo "  No reset steps are configured for this component."
echo ""
echo "==> Component reset complete."
