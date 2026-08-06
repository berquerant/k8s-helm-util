#!/bin/bash

set -e
set -o pipefail

d="$(cd "$(dirname "$0")" || exit 1; pwd)"
. "${d}/common.sh"

usage() {
  local -r name="${0##*/}"
  cat <<EOS >&2
${name} -- fetch helm chart

Usage:
  ${name} CHART DEST_DIR [VERSION]

Example:
  ${name} sentry/sentry dest/sentry 28.0.3
  ${name} ./some_chart dest/chart

Prerequisites:
  helm
EOS
}

fetch() {
  local -r __src="$1"
  local -r __dest_dir="$2"
  local -r __version="$3"
  local __tmpd
  __tmpd="$(tempdir)"
  run_with_debug helm fetch "$__src" --version "$__version" --untar --untardir "$__tmpd"
  local __tempchartd
  __tmpchartd="${__tmpd}/$(ls -1 "$__tmpd")"
  mkdir -p "$__dest_dir"
  run_with_debug mv "${__tmpchartd}"/* "${__dest_dir}/"
}

copy() {
  local -r __src="$1"
  local -r __dest_dir="$2"
  run_with_debug cp -r "$__src/." "${__dest_dir}/"
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

readonly src="$1"
readonly dest_dir="$2"
readonly version="$3"

if [[ -z "$src" ]] ; then
  log "No src (arg0)!"
  exit 1
fi
if [[ -z "$dest_dir" ]] ; then
  log "No dest_dir (arg1)!"
  exit 1
fi

if echo "$src" | grep -qE "^\.?/" ; then
  copy "$src" "$dest_dir"
else
  if [[ -z "$version" ]] ; then
     log "No version (arg2)!"
     exit 1
  fi
  fetch "$src" "$dest_dir" "$version"
fi
