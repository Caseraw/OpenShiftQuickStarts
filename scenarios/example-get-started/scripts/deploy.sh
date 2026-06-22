#!/usr/bin/env bash
# deploy.sh — Apply the "example-get-started" ConsoleQuickStart to the cluster.
#
# Uses this scenario's own kustomization.yaml so it can be deployed
# independently without any root-level configuration.
#
# Usage (from the scenario directory):
#   bash scripts/deploy.sh
#
# or via Makefile (from the repo root):
#   make deploy SCENARIO=scenarios/example-get-started
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

QS_NAME="example-get-started"

echo "==> Deploying scenario: $SCENARIO_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo ""

oc apply -k "$SCENARIO_DIR"
echo ""

if oc get consolequickstart "$QS_NAME" &>/dev/null; then
  echo "  ConsoleQuickStart '$QS_NAME' is installed."
else
  echo "  WARN: ConsoleQuickStart '$QS_NAME' was not found after apply."
  exit 1
fi

echo ""
echo "==> Deployment complete."
echo ""
echo "  Open the OpenShift web console → Help → Quick Starts"
echo "  and launch 'Example — Get started with OpenShift'."
