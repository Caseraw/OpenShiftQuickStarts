#!/usr/bin/env bash
# reset.sh — Reset the "example-get-started" quick start to its initial state.
#
# Deletes the example project created during the quick start tasks so the
# tutorial can be repeated from the beginning.
#
# Usage (from the scenario directory):
#   bash scripts/reset.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

# The project name suggested to users in the quick start task description.
EXAMPLE_PROJECT="my-example-project"

echo "==> Resetting scenario: $SCENARIO_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

if oc get project "$EXAMPLE_PROJECT" &>/dev/null; then
  oc delete project "$EXAMPLE_PROJECT"
  echo "  Deleted project: $EXAMPLE_PROJECT"
else
  echo "  Project $EXAMPLE_PROJECT does not exist, nothing to reset."
fi

echo ""
echo "==> Reset complete. The quick start can now be run again from the beginning."
