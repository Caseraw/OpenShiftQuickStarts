#!/usr/bin/env bash
# components/rhacm-observability/scripts/deploy.sh
#
# Enables the RHACM MultiCluster Observability service backed by an ODF/NooBaa
# object storage bucket.
#
# Deployment phases:
#   1. Pre-flight  — verify RHACM MultiClusterHub is Running
#   2. Namespace   — create open-cluster-management-observability
#   3. OBC         — provision a NooBaa S3 bucket via ObjectBucketClaim
#   4. Pull-secret — copy the RHACM pull-secret into the observability namespace
#   5. Thanos      — build thanos-object-storage Secret from OBC credentials
#   6. MCO         — apply MultiClusterObservability CR
#   7. Wait        — block until observability stack is Ready
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
phase()   { echo -e "\n${BOLD}${CYAN}── Phase $* ${NC}\n"; }

OBS_NS="open-cluster-management-observability"
OBC_NAME="rhacm-observability-bucket"
OBC_TIMEOUT=120
MCO_TIMEOUT=600

# ─── Phase 1: Pre-flight ──────────────────────────────────────────────────────
phase "1 — Pre-flight"

info "Verifying RHACM MultiClusterHub is Running..."
MCH_STATUS=$(oc get multiclusterhub multiclusterhub \
  -n open-cluster-management \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [[ "${MCH_STATUS}" != "Running" ]]; then
  error "MultiClusterHub status: '${MCH_STATUS}' (expected Running)."
  error "Deploy the rhacm component first: make component-deploy COMPONENT=components/rhacm"
  exit 1
fi
success "MultiClusterHub is Running."

info "Verifying ODF/NooBaa is available..."
NOOBAA_PHASE=$(oc get noobaa noobaa -n openshift-storage \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [[ "${NOOBAA_PHASE}" != "Ready" ]]; then
  error "NooBaa phase: '${NOOBAA_PHASE}' (expected Ready). ODF must be installed."
  exit 1
fi
success "NooBaa is Ready."

# ─── Phase 2: Namespace + OBC ─────────────────────────────────────────────────
phase "2 — Namespace and ObjectBucketClaim"

info "Applying namespace and OBC..."
oc apply -k "${COMPONENT_DIR}" --server-side

info "Waiting for namespace ${OBS_NS} to become Active..."
oc wait namespace "${OBS_NS}" --for=jsonpath='{.status.phase}'=Active --timeout=60s
success "Namespace ${OBS_NS} is Active."

# ─── Phase 3: Wait for OBC to become Bound ────────────────────────────────────
phase "3 — Waiting for OBC to become Bound"

info "Waiting up to ${OBC_TIMEOUT}s for OBC '${OBC_NAME}' to become Bound..."
elapsed=0
while [[ ${elapsed} -lt ${OBC_TIMEOUT} ]]; do
  OBC_PHASE=$(oc get objectbucketclaim "${OBC_NAME}" -n "${OBS_NS}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "${OBC_PHASE}" == "Bound" ]]; then
    success "OBC '${OBC_NAME}' is Bound."
    break
  fi
  info "  OBC phase: '${OBC_PHASE:-Pending}' — waiting... (${elapsed}s)"
  sleep 5
  elapsed=$(( elapsed + 5 ))
done

if [[ "${OBC_PHASE:-}" != "Bound" ]]; then
  error "OBC '${OBC_NAME}' did not become Bound within ${OBC_TIMEOUT}s."
  exit 1
fi

# ─── Phase 4: Extract OBC credentials ────────────────────────────────────────
phase "4 — Extracting OBC credentials"

info "Reading bucket metadata from OBC ConfigMap..."
BUCKET_NAME=$(oc get configmap "${OBC_NAME}" -n "${OBS_NS}" \
  -o jsonpath='{.data.BUCKET_NAME}')
BUCKET_HOST=$(oc get configmap "${OBC_NAME}" -n "${OBS_NS}" \
  -o jsonpath='{.data.BUCKET_HOST}')
BUCKET_PORT=$(oc get configmap "${OBC_NAME}" -n "${OBS_NS}" \
  -o jsonpath='{.data.BUCKET_PORT}')

info "Reading access credentials from OBC Secret..."
ACCESS_KEY=$(oc get secret "${OBC_NAME}" -n "${OBS_NS}" \
  -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
SECRET_KEY=$(oc get secret "${OBC_NAME}" -n "${OBS_NS}" \
  -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

# Build the endpoint as "host:port" (Thanos format — no protocol prefix).
ENDPOINT="${BUCKET_HOST}:${BUCKET_PORT}"

success "Bucket: ${BUCKET_NAME}"
success "Endpoint: ${ENDPOINT}"

# ─── Phase 5: Pull-secret ─────────────────────────────────────────────────────
phase "5 — Pull-secret"

if oc get secret multiclusterhub-operator-pull-secret -n "${OBS_NS}" &>/dev/null; then
  info "multiclusterhub-operator-pull-secret already exists — skipping."
else
  info "Copying pull-secret into ${OBS_NS}..."

  # Prefer the RHACM-specific pull secret, fall back to the global one.
  if oc get secret multiclusterhub-operator-pull-secret -n open-cluster-management &>/dev/null; then
    DOCKER_CONFIG_JSON=$(oc extract secret/multiclusterhub-operator-pull-secret \
      -n open-cluster-management --to=- 2>/dev/null)
  else
    warn "multiclusterhub-operator-pull-secret not found in open-cluster-management."
    info "Falling back to global pull-secret from openshift-config."
    DOCKER_CONFIG_JSON=$(oc extract secret/pull-secret \
      -n openshift-config --to=- 2>/dev/null)
  fi

  oc create secret generic multiclusterhub-operator-pull-secret \
    -n "${OBS_NS}" \
    --from-literal=.dockerconfigjson="${DOCKER_CONFIG_JSON}" \
    --type=kubernetes.io/dockerconfigjson
  success "Pull-secret created."
fi

# ─── Phase 6: thanos-object-storage Secret ────────────────────────────────────
phase "6 — Thanos object storage secret"

# Delete and recreate so credentials are always fresh (idempotent).
oc delete secret thanos-object-storage -n "${OBS_NS}" --ignore-not-found &>/dev/null

info "Creating thanos-object-storage Secret (NooBaa S3, TLS, insecure_skip_verify)..."
oc create secret generic thanos-object-storage \
  -n "${OBS_NS}" \
  --from-literal=thanos.yaml="$(cat <<THANOS_EOF
type: s3
config:
  bucket: ${BUCKET_NAME}
  endpoint: ${ENDPOINT}
  insecure: false
  access_key: ${ACCESS_KEY}
  secret_key: ${SECRET_KEY}
  http_config:
    insecure_skip_verify: true
THANOS_EOF
)"
success "thanos-object-storage Secret created."

# ─── Phase 7: MultiClusterObservability CR ───────────────────────────────────
phase "7 — MultiClusterObservability CR"

info "Applying MultiClusterObservability..."
oc apply -f "${COMPONENT_DIR}/multiclusterobservability.yaml" --server-side
success "MultiClusterObservability CR applied."

# ─── Phase 8: Wait for Ready ──────────────────────────────────────────────────
phase "8 — Waiting for observability stack to become Ready"

info "Waiting up to ${MCO_TIMEOUT}s for MultiClusterObservability to become Ready..."
elapsed=0
while [[ ${elapsed} -lt ${MCO_TIMEOUT} ]]; do
  MCO_PHASE=$(oc get multiclusterobservability observability \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

  if [[ "${MCO_PHASE}" == "True" ]]; then
    success "MultiClusterObservability is Ready! (${elapsed}s)"
    break
  fi

  # Show the most recent condition message for visibility.
  MCO_MSG=$(oc get multiclusterobservability observability \
    -o jsonpath='{.status.conditions[-1].message}' 2>/dev/null || echo "initializing")
  info "  Status: ${MCO_MSG:-initializing} (${elapsed}s)"
  sleep 15
  elapsed=$(( elapsed + 15 ))
done

if [[ "${MCO_PHASE:-}" != "True" ]]; then
  warn "MultiClusterObservability did not reach Ready within ${MCO_TIMEOUT}s."
  warn "The stack may still be initializing. Check status with:"
  warn "  oc get multiclusterobservability observability"
  warn "  oc get pods -n ${OBS_NS}"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Summary ──${NC}"
echo ""
oc get multiclusterobservability observability \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status' \
  2>/dev/null || true
echo ""
GRAFANA_URL=$(oc get route grafana -n "${OBS_NS}" \
  -o jsonpath='https://{.spec.host}' 2>/dev/null || echo "<not yet available>")
echo -e "  ${BOLD}Grafana:${NC}    ${GRAFANA_URL}"
echo -e "  ${BOLD}Namespace:${NC}  ${OBS_NS}"
echo -e "  ${BOLD}Bucket:${NC}     ${BUCKET_NAME}"
echo ""
success "rhacm-observability deploy complete."
