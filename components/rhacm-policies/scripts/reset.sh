#!/usr/bin/env bash
# components/rhacm-policies/scripts/reset.sh
# Removes all Policy, Placement, and PlacementBinding resources from every
# policy namespace (leaving the namespaces and ManagedClusterSetBindings intact),
# then re-deploys all policies from the policies/ tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
POLICY_TYPES=(
  placementbindings.policy.open-cluster-management.io
  policies.policy.open-cluster-management.io
  placements.cluster.open-cluster-management.io
)

info "Removing policies from all policy namespaces..."

for ns in "${NAMESPACES[@]}"; do
  if ! oc get namespace "${ns}" &>/dev/null; then
    warn "Namespace ${ns} not found — skipping."
    continue
  fi

  info "  Namespace: ${ns}"
  for resource_type in "${POLICY_TYPES[@]}"; do
    count=$(oc get "${resource_type}" -n "${ns}" \
              -l app.kubernetes.io/part-of=openshift-quickstarts \
              --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${count}" -gt 0 ]]; then
      info "    Deleting ${count} ${resource_type}..."
      oc delete "${resource_type}" \
        -l app.kubernetes.io/part-of=openshift-quickstarts \
        -n "${ns}" --ignore-not-found
    else
      info "    No ${resource_type} found."
    fi
  done
done

success "Policy resources cleared."

echo ""
info "Re-deploying policies..."
"${SCRIPT_DIR}/deploy.sh"
