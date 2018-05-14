#!/usr/bin/env bash

# Submit complete pipeline to an LSF cluser
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(greadlink -fn "$0")"
BINDIR="$(dirname "${BINARY}")"

DUMMY_BOOTSTRAP="/"

## Utility Functions ###################################################

stderr() {
  local message="$*"

  if [[ -t 2 ]]; then
    # Use ANSI red if we're in a terminal
    message="\033[31m${message}\033[0m"
  fi

  >&2 echo -e "${message}"
}

list_pipelines() {
  # List all pipeline steps in this script
  ggrep -Po '(?<=^pipeline_).*(?=\(\)\s*{)' "${BINARY}"
}

is_pipeline() {
  # Check that the given option is a valid pipeline step
  local option="$1"
  list_pipelines | grep -qF "${option}"
}

usage() {
  local pipelines="$(list_pipelines | paste -sd" " -)"

  cat <<-EOF
	Usage: $(basename "${BINARY}") [OPTIONS]
	
	Submit the pipeline to generate the aggregated data and compile the
	final report to an LSF cluser.
	
	Options:
	
	  --output FILENAME       Write the report to FILENAME [$(pwd)/report.pdf]
	  --work-dir DIRECTORY    Use DIRECTORY for the pipeline's working files [$(pwd)]
	  --bootstrap SCRIPT      Source SCRIPT at the begnning of each job in
	                          the pipeline
	  --base TIME             Set the base time for cost calculation to
	                          TIME [now]
	  --mail ADDRESS          E-mail address to which the completed report
	                          is sent; can be specified multiple times
	  --lustre INPUT_DATA     INPUT_DATA for a Lustre filesytem; can be
	                          specified multiple times
	  --nfs INPUT_DATA        INPUT_DATA for a NFS filesytem; can be
	                          specified multiple times
	  --warehouse INPUT_DATA  INPUT_DATA for a warehouse filesytem; can be
	                          specified multiple times
	  --irods INPUT_DATA      INPUT_DATA for a iRODS filesytem; can be
	                          specified multiple times
	  --lsf-STEP OPTION       Provide LSF OPTION to the STEP job submission;
	                          can be specified multiple times
	
	Note that at least one --lustre, --nfs, --warehouse or --irods option
	must be specified with its INPUT_DATA readable from the cluster nodes.
	In addition to the final report, its source aggregated data will be
	compressed alongside it, with the extension .dat.gz.
	
	The following pipeline STEP options are available: ${pipelines}
	EOF
}

## Pipeline Functions ##################################################

# NOTE All pipeline functions must be prefixed with "pipeline_"

pipeline_aggregate() {
  true
}

pipeline_cleanup() {
  true
}

## Entrypoint ##########################################################

