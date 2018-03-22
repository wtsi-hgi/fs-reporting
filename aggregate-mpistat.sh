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

# If the data has been preclassified, it will have an additional field:
# 12. File type

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

usage() {
  cat <<-EOF
	Usage: $(basename ${BINARY}) [ FILETYPE [ BASETIME [ FILESYSTEM ] ] ]
	
	Aggregate uncompressed mpistat data streamed from standard input
	
	Arguments:
	* FILETYPE    Filetype filter [default: all]
	* BASETIME    Base time for cost calculation [default: Current time]
	* FILESYSTEM  Filesystem type for cost calculation [default: lustre]
	
	Note: To do non-trivial filetype filtering, the input data must be
	preclassified by file type.
	EOF
}

main() {
  local filetype="${1-all}"

  local since="${2-$(date +"%s")}"

  local fs_type="${3-lustre}"
  local fs_cost="$(get_fs_cost "${fs_type}")"

  case "${filetype}" in
    "all" | "cram" | "bam" | "index" | "compressed" | \
    "uncompressed" | "checkpoint" | "log" | "temp" | "other")
      # These are all fine
      ;;

    *)
      >&2 echo "Unknown filetype filter \"${filetype}\""
      usage
      exit 1
      ;;
  esac

  if [[ -z "${fs_cost}" ]]; then
    usage
    exit 1
  fi

  awk -v FILETYPE="${filetype}" \
      -v FS_TYPE="${fs_type}" \
      -v FS_COST="${fs_cost}" \
      -v SINCE="${since}" \
  '
    BEGIN {
      FS = OFS = "\t"

      yr = 60 * 60 * 24 * 365.2425  # 31556952s in an average year
      TiB = 1024 ^ 4
    }

    function fail(message) {
      print message > "/dev/stderr"
      exit 1
    }

    # Data sanity checking
    NF < 11                       { fail("Invalid input data!") }
    FILETYPE != "all" && NF != 12 { fail("Input data has not been preclassified!") }

    # Set the filetype of each record
    { file_type = (FILETYPE == "all") ? "all" : $12 }

    # Aggregate on filetype match
    file_type == FILETYPE {
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

      if (file_cost > 0) {
        cost["user:" uid] += file_cost
        cost["group:" gid] += file_cost
      }
    }

    END {
      for (id in inodes) {
        split(id, id_bits, ":")
        org_tag = id_bits[1]
        org_id  = id_bits[2]

        print FS_TYPE, org_tag, org_id, FILETYPE, inodes[id], size[id], cost[id]
      }
    }
  '
}

main "$@"
