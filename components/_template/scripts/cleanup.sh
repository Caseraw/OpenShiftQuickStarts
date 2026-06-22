#!/usr/bin/env bash
# cleanup.sh — Remove all resources created by the "my-component-name" component.
#
# Deletes everything the component installed — workloads, namespaces,
# operators, Helm releases, and cluster-scoped objects. Safe to run multiple
# times because every delete uses --ignore-not-found.
#
# Usage (from the component directory):
#   bash scripts/cleanup.sh
#
# or via Makefile (from the repo root):
#   make component-cleanup COMPONENT=components/my-component-name
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT_NAME="$(basename "$COMPONENT_DIR")"

echo "==> Cleaning up component: $COMPONENT_NAME"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster."
  echo "       Run 'oc login' and try again."
  exit 1
fi

# ---------------------------------------------------------------------------
# Add cleanup steps below. Remove resources in reverse order of creation —
# workloads first, then namespaces, then cluster-scoped objects last.
#
# Always use --ignore-not-found so the script is safe to run multiple times.
#
# Examples:
#
# Delete the component namespace (removes all namespaced resources at once):
#
#   oc delete project <namespace> --ignore-not-found
#   echo "  Deleted project: <namespace>"
#
# Uninstall a Helm release:
#
#   helm uninstall <release> --namespace <namespace> --ignore-not-found
#
# Remove an OLM Subscription and its ClusterServiceVersion:
#
#   oc delete subscription <name> -n <namespace> --ignore-not-found
#   oc delete csv -n <namespace> -l operators.coreos.com/<package>=<namespace>
#
# Remove a cluster-scoped resource:
#
#   oc delete clusterrolebinding <name> --ignore-not-found
# ---------------------------------------------------------------------------

echo "  No cleanup steps are configured for this component."
echo ""
echo "==> Component cleanup complete."
