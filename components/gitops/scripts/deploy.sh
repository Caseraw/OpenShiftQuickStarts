#!/usr/bin/env bash
# components/gitops/scripts/deploy.sh
# Applies all GitOps manifests (ApplicationSets, Placements) bundled in this
# component via Kustomize. Waits for the OpenShift GitOps operator to be
# ready first, since it is installed via the RHACM fleet policy.
#
# To add a new ApplicationSet:
#   1. Add the YAML to components/gitops/applicationsets/
#   2. Reference it in components/gitops/kustomization.yaml
#
# Usage (from the component directory):
#   bash scripts/deploy.sh
#
# or via Makefile (from the repo root):
#   make component-deploy COMPONENT=components/gitops
#
# Requirements:
#   - oc CLI logged in to the hub cluster
#   - RHACM MultiClusterHub must be Running (deploy rhacm component first)
#   - rhacm-policies component must be deployed first
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${BOLD}==> Deploying component: gitops${NC}"
echo ""

if ! oc whoami &>/dev/null; then
  error "Not logged in to an OpenShift cluster. Run 'oc login' and try again."
  exit 1
fi

echo "  Cluster: $(oc whoami --show-server)"
echo "  User:    $(oc whoami)"
echo ""

# ─── Pre-flight: RHACM ───────────────────────────────────────────────────────
echo -e "${CYAN}── Pre-flight ──${NC}"
echo ""

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

# ─── Pre-flight: Wait for OpenShift GitOps operator ──────────────────────────
info "Waiting for OpenShift GitOps operator (openshift-gitops namespace)..."
GITOPS_TIMEOUT=300
GITOPS_ELAPSED=0
until oc get namespace openshift-gitops &>/dev/null; do
  if [[ $GITOPS_ELAPSED -ge $GITOPS_TIMEOUT ]]; then
    error "Timed out waiting for openshift-gitops namespace (${GITOPS_TIMEOUT}s)."
    error "The install-openshift-gitops-operator fleet policy may still be enrolling the hub."
    error "Re-run this component once the policy is Compliant."
    exit 1
  fi
  printf "  [%3ds] Waiting for openshift-gitops namespace...\n" "$GITOPS_ELAPSED"
  sleep 15
  GITOPS_ELAPSED=$(( GITOPS_ELAPSED + 15 ))
done

info "Waiting for ArgoCD instance to become Available..."
ARGOCD_TIMEOUT=300
ARGOCD_ELAPSED=0
until oc get argocd openshift-gitops -n openshift-gitops &>/dev/null; do
  if [[ $ARGOCD_ELAPSED -ge $ARGOCD_TIMEOUT ]]; then
    error "Timed out waiting for ArgoCD CR (${ARGOCD_TIMEOUT}s)."
    exit 1
  fi
  printf "  [%3ds] Waiting for ArgoCD CR...\n" "$ARGOCD_ELAPSED"
  sleep 15
  ARGOCD_ELAPSED=$(( ARGOCD_ELAPSED + 15 ))
done

ARGOCD_STATUS=$(oc get argocd openshift-gitops -n openshift-gitops \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [[ "${ARGOCD_STATUS}" != "Available" ]]; then
  warn "ArgoCD phase is '${ARGOCD_STATUS}' — waiting up to 120s for Available..."
  oc wait argocd openshift-gitops -n openshift-gitops \
    --for=jsonpath='{.status.phase}'=Available --timeout=120s 2>/dev/null || true
fi
success "ArgoCD instance is ready."

# ─── Apply via Kustomize ─────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}── Applying manifests (kustomize) ──${NC}"
echo ""

oc apply -k "${COMPONENT_DIR}"

# ─── Verify ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}── Verification ──${NC}"
echo ""

info "ApplicationSets in openshift-gitops:"
oc get applicationset -n openshift-gitops 2>/dev/null \
  | grep -v "^NAME" \
  | while read -r name rest; do
      printf "  %-40s %s\n" "$name" "$rest"
    done || true

APPSET_COUNT=$(oc get applicationset -n openshift-gitops \
  --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo ""
success "${APPSET_COUNT} ApplicationSet(s) active."

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}==> Component deployed.${NC}"
echo ""
echo "  Kustomization:   ${COMPONENT_DIR}/kustomization.yaml"
echo "  ApplicationSets: ${APPSET_COUNT}"
echo ""
echo "  ArgoCD console:"
ARGOCD_HOST=$(oc get route openshift-gitops-server -n openshift-gitops \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "<not yet available>")
echo "    https://${ARGOCD_HOST}"
echo ""
