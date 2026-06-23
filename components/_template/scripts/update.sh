#!/usr/bin/env bash
# update.sh — Update the "my-component-name" component to its latest definition.
#
# Re-applies manifests, upgrades Helm releases, or refreshes operator
# subscriptions. Should handle the transition gracefully when the cluster
# already has an older version of the component installed.
#
# Usage (from the component directory):
#   bash scripts/update.sh
#
# or via Makefile (from the repo root):
#   make component-update COMPONENT=components/my-component-name
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"

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

# ---------------------------------------------------------------------------
# Add update steps below. Examples:
#
# Re-apply Kustomize resources (safe for additive changes):
#
#   oc apply -k "$COMPONENT_DIR"
#
# Upgrade a Helm release:
#
#   helm upgrade <release> <chart> \
#     --namespace <namespace> \
#     --values "$COMPONENT_DIR/values.yaml" \
#     --wait
#
# Bump an OLM Subscription to a new channel:
#
#   oc patch subscription <name> -n <namespace> \
#     --type=merge -p '{"spec":{"channel":"<new-channel>"}}'
# ---------------------------------------------------------------------------

echo "  No update steps are configured for this component."
echo ""
echo "==> Component update complete."
