#!/usr/bin/env bash

# Map aggregated data to PIs
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(greadlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

source "${WORK_DIR}/get-mapping.sh"
MAPPING="${WORK_DIR}/group-pi.map"

TAB="	"

main() {
  awk -F"${TAB}" '$2 == "group" { print }' \
  | sort -t"${TAB}" -k3n,3 \
  | join -t"${TAB}" -13 -21 - <(get_mapping "${MAPPING}") \
  | awk 'BEGIN { FS = OFS = "\t" } { print $2, "pi", $8, $4, $5, $6, $7 }'
}

main
