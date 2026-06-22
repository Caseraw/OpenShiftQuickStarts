#!/usr/bin/env bash
# cleanup.sh — Fully uninstall RHACM from the cluster.
#
# Removal order (required to avoid orphaned resources):
#   1. Detach all managed clusters (except local-cluster)
#   2. Delete the MultiClusterHub CR and wait for the operator to clean up
#   3. Delete the Subscription to prevent re-install
#   4. Delete the ClusterServiceVersion
#   5. Delete the OperatorGroup
#   6. Delete the open-cluster-management namespace
#   7. Remove any remaining cluster-scoped CRs left by the operator
#
# This is idempotent — every delete uses --ignore-not-found.
# Expect this to take 5–10 minutes for the MultiClusterHub finalizer to complete.
#
# Usage (from the component directory):
#   bash scripts/cleanup.sh
#
# or via Makefile (from the repo root):
#   make component-cleanup COMPONENT=components/rhacm
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="open-cluster-management"
HUB_DELETE_TIMEOUT=600  # seconds

echo "==> Cleaning up component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1 — Detach non-local managed clusters
# ---------------------------------------------------------------------------
if oc api-resources --api-group=cluster.open-cluster-management.io 2>/dev/null | grep -q managedclusters; then
  echo "  Step 1: Detaching managed clusters..."
  mapfile -t clusters < <(oc get managedcluster \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
  for cluster in "${clusters[@]:-}"; do
    [ -z "$cluster" ] && continue
    [ "$cluster" = "local-cluster" ] && continue
    echo "    Detaching: $cluster"
    oc delete managedcluster "$cluster" --ignore-not-found
  done
  echo "  Managed clusters detached."
else
  echo "  Step 1: RHACM cluster API not found — skipping managed cluster detach."
fi
echo ""

# ---------------------------------------------------------------------------
# Step 2 — Delete MultiClusterHub and wait for the operator to clean up
# ---------------------------------------------------------------------------
if oc get crd multiclusterhubs.operator.open-cluster-management.io &>/dev/null; then
  if oc get multiclusterhub multiclusterhub -n "$NAMESPACE" &>/dev/null 2>&1; then
    echo "  Step 2: Deleting MultiClusterHub (waiting up to ${HUB_DELETE_TIMEOUT}s for finalizer)..."
    oc delete multiclusterhub multiclusterhub -n "$NAMESPACE" --ignore-not-found

    elapsed=0
    while oc get multiclusterhub multiclusterhub -n "$NAMESPACE" &>/dev/null 2>&1; do
      if [ "$elapsed" -ge "$HUB_DELETE_TIMEOUT" ]; then
        echo "  WARN: MultiClusterHub finalizer has not cleared after ${HUB_DELETE_TIMEOUT}s."
        echo "        Forcing removal of finalizers..."
        oc patch multiclusterhub multiclusterhub -n "$NAMESPACE" \
          --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' \
          2>/dev/null || true
        break
      fi
      printf "  [%3ds] Waiting for MultiClusterHub to be removed...\n" "$elapsed"
      sleep 15
      elapsed=$((elapsed + 15))
    done
    echo "  MultiClusterHub removed."
  else
    echo "  Step 2: MultiClusterHub not found — skipping."
  fi
else
  echo "  Step 2: MultiClusterHub CRD not found — skipping."
fi
echo ""

# ---------------------------------------------------------------------------
# Step 3 — Delete Subscription
# ---------------------------------------------------------------------------
echo "  Step 3: Deleting Subscription..."
# Use the full resource name to avoid collision with the RHACM Subscription CRD.
oc delete subscriptions.operators.coreos.com advanced-cluster-management \
  -n "$NAMESPACE" --ignore-not-found
echo "  Subscription removed."
echo ""

# ---------------------------------------------------------------------------
# Step 4 — Delete ClusterServiceVersion
# ---------------------------------------------------------------------------
echo "  Step 4: Deleting ClusterServiceVersion..."
oc delete csv \
  -n "$NAMESPACE" \
  -l operators.coreos.com/advanced-cluster-management."$NAMESPACE"= \
  --ignore-not-found 2>/dev/null || true
# Fallback: delete any RHACM CSV by name prefix
oc get csv -n "$NAMESPACE" -o name 2>/dev/null | \
  grep advanced-cluster-management | \
  xargs -r oc delete -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
echo "  CSV removed."
echo ""

# ---------------------------------------------------------------------------
# Step 5 — Delete OperatorGroup
# ---------------------------------------------------------------------------
echo "  Step 5: Deleting OperatorGroup..."
oc delete operatorgroup open-cluster-management \
  -n "$NAMESPACE" --ignore-not-found
echo "  OperatorGroup removed."
echo ""

# ---------------------------------------------------------------------------
# Step 6 — Delete namespace (removes all remaining namespaced resources)
# ---------------------------------------------------------------------------
echo "  Step 6: Deleting namespace '$NAMESPACE'..."
oc delete project "$NAMESPACE" --ignore-not-found
echo "  Namespace deletion initiated."
echo ""

# ---------------------------------------------------------------------------
# Step 7 — Remove cluster-scoped CRs left by the operator
# ---------------------------------------------------------------------------
echo "  Step 7: Removing cluster-scoped RHACM resources..."

# ClusterManagementAddOn resources
if oc api-resources --api-group=addon.open-cluster-management.io 2>/dev/null | grep -q clustermanagementaddon; then
  oc delete clustermanagementaddon --all --ignore-not-found 2>/dev/null || true
fi

# ManagedClusterSet resources
if oc api-resources --api-group=cluster.open-cluster-management.io 2>/dev/null | grep -q managedclustersets; then
  oc delete managedclusterset --all --ignore-not-found 2>/dev/null || true
fi

echo "  Cluster-scoped resources removed."
echo ""
echo "==> Component cleanup complete."
echo "  Note: the namespace deletion runs asynchronously."
echo "        Run 'oc get namespace $NAMESPACE' to confirm it is gone."
