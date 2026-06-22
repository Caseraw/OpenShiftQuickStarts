#!/usr/bin/env bash
# check.sh — Pre-flight environment validation.
#
# Validates that env.sh and credential files are in place, the cluster is
# reachable, and the OCP version is compatible. Does NOT modify the cluster.
#
# Exit codes:
#   0  All required checks passed (warnings are non-fatal)
#   1  One or more required checks failed
#
# Usage:
#   bash environment/scripts/check.sh
#   make env-check
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$ENV_DIR")"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

_pass()  { printf "  ${GREEN}[PASS]${RESET}  %s\n" "$*"; PASSES=$((PASSES+1)); }
_warn()  { printf "  ${YELLOW}[WARN]${RESET}  %s\n" "$*"; WARNS=$((WARNS+1)); }
_fail()  { printf "  ${RED}[FAIL]${RESET}  %s\n" "$*"; FAILS=$((FAILS+1)); }
_skip()  { printf "  ${CYAN}[SKIP]${RESET}  %s\n" "$*"; SKIPS=$((SKIPS+1)); }
_info()  { printf "         %s\n" "$*"; }

PASSES=0; WARNS=0; FAILS=0; SKIPS=0

echo ""
echo -e "${BOLD}==> Environment pre-flight check${RESET}"
echo ""

# ---------------------------------------------------------------------------
# 1. env.sh
# ---------------------------------------------------------------------------
echo -e "${BOLD}--- env.sh ---${RESET}"
echo ""

ENV_FILE="${ENV_DIR}/env.sh"
if [ -f "$ENV_FILE" ]; then
  _pass "env.sh found: $ENV_FILE"
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  _pass "env.sh sourced without errors"

  # Check that all variables declared in env.sh.example are present in env.sh.
  # Only warn — env.sh is allowed to omit optional vars.
  EXAMPLE_VARS=$(grep -E '^export [A-Z_]+=' "${ENV_DIR}/env.sh.example" \
    | sed 's/export \([A-Z_]*\)=.*/\1/' \
    | grep -v '^REPO_ROOT$' \
    | grep -v '^CREDENTIALS_DIR$' || true)
  MISSING_VARS=()
  while IFS= read -r var; do
    [ -z "$var" ] && continue
    if [ -z "${!var:-}" ]; then
      MISSING_VARS+=("$var")
    fi
  done <<< "$EXAMPLE_VARS"

  if [ "${#MISSING_VARS[@]}" -eq 0 ]; then
    _pass "All env.sh variables are set"
  else
    for v in "${MISSING_VARS[@]}"; do
      _warn "Variable not set (will be auto-detected if possible): $v"
    done
  fi
else
  _warn "env.sh not found — using auto-detection only"
  _info "To create it: cp environment/env.sh.example environment/env.sh"
fi

echo ""

# ---------------------------------------------------------------------------
# Helper — check a single cluster's API and optionally test credentials
# Usage: _check_cluster <label> <api_url> [<username> <password>]
# ---------------------------------------------------------------------------
_check_cluster() {
  local label="$1"
  local api_url="$2"
  local username="${3:-}"
  local password="${4:-}"

  if [ -z "$api_url" ]; then
    _warn "$label: API URL not set"
    return
  fi

  # Test raw HTTPS reachability without modifying oc context.
  local http_code
  http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
    --connect-timeout 8 "${api_url}/version" 2>/dev/null || echo "000")

  if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
    _pass "$label API reachable: $api_url"
  elif [ "$http_code" = "000" ]; then
    _fail "$label API unreachable (connection timeout/refused): $api_url"
    return
  else
    _warn "$label API returned HTTP $http_code: $api_url"
  fi

  # Test credentials if provided — use a throwaway kubeconfig to avoid
  # touching the operator's current oc context.
  if [ -n "$username" ] && [ -n "$password" ]; then
    local tmp_kubeconfig
    tmp_kubeconfig=$(mktemp /tmp/qs-kubeconfig-XXXXXX)
    if KUBECONFIG="$tmp_kubeconfig" oc login "$api_url" \
        -u "$username" -p "$password" \
        --insecure-skip-tls-verify=true \
        &>/dev/null 2>&1; then
      # Read OCP version from the ClusterVersion resource (authoritative source).
      # Falls back to oc version output if the resource is unavailable.
      local ver
      ver=$(KUBECONFIG="$tmp_kubeconfig" oc get clusterversion version \
        -o jsonpath='{.status.desired.version}' 2>/dev/null || \
        KUBECONFIG="$tmp_kubeconfig" oc version 2>/dev/null | \
          grep -i 'server version' | awk '{print $NF}' || echo "?")
      _pass "$label credentials valid (user: $username, OCP: $ver)"

      # OCP version compatibility check (compare against 4.7 minimum).
      local major_minor min_version="4.7"
      major_minor=$(echo "$ver" | grep -oE '^[0-9]+\.[0-9]+' | head -1 || true)
      if [ -n "$major_minor" ]; then
        local major minor min_major min_minor
        major=$(echo "$major_minor" | cut -d. -f1)
        minor=$(echo "$major_minor" | cut -d. -f2)
        min_major=$(echo "$min_version" | cut -d. -f1)
        min_minor=$(echo "$min_version" | cut -d. -f2)
        if [ "$major" -gt "$min_major" ] || \
           ([ "$major" -eq "$min_major" ] && [ "$minor" -ge "$min_minor" ]); then
          _pass "$label OCP $major_minor meets minimum ($min_version+)"
        else
          _fail "$label OCP $major_minor is below minimum ($min_version)"
        fi
      fi
    else
      _fail "$label credentials rejected for user '$username' at $api_url"
    fi
    rm -f "$tmp_kubeconfig"
  fi
}

