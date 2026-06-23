#!/usr/bin/env bash
# applications/todo-app/scripts/reset.sh
#
# Resets the todo-app to its seed state by deleting all rows from the todos
# table and re-running the seed SQL. The application stays running.
#
# Usage:
#   bash applications/todo-app/scripts/reset.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

PG_NAMESPACE="todo-postgresql"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${BOLD}==> Resetting application: todo-app${NC}"
echo ""

ENV_FILE="${REPO_ROOT}/environment/env.sh"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

if [[ -n "${SPOKE1_API_URL:-}" && -n "${SPOKE1_USERNAME:-}" && -n "${SPOKE1_PASSWORD:-}" ]]; then
  oc login "${SPOKE1_API_URL}" \
    -u "${SPOKE1_USERNAME}" \
    -p "${SPOKE1_PASSWORD}" \
    --insecure-skip-tls-verify &>/dev/null
fi

PG_POD=$(oc get pod -n "${PG_NAMESPACE}" \
  -l "app.kubernetes.io/name=todo-postgresql" \
  --no-headers 2>/dev/null | awk '$3=="Running"{print $1}' | head -1)

if [[ -z "${PG_POD}" ]]; then
  error "No running todo-postgresql pod found in namespace ${PG_NAMESPACE}."
  exit 1
fi
info "Using pod: ${PG_POD}"

info "Truncating todos table and re-seeding..."
oc exec -n "${PG_NAMESPACE}" "${PG_POD}" -- \
  psql -U todo -d todos -c "TRUNCATE TABLE todos RESTART IDENTITY;" &>/dev/null

oc exec -n "${PG_NAMESPACE}" "${PG_POD}" -- \
  psql -U todo -d todos -c \
  "INSERT INTO todos (title, done) VALUES
    ('Buy groceries for the week', FALSE),
    ('Take out the recycling', FALSE),
    ('Water the indoor plants', TRUE),
    ('Schedule HVAC filter replacement', FALSE),
    ('Organize the kitchen pantry', TRUE);" &>/dev/null

success "todos table reset to seed state."
echo ""
echo -e "${BOLD}==> Reset complete.${NC}"
echo ""
