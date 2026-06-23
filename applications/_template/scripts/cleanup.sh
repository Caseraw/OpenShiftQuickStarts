#!/usr/bin/env bash
# cleanup.sh — Remove the application and all its resources from the cluster.
#
# Usage (from the application directory):
#   bash scripts/cleanup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="$(basename "${APP_DIR}")"

echo "==> Cleaning up application: ${APP_NAME}"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

oc delete -k "${APP_DIR}" --ignore-not-found

echo ""
echo "==> Application removed: ${APP_NAME}"
