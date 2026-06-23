#!/usr/bin/env bash
# applications/todo-app/scripts/update.sh
#
# Rebuilds both the PostgreSQL and Frontend images and waits for the
# deployments to roll out with the new images.
#
# Usage:
#   bash applications/todo-app/scripts/update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

PG_NAMESPACE="todo-postgresql"
FE_NAMESPACE="todo-frontend"
BUILD_TIMEOUT=600
DEPLOY_TIMEOUT=300

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${BOLD}==> Updating application: todo-app${NC}"
echo ""

ENV_FILE="${REPO_ROOT}/environment/env.sh"
if [[ -f "${ENV_FILE}" ]]; then source "${ENV_FILE}"; fi
# shellcheck source=/dev/null
source "${REPO_ROOT}/environment/lib/cluster-target.sh"

wait_for_build() {
  local ns="$1" build_name="$2"
  local elapsed=0 phase=""
  until [[ "${phase}" == "Complete" || "${phase}" == "Failed" || "${phase}" == "Error" || "${phase}" == "Cancelled" ]]; do
    phase=$(oc get build "${build_name}" -n "${ns}" \
      -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ ${elapsed} -ge ${BUILD_TIMEOUT} ]]; then
      error "Build ${build_name} timed out."; exit 1
    fi
    if [[ "${phase}" != "Complete" ]]; then
      printf "  [%3ds] %s phase: %s\n" "${elapsed}" "${build_name}" "${phase}"
      sleep 10; elapsed=$((elapsed+10))
    fi
  done
  [[ "${phase}" == "Complete" ]] || { error "Build ${build_name}: ${phase}"; exit 1; }
  success "Build complete: ${build_name}"
}

info "Starting new PostgreSQL build..."
PG_BUILD=$(oc start-build todo-postgresql -n "${PG_NAMESPACE}" -o name)
wait_for_build "${PG_NAMESPACE}" "${PG_BUILD##*/}"
echo ""

info "Starting new Frontend build..."
FE_BUILD=$(oc start-build todo-frontend -n "${FE_NAMESPACE}" -o name)
wait_for_build "${FE_NAMESPACE}" "${FE_BUILD##*/}"
echo ""

info "Waiting for PostgreSQL rollout..."
oc rollout status deployment/todo-postgresql -n "${PG_NAMESPACE}" --timeout="${DEPLOY_TIMEOUT}s"
success "PostgreSQL rolled out."

info "Waiting for Frontend rollout..."
oc rollout status deployment/todo-frontend -n "${FE_NAMESPACE}" --timeout="${DEPLOY_TIMEOUT}s"
success "Frontend rolled out."

echo ""
echo -e "${BOLD}==> Update complete.${NC}"
echo ""
