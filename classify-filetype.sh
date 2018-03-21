#!/usr/bin/env bash

# Classify mpistat filenames
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

OS="$(uname -s)"
if [[ "${OS}" == "Darwin" ]]; then
  # Use GNU coreutils on macOS (for development/debugging)
  shopt -s expand_aliases
  alias readlink="greadlink"
  alias mktemp="gmktemp"
  alias cut="gcut"
  alias sed="gsed"
  alias base64="gbase64"
fi

BINARY="$(readlink -fn "$0")"

classify() {
  local input="$1"
  cut -f1 "${input}" | sed 's/$/Cg==/' | base64 -di | awk '
    /\.cram$/                                                  { print "cram"; next }
    /\.bam$/                                                   { print "bam"; next }
    /\.(crai|bai|sai|fai|csi)$/                                { print "index"; next }
    /\.(bzip2|gz|tgz|zip|xz|bgz|bcf)$/                         { print "compressed"; next }
    /^README$|\.(sam|fasta|fastq|fa|fq|vcf|csv|tsv|txt|text)$/ { print "uncompressed"; next }
    /jobstate\.context/                                        { print "checkpoint"; next }
    /\.(log|stdout|stderr|o|out|e|err)$/                       { print "log"; next }
    /te?mp/                                                    { print "temp"; next }
                                                               { print "other" }
  '
}

main() {
  case $# in
    0)
      local input="$(mktemp)"
      trap "rm -rf ${input}" EXIT

      cat > "${input}"
      paste "${input}" <("${BINARY}" "${input}")
      ;;

    1)
      local input="$1"
      classify "${input}"
      ;;
  esac
}

main "$@"
