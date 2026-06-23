#!/usr/bin/env bash
# environment/scripts/import-spokes.sh
#
# Imports every spoke cluster defined in env.sh into RHACM using the
# auto-import mechanism.
#
# For each spoke the script:
#   1. Logs into the spoke, captures an OAuth token, then returns to the hub
#   2. Creates the ManagedCluster namespace on the hub (idempotent)
#   3. Applies ManagedCluster, auto-import-secret, KlusterletAddonConfig
#   4. Waits up to WAIT_TIMEOUT seconds for the cluster to become Available
#
# Re-running is safe — clusters already in Available state are skipped;
# clusters stuck in Pending have their auto-import-secret refreshed.
#
# Note: OAuth tokens for admin users expire after ~24 h in OpenShift.
#       Re-running this script before the cluster falls offline will
#       refresh the token automatically.
#
# Usage:
#   bash environment/scripts/import-spokes.sh
#   make env-import-spokes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$(dirname "${SCRIPT_DIR}")"

# ── Output helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}── $* ${NC}"; echo ""; }

# ── Configuration ─────────────────────────────────────────────────────────────
# Maximum seconds to wait for a ManagedCluster to become Available.
WAIT_TIMEOUT="${SPOKE_IMPORT_TIMEOUT:-300}"
# Temp kubeconfig used when logging into spoke clusters.
SPOKE_KUBECONFIG="/tmp/spoke-import-kubeconfig-$$"

# ── Cleanup on exit ───────────────────────────────────────────────────────────
cleanup() { rm -f "${SPOKE_KUBECONFIG}"; }
trap cleanup EXIT

# ── Source env.sh ─────────────────────────────────────────────────────────────
ENV_FILE="${ENV_DIR}/env.sh"
if [[ ! -f "${ENV_FILE}" ]]; then
  error "environment/env.sh not found. Copy env.sh.example and fill in values."
  exit 1
fi
# shellcheck source=/dev/null
source "${ENV_FILE}"

# ── Validate required variables ───────────────────────────────────────────────
: "${SPOKE_COUNT:?SPOKE_COUNT must be set in env.sh}"
: "${HUB_API_URL:?HUB_API_URL must be set in env.sh}"
: "${HUB_USERNAME:?HUB_USERNAME must be set in env.sh}"
: "${HUB_PASSWORD:?HUB_PASSWORD must be set in env.sh}"

if [[ "${SPOKE_COUNT}" -eq 0 ]]; then
  warn "SPOKE_COUNT=0 — nothing to import."
  exit 0
fi

# ── Verify hub is reachable and RHACM is running ──────────────────────────────
header "Pre-flight"

info "Verifying connection to hub..."
if ! oc whoami &>/dev/null; then
  error "Not logged in to the hub. Run: oc login ${HUB_API_URL}"
  exit 1
fi

