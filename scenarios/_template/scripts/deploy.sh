#!/usr/bin/env bash
# deploy.sh — Apply the "my-scenario-name" ConsoleQuickStart to the cluster.
#
# Uses this scenario's kustomization.yaml so the scenario can be deployed
# independently of any root-level configuration.
#
# Run scripts/prepare.sh first if this scenario requires cluster prerequisites
# (namespaces, operators, supporting resources).
#
# Usage (from the scenario directory):
#   bash scripts/deploy.sh
#
# or via Makefile (from the repo root):
#   make deploy SCENARIO=scenarios/my-scenario-name
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

# ---------------------------------------------------------------------------
# Update this to match spec.metadata.name in quickstart.yaml.
# ---------------------------------------------------------------------------
QS_NAME="my-scenario-name"

echo "==> Deploying scenario: $SCENARIO_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo ""

# Apply using the scenario's own kustomization so this scenario is fully
# independent and does not require a root-level kustomization to exist.
oc apply -k "$SCENARIO_DIR"
echo ""

# Verify the resource landed on the cluster.
if oc get consolequickstart "$QS_NAME" &>/dev/null; then
  echo "  ConsoleQuickStart '$QS_NAME' is installed."
else
  echo "  WARN: ConsoleQuickStart '$QS_NAME' was not found after apply."
  echo "        Check the resource name in quickstart.yaml matches QS_NAME in this script."
  exit 1
fi

echo ""
echo "==> Deployment complete."
echo ""
echo "  Open the OpenShift web console → Help → Quick Starts to launch the tutorial."
