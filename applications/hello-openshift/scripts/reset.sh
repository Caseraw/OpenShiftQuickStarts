#!/usr/bin/env bash
# applications/hello-openshift/scripts/reset.sh
#
# This application is stateless — there is no scenario-created runtime state
# to remove. The Deployment is left running, ready for a fresh tutorial run.
#
# Usage:
#   bash applications/hello-openshift/scripts/reset.sh
set -euo pipefail

echo "==> Resetting application: hello-openshift"
echo ""
echo "  Nothing to reset — hello-openshift is stateless."
echo ""
echo "==> Reset complete."
