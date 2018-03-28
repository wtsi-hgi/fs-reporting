#!/usr/bin/env bash

# Classify mpistat filenames
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

classify() {
  # Classify input: Append the base64 encoding of \0 to the first column
  # of each line and then base64 decode; translate any \n that appear to
  # X (i.e., files with newlines in their name) and \0 to a newline, so
  # we restore one record per line. Finally, run the decoded file path
  # through the classifier.
  local input="$1"
  cut -f1 "${input}" | sed 's/$/AA==/' | base64 -di | tr "\n\0" "X\n" | awk '
    BEGIN {
      last = systime()
    }

    # Log progress every 30 seconds
    systime() - last >= 30 {
      last = systime()
      print "Processed " NR " inodes..." > "/dev/stderr"
    }

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
  local input="$(mktemp)"
  trap "rm -rf ${input}" EXIT

  teepot "${input}" - | paste - <(classify "${input}")
}

main "$@"
