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
  alias tr="gtr"
  alias cat="gcat"
  alias paste="gpaste"
fi

BINARY="$(readlink -fn "$0")"

classify() {
  # Classify input: Append the base64 encoding of \0 to the first column
  # of each line and then base64 decode; translate any \n that appear to
  # X (i.e., files with newlines in their name) and \0 to a newline, so
  # we restore one record per line. Finally, run the decoded file path
  # through the classifier.
  local input="$1"
  cut -f1 "${input}" | sed 's/$/AA==/' | base64 -di | tr "\n\0" "X\n" | awk '
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
