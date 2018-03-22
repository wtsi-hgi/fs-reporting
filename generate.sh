#!/usr/bin/env bash

# Generate data and compile report
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

OS="$(uname -s)"
if [[ "${OS}" == "Darwin" ]]; then
  # Use GNU coreutils on macOS (for development/debugging)
  shopt -s expand_aliases
  alias readlink="greadlink"
  alias date="gdate"
fi

BINARY="$(readlink -fn "$0")"

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

dispatch() {
  local mode="${1-}"

  case "${mode}" in
    *)
      # Parse command line arguments and submit jobs
      local -i show_help=0
      local -i bad_options=0

      local output_dir="${PWD}"
      local base_time="$(date +"%s")"
      local -a emails=()
      local -a lustre_data=()
      local -a nfs_data=()
      local -a warehouse_data=()
      local -a irods_data=()
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

          "--lustre")
            value="$2"
            if ! [[ -e "${value}" ]]; then
              >&2 echo "No such input data \"${value}\"!"
              bad_options=1
            fi

            lustre_data+=("${value}")
            shift
            ;;

          "--nfs")
            value="$2"
            if ! [[ -e "${value}" ]]; then
              >&2 echo "No such input data \"${value}\"!"
              bad_options=1
            fi

            nfs_data+=("${value}")
            shift
            ;;

          "--warehouse")
            value="$2"
            if ! [[ -e "${value}" ]]; then
              >&2 echo "No such input data \"${value}\"!"
              bad_options=1
            fi

            warehouse_data+=("${value}")
            shift
            ;;

          "--irods")
            value="$2"
            if ! [[ -e "${value}" ]]; then
              >&2 echo "No such input data \"${value}\"!"
              bad_options=1
            fi

            irods_data+=("${value}")
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

      if ! (( ${#lustre_data[@]} + ${#nfs_data[@]} + ${#warehouse_data[@]} + ${#irods_data[@]} )); then
        >&2 echo "No filesystem input data specified!"
        bad_options=1
      fi

      # Show help on invalid options (or if it was asked for) and exit
      if (( bad_options )) || (( show_help )); then
        usage
        exit "${bad_options}"
      fi
      ;;
  esac
}

dispatch "$@"
