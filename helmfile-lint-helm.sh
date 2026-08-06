#!/bin/bash

set -e
set -o pipefail

d="$(cd "$(dirname "$0")" || exit 1; pwd)"
. "${d}/common.sh"

usage() {
  local -r name="${0##*/}"
  cat <<EOS >&2
${name} -- helm lint wrapper for helmfile

Usage:
  helmfile lint -b ${name} ...

Prerequisites:
  helm
  helm-schema
EOS
}


case "$1" in
  "-h" | "--help")
    usage
    ;;
  "lint")
    readonly chartd="$2"
    build_schema "$chartd"
    helm "$@"
    ;;
  *) helm "$@" ;;
esac
