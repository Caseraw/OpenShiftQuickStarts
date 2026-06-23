#!/usr/bin/env bash
# environment/lib/cluster-target.sh
#
# Resolves and logs into a target cluster for application lifecycle scripts.
# Source this file AFTER sourcing environment/env.sh.
#
# Resolution order (first match wins):
#   1. Explicit overrides — TARGET_API_URL / TARGET_USERNAME / TARGET_PASSWORD
#   2. Spoke index      — TARGET_SPOKE=N  reads SPOKE{N}_* from env.sh
#   3. Default          — TARGET_SPOKE=1  (Spoke 1 when nothing is set)
#
# Usage examples:
#   bash scripts/deploy.sh                              # deploy to Spoke 1 (default)
#   TARGET_SPOKE=3 bash scripts/deploy.sh               # deploy to Spoke 3
#   TARGET_API_URL=https://... bash scripts/deploy.sh   # deploy to any cluster

# ── Helpers (define only if not already defined by the caller) ────────────────
if ! declare -f _ct_info &>/dev/null; then
  _ct_info()    { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
  _ct_success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
  _ct_warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
  _ct_error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
fi

# ── Resolve cluster variables ─────────────────────────────────────────────────
TARGET_SPOKE="${TARGET_SPOKE:-1}"

# Indirect variable lookup: SPOKE{N}_KEY → value
_ct_spoke_var() {
  local key="SPOKE${TARGET_SPOKE}_${1}"
  echo "${!key:-}"
}

TARGET_API_URL="${TARGET_API_URL:-$(_ct_spoke_var API_URL)}"
TARGET_USERNAME="${TARGET_USERNAME:-$(_ct_spoke_var USERNAME)}"
TARGET_PASSWORD="${TARGET_PASSWORD:-$(_ct_spoke_var PASSWORD)}"
TARGET_NAME="${TARGET_NAME:-$(_ct_spoke_var NAME)}"
TARGET_NAME="${TARGET_NAME:-spoke-${TARGET_SPOKE}}"

# ── Login ─────────────────────────────────────────────────────────────────────
if [[ -n "${TARGET_API_URL}" && -n "${TARGET_USERNAME}" && -n "${TARGET_PASSWORD}" ]]; then
  _ct_info "Logging into ${TARGET_NAME}: ${TARGET_API_URL}"
  if ! oc login "${TARGET_API_URL}" \
        -u "${TARGET_USERNAME}" \
        -p "${TARGET_PASSWORD}" \
        --insecure-skip-tls-verify \
        &>/dev/null; then
    _ct_error "Login failed — check TARGET_SPOKE / TARGET_API_URL / credentials."
    exit 1
  fi
  _ct_success "Logged in to ${TARGET_NAME}."
else
  _ct_warn "No target cluster vars found — using current oc context."
  if ! oc whoami &>/dev/null; then
    _ct_error "Not logged in to any cluster. Set TARGET_SPOKE or TARGET_API_URL."
    exit 1
  fi
fi
