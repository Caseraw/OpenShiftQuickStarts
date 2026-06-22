#!/usr/bin/env bash
# deploy.sh — Install the "my-component-name" component on the cluster.
#
# Applies the Kubernetes/OpenShift resources that make up this component.
# Must be idempotent — safe to run more than once.
#
# Usage (from the component directory):
#   bash scripts/deploy.sh
#
# or via Makefile (from the repo root):
#   make component-deploy COMPONENT=components/my-component-name
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"

echo "==> Deploying component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# ---------------------------------------------------------------------------
# Add deployment steps below. Examples:
#
# Apply Kustomize resources bundled with this component:
#
#   oc apply -k "$COMPONENT_DIR"
#
# Wait for a Deployment to become ready:
#
#   oc rollout status deployment/<name> -n <namespace> --timeout=120s
#
# Install an operator via OLM Subscription:
#
#   oc apply -f "$COMPONENT_DIR/subscription.yaml"
#   echo "  Waiting for operator to become ready..."
#   oc wait --for=condition=Available deployment/<operator-deployment> \
#     -n <operator-namespace> --timeout=300s
#
# Install a Helm chart:
#
#   helm upgrade --install <release> <chart> \
#     --namespace <namespace> --create-namespace \
#     --values "$COMPONENT_DIR/values.yaml" \
#     --wait
# ---------------------------------------------------------------------------

echo "  No deployment steps are configured for this component."
echo ""
echo "==> Component deployed."