# ---------------------------------------------------------------------------
# 2. Cluster connectivity
# ---------------------------------------------------------------------------
echo -e "${BOLD}--- Hub cluster ---${RESET}"
echo ""

HUB_URL="${HUB_API_URL:-${CLUSTER_API_URL:-}}"
HUB_USER="${HUB_USERNAME:-}"
HUB_PASS="${HUB_PASSWORD:-}"

if [ -n "$HUB_URL" ]; then
  _check_cluster "Hub" "$HUB_URL" "$HUB_USER" "$HUB_PASS"

  # Auto-detect app domain from hub if not set
  if [ -z "${CLUSTER_APP_DOMAIN:-}" ] && [ -n "$HUB_USER" ] && [ -n "$HUB_PASS" ]; then
    _tmp_kc=$(mktemp /tmp/qs-kubeconfig-XXXXXX 2>/dev/null || echo "")
    if [ -n "$_tmp_kc" ] && KUBECONFIG="$_tmp_kc" oc login "$HUB_URL" \
        -u "$HUB_USER" -p "$HUB_PASS" --insecure-skip-tls-verify=true &>/dev/null 2>&1; then
      CLUSTER_APP_DOMAIN=$(KUBECONFIG="$_tmp_kc" oc get ingresses.config cluster \
        -o jsonpath='{.spec.domain}' 2>/dev/null || true)
      [ -n "$CLUSTER_APP_DOMAIN" ] && _info "App domain auto-detected: $CLUSTER_APP_DOMAIN"
      CLOUD_PROVIDER=$(KUBECONFIG="$_tmp_kc" oc get infrastructure cluster \
        -o jsonpath='{.spec.platformSpec.type}' 2>/dev/null || true)
      [ -n "${CLOUD_PROVIDER:-}" ] && _info "Cloud provider auto-detected: $CLOUD_PROVIDER"
    fi
    rm -f "$_tmp_kc"
  fi
else
  # Fall back to current oc context when no HUB_API_URL is set
  if oc whoami &>/dev/null 2>&1; then
    _pass "Hub (current oc context): $(oc whoami) @ $(oc whoami --show-server)"
  else
    _fail "Hub API URL not set in env.sh and no active oc session"
    _info "Set HUB_API_URL / HUB_USERNAME / HUB_PASSWORD in environment/env.sh"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Spoke clusters
# ---------------------------------------------------------------------------
SPOKE_COUNT="${SPOKE_COUNT:-0}"

if [ "$SPOKE_COUNT" -gt 0 ]; then
  echo -e "${BOLD}--- Spoke clusters (${SPOKE_COUNT} defined) ---${RESET}"
  echo ""

  for i in $(seq 1 "$SPOKE_COUNT"); do
    spoke_name_var="SPOKE${i}_NAME"
    spoke_url_var="SPOKE${i}_API_URL"
    spoke_user_var="SPOKE${i}_USERNAME"
    spoke_pass_var="SPOKE${i}_PASSWORD"

    spoke_label="${!spoke_name_var:-spoke-${i}}"
    spoke_url="${!spoke_url_var:-}"
    spoke_user="${!spoke_user_var:-}"
    spoke_pass="${!spoke_pass_var:-}"

    _check_cluster "Spoke ${i} (${spoke_label})" "$spoke_url" "$spoke_user" "$spoke_pass"
  done
  echo ""
fi

# ---------------------------------------------------------------------------
# 3. Credential files
# ---------------------------------------------------------------------------
echo -e "${BOLD}--- Credential files ---${RESET}"
echo ""

CRED_DIR="${CREDENTIALS_DIR:-${ENV_DIR}/credentials}"

# Pull secret
PULL_FILE="${PULL_SECRET_FILE:-${CRED_DIR}/pull-secret.json}"
if [ -f "$PULL_FILE" ]; then
  # Validate it is parseable JSON
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PULL_FILE" 2>/dev/null; then
    _pass "Pull secret: $PULL_FILE (valid JSON)"
  else
    _fail "Pull secret: $PULL_FILE exists but is not valid JSON"
    _info "Compare with: environment/credentials/pull-secret.json.example"
  fi
