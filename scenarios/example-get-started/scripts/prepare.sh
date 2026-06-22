#!/usr/bin/env bash
# prepare.sh — Preparation for the "example-get-started" quick start.
#
# This scenario requires no pre-created cluster resources. This script
# only verifies that the oc CLI is connected to a cluster.
#
# Usage (from the scenario directory):
#   bash scripts/prepare.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(dirname "$SCRIPT_DIR")"
SCENARIO_NAME="$(basename "$SCENARIO_DIR")"

echo "==> Preparing scenario: $SCENARIO_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""
echo "  No additional preparation is required for this scenario."
echo ""
echo "==> Preparation complete."
echo ""
echo "  Next step: apply the quick start with"
echo "    make apply-one SCENARIO=$SCENARIO_DIR"
