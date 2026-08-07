#!/bin/bash

log() {
  echo >&2 "${0##*/}: $*"
}

debug() {
  if [[ -n "$DEBUG" ]] ; then
    log "$@"
  fi
}

tempdir() {
  local __tmpd
  __tmpd="$(mktemp -d)"
  debug "tempdir: ${__tmpd}"
  if [[ -n "$DEBUG" ]] ; then
    # shellcheck disable=SC2064
    trap "rm -rf ${__tmpd}" EXIT
  fi
  echo "$__tmpd"
}

run_with_debug() {
  debug "$@"
  "$@"
}

find_version() {
  local __found=0
  for arg in "$@"; do
    if [[ "$__found" = "1" ]] ; then
      debug "--version is ${arg}"
      echo "$arg"
      return
    fi
    if [[ "$arg" = "--version" ]] ; then
      __found=1
    fi
  done
  debug "--version not found"
}

build_schema() {
  pushd "$1" > /dev/null || return 1
  if [[ -f "values.yaml" && ! -f "values.schema.json" ]] ; then
    log "build values.schema.json by helm-schema"
    helm-schema --skip-auto-generation required,additionalProperties --skip-dependencies-schema-validation
  fi
  popd > /dev/null || return 1
}
