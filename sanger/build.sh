#!/usr/bin/env bash

# Submit the report pipeline to the Sanger cluster
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

LUSTRE_MPISTAT="/lustre/scratch114/teams/hgi/lustre_reports/mpistat/data"
declare -a LUSTRE_VOLUMES=(114 115 118 119)

to_email() {
  # Convert raw user IDs to @sanger.ac.uk e-mail addresses
  local -a recipients=("$@")

  printf '%s\n' "${recipients[@]}" \
  | sed -E 's/^[^@]+$/&@sanger.ac.uk/' \
  | xargs
}

most_recent_lustre_data() {
  # Return the most recent date (as "%Y%m%d") for which the full
  # complement of humgen Lustre mpistat data exists
  find "${LUSTRE_MPISTAT}" -maxdepth 1 -type f -name "*.dat.gz" -size +10M \
  | awk -v VOLUMES="${LUSTRE_VOLUMES[*]}" '
    BEGIN {
      FS = "[/_.]"

      count = split(VOLUMES, _v, " ")
      for (i in _v) volumes[_v[i]] = 1
    }

    $(NF - 2) in volumes { found[$(NF - 3)]++ }

    END {
      for (i in found)
        if (found[i] == count)
          print i
    }' \
  | sort -nr \
  | head -1
}


main() {
  local -a recipients
  read -ra recipients <<< "$(to_email "$@")"
}

main "${@-$(whoami)}"