dispatch() {
  local mode="${1-}"

  if [[ "${mode:0:2}" == "__" ]]; then
    # Subcommand dispatcher
    local subcommand="${mode:2}"
    local -a args=("${@:2}")

    if ! is_pipeline "${subcommand}"; then
      # Unknown subcommand (n.b., this should never happen because the
      # subcommands are for internal use only)
      stderr "I don't know how to \"${subcommand}\"!"
      usage
      exit 1
    fi

    # TODO Dispatch subcommand
    echo "$subcommand"
    echo "${args[@]/#/X}"
    exit 0
  fi

  # Parse command line arguments and submit jobs
  local -i show_help=0
  local -i bad_options=0

  local output="$(pwd)/report.pdf"
  local work_dir="$(pwd)"
  local bootstrap
  local base_time="$(date "+%s")"
  local -a recipients=()
  local -a input_data=()

  local pipeline
  for pipeline in $(list_pipelines); do
    # I'm going down for this!
    eval "local -a lsf_${pipeline}=()"
  done

  local option
  local value
  while (( $# > 1 )); do
    option="$1"
    if [[ "${option:0:6}" == "--lsf-" ]]; then
      value="${option:6}"
      option="--lsf"
    fi

    case "${option}" in
      "-h" | "--help")
        show_help=1
        ;;

      "--output")
        output="$2"
        shift
        ;;

      "--work-dir")
        work_dir="$2"
        shift
        ;;

      "--bootstrap")
        bootstrap="$2"
        shift
        ;;

      "--base")
        base_time="$(date -d "$2" "+%s")"
        shift
        ;;

      "--mail")
        recipients+=("$2")
        shift
        ;;

      "--lustre" | "--nfs" | "--warehouse" | "--irods")
        value="$2"
        if ! [[ -e "${value}" ]]; then
          stderr "No such input data \"${value}\"!"
          bad_options=1
        fi

        input_data+=("${option:2}:${value}")
        shift
        ;;

      "--lsf")
        if ! is_pipeline "${value}"; then
          stderr "No such pipeline job \"${value}\""
          bad_options=1

        else
          shift
          while (( $# )) && [[ "${1:0:2}" != "--" ]]; do
            # So evil...
            eval "lsf_${value}+=(\"$1\")"
            shift
          done

          # Bypass outer loop shift
          continue
        fi
        ;;

      *)
        stderr "Unknown option \"${option}\"!"
        bad_options=1
        ;;
    esac

    shift
  done

  if ! (( ${#input_data[@]} )); then
    stderr "No filesystem stat data specified!"
    bad_options=1
  fi

  if (( $# )); then
    stderr "Incomplete options provided!"
    bad_options=1
  fi

  # Show help on invalid options (or if it was asked for) and exit
  if (( bad_options )) || (( show_help )); then
    usage
    exit "${bad_options}"
  fi

  # TODO Submit jobs
}

dispatch "$@"


## 
## 
## 
## aggregate_fs_data() {
##   # Generate aggregated data for a particular filesystem type
##   local temp_dir="$1"
##   local fs_type="$2"
##   local base_time="$3"
##   local -a input_data=("${@:4}")
## 
##   # Synchronising tee'd processes is a PITA
##   local work_dir="$(mktemp -d "${temp_dir}/XXXXX")"
##   local output="${work_dir}/output"
##   echo "${work_dir}" >> "${temp_dir}/aggregate-manifest"
## 
##   __aggregate_stream() {
##     # Aggregate the preclassified data stream
##     local filetype="$1"
## 
##     local lock="${work_dir}/${filetype}.lock"
##     touch "${lock}"
## 
##     >&2 echo "Aggregating ${filetype} file statistics for ${fs_type}..."
##     "${BINDIR}/aggregate-mpistat.sh" "${filetype}" "${base_time}" "${fs_type}" \
##     | tee -a "${output}" >/dev/null
##     >&2 echo "Completed ${filetype} aggregation for ${fs_type}"
## 
##     rm -rf "${lock}"
##   }
## 
##   # NOTE Bash gets into a race condition here, if one expects the output
##   # of all the substituted processes to write to the same stdout. To get
##   # around this, we append to a temporary output file (see above) and
##   # use an ad hoc semaphore to block until all the aggregators have
##   # finished... Gross :P
##   zcat "${input_data[@]}" \
##   | "${BINDIR}/classify-filetype.sh" "${temp_dir}" \
##   | teepot >(__aggregate_stream all) \
##            >(__aggregate_stream cram) \
##            >(__aggregate_stream bam) \
##            >(__aggregate_stream index) \
##            >(__aggregate_stream compressed) \
##            >(__aggregate_stream uncompressed) \
##            >(__aggregate_stream checkpoint) \
##            >(__aggregate_stream log) \
##            >(__aggregate_stream temp) \
##            >(__aggregate_stream other)
## 
##   # Block on semaphore files before streaming output to stdout
##   while (( $(find "${work_dir}" -type f -name "*.lock" | wc -l) )); do sleep 1; done
##   cat "${output}"
## }
## 
## aggregate() {
##   # Aggregate data from source inputs
##   local output_dir="$1"
##   local base_time="$2"
##   local -a input_data=("${@:3}")
## 
##   local data_dir="${output_dir}/data"
## 
##   local temp_dir="${output_dir}/temp"
##   local temp_manifest="${temp_dir}/aggregate-manifest"
##   touch "${temp_manifest}"
##   trap "cat \"${temp_manifest}\" | xargs rm -rf \"${temp_manifest}\"" EXIT
## 
##   >&2 echo "Aggregated data will be written to ${data_dir}"
##   >&2 echo "Cost calculations will be based to $(date -d "@${base_time}")"
## 
##   __aggregate() {
##     # Convenience wrapper that extracts the relevant filesystem data
##     # files and then submits them to the aggregator
##     local fs_type="$1"
##     local -a fs_data=()
## 
##     local data
##     local e_fs_type
##     local e_fs_data
##     for data in "${input_data[@]}"; do
##       e_fs_type="${data%%:*}"
##       e_fs_data="${data#*:}"
## 
##       if [[ "${e_fs_type}" == "${fs_type}" ]]; then
##         fs_data+=("${e_fs_data}")
##       fi
##     done
## 
##     if ! (( ${#fs_data[@]} )); then
##       # No data to process
##       return
##     fi
## 
##     aggregate_fs_data "${temp_dir}" "${fs_type}" "${base_time}" "${fs_data[@]}"
##   }
## 
##   # Aggregate filesystem data files and map to PI
##   local fs_type
##   local data
##   for fs_type in "lustre" "nfs" "warehouse" "irods"; do
##     data="${data_dir}/${fs_type}"
##     __aggregate "${fs_type}" \
##     | teepot >("${BINDIR}/map-to-pi.sh" > "${data}-pi") "${data}"
##   done
## 
##   # Merge everything into final output
##   >&2 echo "Merging all aggregated data together..."
##   find "${data_dir}" -type f -exec "${BINDIR}/merge-aggregates.sh" {} \+ > "${data_dir}/aggregated"
##   >&2 echo "All done :)"
## }
## 
## compile() {
##   # Compile report from aggregated data
##   local output_dir="$1"
##   local aggregated_data="${output_dir}/data/aggregated"
## 
##   local -a emails=()
##   local -i send_email=0
##   if (( $# > 1 )); then
##     emails=("${@:2}")
##     send_email=1
##   fi
## 
##   if ! [[ -e "${aggregated_data}" ]]; then
##     if (( send_email )); then
##       mail -s "Filesystem Report Generation Failed!" "${emails[@]}" <<-EOF
## 			Filesystem report could not be generated! No aggregated data found.
## 			EOF
##     fi
## 
##     >&2 echo "No aggregated data available to generate report!"
##     exit 1
##   fi
## 
##   # TODO...
## 
##   # Send completion e-mail
##   if (( send_email )); then
##     mail -s "Filesystem Report Complete!" \
##          -a "${output_dir}/report.pdf" \
##          "${emails[@]}" \
##     <<-EOF
## 		Filesystem report is ready and available at: ${output_dir}/report.pdf
## 		EOF
##   fi
## }
## 
## dispatch() {
##   local mode="${1-}"
## 
##   case "${mode}" in
##     "__aggregate" | "__compile")
##       # Subcommand dispatch
##       local -a args=("${@:2}")
##       "${mode:2}" "${args[@]}"
##       ;;
## 
##     *)
##       # Parse command line arguments and submit jobs
##       local -i show_help=0
##       local -i bad_options=0
## 
##       local output_dir="${PWD}"
##       local base_time="$(date +"%s")"
##       local -a emails=()
##       local -a input_data=()
##       local -a lsf_aggregate_ops=()
##       local -a lsf_compile_ops=()
## 
##       local option
##       local value
##       while (( $# > 1 )); do
##         option="$1"
## 
##         case "${option}" in
## 
##           "--lsf-aggregate" | "--lsf-compile")
##             shift
##             while (( $# )) && [[ "${1:0:2}" != "--" ]]; do
##               case "${option}" in
##                 "--lsf-aggregate")
##                   lsf_aggregate_ops+=("$1")
##                   ;;
## 
##                 "--lsf-compile")
##                   lsf_compile_ops+=("$1")
##                   ;;
##               esac
##               shift
##             done
##             continue
##             ;;
## 
##         esac
## 
##         shift
##       done
## 
## 
##       # Create working directory structure, if it doesn't exist
##       local log_dir="${output_dir}/logs"
##       local data_dir="${output_dir}/data"
##       local temp_dir="${output_dir}/temp"
##       mkdir -p "${output_dir}" "${log_dir}" "${data_dir}" "${temp_dir}"
## 
##       # Submit aggregation job
##       local job_id="${RANDOM}"
##       local aggregate_job_name="fs-report-aggregate-${job_id}"
##       local aggregate_log="${log_dir}/aggregate-${job_id}.log"
##       bsub "${lsf_aggregate_ops[@]+"${lsf_aggregate_ops[@]}"}" \
##            -J "${aggregate_job_name}" \
##            -o "${aggregate_log}" -e "${aggregate_log}" \
##            "${BINARY}" __aggregate "${output_dir}" "${base_time}" "${input_data[@]}"
## 
##       # Submit compilation job
##       local compile_job_name="fs-report-compile-${job_id}"
##       local compile_log="${log_dir}/compile-${job_id}.log"
##       bsub "${lsf_compile_ops[@]+"${lsf_compile_ops[@]}"}" \
##            -J "${compile_job_name}" \
##            -w "ended(${aggregate_job_name})" \
##            -o "${compile_log}" -e "${compile_log}" \
##            "${BINARY}" __compile "${output_dir}" "${emails[@]+"${emails[@]}"}"
##       ;;
##   esac
## }
