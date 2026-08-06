#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd)"
# shellcheck source=tests/test_helper.sh
. "${SCRIPT_DIR}/test_helper.sh"

test_log "=========================================="
test_log "   Running All Unit Test Suites"
test_log "=========================================="

FAILED_SUITES=0
TOTAL_SUITES=0

for test_script in "${SCRIPT_DIR}"/test_*.sh; do
  if [[ -f "${test_script}" ]]; then
    if [[ "${test_script##*/}" == "test_helper.sh" ]]; then
      continue
    fi
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    test_log "Running test suite: ${test_script##*/}"
    if bash "${test_script}"; then
      test_log "Suite ${test_script##*/} PASSED\n"
    else
      test_log "Suite ${test_script##*/} FAILED\n"
      FAILED_SUITES=$((FAILED_SUITES + 1))
    fi
  fi
done

test_log "=========================================="
if [[ "$FAILED_SUITES" -eq 0 ]]; then
  test_log "  ALL TEST SUITES PASSED (${TOTAL_SUITES}/${TOTAL_SUITES})"
  test_log "=========================================="
  exit 0
else
  test_log "  SOME TEST SUITES FAILED (${FAILED_SUITES}/${TOTAL_SUITES} failed)"
  test_log "=========================================="
  exit 1
fi
