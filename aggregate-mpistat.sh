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
#     B=block special, c=character special, F=fifo, X otherwise)
# 9.  Inode ID
# 10. Number of hardlinks to file
# 11. Device ID

# Aggregated data is tab-delimited with the following fields:
# 1.  Filesystem type
# 2.  Organisational unit ("group:GID" or "user:UID")
# 3.  inodes
# 4.  Size (bytes)
# 5.  Cost since last changed (GBP)

set -euo pipefail

OS="$(uname -s)"
if [[ "${OS}" == "Darwin" ]]; then
  # Use GNU coreutils on macOS (for development/debugging)
  shopt -s expand_aliases
  alias readlink="greadlink"
  alias stat="gstat"
fi

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

# Imports
source "${WORK_DIR}/get-fs-cost.sh"
source "${WORK_DIR}/get-group-owners.sh"

main() {
  local mpistat_data="$1"
  local mpistat_time="$(stat -c "%Y" "${mpistat_data}")"

  local fs_type="${2-lustre}"
  local fs_cost="$(get_fs_cost "${fs_type}")"

  # FIXME Is Awk going to handle this at scale?
  zcat "${mpistat_data}" \
  | awk -v FS_TYPE="${fs_type}" \
        -v FS_COST="${fs_cost}" \
        -v NOW="${mpistat_time}" \
  '
    BEGIN {
      FS = OFS = "\t"
    }

    {
      size = $2
      uid = $3
      gid = $4
      ctime = $7

      # 60s * 60m * 24hr * 365.2425d = 31556952s in an average year
      cost = ctime > NOW ? 0
                         : FS_COST * (NOW - ctime) / 31556952

      user_inodes[uid]++
      user_size[uid] += size
      user_cost[uid] += cost

      group_inodes[gid]++
      group_size[gid] += size
      group_cost[gid] += cost
    }

    END {
      for (user in user_inodes)
        print FS_TYPE, "user:" user, user_inodes[user], user_size[user], user_cost[user]

      for (group in group_inodes)
        print FS_TYPE, "group:" group, group_inodes[group], group_size[group], group_cost[group]
    }
  '
}

main "$@"
