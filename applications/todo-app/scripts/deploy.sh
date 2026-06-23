#!/usr/bin/env bash
# applications/todo-app/scripts/deploy.sh
#
# Deploys the todo-app (2-tier: PostgreSQL + Flask frontend) to a target cluster:
#   1. Logs into the target cluster (Spoke 1 by default via env.sh)
#   2. Applies the PostgreSQL Kustomization (Namespace, Secret, PVC,
#      ImageStream, BuildConfig, Deployment, Service)
#   3. Waits for the PostgreSQL build and deployment to be ready
#   4. Applies the frontend Kustomization (Namespace, ConfigMap, Secret,
#      ImageStream, BuildConfig, Deployment, Service, Route)
#   5. Waits for the frontend build and deployment to be ready
#   6. Prints the Route URL
#
# Usage:
#   bash applications/todo-app/scripts/deploy.sh
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

PG_NAMESPACE="todo-postgresql"
FE_NAMESPACE="todo-frontend"
BUILD_TIMEOUT=600
DEPLOY_TIMEOUT=300

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${BOLD}==> Deploying application: todo-app (2-tier)${NC}"
echo ""

# ─── Source environment ──────────────────────────────────────────────────────
ENV_FILE="${REPO_ROOT}/environment/env.sh"
if [[ -f "${ENV_FILE}" ]]; then source "${ENV_FILE}"; fi
# shellcheck source=/dev/null
source "${REPO_ROOT}/environment/lib/cluster-target.sh"

echo ""
echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# ─── Helper: wait for a build in a namespace ─────────────────────────────────
wait_for_build() {
  local ns="$1"
  local bc_label="$2"

  info "Waiting for a Build to appear in namespace ${ns}..."
  local elapsed=0
  local build_name=""
  until [[ -n "${build_name}" ]]; do
    build_name=$(oc get build -n "${ns}" \
      -l "buildconfig=${bc_label}" \
      --no-headers 2>/dev/null | head -1 | awk '{print $1}' || true)
    if [[ -z "${build_name}" ]]; then
      if [[ ${elapsed} -ge 60 ]]; then
        error "No Build appeared after 60s in namespace ${ns}."
        exit 1
      fi
      sleep 5; elapsed=$((elapsed+5))
    fi
  done
  info "Build found: ${build_name}"

  info "Streaming build logs..."
  echo ""
  oc logs -n "${ns}" "build/${build_name}" -f 2>/dev/null || true
  echo ""

  elapsed=0
  local phase=""
  until [[ "${phase}" == "Complete" || "${phase}" == "Failed" || "${phase}" == "Error" || "${phase}" == "Cancelled" ]]; do
    phase=$(oc get build "${build_name}" -n "${ns}" \
      -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ ${elapsed} -ge ${BUILD_TIMEOUT} ]]; then
      error "Build ${build_name} timed out after ${BUILD_TIMEOUT}s."
      exit 1
    fi
    if [[ "${phase}" != "Complete" ]]; then
      printf "  [%3ds] Build phase: %s\n" "${elapsed}" "${phase}"
      sleep 10; elapsed=$((elapsed+10))
    fi
  done

  if [[ "${phase}" != "Complete" ]]; then
    error "Build ${build_name} ended with phase: ${phase}"
    error "Inspect with: oc logs -n ${ns} build/${build_name}"
    exit 1
  fi
  success "Build complete: ${build_name}"
}

# ─── Deploy PostgreSQL ────────────────────────────────────────────────────────
echo -e "${CYAN}── Deploying PostgreSQL ──${NC}"
echo ""
oc apply -k "${APP_DIR}/kustomize/postgresql"
echo ""

wait_for_build "${PG_NAMESPACE}" "todo-postgresql"
echo ""

info "Waiting for PostgreSQL Deployment rollout..."
if ! oc rollout status deployment/todo-postgresql \
      -n "${PG_NAMESPACE}" \
      --timeout="${DEPLOY_TIMEOUT}s"; then
  error "PostgreSQL deployment rollout did not complete within ${DEPLOY_TIMEOUT}s."
  error "Inspect with: oc get pods -n ${PG_NAMESPACE}"
  exit 1
fi
success "PostgreSQL is ready."
echo ""

# ─── Deploy Frontend ─────────────────────────────────────────────────────────
echo -e "${CYAN}── Deploying Frontend ──${NC}"
echo ""
oc apply -k "${APP_DIR}/kustomize/frontend"
echo ""

wait_for_build "${FE_NAMESPACE}" "todo-frontend"
echo ""

info "Waiting for Frontend Deployment rollout..."
if ! oc rollout status deployment/todo-frontend \
      -n "${FE_NAMESPACE}" \
      --timeout="${DEPLOY_TIMEOUT}s"; then
  error "Frontend deployment rollout did not complete within ${DEPLOY_TIMEOUT}s."
  error "Inspect with: oc get pods -n ${FE_NAMESPACE}"
  exit 1
fi
success "Frontend is ready."
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────
ROUTE=$(oc get route todo-frontend -n "${FE_NAMESPACE}" \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "<unavailable>")

echo -e "${BOLD}==> todo-app deployed successfully.${NC}"
echo ""
echo "  PostgreSQL namespace:  ${PG_NAMESPACE}"
echo "  Frontend namespace:    ${FE_NAMESPACE}"
echo "  URL:                   https://${ROUTE}"
echo ""
