#!/bin/bash

set -e
set -o pipefail

d="$(cd "$(dirname "$0")" || exit 1; pwd)"
. "${d}/common.sh"

usage() {
  local -r name="${0##*/}"
  cat <<EOS >&2
${name} -- Helm & Helmfile utility CLI

Usage:
  ${name} COMMAND [args...]

Commands:
  compute-values, cv      Show final merged values
  dep-args, da            Construct dependency arguments
  fetch, f                Fetch or copy Helm chart
  helmfile-args, ha       Construct Helm arguments from helmfile.yaml
  helmfile-lint-helm, hl  Helm lint wrapper for helmfile
  lint, l                 Lint Helm chart with values.schema.json generation

Options:
  -h, --help              Show this help message
EOS
}

script=""
case "$1" in
  "compute-values" | "cv") script="compute-values.sh" ;;
  "dep-args" | "da") script="dep-args.sh" ;;
  "fetch" | "f") script="fetch.sh" ;;
  "helmfile-args" | "ha") script="helmfile-args.sh" ;;
  "helmfile-lint-helm" | "hl") script="helmfile-lint-helm.sh" ;;
  "lint" | "l") script="lint.sh" ;;
  "-h" | "--help")
    usage
    exit
    ;;
  *)
    usage
    exit 1
    ;;
esac

shift
"${d}/${script}" "$@"
