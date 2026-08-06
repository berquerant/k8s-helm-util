#!/bin/bash

set -e
set -o pipefail

d="$(cd "$(dirname "$0")" || exit 1; pwd)"
. "${d}/common.sh"

usage() {
  local -r name="${0##*/}"
  cat <<EOS >&2
${name} -- lint helm chart

Usage:
  ${name} CHART [helm lint options...]

Example:
  ${name} sentry/sentry --version 28.0.3 -f values.yaml

Prerequisites:
  helm
  helm-schema
EOS
}

fetch() {
  "${d}/fetch.sh" "$@"
}


case "$1" in
  "-h" | "--help")
    usage
    exit
    ;;
  "")
    usage
    exit 1
    ;;
esac

readonly chart="$1"
shift

chartd="$(tempdir)"
run_with_debug fetch "$chart" "$chartd" "$(find_version "$@")"
build_schema "$chartd"

new_args=("$chartd")
skip=0
for arg in "$@" ; do
  if [[ "$skip" = 1 ]] ; then
    skip=0
    continue
  fi
  case "$arg" in
    "--version")
      skip=1
      ;;
    *)
      new_args+=("$arg")
      ;;
  esac
done
run_with_debug helm lint "${new_args[@]}"
