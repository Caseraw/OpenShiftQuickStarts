#!/usr/bin/env bash
# components/rhacm-observability/scripts/reset.sh
# Deletes the MultiClusterObservability CR and the thanos-object-storage
# Secret, then re-runs deploy.sh. The OBC bucket and its data are preserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

OBS_NS="open-cluster-management-observability"

info "Deleting MultiClusterObservability CR..."
oc delete multiclusterobservability observability \
  --ignore-not-found --timeout=120s 2>/dev/null || true

info "Waiting for observability pods to terminate..."
oc wait pods --all -n "${OBS_NS}" \
  --for=delete --timeout=120s 2>/dev/null || true

info "Deleting thanos-object-storage Secret (will be rebuilt from OBC)..."
oc delete secret thanos-object-storage -n "${OBS_NS}" --ignore-not-found 2>/dev/null || true

success "Observability CR removed. Re-deploying..."
"${SCRIPT_DIR}/deploy.sh"
