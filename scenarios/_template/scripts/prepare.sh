#!/usr/bin/env bash
# prepare.sh — Set up prerequisites for the "my-scenario-name" quick start.
#
# Run this once before presenting or attempting the quick start. It creates
# any required namespaces, installs operators, or applies supporting resources.
#
# Usage (from the scenario directory):
#   bash scripts/prepare.sh
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

echo "==> Preparing scenario: $SCENARIO_NAME"
echo ""

# ---------------------------------------------------------------------------
# Verify cluster connectivity before doing anything.
# ---------------------------------------------------------------------------
if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi
echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# ---------------------------------------------------------------------------
# Add preparation steps below. Examples:
#
# Create a dedicated namespace for the scenario:
#
#   NAMESPACE="qs-${SCENARIO_NAME}"
#   if oc get project "$NAMESPACE" &>/dev/null; then
#     echo "  Project $NAMESPACE already exists, skipping."
#   else
#     oc new-project "$NAMESPACE"
#     echo "  Created project: $NAMESPACE"
#   fi
#
# Apply supporting resources bundled with the scenario:
#
#   oc apply -f "$SCENARIO_DIR/resources/" -n "$NAMESPACE"
#
# Install an operator via OLM subscription:
#
#   oc apply -f "$SCENARIO_DIR/subscription.yaml"
#   echo "  Waiting for operator to become ready..."
#   oc wait --for=condition=Available deployment/<operator-deployment> \
#     -n <operator-namespace> --timeout=300s
#
# Apply the ConsoleQuickStart itself (optional — can also use 'make apply-one'):
#
#   oc apply -f "$SCENARIO_DIR/quickstart.yaml"
# ---------------------------------------------------------------------------

echo "  No preparation steps are required for this scenario."
echo ""
echo "==> Preparation complete."
