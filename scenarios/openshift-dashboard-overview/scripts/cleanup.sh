#!/usr/bin/env bash
# cleanup.sh — Remove all resources created by the "openshift-dashboard-overview" scenario.
#
# Removes everything: workloads, the namespace, and the ConsoleQuickStart
# resource itself. Run this after you are done with the scenario.
# Always uses --ignore-not-found so it is safe to run multiple times.
#
# Usage (from the scenario directory):
#   bash scripts/cleanup.sh
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

echo "==> Cleaning up scenario: $SCENARIO_NAME"
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
# Add cleanup steps below. Remove resources in reverse order of creation
# (workloads first, then namespace, then cluster-scoped resources last).
#
# Always use --ignore-not-found so the script is safe to run multiple times.
#
# Examples:
#
# Delete the scenario namespace (removes everything inside it at once):
#
#   NAMESPACE="qs-${SCENARIO_NAME}"
#   oc delete project "$NAMESPACE" --ignore-not-found
#   echo "  Deleted project: $NAMESPACE"
#
# Remove cluster-scoped resources created during the scenario:
#
#   oc delete clusterrolebinding my-scenario-binding --ignore-not-found
# ---------------------------------------------------------------------------

# Remove the ConsoleQuickStart resource from the cluster.
if oc delete -f "$SCENARIO_DIR/quickstart.yaml" --ignore-not-found 2>/dev/null; then
  echo "  Removed ConsoleQuickStart."
fi

echo ""
echo "==> Cleanup complete."
