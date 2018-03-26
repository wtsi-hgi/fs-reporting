#!/usr/bin/env bash

# Generate data and compile report
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(readlink -fn "$0")"
BINDIR="$(dirname "${BINARY}")"

usage() {
  cat <<-EOF
	Usage: $(basename "${BINARY}") [OPTIONS]
	
	Submit a job to an LSF cluster to generate the aggregated data and
	compile the final report.
	
	Options:
	
	  --output DIRECTORY      Create the output in DIRECTORY [${PWD}]
	  --base TIME             Set the base time to TIME [now]
	  --email ADDRESS         E-mail address to which the completion
	                          notification is sent; can be specified
	                          multiple times
	  --lustre INPUT_DATA     INPUT_DATA for a Lustre filesytem; can be
	                          specified multiple times
	  --nfs INPUT_DATA        INPUT_DATA for a NFS filesytem; can be
	                          specified multiple times
	  --warehouse INPUT_DATA  INPUT_DATA for a warehouse filesytem; can be
	                          specified multiple times
	  --irods INPUT_DATA      INPUT_DATA for a iRODS filesytem; can be
	                          specified multiple times
	  --lsf-aggregate OPTION  Provide LSF OPTION to the aggregation job
	                          submission; can be specified multiple times
	  --lsf-compile OPTION    Provide LSF OPTION to the compilation job
	                          submission; can be specified multiple times
	
	Note that at least one --lustre, --nfs, --warehouse or --irods option
	must be specified with its INPUT_DATA readable from the cluster nodes.
	EOF
}

aggregate_fs_data() {
  # Generate aggregated data for a particular filesystem type
  local fs_type="$1"
  local base_time="$2"
  local -a input_data=("${@:3}")

  # Synchronising tee'd processes is a PITA
  local lock_dir="$(mktemp -d)"

  __aggregate_stream() {
    # Aggregate the preclassified data stream
    local filetype="$1"
    >&2 echo "Aggregating ${filetype} files for ${fs_type}..."
    "${BINDIR}/aggregate-mpistat.sh" "${filetype}" "${base_time}" "${fs_type}"
    touch "${lock_dir}/${filetype}"
    >&2 echo "Completed ${filetype} aggregation for ${fs_type}"
  }

  zcat "${input_data[@]}" \
  | "${BINDIR}/classify-filetype.sh" \
  | teepot >(__aggregate_stream all) \
           >(__aggregate_stream cram) \
           >(__aggregate_stream bam) \
           >(__aggregate_stream index) \
           >(__aggregate_stream compressed) \
           >(__aggregate_stream uncompressed) \
           >(__aggregate_stream checkpoint) \
           >(__aggregate_stream log) \
           >(__aggregate_stream temp) \
           >(__aggregate_stream other)

  # Block on barrier condition
  local -i num_done
  while :; do
    num_done="$(find "${lock_dir}" -type f | wc -l)"
    (( num_done == 10 )) && break

    >&2 echo "Finished ${num_done} of 10 ${fs_type} aggregations..."
    sleep 10
  done
  rm -rf "${lock_dir}"
}

