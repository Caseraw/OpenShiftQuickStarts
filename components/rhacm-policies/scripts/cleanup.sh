#!/usr/bin/env bash
# components/rhacm-policies/scripts/cleanup.sh
# Full removal: deletes all policy resources, ManagedClusterSetBindings, and
# the three policy namespaces themselves. This is NOT reversible without
# re-running deploy.sh.
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

NAMESPACES=(
  acm-default-fleet-policies
  acm-default-hub-policies
  acm-default-spoke-policies
)

# ─── Phase 1: Policy resources (order matters for finalizers) ─────────────────
info "Phase 1 — Removing PlacementBindings, Policies, and Placements..."
for ns in "${NAMESPACES[@]}"; do
  if ! oc get namespace "${ns}" &>/dev/null; then
    warn "Namespace ${ns} not found — skipping."
    continue
  fi

  info "  Namespace: ${ns}"

  for rtype in \
    "placementbindings.policy.open-cluster-management.io" \
    "policies.policy.open-cluster-management.io" \
    "placements.cluster.open-cluster-management.io"
  do
    oc delete "${rtype}" \
      -l app.kubernetes.io/part-of=openshift-quickstarts \
      -n "${ns}" \
      --ignore-not-found \
      --timeout=60s 2>/dev/null || true
  done
done
success "Policy resources removed."

# ─── Phase 2: ManagedClusterSetBindings ───────────────────────────────────────
info "Phase 2 — Removing ManagedClusterSetBindings..."
for ns in "${NAMESPACES[@]}"; do
  oc delete managedclustersetbinding global \
    -n "${ns}" \
    --ignore-not-found \
    --timeout=60s 2>/dev/null || true
done
success "ManagedClusterSetBindings removed."

# ─── Phase 3: Namespaces ──────────────────────────────────────────────────────
info "Phase 3 — Deleting policy namespaces..."
for ns in "${NAMESPACES[@]}"; do
  if oc get namespace "${ns}" &>/dev/null; then
    info "  Deleting namespace ${ns}..."
    oc delete namespace "${ns}" --timeout=120s
    success "  Namespace ${ns} deleted."
  else
    info "  Namespace ${ns} not found — skipping."
  fi
done

success "rhacm-policies cleanup complete."
