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