else
  _warn "Pull secret not found: $PULL_FILE"
  _info "Required for Red Hat operators (RHACM, Pipelines, etc.)"
  _info "Get yours at: https://console.redhat.com → OpenShift → Downloads → Pull secret"
  _info "Then: cp environment/credentials/pull-secret.json.example \\"
  _info "         environment/credentials/pull-secret.json"
fi

# SSH public key
SSH_PUB_FILE="${SSH_PUBLIC_KEY_FILE:-${CRED_DIR}/ssh-public-key}"
if [ -f "$SSH_PUB_FILE" ]; then
  _pass "SSH public key: $SSH_PUB_FILE"
else
  _skip "SSH public key not found: $SSH_PUB_FILE (optional)"
fi

# SSH private key
SSH_PRIV_FILE="${SSH_PRIVATE_KEY_FILE:-${CRED_DIR}/ssh-private-key}"
if [ -f "$SSH_PRIV_FILE" ]; then
  KEY_PERMS=$(stat -c "%a" "$SSH_PRIV_FILE" 2>/dev/null || stat -f "%Lp" "$SSH_PRIV_FILE" 2>/dev/null || echo "unknown")
  if [ "$KEY_PERMS" = "600" ] || [ "$KEY_PERMS" = "400" ]; then
    _pass "SSH private key: $SSH_PRIV_FILE (permissions: $KEY_PERMS)"
  else
    _warn "SSH private key: $SSH_PRIV_FILE — permissions are $KEY_PERMS (should be 600)"
    _info "Fix with: chmod 600 $SSH_PRIV_FILE"
  fi
else
  _skip "SSH private key not found: $SSH_PRIV_FILE (optional)"
fi

# Cloud credentials
CLOUD_CRED_FILE="${CLOUD_CREDENTIALS_FILE:-${CRED_DIR}/cloud-credentials.env}"
if [ -f "$CLOUD_CRED_FILE" ]; then
  _pass "Cloud credentials: $CLOUD_CRED_FILE"
else
  if [ -n "${CLOUD_PROVIDER:-}" ] && [ "${CLOUD_PROVIDER}" != "baremetal" ] && [ "${CLOUD_PROVIDER}" != "none" ]; then
    _warn "Cloud credentials not found: $CLOUD_CRED_FILE"
    _info "Cloud provider is '$CLOUD_PROVIDER' — cloud credentials may be required"
    _info "Copy: cp environment/credentials/cloud-credentials.env.example \\"
    _info "          environment/credentials/cloud-credentials.env"
  else
    _skip "Cloud credentials not found: $CLOUD_CRED_FILE (optional)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Component-specific checks
# ---------------------------------------------------------------------------
echo -e "${BOLD}--- Component checks ---${RESET}"
echo ""

# RHACM channel
RHACM_CH="${RHACM_CHANNEL:-release-2.17}"
if oc get packagemanifest advanced-cluster-management \
   -n openshift-marketplace &>/dev/null 2>&1; then
  AVAILABLE=$(oc get packagemanifest advanced-cluster-management \
    -n openshift-marketplace \
    -o jsonpath='{.status.channels[*].name}' 2>/dev/null | tr ' ' '\n' || true)
  if echo "$AVAILABLE" | grep -q "^${RHACM_CH}$"; then
    _pass "RHACM channel '$RHACM_CH' is available in the catalog"
  else
    _warn "RHACM channel '$RHACM_CH' not found — available: $(echo "$AVAILABLE" | tr '\n' ' ')"
    _info "Update RHACM_CHANNEL in environment/env.sh"
  fi
else
  _skip "RHACM PackageManifest not found — skipping RHACM channel check"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================"
echo ""
printf "  Summary: "
[ "$PASSES" -gt 0 ] && printf "${GREEN}%d passed${RESET}  " "$PASSES"
[ "$WARNS"  -gt 0 ] && printf "${YELLOW}%d warning(s)${RESET}  " "$WARNS"
[ "$SKIPS"  -gt 0 ] && printf "${CYAN}%d skipped${RESET}  " "$SKIPS"
[ "$FAILS"  -gt 0 ] && printf "${RED}%d failed${RESET}" "$FAILS"
echo ""
echo ""

if [ "$FAILS" -gt 0 ]; then
  echo -e "${RED}==> Pre-flight check FAILED — fix the errors above before proceeding.${RESET}"
  echo ""
  exit 1
elif [ "$WARNS" -gt 0 ]; then
  echo -e "${YELLOW}==> Pre-flight check passed with warnings — review the items above.${RESET}"
  echo ""
  exit 0
else
  echo -e "${GREEN}==> Pre-flight check passed.${RESET}"
  echo ""
  exit 0
fi
