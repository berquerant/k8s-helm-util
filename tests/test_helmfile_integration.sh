#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)"
HELMFILE_ARGS_SCRIPT="${PROJECT_ROOT}/helmfile-args.sh"
HELMFILE_LINT_SCRIPT="${PROJECT_ROOT}/helmfile-lint-helm.sh"

# Temporary workspace for integration test
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

test_log "=== Running Helmfile Integration Tests (Real Binaries) ==="

# Test 1: Integration test for helmfile lint -b helmfile-lint-helm.sh
test_helmfile_lint_integration() {
  test_log "Test Suite: Real helmfile lint integration with helmfile-lint-helm.sh"

  local chart_dir="${TMP_DIR}/test-chart"
  mkdir -p "${chart_dir}/templates"

  cat <<EOF > "${chart_dir}/Chart.yaml"
apiVersion: v2
name: test-chart
version: 0.1.0
EOF

  cat <<EOF > "${chart_dir}/values.yaml"
replicaCount: 1
image:
  repository: nginx
  tag: latest
EOF

  cat <<EOF > "${chart_dir}/templates/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
        - name: nginx
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
EOF

  local helmfile_yaml="${TMP_DIR}/helmfile.yaml"
  cat <<EOF > "${helmfile_yaml}"
releases:
  - name: test-release
    chart: ${chart_dir}
EOF

  # Execute real helmfile lint using our wrapper script as the helm binary (-b)
  local output exit_code
  output=$(helmfile -f "${helmfile_yaml}" lint -b "${HELMFILE_LINT_SCRIPT}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile lint -b helmfile-lint-helm.sh succeeds with exit code 0"
  assert_equals "1" "$([[ -f "${chart_dir}/values.schema.json" ]] && echo 1 || echo 0)" "values.schema.json automatically generated during helmfile lint"
}

# Test 2: Integration test for helmfile-args.sh output used in real helm commands
test_helmfile_args_integration() {
  test_log "Test Suite: Real helmfile-args.sh output with real helm show"

  local helmfile_yaml="${TMP_DIR}/integration_helmfile.yaml"
  cat <<EOF > "${helmfile_yaml}"
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: oci-repo
    url: registry-1.docker.io/bitnamicharts
    oci: true

releases:
  - name: my-datadog
    chart: bitnami/redis
    version: 17.3.1
EOF

  local args output exit_code
  args=$("${HELMFILE_ARGS_SCRIPT}" "my-datadog" "${helmfile_yaml}")
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helmfile-args.sh executes with exit code 0"
  assert_equals "--repo https://charts.bitnami.com/bitnami redis --version 17.3.1" "${args}" "Constructs correct arguments string"

  # Execute real helm show chart using constructed arguments
  # shellcheck disable=SC2086
  output=$(helm show chart ${args} 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "helm show chart using constructed args succeeds with exit code 0"
  assert_contains "$output" "name: redis" "helm show chart returns valid chart info"
}

# Run integration test suites
test_helmfile_lint_integration
test_helmfile_args_integration

print_test_summary
