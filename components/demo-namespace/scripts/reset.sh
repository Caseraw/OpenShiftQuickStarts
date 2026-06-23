#!/usr/bin/env bash
# reset.sh — Remove scenario-created workloads from "qs-demo", leaving the namespace intact.
#
# Deletes Deployments, Services, Routes, Jobs, and ConfigMaps that scenarios
# created inside the namespace during tutorial tasks. The namespace itself,
# its ResourceQuota, and its LimitRange are preserved so the component does
# not need to be fully redeployed between tutorial runs.
#
# Usage (from the component directory):
#   bash scripts/reset.sh
#
# or via Makefile (from the repo root):
#   make component-reset COMPONENT=components/demo-namespace
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Sufficient privileges to delete workloads in qs-demo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"
NAMESPACE="qs-demo"

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

# Remove workloads that were created by scenario tutorials.
# Scenarios must label their resources with:
#   app.kubernetes.io/part-of: openshift-quickstarts
# This keeps OpenShift-managed system resources (kube-root-ca.crt,
# service-account secrets, etc.) untouched.
echo "  Removing scenario workloads from namespace '$NAMESPACE'..."
oc delete deployment,statefulset,daemonset,job,cronjob,service,route,configmap,secret,pvc \
  -n "$NAMESPACE" \
  -l "app.kubernetes.io/part-of=openshift-quickstarts" \
  --ignore-not-found 2>/dev/null || true

echo "  Workloads removed."
echo ""
echo "==> Reset complete. Namespace '$NAMESPACE' is ready for a fresh tutorial run."
