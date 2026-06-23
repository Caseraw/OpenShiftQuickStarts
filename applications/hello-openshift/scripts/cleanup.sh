#!/usr/bin/env bash
# applications/hello-openshift/scripts/cleanup.sh
#
# Removes the entire hello-openshift application from the cluster, including
# the namespace and all resources within it.
#
# Usage:
#   bash applications/hello-openshift/scripts/cleanup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_DIR}/../.." && pwd)"
APP_NAME="hello-openshift"
NAMESPACE="hello-openshift"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${BOLD}==> Cleaning up application: ${APP_NAME}${NC}"
echo ""

ENV_FILE="${REPO_ROOT}/environment/env.sh"
if [[ -f "${ENV_FILE}" ]]; then source "${ENV_FILE}"; fi
# shellcheck source=/dev/null
source "${REPO_ROOT}/environment/lib/cluster-target.sh"

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

if ! oc get namespace "${NAMESPACE}" &>/dev/null; then
  info "Namespace '${NAMESPACE}' does not exist — nothing to clean up."
  echo ""
  echo -e "${BOLD}==> Cleanup complete.${NC}"
  exit 0
fi

info "Deleting manifests via Kustomize..."
oc delete -k "${APP_DIR}" --ignore-not-found

info "Waiting for namespace '${NAMESPACE}' to be removed..."
timeout 120 bash -c "until ! oc get namespace ${NAMESPACE} &>/dev/null; do sleep 5; done" \
  || warn "Namespace deletion is still in progress. Check with: oc get namespace ${NAMESPACE}"

echo ""
success "Application removed."
echo ""
echo -e "${BOLD}==> Cleanup complete.${NC}"
echo ""
