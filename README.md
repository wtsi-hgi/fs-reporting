# Filesystem Reporting

Generate reports and visualisations of filesystem usage, grouped by:

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

Specifically, we are interested in:

* Total inodes
* Total size of data
* Total cost, relative to `ctime`

## Prerequisites

* Bash (4.2, or higher)
* GNU Awk
* GNU coreutils (8.21, or higher)
* [teepot](https://github.com/wtsi-npg/teepot)
* R (packages: dplyr, ggplot2, xtable, functional)
* LaTeX (packages: datetime, fancyhdr, parskip, mathpazo, eulervm)

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
   `uncompressed`, `checkpoint`, `log`, `temp` or `other`)
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
in `fs-cost.map`. Note also that, for shared filesystems, it may be
worth filtering the `mpistat` data before classifying and/or aggregating
it; for example, by group.

Aggregated data can be mapped to PI by running it through `map-to-pi.sh`.
This script strips out any `user` records and replaces `group` records
with an appropriate `pi` record, using `gid-pi_uid.map`:

    zcat foo.dat.gz | ./aggregate-mpistat.sh | ./map-to-pi.sh

Note that this will not aggregate records by PI, it's strictly a mapping
operation. It defines a third organisational tag, `pi`, in the
aggregated output, where the organisation ID (third field) is the PI's
Unix user ID (per the mapping definition).

An additional mapping step can then be applied, which maps Unix user and
group IDs to their human readable counterparts; defined in `uid-user.map`
and `gid-group.map`, respectively. Note that a full join (in relational
algebra terms) is performed, so any records in the aggregated data
without a corresponding mapping will be lost; this can be beneficial
when looking at subsets of data. The mapping can be performed using the
`map-to-readable.sh` convenience script, which reads from `stdin` and
writes to `stdout`:

    cat lustre01-logs lustre01-logs-by_pi | ./map-to-readable.sh

Final aggregation/merging can be done using the `merge-aggregates.sh`
script:

    ./merge-aggregates.sh lustre01-all lustre01-cram lustre01-cram-by_pi

This will produce the output data that drives report generation.

Once the completely aggregated output has been produced, it can be run
through `generate-assets.R`, which will generate the tables, plots and
LaTeX source for the final report. The script takes three positional
arguments:

1. The path to the aggregated output.
2. The output directory for the report assets.
3. The data aggregation date (optional; defaults to today).

It will produce assets named `OUTPUT_DIR/FILESYSTEM-ORG_TAG.EXT` -- for
example, `/path/to/assets/lustre-pi.pdf` for the plot of Lustre data
usage by PI -- as well as `OUTPUT_DIR/report.tex`, which makes use of
these. (Note that the PI assets are unconstrained, but the group
and user assets will be limited to the top 10, by cost.)

The final report can be compiled using LaTeX. For example:

    cd /path/to/assets
    latexmk -pdf report.tex

## tl;dr

To compile the aggregated data (i.e., running the complete pipeline as
outlined above) into the final report, a convenience script is available
that will submit the pipeline to an LSF cluster:

    submit-pipeline.sh [--output FILENAME]
                       [--work-dir DIRECTORY]
                       [--bootstrap SCRIPT]
                       [--base TIME]
                       [--email ADDRESS]
                       [--lustre INPUT_DATA]
                       [--nfs INPUT_DATA]
                       [--warehouse INPUT_DATA]
                       [--irods INPUT_DATA]
                       [--lsf-STEP OPTION...]

Taking the following options:

Option                      | Behaviour
--------------------------- | ------------------------------------------
`--output FILENAME`         | Write the report to `FILENAME`, defaulting to `$(pwd)/report.pdf`
`--work-dir DIRECTORY`      | Use `DIRECTORY` for the pipeline's working files, defaulting to the current working directory
`--bootstrap SCRIPT`        | Source `SCRIPT` at the beginning of each job in the pipeline
`--base TIME`               | Set the base time to `TIME`, defaulting to the current system time
`--mail ADDRESS`            | E-mail address to which the completed report is sent; can be specified multiple times
`--lustre INPUT_DATA`       | `INPUT_DATA` for a Lustre filesytem; can be specified multiple times
`--nfs INPUT_DATA`          | `INPUT_DATA` for a NFS filesytem; can be specified multiple times
`--warehouse INPUT_DATA`    | `INPUT_DATA` for a warehouse filesytem; can be specified multiple times
`--irods INPUT_DATA`        | `INPUT_DATA` for an iRODS filesytem; can be specified multiple times
`--lsf-STEP OPTION...`      | Provide LSF `OPTION`s to the `STEP` job submission; can be specified multiple times

Note that at least one `--lustre`, `--nfs`, `--warehouse` or `--irods`
option must be specified with its `INPUT_DATA` readable from the cluster
nodes. In addition to the final report, its source aggregated data will
be compressed alongside it, with the extension `.dat.gz`. Otherwise, the
working directory and its contents will be deleted upon successful
completion; as such, do not set the output or any logging to be written
inside the working directory.

A number of environment variables can also be set to constrain how
aggressively the pipeline utilises the LSF cluster:

Environment Variable | Default      | Behaviour
-------------------- | ------------ | ----------------------------------
`CHUNK_SIZE`         | 536870912    | Approximate input data chunk size (bytes)
`MAX_CHUNKS`         | 20           | Maximum number of input data chunks
`CONCURRENT`         | `MAX_CHUNKS` | Number of chunks to process concurrently

Note that `CHUNK_SIZE` ought to decrease as `MAX_CHUNKS` increases,
otherwise the constraints won't balance each other; `MAX_CHUNKS` should
not exceed your LSF `MAX_JOB_ARRAY_SIZE` value. Lowering `CHUNK_SIZE`
should produce output faster, but your cluster administrators and fellow
users won't be happy with you!

The following `STEP`s make up the pipeline and are run in the following
order:

* `split` Splits and distributes the decompressed input data for each
  filesystem type into approximately even sized chunks, based on the
  aforementioned constraints set by environment variables. This step
  attempts to maintain uniformity across the chunks, in terms of size,
  to maintain efficient parallelism. However, note that very small input
  data will cause the algorithm to degrade, as data is split into exact
  records (i.e., at EOL). Please ensure your working directory can
  contain the decompressed input data for the duration of the pipeline.
