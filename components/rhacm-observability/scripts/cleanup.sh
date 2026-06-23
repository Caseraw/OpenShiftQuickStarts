#!/usr/bin/env bash
# components/rhacm-observability/scripts/cleanup.sh
# Full removal: MultiClusterObservability CR, OBC (and bucket data), all
# secrets, and the observability namespace.
# WARNING: This deletes all collected metrics data stored in the OBC bucket.
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

OBS_NS="open-cluster-management-observability"
OBC_NAME="rhacm-observability-bucket"

warn "This will permanently delete all observability data in the OBC bucket."
echo ""

# ─── Phase 1: MultiClusterObservability CR ───────────────────────────────────
info "Phase 1 — Deleting MultiClusterObservability CR..."
oc delete multiclusterobservability observability \
  --ignore-not-found --timeout=180s 2>/dev/null || true

info "  Waiting for MCO pods to terminate..."
oc wait pods --all -n "${OBS_NS}" \
  --for=delete --timeout=180s 2>/dev/null || true
success "MultiClusterObservability removed."

# ─── Phase 2: OBC (deletes bucket and all data) ───────────────────────────────
info "Phase 2 — Deleting ObjectBucketClaim (and bucket contents)..."
oc delete objectbucketclaim "${OBC_NAME}" \
  -n "${OBS_NS}" --ignore-not-found --timeout=60s 2>/dev/null || true
success "OBC deleted."

# ─── Phase 3: Secrets ─────────────────────────────────────────────────────────
info "Phase 3 — Deleting secrets..."
for secret in thanos-object-storage multiclusterhub-operator-pull-secret; do
  oc delete secret "${secret}" -n "${OBS_NS}" --ignore-not-found 2>/dev/null || true
done
success "Secrets removed."

# ─── Phase 4: Namespace ───────────────────────────────────────────────────────
info "Phase 4 — Deleting namespace ${OBS_NS}..."
if oc get namespace "${OBS_NS}" &>/dev/null; then
  oc delete namespace "${OBS_NS}" --timeout=120s
  success "Namespace ${OBS_NS} deleted."
else
  info "Namespace ${OBS_NS} not found — skipping."
fi

success "rhacm-observability cleanup complete."
