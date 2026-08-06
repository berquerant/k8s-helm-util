#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

TARGET_SCRIPT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)/lint.sh"

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

test_log "=== Running lint.sh Unit Tests ==="

# Test 1: Help option (--help and -h)
test_help() {
  test_log "Test Suite: Help option"
  local output exit_code

  output=$("${TARGET_SCRIPT}" --help 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "lint.sh --help returns exit code 0"
  assert_contains "$output" "lint helm chart" "lint.sh --help output contains usage description"

  output=$("${TARGET_SCRIPT}" -h 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "lint.sh -h returns exit code 0"
  assert_contains "$output" "lint helm chart" "lint.sh -h output contains usage description"
}

# Test 2: Missing arguments validation
test_missing_args() {
  test_log "Test Suite: Missing arguments validation"
  local output exit_code

  output=$("${TARGET_SCRIPT}" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "lint.sh with 0 args returns exit code 1"
  assert_contains "$output" "Usage:" "lint.sh with 0 args displays usage"
}

# Test 3: Local chart linting & build_schema execution
test_local_chart_lint() {
  test_log "Test Suite: Local chart linting and schema building"
  local dummy_chart="${TMP_DIR}/dummy-chart"
  mkdir -p "${dummy_chart}"
  cat <<EOF > "${dummy_chart}/Chart.yaml"
apiVersion: v2
name: dummy-chart
version: 0.1.0
EOF
  cat <<EOF > "${dummy_chart}/values.yaml"
service:
  type: ClusterIP
EOF

  rm -f "${MOCK_LOG}"

  local output exit_code
  output=$(PATH="${MOCK_BIN_DIR}:${PATH}" "${TARGET_SCRIPT}" "${dummy_chart}" --strict 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "lint.sh on local chart returns exit code 0"
  assert_contains "$(cat "${MOCK_LOG}")" "helm lint" "helm lint command invoked"
  assert_contains "$(cat "${MOCK_LOG}")" "--strict" "Option --strict passed to helm lint"
}

# Test 4: Filtering out --version argument before passing to helm lint
test_filter_version_arg() {
  test_log "Test Suite: Filter --version argument for helm lint"
  local dummy_chart="${TMP_DIR}/dummy-chart"
  rm -f "${MOCK_LOG}"

  local output exit_code
  output=$(PATH="${MOCK_BIN_DIR}:${PATH}" "${TARGET_SCRIPT}" "${dummy_chart}" --version 1.2.3 -f custom.yaml 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "lint.sh returns exit code 0"
  local call_log
  call_log="$(cat "${MOCK_LOG}")"
  assert_contains "${call_log}" "-f custom.yaml" "-f option preserved in helm lint call"

  # Verify --version 1.2.3 was stripped from helm lint arguments
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if echo "${call_log}" | grep -q "\--version"; then
    test_log "  [${RED}FAIL${RESET}] --version argument should be stripped from helm lint command"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  else
    test_log "  [${GREEN}PASS${RESET}] --version argument was correctly stripped from helm lint command"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  fi
}

# Run test suites
test_help
test_missing_args
test_local_chart_lint
test_filter_version_arg

print_test_summary
