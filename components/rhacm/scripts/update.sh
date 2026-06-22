#!/usr/bin/env bash
# update.sh — Update the RHACM component to a new channel or re-apply manifests.
#
# By default re-applies the Subscription and MultiClusterHub manifests in-place,
# which picks up any definition changes (annotations, spec fields) without
# changing the channel. To upgrade to a new RHACM release, edit the channel
# value in subscription.yaml and then run this script.
#
# OLM handles the operator upgrade automatically once the Subscription channel
# is updated (InstallPlanApproval: Automatic). This script waits for the new
# CSV to succeed before exiting.
#
# Usage (from the component directory):
#   bash scripts/update.sh
#
# or via Makefile (from the repo root):
#   make component-update COMPONENT=components/rhacm
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="open-cluster-management"
CSV_TIMEOUT=600

echo "==> Updating component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# Re-apply Subscription (and supporting resources) to pick up any changes.
echo "  Re-applying operator manifests..."
oc apply -k "$COMPONENT_DIR"
echo ""

# Wait for OLM to converge on the expected CSV.
# Use the full resource name to avoid collision with the RHACM Subscription CRD
# (apps.open-cluster-management.io/v1) that is installed by the operator.
expected_channel=$(oc get subscriptions.operators.coreos.com advanced-cluster-management \
  -n "$NAMESPACE" -o jsonpath='{.spec.channel}' 2>/dev/null || true)
echo "  Subscription channel: ${expected_channel:-unknown}"
echo "  Waiting for CSV to succeed (timeout: ${CSV_TIMEOUT}s)..."
echo ""

elapsed=0
csv_name=""
phase=""
while [ "$elapsed" -lt "$CSV_TIMEOUT" ]; do
  csv_name=$(oc get subscriptions.operators.coreos.com advanced-cluster-management \
    -n "$NAMESPACE" -o jsonpath='{.status.currentCSV}' 2>/dev/null || true)

  if [ -n "$csv_name" ]; then
    phase=$(oc get csv "$csv_name" -n "$NAMESPACE" \
      -o jsonpath='{.status.phase}' 2>/dev/null || true)
    printf "  [%3ds] CSV: %-45s  phase: %s\n" "$elapsed" "$csv_name" "${phase:-pending}"
    if [ "$phase" = "Succeeded" ]; then
      echo ""
      echo "  CSV is Succeeded: $csv_name"
      break
    fi
  else
    printf "  [%3ds] Waiting for Subscription to resolve CSV...\n" "$elapsed"
  fi

  sleep 15
  elapsed=$((elapsed + 15))
done

if [ "$elapsed" -ge "$CSV_TIMEOUT" ] && [ "${phase:-}" != "Succeeded" ]; then
  echo ""
  echo "ERROR: Timed out after ${CSV_TIMEOUT}s waiting for CSV to succeed."
  echo "       Check: oc get csv -n $NAMESPACE"
  exit 1
fi

# Re-apply MultiClusterHub to pick up any spec changes.
if oc get crd multiclusterhubs.operator.open-cluster-management.io &>/dev/null; then
  echo ""
  echo "  Re-applying MultiClusterHub..."
  oc apply -f "$COMPONENT_DIR/multiclusterhub.yaml"
fi

echo ""
echo "==> Component update complete."
echo "  CSV: $csv_name"
