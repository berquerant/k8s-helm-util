#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

TARGET_SCRIPT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)/dep-args.sh"

# Temporary workspace for tests
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Setup mock helm command
MOCK_BIN_DIR="${TMP_DIR}/bin"
mkdir -p "${MOCK_BIN_DIR}"
MOCK_HELM="${MOCK_BIN_DIR}/helm"

cat <<'EOF' > "${MOCK_HELM}"
#!/bin/bash
if [[ "$1" == "show" && "$2" == "chart" ]]; then
  cat <<YAML
name: test-parent-chart
version: 1.0.0
dependencies:
  - name: redis
    version: 17.3.1
    repository: https://charts.bitnami.com/bitnami
  - name: kafka
    version: 26.1.0
    repository: oci://registry-1.docker.io/bitnamicharts
YAML
  exit 0
fi

echo "Unknown mock helm command: $*" >&2
exit 1
EOF

chmod +x "${MOCK_HELM}"

# Override PATH to use mock helm
export PATH="${MOCK_BIN_DIR}:${PATH}"

test_log "=== Running dep-args.sh Unit Tests ==="

# Test 1: Help option (--help and -h)
test_help() {
  test_log "Test Suite: Help option"
  local output exit_code

  output=$("${TARGET_SCRIPT}" --help 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "dep-args.sh --help returns exit code 0"
  assert_contains "$output" "construct dependency arguments" "dep-args.sh --help contains description"

  output=$("${TARGET_SCRIPT}" -h 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "dep-args.sh -h returns exit code 0"
  assert_contains "$output" "construct dependency arguments" "dep-args.sh -h contains description"
}

# Test 2: Missing arguments
test_missing_args() {
  test_log "Test Suite: Missing arguments validation"
  local output exit_code

  output=$("${TARGET_SCRIPT}" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "dep-args.sh with 0 args returns exit code 1"
  assert_contains "$output" "Usage:" "dep-args.sh with 0 args shows usage"

  output=$("${TARGET_SCRIPT}" "my-chart" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "dep-args.sh with 1 arg returns exit code 1"
  assert_contains "$output" "version(arg1) is required" "dep-args.sh complains about missing version"

  output=$("${TARGET_SCRIPT}" "my-chart" "1.0.0" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "dep-args.sh with 2 args returns exit code 1"
  assert_contains "$output" "name(arg2) is required" "dep-args.sh complains about missing dependency name"
}

# Test 3: Standard HTTP/HTTPS dependency resolution
test_http_dependency() {
  test_log "Test Suite: Standard HTTP/HTTPS dependency resolution"
  local output exit_code

  output=$("${TARGET_SCRIPT}" "my-chart" "1.0.0" "redis" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "dep-args.sh returns exit code 0 for redis"
  assert_equals "--repo https://charts.bitnami.com/bitnami redis --version 17.3.1" "$output" "Output formatted with --repo flag"
}

# Test 4: OCI registry dependency resolution
test_oci_dependency() {
  test_log "Test Suite: OCI registry dependency resolution"
  local output exit_code

  output=$("${TARGET_SCRIPT}" "my-chart" "1.0.0" "kafka" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "dep-args.sh returns exit code 0 for kafka"
  assert_equals "oci://registry-1.docker.io/bitnamicharts/kafka --version 26.1.0" "$output" "Output formatted with oci:// URL prefix"
}

# Test 5: Non-existent dependency resolution
test_nonexistent_dependency() {
  test_log "Test Suite: Non-existent dependency resolution"
  local output exit_code

  output=$("${TARGET_SCRIPT}" "my-chart" "1.0.0" "nonexistent-dep" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "dep-args.sh executes for nonexistent dependency"
  assert_contains "$output" "null" "Output contains null for unmatched dependency fields"
}

# Run test suites
test_help
test_missing_args
test_http_dependency
test_oci_dependency
test_nonexistent_dependency

print_test_summary
