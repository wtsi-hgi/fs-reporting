#!/usr/bin/env bash

# Final aggregate merging
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(readlink -fn "$0")"

usage() {
  cat <<-EOF
	Usage: $(basename "${BINARY}") FILE ...
	
	Merge and aggregate input files to stdout
	EOF
}

main() {
  if ! (( $# )); then
    >&2 echo "No input files provided!"
    usage
    exit 1
  fi

  local -a inputs=("$@")
  awk '
    BEGIN {
      FS = OFS = "\t"
    }

    NF != 7 {
      print "Invalid input data!" > "/dev/stderr"
      exit 1
    }

    {
      fs_type   = $1
      org_tag   = $2
      org_id    = $3
      file_type = $4
      inodes    = $5
      size      = $6
      cost      = $7

      # The first four fields define the composite key
      id = fs_type ":" org_tag ":" org_id ":" file_type

      total_inodes[id] += inodes
      total_size[id]   += size
      total_cost[id]   += cost
    }

    END {
      for (id in total_inodes) {
        split(id, id_bits, ":")
        fs_type   = id_bits[1]
        org_tag   = id_bits[2]
        org_id    = id_bits[3]
        file_type = id_bits[4]

        print fs_type, org_tag, org_id, file_type, total_inodes[id], total_size[id], total_cost[id]
      }
    }
  ' "${inputs[@]}"
}

main "$@"
