#!/usr/bin/env bash
# deploy.sh — Install Red Hat Advanced Cluster Management (RHACM) on the cluster.
#
# Phase 1 — Operator: creates the open-cluster-management namespace, OperatorGroup,
#            and Subscription, then waits for the operator CSV to succeed.
# Phase 2 — Hub: applies the MultiClusterHub CR and waits for it to reach Running.
#
# Installation typically takes 10–20 minutes end to end.
# Both phases are idempotent — re-running is safe at any point.
#
# Usage (from the component directory):
#   bash scripts/deploy.sh
#
# or via Makefile (from the repo root):
#   make component-deploy COMPONENT=components/rhacm
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
#   - OCP 4.14 or later (RHACM 2.17 requirement)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="open-cluster-management"
CHANNEL="release-2.17"
CSV_TIMEOUT=300    # seconds to wait for the operator CSV to succeed
HUB_TIMEOUT=1200   # seconds to wait for MultiClusterHub to reach Running (up to 20 min)

echo "==> Deploying component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo "  Channel: $CHANNEL"
echo ""

# ---------------------------------------------------------------------------
# Phase 1 — Apply namespace, OperatorGroup, and Subscription
# ---------------------------------------------------------------------------
echo "--- Phase 1: Installing the RHACM operator ---"
echo ""

oc apply -k "$COMPONENT_DIR"
echo ""

# Wait for the InstallPlan to be created and the CSV to reach Succeeded.
echo "  Waiting for the RHACM CSV to succeed (timeout: ${CSV_TIMEOUT}s)..."
echo "  This typically takes 3–5 minutes..."
echo ""

elapsed=0
csv_name=""
while [ "$elapsed" -lt "$CSV_TIMEOUT" ]; do
  # Discover the CSV name from the Subscription status once it appears.
  if [ -z "$csv_name" ]; then
    # Use the full resource name to avoid collision with the RHACM Subscription CRD
    # that gets installed after Phase 1 (apps.open-cluster-management.io/v1).
    csv_name=$(oc get subscriptions.operators.coreos.com advanced-cluster-management \
      -n "$NAMESPACE" \
      -o jsonpath='{.status.currentCSV}' 2>/dev/null || true)
  fi

  if [ -n "$csv_name" ]; then
    phase=$(oc get csv "$csv_name" -n "$NAMESPACE" \
      -o jsonpath='{.status.phase}' 2>/dev/null || true)
    printf "  [%3ds] CSV: %-45s  phase: %s\n" "$elapsed" "$csv_name" "${phase:-pending}"
    if [ "$phase" = "Succeeded" ]; then
      echo ""
      echo "  Operator CSV succeeded: $csv_name"
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
  echo "       Check the operator pod logs in namespace '$NAMESPACE':"
  echo "         oc get pods -n $NAMESPACE"
  echo "         oc get csv -n $NAMESPACE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Phase 2 — Apply MultiClusterHub CR
# ---------------------------------------------------------------------------
echo ""
echo "--- Phase 2: Creating MultiClusterHub ---"
echo ""

# Verify the CRD is present before applying (it was installed by the operator).
if ! oc get crd multiclusterhubs.operator.open-cluster-management.io &>/dev/null; then
  echo "ERROR: MultiClusterHub CRD not found. The operator may not have installed correctly."
  echo "       Run: oc get csv -n $NAMESPACE"
  exit 1
fi

oc apply -f "$COMPONENT_DIR/multiclusterhub.yaml"
echo ""

echo "  Waiting for MultiClusterHub to reach Running phase (timeout: ${HUB_TIMEOUT}s)..."
echo "  This typically takes 10–15 minutes for a first install..."
echo ""

elapsed=0
while [ "$elapsed" -lt "$HUB_TIMEOUT" ]; do
  hub_phase=$(oc get multiclusterhub multiclusterhub \
    -n "$NAMESPACE" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)
  printf "  [%4ds] MultiClusterHub phase: %s\n" "$elapsed" "${hub_phase:-pending}"

  if [ "$hub_phase" = "Running" ]; then
    echo ""
    echo "  MultiClusterHub is Running."
    break
  fi

  sleep 30
  elapsed=$((elapsed + 30))
done

if [ "$elapsed" -ge "$HUB_TIMEOUT" ] && [ "${hub_phase:-}" != "Running" ]; then
  echo ""
  echo "ERROR: Timed out after ${HUB_TIMEOUT}s waiting for MultiClusterHub to reach Running."
  echo "       Current phase: ${hub_phase:-unknown}"
  echo "       Check component status:"
  echo "         oc get multiclusterhub -n $NAMESPACE"
  echo "         oc get pods -n $NAMESPACE | grep -v Running"
  exit 1
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Component deployed."
echo ""
echo "  Namespace:       $NAMESPACE"
echo "  Operator CSV:    $csv_name"
echo "  MultiClusterHub: multiclusterhub (Running)"
echo ""
echo "  Open the OpenShift web console → All Clusters to access RHACM."
