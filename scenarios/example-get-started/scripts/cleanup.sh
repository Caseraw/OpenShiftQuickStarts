#!/usr/bin/env bash
# cleanup.sh — Remove all resources created by the "example-get-started" scenario.
#
# Deletes the example project and removes the ConsoleQuickStart resource
# from the cluster.
#
# Usage (from the scenario directory):
#   bash scripts/cleanup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

# The project name suggested to users in the quick start task description.
EXAMPLE_PROJECT="my-example-project"

echo "==> Cleaning up scenario: $SCENARIO_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

# Remove the example project created during the quick start tasks.
if oc get project "$EXAMPLE_PROJECT" &>/dev/null; then
  oc delete project "$EXAMPLE_PROJECT"
  echo "  Deleted project: $EXAMPLE_PROJECT"
else
  echo "  Project $EXAMPLE_PROJECT not found, skipping."
fi

# Remove the ConsoleQuickStart resource.
if oc delete -f "$SCENARIO_DIR/quickstart.yaml" --ignore-not-found 2>/dev/null; then
  echo "  Removed ConsoleQuickStart."
fi

echo ""
echo "==> Cleanup complete."