aggregate() {
  # Aggregate data from source inputs
  local output_dir="$1"
  local base_time="$2"
  local -a input_data=("${@:3}")

  local data_dir="${output_dir}/data"

  >&2 echo "Aggregated data will be written to ${data_dir}"
  >&2 echo "Cost calculations will be based to $(date -d "@${base_time}")"

  __aggregate() {
    # Convenience wrapper that extracts the relevant filesystem data
    # files and then submits them to the aggregator
    local fs_type="$1"
    local -a fs_data=()

    local data
    local e_fs_type
    local e_fs_data
    for data in "${input_data[@]}"; do
      e_fs_type="${data%%:*}"
      e_fs_data="${data#*:}"

      if [[ "${e_fs_type}" == "${fs_type}" ]]; then
        fs_data+=("${e_fs_data}")
      fi
    done

    if ! (( ${#fs_data[@]} )); then
      # No data to process
      return
    fi

    aggregate_fs_data "${fs_type}" "${base_time}" "${fs_data[@]}"
  }

  # Aggregate filesystem data files and map to PI
  local fs_type
  local data
  for fs_type in "lustre" "nfs" "warehouse" "irods"; do
    data="${data_dir}/${fs_type}"
    __aggregate "${fs_type}" \
    | teepot >("${BINDIR}/map-to-pi.sh" > "${data}-pi") "${data}"
  done

  # Merge everything into final output
  >&2 echo "Merging all aggregated data together..."
  "${BINDIR}/merge-aggregates.sh" "${data_dir}/"{lustre,nfs,warehouse,irods}{,-pi} > "${data_dir}/aggregated"
  >&2 echo "All done :)"
}

compile() {
  # Compile report from aggregated data
  local output_dir="$1"
  local aggregated_data="${output_dir}/data/aggregated"

  local -a emails=()
  local -i send_email=0
  if (( $# > 1 )); then
    emails=("${@:2}")
    send_email=1
  fi

  if ! [[ -e "${aggregated_data}" ]]; then
    if (( send_email )); then
      mail -s "Filesystem Report Generation Failed!" "${emails[@]}" <<-EOF
			Filesystem report could not be generated! No aggregated data found.
			EOF
    fi

    >&2 echo "No aggregated data available to generate report!"
    exit 1
  fi

  # TODO...

  # Send completion e-mail
  if (( send_email )); then
    mail -s "Filesystem Report Complete!" \
         -a "${output_dir}/report.pdf" \
         "${emails[@]}" \
    <<-EOF
		Filesystem report is ready and available at: ${output_dir}/report.pdf
		EOF
  fi
}

dispatch() {
  local mode="${1-}"

  case "${mode}" in
    "__aggregate" | "__compile")
      # Subcommand dispatch
      local -a args=("${@:2}")
      "${mode:2}" "${args[@]}"
      ;;

    *)
      # Parse command line arguments and submit jobs
      local -i show_help=0
      local -i bad_options=0

      local output_dir="${PWD}"
      local base_time="$(date +"%s")"
      local -a emails=()
      local -a input_data=()
      local -a lsf_aggregate_ops=()
      local -a lsf_compile_ops=()

      local option
      local value
      while (( $# )); do
        option="$1"

        case "${option}" in
          "-h" | "--help")
            show_help=1
            ;;

          "--output")
            output_dir="$2"
            shift
            ;;

          "--base")
            base_time="$(date -d "$2" +"%s")"
            shift
            ;;

          "--email")
            emails+=("$2")
            shift
            ;;

          "--lustre" | "--nfs" | "--warehouse" | "--irods")
            value="$2"
            if ! [[ -e "${value}" ]]; then
              >&2 echo "No such input data \"${value}\"!"
              bad_options=1
            fi

            input_data+=("${option:2}:${value}")
            shift
            ;;

          "--lsf-aggregate")
            lsf_aggregate_ops+=("$2")
            shift
            ;;

          "--lsf-compile")
            lsf_compile_ops+=("$2")
            shift
            ;;

          *)
            >&2 echo "Unknown option \"${option}\"!"
            bad_options=1
            ;;
        esac

        shift
      done

      if ! (( ${#input_data[@]} )); then
        >&2 echo "No filesystem input data specified!"
        bad_options=1
      fi

      # Show help on invalid options (or if it was asked for) and exit
      if (( bad_options )) || (( show_help )); then
        usage
        exit "${bad_options}"
      fi

      # Create working directory structure, if it doesn't exist
      local log_dir="${output_dir}/logs"
      local data_dir="${output_dir}/data"
      mkdir -p "${output_dir}" "${log_dir}" "${data_dir}"

      # Submit aggregation job
      local job_id="${RANDOM}"
      local aggregate_job_name="fs-report-aggregate-${job_id}"
      local aggregate_log="${log_dir}/aggregate-${job_id}.log"
      bsub "${lsf_aggregate_ops[@]+"${lsf_aggregate_ops[@]}"}" \
           -J "${aggregate_job_name}" \
           -o "${aggregate_log}" -e "${aggregate_log}" \
           "${BINARY}" __aggregate "${output_dir}" "${base_time}" "${input_data[@]}"

      # Submit compilation job
      local compile_job_name="fs-report-compile-${job_id}"
      local compile_log="${log_dir}/compile-${job_id}.log"
      bsub "${lsf_compile_ops[@]+"${lsf_compile_ops[@]}"}" \
           -J "${compile_job_name}" \
           -w "ended(${aggregate_job_name})" \
           -o "${compile_log}" -e "${compile_log}" \
           "${BINARY}" __compile "${output_dir}" "${emails[@]+"${emails[@]}"}"
      ;;
  esac
}

dispatch "$@"
