#!/usr/bin/env bash
# reset.sh — Reset the "openshift-dashboard-overview" scenario to its initial state.
#
# Removes resources created during the quick start tasks, but keeps the
# namespace and any operator installations intact. Use this to re-run the
# tutorial without full teardown and re-preparation.
#
# Usage (from the scenario directory):
#   bash scripts/reset.sh
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Sufficient privileges to delete the resources being reset
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

echo "==> Resetting scenario: $SCENARIO_NAME"
echo ""

# ---------------------------------------------------------------------------
# Verify cluster connectivity.
# ---------------------------------------------------------------------------
if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

# ---------------------------------------------------------------------------
# Add reset steps below. Remove only the resources created during the quick
# start tasks, leaving the namespace and operator installations in place.
#
# Always use --ignore-not-found so the script is safe to run multiple times.
#
# Examples:
#
# Delete workloads created during the tasks:
#
#   NAMESPACE="qs-${SCENARIO_NAME}"
#   oc delete deployment,service,route -l app=my-app \
#     -n "$NAMESPACE" --ignore-not-found
#   echo "  Deleted application workloads."
#
# Restore a ConfigMap to its original values:
#
#   oc apply -f "$SCENARIO_DIR/resources/configmap.yaml" -n "$NAMESPACE"
#   echo "  Restored ConfigMap to original state."
# ---------------------------------------------------------------------------

echo "  No reset steps are required for this scenario."
echo ""
echo "==> Reset complete."
