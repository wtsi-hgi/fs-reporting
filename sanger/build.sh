#!/usr/bin/env bash

# Submit the report pipeline to the Sanger cluster
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

REPO_DIR="$(git rev-parse --show-toplevel)"

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
      nothing = 1

      for (i in found) {
        if (found[i] == count) {
          print i
          nothing = 0
        }
      }

      exit nothing
    }' \
  | sort -nr \
  | head -1
}

stat_irods() {
  # Generate the iRODS mpistat-style output, filtered to the given date
  local data_date="$(date -d "$1" "+%s")"

  # TODO
}

main() {
  local -a recipients
  if (( $# )); then
    read -ra recipients <<< "$(to_email "$@")"
  fi

  local data_date
  if ! data_date="$(most_recent_lustre_data)"; then
    >&2 echo "No Lustre stat data found!"
    exit 1
  fi

  echo "Most recent full complement of Lustre stat data found on $(date -d "${data_date}" "+%A, %-d %B, %Y")"

  # Check if report already exists for that date
  local report="${REPO_DIR}/sanger/reports/${data_date}.pdf"
  if [[ -e "${report}" ]]; then
    echo "Report already exists for this date: ${report}"
    exit 0
  fi

  local log_dir="${REPO_DIR}/sanger/logs"
  local working_dir="$(mktemp -d "${REPO_DIR}/sanger/working/XXXXX")"

  # Create iRODS stat file, filtered to the data date
  local irods_data="${REPO_DIR}/sanger/irods-data/${data_date}.dat.gz"
  stat_irods "${data_date}" | gzip > "${irods_data}"

  # Create mappings
  "${REPO_DIR}/sanger/create-mappings.sh" --force
  mv -f uid-user.map gid-group.map gid-pi_uid.map "${REPO_DIR}/"

  # Construct options
  local i
  local -a options

  # Add recipients
  for i in "${recipients[@]+"${recipients[@]}"}"; do
    options+=("--mail" "$i")
  done

  # Add stat files
  for i in "${LUSTRE_VOLUMES[@]}"; do
    options+=("--lustre" "${LUSTRE_MPISTAT}/${data_date}_${i}.dat.gz")
  done
  options+=("--irods" "${irods_data}")

  # Submit the pipeline!
  # TODO Set appropriate LSF options...
  "${REPO_DIR}/submit-pipline.sh" --output "${report}" \
                                  --work-dir "${working_dir}" \
                                  --base "${data_date}" \
                                  --bootstrap "${REPO_DIR}/sanger/bootstrap.sh" \
                                  --lsf-split -G hgi \
                                              -q normal \
                                              -e "${log_dir}/split-${data_date}.log" \
                                              -o "${log_dir}/split-${data_date}.log" \
                                              -n 1 \
                                              -M 1000 \
                                              -R "select(mem>1000) rusage(mem=1000)" \
                                  "${options[@]}"
}

main "$@"
