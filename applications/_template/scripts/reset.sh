#!/usr/bin/env bash
# reset.sh — Remove runtime state created during the scenario, keeping the
# application itself installed and ready for a fresh run.
#
# Usage (from the application directory):
#   bash scripts/reset.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="$(basename "${APP_DIR}")"

echo "==> Resetting application: ${APP_NAME}"
echo ""

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

# TODO: Remove any scenario-created runtime state here (e.g. user-created
# objects, populated databases, uploaded files). Leave the core application
# resources intact so participants can start the scenario again without
# a full re-deploy.

echo "==> Reset complete."
