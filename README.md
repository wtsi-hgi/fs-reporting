# Filesystem Reporting

Grouped by:

* Filesystem
  * Lustre
  * NFS
  * Warehouse
  * iRODS
* Organisational Unit
  * Unix User
  * Unix Group
    * PI
* File Type
  * CRAMs
  * BAMs
  * Indices (`*.{crai,bai,sai,fai,csi}`)
  * Compressed (`*.{bzip2,gz,tgz,zip,xz,bgz,bcf}`)
  * Uncompressed (`{README,*.{sam,fasta,fastq,fa,fq,vcf,csv,tsv,txt,text}}`)
  * Checkpoints (`*jobstate.context`)
  * Log files (`*.{log,stdout,stderr,o,out,e,err}`)
  * Temporary (`*{tmp,temp}*`)
  * Other (everything else)

Interested in:

* Total inodes
* Total size
* Total cost, relative to `ctime`

## Pipeline

File paths in the `mpistat` data are base64 encoded. For aggregating by
filetype, the data must be preclassified:

    zcat lustre01.dat.gz | ./classify-filetype.sh

This appends a field to the `mpistat` data containing the filetype and
streams it to `stdout`.

`mpistat` data can be aggregated using `aggregate-mpistat.sh`, taking
uncompressed data from `stdin`:

    zcat lustre01.dat.gz lustre02.dat.gz | ./aggregate-mpistat.sh

The aggregation is output to `stdout` as tab-delimited data with the
following fields:

1. Filesystem type
2. Organisational tag (`group` or `user`)
3. Organisational ID (Unix group ID or user ID)
4. Filetype tag (`all`, `cram`, `bam`, `index`, `compressed`,
   `uncompressed`, `checkpoints`, `logs`, `temp` or `other`)
5. Total inodes
6. Total size (bytes)
7. Total cost since last changed (GBP)

The aggregation script takes three optional, positional arguments:

1. The filetype tag filter, defaulting to `all`. Note that if the input
   data has not been preclassified by filetype, the aggregation step
   will fail.
2. The Unix time from which to base cost calculation, defaulting to the
   current system time.
3. The filesystem type from which to base the cost calculation,
   defaulting to `lustre`.

The filesystem types, that define cost per terabyte year, are enumerated
in `get-fs-cost.sh`.

Aggregated data can be mapped to PI by running it through `map-to-pi.sh`.
This script strips out any `user` records and replaces `group` records
with an appropriate `pi` record, using `group-pi.map`:

    zcat foo.dat.gz | ./aggregate-mpistat.sh | ./map-to-pi.sh

Note that this will not aggregate records by PI, it's strictly a mapping
operation. It defines a third organisational tag, `pi`, in the
aggregated output, where the organisation ID (third field) is the PI's
Unix user ID (per the mapping definition).

Final aggregation/merging can be done using the `merge-aggregates.sh`
script:

    ./merge-aggregates.sh lustre01-all lustre01-cram lustre01-cram-pi

This will produce the output data that drives report generation.

## tl;dr

To generate the aggregated data (i.e., running the complete pipeline
outlined above) and compile the final report, a convenience script is
available that will submit the jobs to an LSF cluster:

    generate.sh [--output DIRECTORY]
                [--base TIME]
                [--email ADDRESS]
                [--lustre INPUT_DATA]
                [--nfs INPUT_DATA]
                [--warehouse INPUT_DATA]
                [--irods INPUT_DATA]
                [--lsf-aggregate OPTION]
                [--lsf-compile OPTION]

Taking the following options:

Option                   | Behaviour
------------------------ | --------------------------------------------------------
`--output DIRECTORY`     | Create the output in `DIRECTORY`, defaulting to the current working directory
`--base TIME`            | Set the base time to `TIME`, defaulting to the current system time
`--email ADDRESS`        | E-mail address to which the completion notification is sent; can be specified multiple times
`--lustre INPUT_DATA`    | `INPUT_DATA` for a Lustre filesytem; can be specified multiple times
`--nfs INPUT_DATA`       | `INPUT_DATA` for a NFS filesytem; can be specified multiple times
`--warehouse INPUT_DATA` | `INPUT_DATA` for a warehouse filesytem; can be specified multiple times
`--irods INPUT_DATA`     | `INPUT_DATA` for a iRODS filesytem; can be specified multiple times
`--lsf-aggregate OPTION` | Provide LSF `OPTION` to the aggregation job submission; can be specified multiple times
`--lsf-compile OPTION`   | Provide LSF `OPTION` to the compilation job submission; can be specified multiple times

Note that at least one `--lustre`, `--nfs`, `--warehouse` or `--irods`
option must be specified with its `INPUT_DATA` readable from the cluster
nodes.
