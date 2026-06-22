#!/usr/bin/env bash
# components/rhacm-policies/scripts/deploy.sh
# Creates the three policy namespaces + ManagedClusterSetBindings, then
# applies every non-template policy file found under policies/fleet|hub|spoke/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Namespace → scope mapping ───────────────────────────────────────────────
declare -A NS_SCOPE=(
  [fleet]="acm-default-fleet-policies"
  [hub]="acm-default-hub-policies"
  [spoke]="acm-default-spoke-policies"
)
SCOPES=(fleet hub spoke)

# ─── Preflight: RHACM must be running ────────────────────────────────────────
info "Verifying RHACM MultiClusterHub is Running..."
MCH_STATUS=$(oc get multiclusterhub multiclusterhub \
  -n open-cluster-management \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [[ "${MCH_STATUS}" != "Running" ]]; then
  error "MultiClusterHub status is '${MCH_STATUS}' (expected: Running)."
  error "Deploy the rhacm component first: make component-deploy COMPONENT=rhacm"
  exit 1
fi
success "MultiClusterHub is Running."

# ─── Phase 1: Namespaces + ManagedClusterSetBindings ─────────────────────────
echo ""
info "Phase 1 — Applying policy namespaces and ManagedClusterSetBindings..."
oc apply -k "${COMPONENT_DIR}" --server-side

for scope in "${SCOPES[@]}"; do
  ns="${NS_SCOPE[$scope]}"
  info "  Waiting for namespace ${ns}..."
  oc wait namespace "${ns}" --for=jsonpath='{.status.phase}'=Active --timeout=60s
  success "  Namespace ${ns} is Active."
done

# ─── Phase 2: Apply policy files per scope ───────────────────────────────────
echo ""
info "Phase 2 — Applying policies..."
TOTAL=0

for scope in "${SCOPES[@]}"; do
  ns="${NS_SCOPE[$scope]}"
  policy_dir="${COMPONENT_DIR}/policies/${scope}"

  # Collect non-template YAML files (files not prefixed with _).
  mapfile -t policy_files < <(
    find "${policy_dir}" -maxdepth 1 -name "*.yaml" ! -name "_*" 2>/dev/null | sort
  )

  if [[ ${#policy_files[@]} -eq 0 ]]; then
    info "  [${scope}] No policy files found — skipping (add YAMLs to policies/${scope}/)."
    continue
  fi

  echo -e "${CYAN}  Scope: ${scope} → namespace: ${ns}${NC}"
  for f in "${policy_files[@]}"; do
    fname="$(basename "${f}")"
    info "    Applying ${fname}..."
    oc apply -f "${f}" -n "${ns}"
    success "    ${fname} applied."
    TOTAL=$(( TOTAL + 1 ))
  done
done

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
success "rhacm-policies deploy complete. ${TOTAL} policy file(s) applied."
echo ""
echo "  Policy namespaces:"
for scope in "${SCOPES[@]}"; do
  printf "    %-10s  %s\n" "${scope}" "${NS_SCOPE[$scope]}"
done
echo ""
echo "  To add a policy, copy a template and fill it in:"
echo "    cp policies/fleet/_template.yaml  policies/fleet/<name>.yaml"
echo "    cp policies/hub/_template.yaml    policies/hub/<name>.yaml"
echo "    cp policies/spoke/_template.yaml  policies/spoke/<name>.yaml"
