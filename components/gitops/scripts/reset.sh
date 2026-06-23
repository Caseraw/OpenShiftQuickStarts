#!/usr/bin/env bash
# components/gitops/scripts/reset.sh
# There is no runtime state to reset for the gitops component.
# ApplicationSets are declarative resources — they continuously reconcile
# ArgoCD Applications from the Git repository. No scenario-created state
# lives in this component.
#
# Usage (from the component directory):
#   bash scripts/reset.sh
#
# or via Makefile (from the repo root):
#   make component-reset COMPONENT=components/gitops
set -euo pipefail

echo "==> Resetting component: gitops"
echo ""
echo "  Nothing to reset — ApplicationSets are stateless declarative resources."
echo ""
echo "==> Reset complete."
