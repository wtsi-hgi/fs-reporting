#!/usr/bin/env bash

# Aggregate mpistat data
# Christopher Harrison <ch12@sanger.ac.uk>

# mpistat data is tab-delimited with the following fields per inode:
# 1.  File path (base64 encoded)
# 2.  Size (bytes)
# 3.  User (Unix uid)
# 4.  Group (Unix gid)
# 5.  Last access time (Unix time)
# 6.  Last modified time (Unix time)
# 7.  Last changed time (Unix time)
# 8.  Protection Mode (f=regular file, d=directory, l=symlink, s=socket,
#     b=block special, c=character special, F=fifo, X otherwise)
# 9.  inode ID
# 10. Number of hardlinks to file
# 11. Device ID

# Aggregated data is tab-delimited with the following fields:
# 1.  Filesystem type
# 2.  Organisational tag ("group" or "user")
# 3.  Organisational ID (Unix group ID or user ID)
# 4.  Filetype tag ("all", "cram", "bam", "index", "compressed",
#     "uncompressed", "checkpoints", "logs", "temp" or "other")
# 5.  inodes
# 6.  Size (bytes)
# 7.  Cost since last changed (GBP)

set -euo pipefail

OS="$(uname -s)"
if [[ "${OS}" == "Darwin" ]]; then
  # Use GNU coreutils on macOS (for development/debugging)
  shopt -s expand_aliases
  alias readlink="greadlink"
  alias date="gdate"
fi

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

# Imports
source "${WORK_DIR}/get-fs-cost.sh"
source "${WORK_DIR}/get-group-owners.sh"

main() {
  local since="${1-$(date +"%s")}"

  local fs_type="${2-lustre}"
  local fs_cost="$(get_fs_cost "${fs_type}")"

  awk -v FS_TYPE="${fs_type}" \
      -v FS_COST="${fs_cost}" \
      -v SINCE="${since}" \
  '
    BEGIN {
      FS = OFS = "\t"

      yr = 60 * 60 * 24 * 365.2425  # 31556952s in an average year
      TiB = 1024 ^ 4
    }

    {
      file_size = $2
      uid = $3
      gid = $4

      ctime = $7
      file_cost = FS_COST * (file_size / TiB) * ((SINCE - ctime) / yr)

      # Tally up
      inodes["user:" uid]++
      inodes["group:" gid]++

      size["user:" uid] += file_size
      size["group:" gid] += file_size

      if (filecost > 0) {
        cost["user:" uid] += file_cost
        cost["group:" gid] += file_cost
      }
    }

    END {
      for (id in inodes) {
        split(id, id_bits, ":")
        org_tag = id_bits[1]
        org_id  = id_bits[2]

        print FS_TYPE, org_tag, org_id, "all", inodes[id], size[id], cost[id]
      }
    }
  '
}

main "$@"
