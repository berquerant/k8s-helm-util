#!/bin/bash

set -e
set -o pipefail

d="$(cd "$(dirname "$0")" || exit 1; pwd)"
. "${d}/common.sh"

usage() {
  local -r name="${0##*/}"
  cat <<EOS >&2
${name} -- show final values

Usage:
  ${name} CHART --version VERSION [helm template options...]
  ${name} r|raw values.yaml [values.yaml...]

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
  "r" | "raw")
    shift
    # shellcheck disable=SC2016
    yq eval-all '. as $item ireduce ({}; . * $item )' "$@"
    exit
    ;;
  "")
    usage
    exit 1
    ;;
esac

fetch() {
  "${d}/fetch.sh" "$@"
}

readonly chart="$1"
shift

chartd="$(tempdir)"
run_with_debug fetch "$chart" "$chartd" "$(find_version "$@")"

readonly templated="${chartd}/templates"
tmp_compute_yaml="$(mktemp -p "$templated")"
readonly compute_yaml="${tmp_compute_yaml}.yaml"
mv "$tmp_compute_yaml" "$compute_yaml"
echo '{{ toYaml .Values }}' > "$compute_yaml"
target="templates/$(basename "$compute_yaml")"
run_with_debug helm template release-name "$chartd" --show-only "$target" --dependency-update "$@"
