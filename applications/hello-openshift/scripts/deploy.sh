#!/usr/bin/env bash
# applications/hello-openshift/scripts/deploy.sh
#
# Deploys the hello-openshift application to a target cluster:
#   1. Logs into the target cluster (Spoke 1 by default via env.sh)
#   2. Applies all manifests via Kustomize (Namespace, ImageStream,
#      BuildConfig, Deployment, Service, Route)
#   3. Waits for the S2I Build to complete
#   4. Waits for the Deployment rollout to finish
#   5. Prints the Route URL
#
# Usage:
#   bash applications/hello-openshift/scripts/deploy.sh
#
# Environment (sourced from environment/env.sh if present):
#   TARGET_SPOKE       Spoke index to deploy to (default: 1)
#   TARGET_API_URL     Override cluster API URL directly
#   TARGET_USERNAME    Override cluster username directly
#   TARGET_PASSWORD    Override cluster password directly
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APP_DIR}/../.." && pwd)"
APP_NAME="hello-openshift"
NAMESPACE="hello-openshift"
BUILD_TIMEOUT=600   # seconds to wait for the S2I build
DEPLOY_TIMEOUT=180  # seconds to wait for the rollout

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${BOLD}==> Deploying application: ${APP_NAME}${NC}"
echo ""

# ─── Source environment and resolve target cluster ───────────────────────────
ENV_FILE="${REPO_ROOT}/environment/env.sh"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi
# shellcheck source=/dev/null
source "${REPO_ROOT}/environment/lib/cluster-target.sh"

echo ""
echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# ─── Apply build resources first ─────────────────────────────────────────────
# Namespace, ImageStream, and BuildConfig are applied first so the S2I build
# can run and push the image before the Deployment tries to pull it.
# This avoids an ImagePullBackOff on the initial pod.
echo -e "${CYAN}── Applying build resources ──${NC}"
echo ""

oc apply -f "${APP_DIR}/namespace.yaml"
oc apply -f "${APP_DIR}/imagestream.yaml"
oc apply -f "${APP_DIR}/buildconfig.yaml"

echo ""

# ─── Wait for Build ──────────────────────────────────────────────────────────
echo -e "${CYAN}── Waiting for S2I Build ──${NC}"
echo ""

info "Waiting for a Build to appear in namespace ${NAMESPACE}..."
elapsed=0
BUILD_NAME=""
until [[ -n "${BUILD_NAME}" ]]; do
  BUILD_NAME=$(oc get build -n "${NAMESPACE}" \
    -l buildconfig=hello-openshift \
    --no-headers 2>/dev/null | head -1 | awk '{print $1}' || true)
  if [[ -z "${BUILD_NAME}" ]]; then
    if [[ ${elapsed} -ge 60 ]]; then
      error "No Build appeared after 60s. Check the BuildConfig."
      exit 1
    fi
    sleep 5; elapsed=$((elapsed+5))
  fi
done
info "Build found: ${BUILD_NAME}"

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
    error "Build timed out after ${BUILD_TIMEOUT}s."
    exit 1
  fi
  if [[ "${BUILD_PHASE}" != "Complete" ]]; then
    printf "  [%3ds] Build phase: %s\n" "${elapsed}" "${BUILD_PHASE}"
    sleep 10; elapsed=$((elapsed+10))
  fi
done

if [[ "${BUILD_PHASE}" != "Complete" ]]; then
  error "Build ended with phase: ${BUILD_PHASE}"
  error "Inspect with: oc logs -n ${NAMESPACE} build/${BUILD_NAME}"
  exit 1
fi
success "Build complete: ${BUILD_NAME}"
echo ""

# ─── Apply remaining resources now that the image exists ─────────────────────
echo -e "${CYAN}── Applying remaining manifests ──${NC}"
echo ""

oc apply -f "${APP_DIR}/deployment.yaml"
oc apply -f "${APP_DIR}/service.yaml"
oc apply -f "${APP_DIR}/route.yaml"

echo ""

# ─── Wait for Deployment rollout ─────────────────────────────────────────────
echo -e "${CYAN}── Waiting for Deployment rollout ──${NC}"
echo ""

info "Waiting for rollout of deployment/${APP_NAME}..."
if ! oc rollout status deployment/"${APP_NAME}" \
      -n "${NAMESPACE}" \
      --timeout="${DEPLOY_TIMEOUT}s"; then
  error "Deployment rollout did not complete within ${DEPLOY_TIMEOUT}s."
  error "Inspect with: oc get pods -n ${NAMESPACE}"
  exit 1
fi
success "Deployment is ready."
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────
ROUTE=$(oc get route "${APP_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "<unavailable>")

echo -e "${BOLD}==> Application deployed successfully.${NC}"
echo ""
echo "  Namespace:  ${NAMESPACE}"
echo "  Build:      ${BUILD_NAME} (Complete)"
echo "  URL:        https://${ROUTE}"
echo ""
