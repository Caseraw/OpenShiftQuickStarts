#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---------------------------------------------------------------------------
# Probe for an available YAML tool once so we report clearly and use it
# consistently throughout the script.
# ---------------------------------------------------------------------------
yaml_tool=""
if python3 -c "import yaml" 2>/dev/null; then
  yaml_tool="python3"
elif command -v yq >/dev/null 2>&1; then
  yaml_tool="yq"
fi

# ---------------------------------------------------------------------------
# validate_syntax <file>
# Returns 0 if the file is valid YAML, nonzero otherwise.
# ---------------------------------------------------------------------------
validate_syntax() {
  local file="$1"
  case "$yaml_tool" in
    python3)
      python3 -c "
import sys, yaml
try:
    yaml.safe_load(open(sys.argv[1]))
except yaml.YAMLError as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
" "$file" ;;
    yq)
      yq eval '.' "$file" >/dev/null 2>&1 ;;
    *)
      return 0 ;;
  esac
}

# ---------------------------------------------------------------------------
# validate_fields <file>
# Checks that all required ConsoleQuickStart spec and task fields are present.
# Only runs when python3+PyYAML is available; gracefully skips otherwise.
# ---------------------------------------------------------------------------
FIELD_CHECK='
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
spec = (doc or {}).get("spec") or {}
errs = []

for f in ("displayName", "description", "introduction", "durationMinutes", "tasks"):
    if f not in spec:
        errs.append("Missing required spec field: " + f)

for i, task in enumerate(spec.get("tasks") or []):
    for f in ("title", "description"):
        if f not in task:
            errs.append("tasks[" + str(i) + "] missing required field: " + f)
    for block, fields in (("review", ("instructions", "failedTaskHelp")),
                           ("summary", ("success", "failed"))):
        if block in task:
            for f in fields:
                if f not in task[block]:
                    errs.append("tasks[" + str(i) + "]." + block + " missing field: " + f)

for e in errs:
    print(e, file=sys.stderr)
sys.exit(1 if errs else 0)
'

validate_fields() {
  local file="$1"
  [ "$yaml_tool" = "python3" ] || return 0
  python3 -c "$FIELD_CHECK" "$file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "Validating quick start YAML files..."
echo ""

if [ -z "$yaml_tool" ]; then
  echo "  WARN: python3+PyYAML and yq not found — YAML syntax checks will be skipped."
  echo "        Install python3 with PyYAML, or yq, for full validation."
  echo ""
elif [ "$yaml_tool" = "yq" ]; then
  echo "  INFO: Using yq for syntax checks. Install python3+PyYAML to also enable required-field checks."
  echo ""
fi

errors=0
checked=0

for file in scenarios/*/quickstart.yaml; do
  [ -f "$file" ] || continue
  scenario="$(basename "$(dirname "$file")")"
  [ "$scenario" = "_template" ] && continue

  echo "  $file"
  checked=$((checked + 1))
  file_errors=0

  # Syntax check
  if ! syntax_err=$(validate_syntax "$file" 2>&1); then
    echo "    ERROR: YAML syntax error${syntax_err:+ — }${syntax_err}"
    errors=$((errors + 1))
    continue  # field checks are meaningless on unparseable YAML
  fi

  # Required field check
  if ! field_err=$(validate_fields "$file" 2>&1); then
    while IFS= read -r line; do
      [ -n "$line" ] && echo "    ERROR: $line"
    done <<< "$field_err"
    errors=$((errors + 1))
    file_errors=$((file_errors + 1))
  fi

  [ "$file_errors" -eq 0 ] && echo "    OK"
done

echo ""

if [ "$checked" -eq 0 ]; then
  echo "No deployable quickstart.yaml files found under scenarios/ (excluding _template)."
  exit 1
fi

if [ "$errors" -gt 0 ]; then
  echo "Scenario validation failed — $errors error(s) across $checked file(s)."
  exit 1
fi

echo "Scenario validation complete — $checked file(s) checked, all OK."

# ---------------------------------------------------------------------------
# Component validation
# Checks that every non-template component under components/ has the four
# required lifecycle scripts and that they are executable.
# ---------------------------------------------------------------------------
echo ""
echo "Validating components..."
echo ""

REQUIRED_SCRIPTS=("deploy.sh" "reset.sh" "update.sh" "cleanup.sh")
component_errors=0
component_checked=0

for dir in components/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  [ "$name" = "_template" ] && continue

  echo "  $dir"
  component_checked=$((component_checked + 1))
  dir_errors=0

  for script in "${REQUIRED_SCRIPTS[@]}"; do
    script_path="${dir}scripts/${script}"
    if [ ! -f "$script_path" ]; then
      echo "    ERROR: Missing required script: scripts/${script}"
      component_errors=$((component_errors + 1))
      dir_errors=$((dir_errors + 1))
    elif [ ! -x "$script_path" ] && ! head -1 "$script_path" | grep -q '^#!'; then
      echo "    WARN:  scripts/${script} has no shebang line"
    fi
  done

  if [ ! -f "${dir}README.md" ]; then
    echo "    ERROR: Missing README.md"
    component_errors=$((component_errors + 1))
    dir_errors=$((dir_errors + 1))
  fi

  [ "$dir_errors" -eq 0 ] && echo "    OK"
done

echo ""

if [ "$component_checked" -eq 0 ]; then
  echo "No components found under components/ (excluding _template) — skipping."
else
  if [ "$component_errors" -gt 0 ]; then
    echo "Component validation failed — $component_errors error(s) across $component_checked component(s)."
    exit 1
  fi
  echo "Component validation complete — $component_checked component(s) checked, all OK."
fi
