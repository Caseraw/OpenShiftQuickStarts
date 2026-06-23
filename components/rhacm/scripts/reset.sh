#!/usr/bin/env bash
# reset.sh — Remove tutorial-created RHACM objects, leaving the hub installed.
#
# Deletes ManagedClusters, Policies, PolicySets, PlacementRules, Placements,
# Applications, Channels, and Subscriptions that were created by scenario
# tutorial tasks (identified by the app.kubernetes.io/part-of label).
#
# The MultiClusterHub itself, its operator, and the local-cluster registration
# are preserved so the hub does not need to be fully reinstalled between runs.
#
# Usage (from the component directory):
#   bash scripts/reset.sh
#
# or via Makefile (from the repo root):
#   make component-reset COMPONENT=components/rhacm
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="open-cluster-management"
LABEL="app.kubernetes.io/part-of=openshift-quickstarts"

echo "==> Resetting component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

if ! oc get namespace "$NAMESPACE" &>/dev/null; then
  echo "  Namespace '$NAMESPACE' does not exist — nothing to reset."
  echo ""
  echo "==> Reset complete."
  exit 0
fi

# Verify RHACM CRDs are present before attempting to delete RHACM objects.
RHACM_READY=false
if oc get crd multiclusterhubs.operator.open-cluster-management.io &>/dev/null; then
  RHACM_READY=true
fi

if [ "$RHACM_READY" = "true" ]; then
  echo "  Removing scenario-created RHACM objects (label: $LABEL)..."

  # Cluster-scoped RHACM resources
  for kind in \
    managedclusters.cluster.open-cluster-management.io \
    policies.policy.open-cluster-management.io \
    policysets.policy.open-cluster-management.io \
    placementrules.apps.open-cluster-management.io \
    placements.cluster.open-cluster-management.io \
    channels.apps.open-cluster-management.io \
    applications.app.k8s.io; do
    if oc api-resources --api-group="${kind#*.}" &>/dev/null 2>&1 || \
       oc get crd "${kind}" &>/dev/null 2>&1; then
      resource="${kind%%.*}"
      oc delete "$resource" -l "$LABEL" --all-namespaces \
        --ignore-not-found 2>/dev/null || true
    fi
  done

  echo "  RHACM objects removed."
else
  echo "  WARN: RHACM CRDs not found — skipping RHACM-specific object cleanup."
fi

echo "  Removing any namespace-scoped scenario resources from '$NAMESPACE'..."
oc delete deployment,service,configmap,secret \
  -n "$NAMESPACE" -l "$LABEL" \
  --ignore-not-found 2>/dev/null || true

echo "  Done."
echo ""
echo "==> Reset complete. RHACM hub is ready for a fresh tutorial run."
