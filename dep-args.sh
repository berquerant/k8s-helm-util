#!/bin/bash

set -e
set -o pipefail

d="$(cd "$(dirname "$0")" || exit 1; pwd)"
. "${d}/common.sh"

usage() {
  local -r name="${0##*/}"
  cat <<EOS >&2
${name} -- construct dependency arguments

Usage:
  ${name} CHART VERSION DEPNAME

Example:
  helm show values \$(${name} sentry/sentry 28.0.3 kafka)

Prerequisites:
  helm
  yq

EOS
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
readonly version="$2"
readonly name="$3"
if [[ -z "$chart" ]] ; then
  log "chart(arg0) is required"
  exit 1
fi
if [[ -z "$version" ]] ; then
  log "version(arg1) is required"
  exit 1
fi
if [[ -z "$name" ]] ; then
  log "name(arg2) is required"
  exit 1
fi

select_dep() {
  helm show chart "$chart" --version "$version" |\
    yq ".dependencies[] | select(.name == \"${name}\")"
}

depchart="$(select_dep | yq -r .name)"
deprepo="$(select_dep | yq -r .repository)"
depversion="$(select_dep | yq -r .version)"

if echo "$deprepo" | grep -q -E "^oci://" ; then
  echo "${deprepo}/${depchart} --version ${depversion}"
else
  echo "--repo ${deprepo} ${depchart} --version ${depversion}"
fi
