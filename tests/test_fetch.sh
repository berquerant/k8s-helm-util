#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

TARGET_SCRIPT="$(cd "${SCRIPT_DIR}/.." || exit 1; pwd)/fetch.sh"

# Temporary workspace for tests
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Setup mock helm command for remote fetch testing
MOCK_BIN_DIR="${TMP_DIR}/bin"
mkdir -p "${MOCK_BIN_DIR}"
MOCK_HELM="${MOCK_BIN_DIR}/helm"

cat <<'EOF' > "${MOCK_HELM}"
#!/bin/bash
if [[ "$1" == "fetch" ]]; then
  # Parse --untardir
  untardir=""
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--untardir" ]]; then
      untardir="$2"
      shift 2
    else
      shift
    fi
  done

  if [[ -n "$untardir" ]]; then
    chart_dir="${untardir}/mock-fetched-chart"
    mkdir -p "${chart_dir}"
    echo "apiVersion: v2" > "${chart_dir}/Chart.yaml"
    echo "name: mock-fetched-chart" >> "${chart_dir}/Chart.yaml"
    echo "fetched: true" > "${chart_dir}/values.yaml"
    exit 0
  fi
fi

echo "Unknown mock helm command: $*" >&2
exit 1
EOF

chmod +x "${MOCK_HELM}"

test_log "=== Running fetch.sh Unit Tests ==="

# Test 1: Help option (--help and -h)
test_help() {
  test_log "Test Suite: Help option"
  local output exit_code

  output=$("${TARGET_SCRIPT}" --help 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "fetch.sh --help returns exit code 0"
  assert_contains "$output" "fetch helm chart" "fetch.sh --help output contains usage description"

  output=$("${TARGET_SCRIPT}" -h 2>&1)
  exit_code=$?
  assert_exit_code 0 "$exit_code" "fetch.sh -h returns exit code 0"
  assert_contains "$output" "fetch helm chart" "fetch.sh -h output contains usage description"
}

# Test 2: Missing arguments validation
test_missing_args() {
  test_log "Test Suite: Missing arguments validation"
  local output exit_code

  output=$("${TARGET_SCRIPT}" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "fetch.sh with 0 args returns exit code 1"
  assert_contains "$output" "Usage:" "fetch.sh with 0 args shows usage"

  output=$("${TARGET_SCRIPT}" "sentry/sentry" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "fetch.sh with 1 arg returns exit code 1"
  assert_contains "$output" "No dest_dir" "fetch.sh complains about missing dest_dir"

  output=$("${TARGET_SCRIPT}" "sentry/sentry" "${TMP_DIR}/dest" 2>&1)
  exit_code=$?
  assert_exit_code 1 "$exit_code" "fetch.sh remote with no version returns exit code 1"
  assert_contains "$output" "No version" "fetch.sh complains about missing version for remote chart"
}

# Test 3: Local directory copy
test_local_copy() {
  test_log "Test Suite: Local directory chart copy"
  local local_chart="${TMP_DIR}/local-chart"
  local dest_dir="${TMP_DIR}/dest-local"
  mkdir -p "${local_chart}/templates"

  cat <<EOF > "${local_chart}/Chart.yaml"
apiVersion: v2
name: local-chart
version: 1.0.0
EOF

  cat <<EOF > "${local_chart}/values.yaml"
replicaCount: 2
EOF

  cat <<EOF > "${local_chart}/templates/deployment.yaml"
# deployment template
EOF

  local output exit_code
  output=$("${TARGET_SCRIPT}" "${local_chart}" "${dest_dir}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "fetch.sh on local chart returns exit code 0"
  assert_equals "1" "$([[ -f "${dest_dir}/Chart.yaml" ]] && echo 1 || echo 0)" "Chart.yaml copied to dest_dir"
  assert_equals "1" "$([[ -f "${dest_dir}/values.yaml" ]] && echo 1 || echo 0)" "values.yaml copied to dest_dir"
  assert_equals "1" "$([[ -f "${dest_dir}/templates/deployment.yaml" ]] && echo 1 || echo 0)" "templates/deployment.yaml copied to dest_dir"
}

# Test 4: Remote chart fetch (using mock helm)
test_remote_fetch() {
  test_log "Test Suite: Remote chart fetch"
  local dest_dir="${TMP_DIR}/dest-remote"

  # Execute with PATH including mock helm
  local output exit_code
  output=$(PATH="${MOCK_BIN_DIR}:${PATH}" "${TARGET_SCRIPT}" "bitnami/redis" "${dest_dir}" "17.3.1" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "fetch.sh remote fetch returns exit code 0"
  assert_equals "1" "$([[ -f "${dest_dir}/Chart.yaml" ]] && echo 1 || echo 0)" "Remote Chart.yaml fetched and extracted to dest_dir"
  assert_equals "1" "$([[ -f "${dest_dir}/values.yaml" ]] && echo 1 || echo 0)" "Remote values.yaml fetched and extracted to dest_dir"
}

# Test 5: Local directory copy using absolute path
test_local_copy_absolute_path() {
  test_log "Test Suite: Local directory chart copy using absolute path"
  local abs_chart="${TMP_DIR}/abs-chart"
  local dest_dir="${TMP_DIR}/dest-abs"
  mkdir -p "${abs_chart}"

  echo "apiVersion: v2" > "${abs_chart}/Chart.yaml"

  local output exit_code
  output=$("${TARGET_SCRIPT}" "${abs_chart}" "${dest_dir}" 2>&1)
  exit_code=$?

  assert_exit_code 0 "$exit_code" "fetch.sh on absolute path chart returns exit code 0"
  assert_equals "1" "$([[ -f "${dest_dir}/Chart.yaml" ]] && echo 1 || echo 0)" "Chart.yaml copied using absolute path"
}

# Run test suites
test_help
test_missing_args
test_local_copy
test_remote_fetch
test_local_copy_absolute_path

print_test_summary
