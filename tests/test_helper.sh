#!/bin/bash

# Script name prefix for logs
SCRIPT_NAME="${0##*/}"

# Test helper counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Terminal output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

test_log() {
  printf "%s: %b\n" "${SCRIPT_NAME}" "$*"
}

assert_equals() {
  local want="$1"
  local got="$2"
  local test_name="$3"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$want" == "$got" ]]; then
    test_log "  [${GREEN}PASS${RESET}] ${test_name}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    test_log "  [${RED}FAIL${RESET}] ${test_name}"
    test_log "    Want: '${want}'"
    test_log "    Got : '${got}'"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local test_name="$3"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if echo "$haystack" | grep -F -q -- "$needle"; then
    test_log "  [${GREEN}PASS${RESET}] ${test_name}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    test_log "  [${RED}FAIL${RESET}] ${test_name}"
    test_log "    Want output to contain: '${needle}'"
    test_log "    Got output:\n${haystack}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

assert_exit_code() {
  local want_code="$1"
  local got_code="$2"
  local test_name="$3"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$want_code" -eq "$got_code" ]]; then
    test_log "  [${GREEN}PASS${RESET}] ${test_name}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    test_log "  [${RED}FAIL${RESET}] ${test_name}"
    test_log "    Want exit code: ${want_code}"
    test_log "    Got exit code : ${got_code}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

print_test_summary() {
  test_log "=========================================="
  test_log "Summary: Total: ${TOTAL_TESTS} | ${GREEN}Passed: ${PASSED_TESTS}${RESET} | ${RED}Failed: ${FAILED_TESTS}${RESET}"

  if [[ "$FAILED_TESTS" -ne 0 ]]; then
    exit 1
  fi
}
