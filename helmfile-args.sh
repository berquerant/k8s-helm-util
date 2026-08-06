#!/bin/bash

set -e
set -o pipefail

d="$(cd "$(dirname "$0")" || exit 1; pwd)"
. "${d}/common.sh"

usage() {
  local -r name="${0##*/}"
  cat <<EOS >&2
${name} -- construct helm arguments from helmfile

Usage:
  ${name} RELEASE_NAME [STATE]

Example:
  helm show values \$(${name} datadog)
  helm show chart \$(${name} sentry /path/to/helmfile.yaml)

Prerequisites:
  helmfile
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

readonly name="$1"
readonly state="${2:-helmfile.yaml}"
if [[ -z "$name" ]] ; then
  log "name(arg0) is required"
  exit 1
fi

select_release() {
  yq ".releases[] | select(.name == \"${name}\")" "$state"
}

chart="$(select_release | yq -r .chart)"
readonly chart
version="$(select_release | yq -r .version)"
readonly version

reponame="$(echo "$chart" | cut -d / -f 1)"
chartname="$(echo "$chart" | cut -d / -f 2)"

select_repository() {
  yq ".repositories[] | select(.name == \"${reponame}\")" "$state"
}

url="$(select_repository | yq -r .url)"
readonly url

# https://helmfile.readthedocs.io/en/latest/#oci-registries
if select_repository | yq -r .oci | grep -q "true" ; then
  echo "oci://${url}/${chartname} --version ${version}"
else
  echo "--repo ${url} ${chartname} --version ${version}"
fi