info "Verifying MultiClusterHub is Running..."
MCH_STATUS=$(oc get multiclusterhub multiclusterhub \
  -n open-cluster-management \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [[ "${MCH_STATUS}" != "Running" ]]; then
  error "MultiClusterHub status is '${MCH_STATUS}' — RHACM must be Running before importing spokes."
  exit 1
fi
success "MultiClusterHub is Running."

# ── Helper: get an auth token from a spoke cluster ────────────────────────────
_get_spoke_token() {
  local api_url="$1" username="$2" password="$3"

  KUBECONFIG="${SPOKE_KUBECONFIG}" \
    oc login "${api_url}" \
      --username="${username}" \
      --password="${password}" \
      --insecure-skip-tls-verify \
      --kubeconfig="${SPOKE_KUBECONFIG}" \
      &>/dev/null

  KUBECONFIG="${SPOKE_KUBECONFIG}" oc whoami --show-token 2>/dev/null
}

# ── Helper: apply a single spoke import ───────────────────────────────────────
_import_spoke() {
  local index="$1"
  local name_var="SPOKE${index}_NAME"
  local api_var="SPOKE${index}_API_URL"
  local user_var="SPOKE${index}_USERNAME"
  local pass_var="SPOKE${index}_PASSWORD"

  local cluster_name="${!name_var:-}"
  local api_url="${!api_var:-}"
  local username="${!user_var:-}"
  local password="${!pass_var:-}"

  if [[ -z "${cluster_name}" || -z "${api_url}" || -z "${username}" || -z "${password}" ]]; then
    warn "Spoke ${index}: missing variables (${name_var}, ${api_var}, ${user_var}, ${pass_var}) — skipping."
    return 0
  fi

  header "Spoke ${index}: ${cluster_name}"

  # ── Check if already Available ────────────────────────────────────────────
  local current_status
  current_status=$(oc get managedcluster "${cluster_name}" \
    -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' \
    2>/dev/null || echo "")

  if [[ "${current_status}" == "True" ]]; then
    success "Cluster '${cluster_name}' is already Available — skipping."
    return 0
  fi

  if [[ -n "${current_status}" ]]; then
    warn "Cluster '${cluster_name}' exists but is not Available (status: '${current_status}') — refreshing auto-import-secret."
  else
    info "Cluster '${cluster_name}' not yet imported — starting import."
  fi

  # ── Get token from spoke ──────────────────────────────────────────────────
  info "Logging into spoke at ${api_url}..."
  local token
  token=$(_get_spoke_token "${api_url}" "${username}" "${password}")
  if [[ -z "${token}" ]]; then
    error "Failed to retrieve token from spoke '${cluster_name}'. Check API URL and credentials."
    return 1
  fi
  success "Token acquired from spoke '${cluster_name}'."

  # ── Return to hub ─────────────────────────────────────────────────────────
  info "Returning to hub..."
  oc login "${HUB_API_URL}" \
    --username="${HUB_USERNAME}" \
    --password="${HUB_PASSWORD}" \
    --insecure-skip-tls-verify \
    &>/dev/null
  success "Connected to hub."

  # ── Create the cluster namespace ──────────────────────────────────────────
  info "Ensuring namespace '${cluster_name}'..."
  oc create namespace "${cluster_name}" --dry-run=client -o yaml | oc apply -f - &>/dev/null

  # ── Apply ManagedCluster ──────────────────────────────────────────────────
  info "Applying ManagedCluster..."
  oc apply -f - <<EOF
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ${cluster_name}
  labels:
    name: ${cluster_name}
    cloud: auto-detect
    vendor: auto-detect
    cluster.open-cluster-management.io/clusterset: default
  annotations: {}
spec:
  hubAcceptsClient: true
EOF

  # ── Apply auto-import-secret (delete first to force re-import if refreshing) ─
  info "Applying auto-import-secret..."
  oc delete secret auto-import-secret -n "${cluster_name}" --ignore-not-found &>/dev/null
  oc create secret generic auto-import-secret \
    --namespace="${cluster_name}" \
    --from-literal=token="${token}" \
    --from-literal=server="${api_url}"

  # ── Apply KlusterletAddonConfig ───────────────────────────────────────────
  info "Applying KlusterletAddonConfig..."
  oc apply -f - <<EOF
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: ${cluster_name}
  namespace: ${cluster_name}
spec:
  clusterName: ${cluster_name}
  clusterNamespace: ${cluster_name}
  clusterLabels:
    name: ${cluster_name}
    cloud: auto-detect
    vendor: auto-detect
    cluster.open-cluster-management.io/clusterset: default
  applicationManager:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
  certPolicyController:
    enabled: true
EOF

  success "Import resources applied for '${cluster_name}'."

  # ── Wait for Available ────────────────────────────────────────────────────
  info "Waiting up to ${WAIT_TIMEOUT}s for '${cluster_name}' to become Available..."
  local elapsed=0
  local interval=10
  while [[ ${elapsed} -lt ${WAIT_TIMEOUT} ]]; do
    local status
    status=$(oc get managedcluster "${cluster_name}" \
      -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' \
      2>/dev/null || echo "")

    if [[ "${status}" == "True" ]]; then
      success "Cluster '${cluster_name}' is Available! (${elapsed}s)"
      return 0
    fi

    local joined
    joined=$(oc get managedcluster "${cluster_name}" \
      -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterJoined")].status}' \
      2>/dev/null || echo "")

    if [[ "${joined}" == "True" ]]; then
      info "  Joined hub — waiting for Available... (${elapsed}s)"
    else
      info "  Waiting for cluster to join hub... (${elapsed}s)"
    fi

    sleep ${interval}
    elapsed=$(( elapsed + interval ))
  done

  warn "Cluster '${cluster_name}' did not become Available within ${WAIT_TIMEOUT}s."
  warn "The import is still in progress. Check status with:"
  warn "  oc get managedcluster ${cluster_name}"
  return 0
}

# ── Main: iterate over all spokes ─────────────────────────────────────────────
ERRORS=0
header "Importing ${SPOKE_COUNT} spoke cluster(s)"

for i in $(seq 1 "${SPOKE_COUNT}"); do
  if ! _import_spoke "${i}"; then
    ERRORS=$(( ERRORS + 1 ))
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Summary ──${NC}"
echo ""
oc get managedcluster 2>/dev/null | grep -v "^local-cluster " || true
echo ""

if [[ ${ERRORS} -gt 0 ]]; then
  error "${ERRORS} spoke(s) failed to import. Review errors above."
  exit 1
fi

success "Spoke import complete."
