#!/usr/bin/env bash
# update.sh — Re-apply manifests to pick up definition changes.
#
# Usage (from the application directory):
#   bash scripts/update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="$(basename "${APP_DIR}")"

echo "==> Updating application: ${APP_NAME}"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

oc apply -k "${APP_DIR}"

echo ""
echo "==> Application updated: ${APP_NAME}"
