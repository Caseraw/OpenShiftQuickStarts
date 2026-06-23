#!/usr/bin/env bash
# deploy.sh — Full environment and component deployment pipeline.
#
# Runs four sequential phases:
#   Phase 1 — Pre-flight check    (environment/scripts/check.sh)
#   Phase 2 — Environment apply   (environment/scripts/apply.sh)
#   Phase 3 — Component deploy    (components/<name>/scripts/deploy.sh)
#   Phase 4 — Spoke import        (environment/scripts/import-spokes.sh)
#
# Each phase must succeed before the next begins. The script is idempotent —
# re-running it on an already-configured cluster is safe.
#
# Usage:
#   bash environment/scripts/deploy.sh [options]
#   make env-deploy
#
# Options:
#   --skip-check      Skip Phase 1 (pre-flight validation)
#   --skip-apply      Skip Phase 2 (credential push)
#   --skip-components Skip Phase 3 (component deployment)
#   --skip-import     Skip Phase 4 (spoke cluster import)
#   --dry-run         Run Phase 1 only — never modifies the cluster
#   -h, --help        Show this help
#
# Requirements:
#   - oc CLI configured and logged in to your cluster
#   - Cluster administrator privileges
#   - environment/env.sh filled in (copy from env.sh.example)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$ENV_DIR")"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

_header() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
  printf "${BOLD}║  %-56s║${RESET}\n" "$*"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

_phase() {
  local num="$1"; shift
  echo ""
  echo -e "${BOLD}${CYAN}━━━ Phase ${num}: $* ${RESET}"
  echo ""
}

_ok()      { printf "  ${GREEN}✔${RESET}  %s\n" "$*"; }
_warn()    { printf "  ${YELLOW}⚠${RESET}  %s\n" "$*"; }
_fail()    { printf "  ${RED}✖${RESET}  %s\n" "$*"; }
_skip()    { printf "  ${CYAN}⊘${RESET}  %s\n" "$*"; }
_elapsed() { printf "  ${DIM}⏱  %s${RESET}\n" "$*"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
SKIP_CHECK=false
SKIP_APPLY=false
SKIP_COMPONENTS=false
SKIP_IMPORT=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --skip-check)      SKIP_CHECK=true ;;
    --skip-apply)      SKIP_APPLY=true ;;
    --skip-components) SKIP_COMPONENTS=true ;;
    --skip-import)     SKIP_IMPORT=true ;;
    --dry-run)         DRY_RUN=true; SKIP_APPLY=true; SKIP_COMPONENTS=true; SKIP_IMPORT=true ;;
    -h|--help)
      sed -n '/^# Usage:/,/^[^#]/{ /^#/{ s/^# \{0,1\}//; p }; /^[^#]/q }' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $arg  (use --help for usage)"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Component list — add or remove entries here to change what gets deployed.
# Each entry is a path relative to the repo root.
# ---------------------------------------------------------------------------
COMPONENTS=(
  "components/rhacm"
  "components/rhacm-policies"
  "components/rhacm-observability"
  "components/gitops"
)

# ---------------------------------------------------------------------------
# Timing helpers
# ---------------------------------------------------------------------------
_ts()       { date +%s; }
_duration() {
  local secs=$(( $(_ts) - $1 ))
  printf "%dm %02ds" $((secs/60)) $((secs%60))
}

# ---------------------------------------------------------------------------
# Phase runner — executes a script and tracks timing + exit code
# ---------------------------------------------------------------------------
PHASE_RESULTS=()   # "Phase N — label: PASSED/FAILED/SKIPPED (Xm Ys)"

_run_phase() {
  local num="$1" label="$2" script="$3"
  _phase "$num" "$label"

  local t0; t0=$(_ts)

  if bash "$script"; then
    local dur; dur=$(_duration "$t0")
    _ok  "Phase $num complete"
    _elapsed "$dur"
    PHASE_RESULTS+=("  Phase $num — $label: $(printf "${GREEN}PASSED${RESET}") ($dur)")
  else
    local rc=$? dur; dur=$(_duration "$t0")
    _fail "Phase $num failed (exit $rc)"
    _elapsed "$dur"
    PHASE_RESULTS+=("  Phase $num — $label: $(printf "${RED}FAILED${RESET}") ($dur)")
    echo ""
    echo -e "${RED}  Aborting deployment — fix the errors above and re-run.${RESET}"
    echo ""
    _print_summary
    exit "$rc"
  fi
}

