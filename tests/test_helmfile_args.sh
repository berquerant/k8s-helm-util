#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

TARGET_SCRIPT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)/helmfile-args.sh"

# Temporary workspace for tests
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

test_log "=== Running helmfile-args.sh Unit Tests ==="

# Test 1: Help option (--help and -h)
test_help() {
  test_log "Test Suite: Help option"
  local output exit_code

  output=$("${TARGET_SCRIPT}" --help 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "helmfile-args.sh --help returns exit code 0"
  assert_contains "$output" "construct helm arguments from helmfile" "helmfile-args.sh --help output contains usage description"

  output=$("${TARGET_SCRIPT}" -h 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "helmfile-args.sh -h returns exit code 0"
  assert_contains "$output" "construct helm arguments from helmfile" "helmfile-args.sh -h output contains usage description"
}

# Test 2: Missing arguments validation
test_missing_args() {
  test_log "Test Suite: Missing arguments validation"
  local output exit_code

  output=$("${TARGET_SCRIPT}" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "helmfile-args.sh with 0 args returns exit code 1"
  assert_contains "$output" "Usage:" "helmfile-args.sh with 0 args shows usage"
}

# Test 3: HTTP/HTTPS repository release resolution
test_http_repository() {
  test_log "Test Suite: HTTP/HTTPS repository release resolution"
  local helmfile_path="${TMP_DIR}/test_helmfile.yaml"

  cat <<EOF > "${helmfile_path}"
repositories:
  - name: datadog
    url: https://helm.datadoghq.com
  - name: bitnami
    url: registry-1.docker.io/bitnamicharts
    oci: true

releases:
  - name: datadog-agent
    chart: datadog/datadog
    version: 3.42.0
  - name: my-redis
    chart: bitnami/redis
    version: 17.3.1
EOF

  local output exit_code
  output=$("${TARGET_SCRIPT}" "datadog-agent" "${helmfile_path}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile-args.sh returns exit code 0 for HTTP repo release"
  assert_equals "--repo https://helm.datadoghq.com datadog --version 3.42.0" "$output" "Output formatted with --repo flag"
}

# Test 4: OCI registry repository release resolution
test_oci_repository() {
  test_log "Test Suite: OCI registry repository release resolution"
  local helmfile_path="${TMP_DIR}/test_helmfile.yaml"

  cat <<EOF > "${helmfile_path}"
repositories:
  - name: bitnami
    url: registry-1.docker.io/bitnamicharts
    oci: true

releases:
  - name: my-redis
    chart: bitnami/redis
    version: 17.3.1
EOF

  local output exit_code
  output=$("${TARGET_SCRIPT}" "my-redis" "${helmfile_path}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile-args.sh returns exit code 0 for OCI repo release"
  assert_equals "oci://registry-1.docker.io/bitnamicharts/redis --version 17.3.1" "$output" "Output formatted with oci:// URL prefix"
}

# Test 5: Default helmfile.yaml state file in working directory
test_default_state_file() {
  test_log "Test Suite: Default helmfile.yaml state file"

  # Create helmfile.yaml in temporary directory and cd into it
  local orig_pwd="$PWD"
  cd "${TMP_DIR}" || exit 1

  cat <<EOF > "helmfile.yaml"
repositories:
  - name: stable
    url: https://charts.helm.sh/stable

releases:
  - name: default-release
    chart: stable/nginx-ingress
    version: 1.41.3
EOF

  local output exit_code
  output=$("${TARGET_SCRIPT}" "default-release" 2>&1)
  exit_code=$?

  cd "${orig_pwd}" || exit 1

  assert_exit_code 0 "$exit_code" "helmfile-args.sh returns exit code 0 using default helmfile.yaml"
  assert_equals "--repo https://charts.helm.sh/stable nginx-ingress --version 1.41.3" "$output" "Output correctly constructed from default helmfile.yaml"
}

# Test 6: Non-existent release resolution
test_nonexistent_release() {
  test_log "Test Suite: Non-existent release resolution"
  local helmfile_path="${TMP_DIR}/test_helmfile.yaml"

  cat <<EOF > "${helmfile_path}"
repositories:
  - name: stable
    url: https://charts.helm.sh/stable

releases:
  - name: existing-release
    chart: stable/nginx-ingress
    version: 1.41.3
EOF

  local output exit_code
  output=$("${TARGET_SCRIPT}" "nonexistent-release" "${helmfile_path}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile-args.sh executes for nonexistent release"
  assert_contains "$output" "null" "Output contains null for unmatched release fields"
}

# Run test suites
test_help
test_missing_args
test_http_repository
test_oci_repository
test_default_state_file
test_nonexistent_release

print_test_summary
