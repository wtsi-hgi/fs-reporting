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
  * Log files (`*.{log,stdout,stderr,o,e}`)
  * Temporary (`*{tmp,temp}*`)
  * Other (everything else)

Interested in:

* Total inodes
* Total size
* Total cost, relative to `ctime`

## Usage

Aggregate `mpistat` data using `aggregate-mpistat.sh`, taking
uncompressed data from `stdin`:

    zcat lustre01.dat.gz lustre02.dat.gz | ./aggregate-mpistat.sh

The aggregation is output to `stdout` as tab-delimited data with the
following fields:

1. Filesystem type
2. Organisational tag ("group:GID" or "user:UID")
3. Filetype tag ("all", "cram", "bam", "index", "compressed",
   "uncompressed", "checkpoints", "logs", "temp" or "other")
4. inodes
5. Size (bytes)
6. Cost since last changed (GBP)

The aggregation script takes two optional, positional arguments, which
are necessary to calculate the `ctime` cost:

1. The Unix time from which to base cost calculation, defaulting to the
   current system time.
2. The filesystem type from which to base the cost calculation,
   defaulting to `lustre`.

The filesystem types, that define cost per terabyte year, are enumerated
in `get-fs-cost.sh`.