_skip_phase() {
  local num="$1" label="$2" reason="$3"
  _phase "$num" "$label"
  _skip "Skipped — $reason"
  PHASE_RESULTS+=("  Phase $num — $label: $(printf "${CYAN}SKIPPED${RESET}") ($reason)")
}

_print_summary() {
  echo ""
  echo -e "${BOLD}━━━ Deployment summary ━━━${RESET}"
  echo ""
  for line in "${PHASE_RESULTS[@]:-}"; do
    echo -e "$line"
  done
  echo ""
}

# ---------------------------------------------------------------------------
# Source env.sh
# ---------------------------------------------------------------------------
ENV_FILE="${ENV_DIR}/env.sh"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

# ---------------------------------------------------------------------------
# Ensure we are logged into the HUB — always, regardless of current context.
# Without this, whatever cluster was last used by 'oc login' becomes the
# deployment target, which causes components to be installed on the wrong cluster.
# ---------------------------------------------------------------------------
if [ -n "${HUB_API_URL:-}" ] && [ -n "${HUB_USERNAME:-}" ] && [ -n "${HUB_PASSWORD:-}" ]; then
  echo ""
  echo -e "  ${BOLD}Logging into hub cluster…${RESET}"
  if ! oc login "${HUB_API_URL}" \
        -u "${HUB_USERNAME}" \
        -p "${HUB_PASSWORD}" \
        --insecure-skip-tls-verify \
        &>/dev/null; then
    echo -e "  ${RED}ERROR: Failed to log into hub cluster: ${HUB_API_URL}${RESET}"
    echo -e "  ${RED}       Check HUB_API_URL, HUB_USERNAME, HUB_PASSWORD in env.sh${RESET}"
    exit 1
  fi
else
  echo -e "  ${YELLOW}WARN: HUB_API_URL/HUB_USERNAME/HUB_PASSWORD not set — using current oc context.${RESET}"
fi

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
_header "OpenShift Quick Starts — Deployment Pipeline"

echo -e "  ${BOLD}Timestamp:${RESET}   $(date '+%Y-%m-%d %H:%M:%S %Z')"
if oc whoami &>/dev/null 2>&1; then
  echo -e "  ${BOLD}Cluster:${RESET}     $(oc whoami --show-server)"
  echo -e "  ${BOLD}User:${RESET}        $(oc whoami)"
fi
echo -e "  ${BOLD}Hub API:${RESET}     ${HUB_API_URL:-auto-detect}"
echo -e "  ${BOLD}Spokes:${RESET}      ${SPOKE_COUNT:-0} defined"
echo -e "  ${BOLD}Components:${RESET}  ${#COMPONENTS[@]} queued — ${COMPONENTS[*]}"
echo -e "  ${BOLD}Spokes:${RESET}      ${SPOKE_COUNT:-0} to import"
echo ""
if $DRY_RUN; then
  echo -e "  ${YELLOW}⚠  DRY-RUN mode — only the pre-flight check will run.${RESET}"
fi

DEPLOY_START=$(_ts)

# ---------------------------------------------------------------------------
# Phase 1 — Pre-flight check
# ---------------------------------------------------------------------------
if $SKIP_CHECK; then
  _skip_phase 1 "Pre-flight check" "--skip-check flag set"
else
  _run_phase 1 "Pre-flight check" "${SCRIPT_DIR}/check.sh"
fi

# ---------------------------------------------------------------------------
# Phase 2 — Environment apply (credentials)
# ---------------------------------------------------------------------------
if $SKIP_APPLY; then
  if $DRY_RUN; then
    _skip_phase 2 "Environment apply" "dry-run mode"
  else
    _skip_phase 2 "Environment apply" "--skip-apply flag set"
  fi
