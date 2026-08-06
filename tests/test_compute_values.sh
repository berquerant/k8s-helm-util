#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

TARGET_SCRIPT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)/compute-values.sh"

# Temporary workspace for tests
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

test_log "=== Running compute-values.sh Unit Tests ==="

# Test 1: Help flags (--help and -h)
test_help() {
  test_log "Test Suite: Help option"
  local output exit_code

  output=$("${TARGET_SCRIPT}" --help 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "compute-values.sh --help returns exit code 0"
  assert_contains "$output" "show final values" "compute-values.sh --help output contains usage description"

  output=$("${TARGET_SCRIPT}" -h 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "compute-values.sh -h returns exit code 0"
  assert_contains "$output" "show final values" "compute-values.sh -h output contains usage description"
}

# Test 2: No arguments provided
test_no_args() {
  test_log "Test Suite: No arguments"
  local output exit_code

  output=$("${TARGET_SCRIPT}" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "compute-values.sh with no args returns exit code 1"
  assert_contains "$output" "Usage:" "compute-values.sh with no args displays Usage"
}

# Test 3: raw / r mode for YAML deep merging
test_raw_merge() {
  test_log "Test Suite: Raw mode (YAML merging)"
  local f1="${TMP_DIR}/val1.yaml"
  local f2="${TMP_DIR}/val2.yaml"

  cat <<EOF > "$f1"
app:
  name: my-app
  replicas: 1
env: dev
EOF

  cat <<EOF > "$f2"
app:
  replicas: 3
  port: 8080
env: prod
EOF

  local output exit_code
  output=$("${TARGET_SCRIPT}" raw "$f1" "$f2" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "raw command returns exit code 0"
  assert_contains "$output" "name: my-app" "Merged YAML preserves un-overridden key (name)"
  assert_contains "$output" "replicas: 3" "Merged YAML updates overridden key (replicas)"
  assert_contains "$output" "port: 8080" "Merged YAML includes new key (port)"
  assert_contains "$output" "env: prod" "Merged YAML updates top-level key (env)"

  # Also test shortcut 'r'
  output=$("${TARGET_SCRIPT}" r "$f1" "$f2" 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "r command shortcut returns exit code 0"
  assert_contains "$output" "replicas: 3" "r command merges correctly"
}

# Test 4: Helm chart values calculation
test_chart_compute_values() {
  test_log "Test Suite: Helm chart template compute values"
  local dummy_chart="${TMP_DIR}/test-chart"
  mkdir -p "${dummy_chart}/templates"

  cat <<EOF > "${dummy_chart}/Chart.yaml"
apiVersion: v2
name: test-chart
version: 0.1.0
EOF

  cat <<EOF > "${dummy_chart}/values.yaml"
global:
  environment: staging
service:
  type: ClusterIP
  port: 80
tags:
  - web
  - api
EOF

  local output exit_code
  output=$("${TARGET_SCRIPT}" "$dummy_chart" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "compute-values.sh on local chart returns exit code 0"
  assert_contains "$output" "environment: staging" "Evaluates global.environment correctly"
  assert_contains "$output" "type: ClusterIP" "Evaluates service.type correctly"
  assert_contains "$output" "port: 80" "Evaluates service.port correctly"

  # Test with helm template override flags (--set)
  output=$("${TARGET_SCRIPT}" "$dummy_chart" --set service.port=8080 --set global.environment=production 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "compute-values.sh with --set flags returns exit code 0"
  assert_contains "$output" "environment: production" "--set flag overrides global.environment"
  assert_contains "$output" "port: 8080" "--set flag overrides service.port"

  # Test with extra values file (-f / -values)
  local custom_val="${TMP_DIR}/custom-values.yaml"
  cat <<EOF > "$custom_val"
service:
  type: NodePort
EOF
  output=$("${TARGET_SCRIPT}" "$dummy_chart" -f "$custom_val" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "compute-values.sh with -f custom values file returns exit code 0"
  assert_contains "$output" "type: NodePort" "-f flag overrides service.type"
}

# Run test suites
test_help
test_no_args
test_raw_merge
test_chart_compute_values

print_test_summary
