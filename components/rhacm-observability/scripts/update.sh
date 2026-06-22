#!/usr/bin/env bash
# components/rhacm-observability/scripts/update.sh
# Re-applies the MultiClusterObservability CR. Use this after editing
# multiclusterobservability.yaml (e.g. replica counts, storage sizes).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

OBS_NS="open-cluster-management-observability"

info "Re-applying MultiClusterObservability CR..."
oc apply -f "${COMPONENT_DIR}/multiclusterobservability.yaml" --server-side

info "Re-applying kustomize resources (namespace, OBC)..."
oc apply -k "${COMPONENT_DIR}" --server-side

success "Update applied. Check status with:"
echo "  oc get multiclusterobservability observability"
echo "  oc get pods -n ${OBS_NS}"
