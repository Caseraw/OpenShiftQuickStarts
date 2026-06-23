#!/usr/bin/env bash
# applications/hello-openshift/scripts/update.sh
#
# Triggers a new S2I Build to pick up source code changes committed to the
# main branch, then waits for the Build to complete and the Deployment to
# roll out the new image.
#
# Usage:
#   bash applications/hello-openshift/scripts/update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_DIR}/../.." && pwd)"
APP_NAME="hello-openshift"
NAMESPACE="hello-openshift"
BUILD_TIMEOUT=600
DEPLOY_TIMEOUT=180

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${BOLD}==> Updating application: ${APP_NAME}${NC}"
echo ""

ENV_FILE="${REPO_ROOT}/environment/env.sh"
if [[ -f "${ENV_FILE}" ]]; then source "${ENV_FILE}"; fi
# shellcheck source=/dev/null
source "${REPO_ROOT}/environment/lib/cluster-target.sh"

# Re-apply manifests in case definitions changed
info "Re-applying manifests..."
oc apply -k "${APP_DIR}"
echo ""

# Trigger a new build
info "Starting new Build..."
BUILD_NAME=$(oc start-build "${APP_NAME}" -n "${NAMESPACE}" -o name 2>/dev/null | sed 's|build.build.openshift.io/||')
info "Build started: ${BUILD_NAME}"

info "Streaming build logs..."
echo ""
oc logs -n "${NAMESPACE}" "build/${BUILD_NAME}" -f 2>/dev/null || true
echo ""

elapsed=0
BUILD_PHASE=""
until [[ "${BUILD_PHASE}" == "Complete" || "${BUILD_PHASE}" == "Failed" || "${BUILD_PHASE}" == "Error" || "${BUILD_PHASE}" == "Cancelled" ]]; do
  BUILD_PHASE=$(oc get build "${BUILD_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  if [[ ${elapsed} -ge ${BUILD_TIMEOUT} ]]; then
    error "Build timed out."
    exit 1
  fi
  if [[ "${BUILD_PHASE}" != "Complete" ]]; then
    printf "  [%3ds] Build phase: %s\n" "${elapsed}" "${BUILD_PHASE}"
    sleep 10; elapsed=$((elapsed+10))
  fi
done

if [[ "${BUILD_PHASE}" != "Complete" ]]; then
  error "Build ended with phase: ${BUILD_PHASE}"
  exit 1
fi
success "Build complete."
echo ""

info "Waiting for rollout..."
oc rollout status deployment/"${APP_NAME}" -n "${NAMESPACE}" --timeout="${DEPLOY_TIMEOUT}s"
success "Deployment updated."
echo ""

ROUTE=$(oc get route "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "<unavailable>")
echo -e "${BOLD}==> Update complete.${NC}"
echo ""
echo "  URL: https://${ROUTE}"
echo ""
