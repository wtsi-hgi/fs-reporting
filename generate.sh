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

create_directories() {
  # Create directories, if they don't already exist
  local -a dirs=("$@")

  for dir in "${dirs[@]}"; do
    if ! [[ -d "${dir}" ]]; then
      mkdir -p "${dir}"
    fi
  done
}

aggregate_fs_data() {
  # Generate aggregated data for a particular filesystem type
  local fs_type="$1"
  local base_time="$2"

  if (( $# == 2 )); then
    # No data to process
    return
  fi

  local -a input_data=("${@:3}")

  zcat "${input_data[@]}" \
  | "${BINDIR}/classify-filetype.sh" \
  | tee >("${BINDIR}/aggregate-mpistat.sh" cram         "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" bam          "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" index        "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" compressed   "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" uncompressed "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" checkpoint   "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" log          "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" temp         "${base_time}" "${fs_type}") \
        >("${BINDIR}/aggregate-mpistat.sh" other        "${base_time}" "${fs_type}") \
  | "${BINDIR}/aggregate-mpistat.sh" all "${base_time}" "${fs_type}"
}

aggregate() {
  # Aggregate data from source inputs
  local output_dir="$1"
  local base_time="$2"
  local -a input_data=("${@:3}")

  local -a lustre_data=()
  local -a nfs_data=()
  local -a warehouse_data=()
  local -a irods_data=()

  local data
  local fs_type
  local fs_data
  for data in "${input_data[@]}"; do
    fs_type="${data%%:*}"
    fs_data="${data#*:}"

    case "${fs_type}" in
      "lustre")
        lustre_data+=("${fs_data}");
        ;;

      "nfs")
        nfs_data+=("${fs_data}");
        ;;

      "warehouse")
        warehouse_data+=("${fs_data}")
        ;;

      "irods")
        irods_data+=("${fs_data}")
        ;;
    esac
  done

  local data_dir="${output_dir}/data"

  # Aggregate filesystem data files
  aggregate_fs_data "lustre"    "${base_time}" "${lustre_data[@]-}"    > "${data_dir}/lustre"
  aggregate_fs_data "nfs"       "${base_time}" "${nfs_data[@]-}"       > "${data_dir}/nfs"
  aggregate_fs_data "warehouse" "${base_time}" "${warehouse_data[@]-}" > "${data_dir}/warehouse"
  aggregate_fs_data "irods"     "${base_time}" "${irods_data[@]-}"     > "${data_dir}/irods"

  # Map to PI
  for fs_type in "lustre" "nfs" "warehouse" "irods"; do
    data="${data_dir}/${fs_type}"
    "${BINDIR}/map-to-pi.sh" < "${data}" > "${data}-pi"
  done

  # Merge everything into final output
  "${BINDIR}/merge-aggregates.sh" "${data_dir}/"{lustre,nfs,warehouse,irods}{,pi} > "${data_dir}/aggregated"
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
      create_directories "${output_dir}" \
                         "${log_dir}" \
                         "${data_dir}"

      # Submit aggregation job
      local job_id="${RANDOM}"
      local aggregate_job_name="fs-report-aggregate-${job_id}"
      local aggregate_log="${log_dir}/aggregate-${job_id}.log"
      bsub "${lsf_aggregate_ops[@]-}" \
           -J "${aggregate_job_name}" \
           -o "${aggregate_log}" -e "${aggregate_log}" \
           "${BINARY}" __aggregate "${output_dir}" "${base_time}" "${input_data[@]}"

      # Submit compilation job
      local compile_job_name="fs-report-compile-${job_id}"
      local compile_log="${log_dir}/compile-${job_id}.log"
      bsub "${lsf_compile_ops[@]-}" \
           -J "${compile_job_name}" \
           -w "ended(${aggregate_job_name})" \
           -o "${compile_log}" -e "${compile_log}" \
           "${BINARY}" __compile "${output_dir}" "${emails[@]-}"
      ;;
  esac
}

dispatch "$@"
