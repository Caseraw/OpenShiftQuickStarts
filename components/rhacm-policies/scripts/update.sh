#!/usr/bin/env bash
# components/rhacm-policies/scripts/update.sh
# Idempotently re-applies all policy files. Safe to run after adding or editing
# policy YAML files without tearing down existing resources first.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC}  $*"; }

info "Running incremental update — re-applying all policy files..."
"${SCRIPT_DIR}/deploy.sh"
