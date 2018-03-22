#!/usr/bin/env bash

# Map aggregated data to PIs
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

OS="$(uname -s)"
if [[ "${OS}" == "Darwin" ]]; then
  # Use GNU coreutils on macOS (for development/debugging)
  shopt -s expand_aliases
  alias readlink="greadlink"
  alias sed="gsed"
  alias sort="gsort"
  alias join="gjoin"
fi

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"
MAPPING="${WORK_DIR}/group-pi.map"

TAB="	"

get_mapping() {
  # Return sorted mapping with comments and blanks stripped out
  sed '/^\s*#/d;/^\s*$/d;s/\s*#.*//' "${MAPPING}" | sort -t"${TAB}" -k1n,1
}

main() {
  awk -F"${TAB}" '$2 == "group" { print }' \
  | sort -t"${TAB}" -k3n,3 \
  | join -t"${TAB}" -1 3 -2 1  - <(get_mapping) \
  | awk 'BEGIN { FS = OFS = "\t" } { print $2, "pi", $8, $4, $5, $6, $7 }'
}

main
