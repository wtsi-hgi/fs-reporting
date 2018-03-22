#!/usr/bin/env bash

# Generate data and compile report
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

OS="$(uname -s)"
if [[ "${OS}" == "Darwin" ]]; then
  # Use GNU coreutils on macOS (for development/debugging)
  shopt -s expand_aliases
  alias readlink="greadlink"
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
	
	Note that at least one --lustre, --nfs, --warehouse or --irods option
	must be specified with its INPUT_DATA readable from the cluster nodes.
	EOF
}

dispatch() {
  usage
}

dispatch "$@"
