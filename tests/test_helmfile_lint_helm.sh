#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

TARGET_SCRIPT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)/helmfile-lint-helm.sh"

# Temporary workspace for tests
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Setup mock binaries
MOCK_BIN_DIR="${TMP_DIR}/bin"
mkdir -p "${MOCK_BIN_DIR}"
MOCK_HELM="${MOCK_BIN_DIR}/helm"
MOCK_HELM_SCHEMA="${MOCK_BIN_DIR}/helm-schema"
MOCK_LOG="${TMP_DIR}/mock_calls.log"

# Mock helm binary
cat <<EOF > "${MOCK_HELM}"
#!/bin/bash
echo "helm \$*" >> "${MOCK_LOG}"
exit 0
EOF

# Mock helm-schema binary
cat <<EOF > "${MOCK_HELM_SCHEMA}"
#!/bin/bash
echo "helm-schema \$*" >> "${MOCK_LOG}"
touch values.schema.json
exit 0
EOF

chmod +x "${MOCK_HELM}" "${MOCK_HELM_SCHEMA}"

test_log "=== Running helmfile-lint-helm.sh Unit Tests ==="

# Test 1: Help option (--help and -h)
test_help() {
  test_log "Test Suite: Help option"
  local output exit_code

  output=$("${TARGET_SCRIPT}" --help 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "helmfile-lint-helm.sh --help returns exit code 0"
  assert_contains "$output" "helm lint wrapper for helmfile" "helmfile-lint-helm.sh --help output contains usage description"

  output=$("${TARGET_SCRIPT}" -h 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "helmfile-lint-helm.sh -h returns exit code 0"
  assert_contains "$output" "helm lint wrapper for helmfile" "helmfile-lint-helm.sh -h output contains usage description"
}

# Test 2: 'lint' subcommand triggers build_schema and calls helm
test_lint_subcommand() {
  test_log "Test Suite: lint subcommand schema building and helm invocation"
  local dummy_chart="${TMP_DIR}/dummy-chart"
  mkdir -p "${dummy_chart}"
  cat <<EOF > "${dummy_chart}/values.yaml"
foo: bar
EOF

  rm -f "${MOCK_LOG}"

  local output exit_code
  output=$(PATH="${MOCK_BIN_DIR}:${PATH}" "${TARGET_SCRIPT}" lint "${dummy_chart}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile-lint-helm.sh lint returns exit code 0"
  assert_equals "1" "$([[ -f "${dummy_chart}/values.schema.json" ]] && echo 1 || echo 0)" "build_schema created values.schema.json in chart directory"
  assert_contains "$(cat "${MOCK_LOG}")" "helm lint ${dummy_chart}" "Passes lint command and arguments to helm binary"
}

# Test 3: Pass-through for non-lint commands
test_passthrough_command() {
  test_log "Test Suite: Pass-through non-lint commands to helm"
  rm -f "${MOCK_LOG}"

  local output exit_code
  output=$(PATH="${MOCK_BIN_DIR}:${PATH}" "${TARGET_SCRIPT}" version 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile-lint-helm.sh version returns exit code 0"
  assert_contains "$(cat "${MOCK_LOG}")" "helm version" "Passes non-lint subcommand directly to helm"
}

# Test 4: Skip helm-schema execution if values.schema.json already exists
test_existing_schema_skip() {
  test_log "Test Suite: Skip helm-schema execution when schema exists"
  local dummy_chart="${TMP_DIR}/dummy-chart-with-schema"
  mkdir -p "${dummy_chart}"
  echo '{"existing": true}' > "${dummy_chart}/values.schema.json"

  rm -f "${MOCK_LOG}"

  local output exit_code
  output=$(PATH="${MOCK_BIN_DIR}:${PATH}" "${TARGET_SCRIPT}" lint "${dummy_chart}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile-lint-helm.sh lint returns exit code 0 when schema exists"
  assert_contains "$(cat "${MOCK_LOG}")" "helm lint ${dummy_chart}" "helm lint executed"

  # Verify helm-schema was NOT invoked
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if grep -q "helm-schema" "${MOCK_LOG}"; then
    test_log "  [${RED}FAIL${RESET}] helm-schema should not be invoked if values.schema.json exists"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  else
    test_log "  [${GREEN}PASS${RESET}] helm-schema execution was correctly skipped"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  fi
}

# Run test suites
test_help
test_lint_subcommand
test_passthrough_command
test_existing_schema_skip

print_test_summary
