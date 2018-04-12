#!/usr/bin/env bash

# Map Unix UIDs and GIDs to their human-readable counterparts
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

source "${WORK_DIR}/lib/get-mapping.sh"
USER_MAPPING="${WORK_DIR}/uid-user.map"
GROUP_MAPPING="${WORK_DIR}/gid-group.map"

teepot >(filter_by user  | map_to "${USER_MAPPING}") \
       >(filter_by pi    | map_to "${USER_MAPPING}") \
       >(filter_by group | map_to "${GROUP_MAPPING}")
