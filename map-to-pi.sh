#!/usr/bin/env bash

# Map aggregated group data to PIs
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

source "${WORK_DIR}/mapping-utils.sh"
MAPPING="${WORK_DIR}/gid-pi_uid.map"

filter_by group | map_to "${MAPPING}" | awk 'BEGIN { FS = OFS = "\t"} { $2 = "pi"; print }'
