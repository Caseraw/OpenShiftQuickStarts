#!/usr/bin/env bash
# applications/todo-app/scripts/cleanup.sh
#
# Removes the todo-app from the cluster by deleting both namespaces
# (todo-frontend and todo-postgresql) and all resources within them.
#
# Usage:
#   bash applications/todo-app/scripts/cleanup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

PG_NAMESPACE="todo-postgresql"
FE_NAMESPACE="todo-frontend"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

echo -e "${BOLD}==> Cleaning up application: todo-app${NC}"
echo ""

ENV_FILE="${REPO_ROOT}/environment/env.sh"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

if [[ -n "${SPOKE1_API_URL:-}" && -n "${SPOKE1_USERNAME:-}" && -n "${SPOKE1_PASSWORD:-}" ]]; then
  oc login "${SPOKE1_API_URL}" \
    -u "${SPOKE1_USERNAME}" \
    -p "${SPOKE1_PASSWORD}" \
    --insecure-skip-tls-verify &>/dev/null
fi

for ns in "${FE_NAMESPACE}" "${PG_NAMESPACE}"; do
  if oc get namespace "${ns}" &>/dev/null; then
    info "Deleting namespace: ${ns}"
    oc delete namespace "${ns}" --ignore-not-found
    info "Waiting for namespace ${ns} to terminate..."
    oc wait --for=delete namespace/"${ns}" --timeout=120s 2>/dev/null || \
      warn "Timeout waiting for ${ns} to terminate — it may still be terminating."
    success "Namespace ${ns} deleted."
  else
    warn "Namespace ${ns} not found — skipping."
  fi
  echo ""
done

echo -e "${BOLD}==> Cleanup complete.${NC}"
echo ""