else
  _run_phase 2 "Environment apply" "${SCRIPT_DIR}/apply.sh"
fi

# ---------------------------------------------------------------------------
# Phase 3 — Component deployment
# ---------------------------------------------------------------------------
if $SKIP_COMPONENTS; then
  _skip_phase 3 "Component deployment" \
    "$( $DRY_RUN && echo 'dry-run mode' || echo '--skip-components flag set' )"
else
  _phase 3 "Component deployment (${#COMPONENTS[@]} component(s))"

  COMP_ERRORS=0
  for comp in "${COMPONENTS[@]}"; do
    comp_script="${REPO_ROOT}/${comp}/scripts/deploy.sh"
    comp_name="$(basename "$comp")"

    echo -e "  ${BOLD}Deploying:${RESET} $comp"
    echo ""

    if [ ! -f "$comp_script" ]; then
      _fail "deploy.sh not found: $comp_script"
      COMP_ERRORS=$((COMP_ERRORS+1))
      continue
    fi

    comp_t0=$(_ts)
    if bash "$comp_script"; then
      comp_dur=$(_duration "$comp_t0")
      _ok  "Component deployed: $comp_name"
      _elapsed "$comp_dur"
      PHASE_RESULTS+=("    ├─ $comp_name: $(printf "${GREEN}DEPLOYED${RESET}") ($comp_dur)")
    else
      comp_dur=$(_duration "$comp_t0")
      _fail "Component failed: $comp_name"
      _elapsed "$comp_dur"
      PHASE_RESULTS+=("    ├─ $comp_name: $(printf "${RED}FAILED${RESET}") ($comp_dur)")
      COMP_ERRORS=$((COMP_ERRORS+1))
    fi
    echo ""
  done

  if [ "$COMP_ERRORS" -gt 0 ]; then
    PHASE_RESULTS+=("  Phase 3 — Component deployment: $(printf "${RED}FAILED${RESET}") ($COMP_ERRORS error(s))")
    _print_summary
    exit 1
  else
    total_dur=$(_duration "$DEPLOY_START")
    PHASE_RESULTS+=("  Phase 3 — Component deployment: $(printf "${GREEN}PASSED${RESET}")")
  fi
fi

# ---------------------------------------------------------------------------
# Phase 4 — Spoke import
# ---------------------------------------------------------------------------
if $SKIP_IMPORT; then
  _skip_phase 4 "Spoke import" \
    "$( $DRY_RUN && echo 'dry-run mode' || echo '--skip-import flag set' )"
elif [ "${SPOKE_COUNT:-0}" -eq 0 ]; then
  _skip_phase 4 "Spoke import" "SPOKE_COUNT=0 — no spokes defined"
else
  _run_phase 4 "Spoke import (${SPOKE_COUNT} spoke(s))" "${SCRIPT_DIR}/import-spokes.sh"
fi

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
total_dur=$(_duration "$DEPLOY_START")
_print_summary

echo -e "  ${BOLD}Total time:${RESET} $total_dur"
echo ""

if oc whoami &>/dev/null 2>&1; then
  echo -e "  ${BOLD}Hub console:${RESET}  ${HUB_CONSOLE_URL:-$(oc whoami --show-server | sed 's|api\.|console-openshift-console.apps.|; s|:6443||')}"
fi

if [ "${SPOKE_COUNT:-0}" -gt 0 ]; then
  echo ""
  echo -e "  ${BOLD}Spoke clusters:${RESET}"
  for i in $(seq 1 "${SPOKE_COUNT}"); do
    spoke_name_var="SPOKE${i}_NAME"
    spoke_url_var="SPOKE${i}_CONSOLE_URL"
    echo -e "    ${i}. ${!spoke_name_var:-spoke-$i}  →  ${!spoke_url_var:-<console url not set>}"
  done
fi

echo ""
echo -e "${GREEN}${BOLD}==> Deployment complete.${RESET}"
echo ""
