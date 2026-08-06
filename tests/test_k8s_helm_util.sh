#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

TARGET_SCRIPT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)/k8s-helm-util.sh"

test_log "=== Running k8s-helm-util.sh Unit Tests ==="

# Test 1: Help option (--help and -h)
test_help() {
  test_log "Test Suite: Help option"
  local output exit_code

  output=$("${TARGET_SCRIPT}" --help 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "k8s-helm-util.sh --help returns exit code 0"
  assert_contains "$output" "Helm & Helmfile utility CLI" "k8s-helm-util.sh --help output contains usage description"

  output=$("${TARGET_SCRIPT}" -h 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "k8s-helm-util.sh -h returns exit code 0"
  assert_contains "$output" "Helm & Helmfile utility CLI" "k8s-helm-util.sh -h output contains usage description"
}

# Test 2: Missing or invalid command validation
test_invalid_cmd() {
  test_log "Test Suite: Missing or invalid command validation"
  local output exit_code

  output=$("${TARGET_SCRIPT}" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "k8s-helm-util.sh with 0 args returns exit code 1"
  assert_contains "$output" "Usage:" "k8s-helm-util.sh with 0 args displays usage"

  output=$("${TARGET_SCRIPT}" invalid-command 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "k8s-helm-util.sh with invalid command returns exit code 1"
  assert_contains "$output" "Usage:" "k8s-helm-util.sh with invalid command displays usage"
}

# Run test suites
test_help
test_invalid_cmd

print_test_summary
