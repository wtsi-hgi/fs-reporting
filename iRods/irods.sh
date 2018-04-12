#!/usr/bin/env bash

# Retrieve iRods data
# Sarah Chacko <sc35@sanger.ac.uk>

set -euo pipefail

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"

usage() {
    cat <<- EOF
    usage: $PROGNAME options 
    
    Program retrieves storage data from iRods for the humgen zone.

    The data for each file (data object) is filename, collection name, create date (unix), size (bytes), owner

    The query for iRods is 
    
    iquest -z humgen "%s\t%s\t%s\t%s\t%s\t%s\t%s" no-distinct "SELECT DATA_ID, COLL_ID, COLL_NAME,DATA_NAME,min(DATA_CREATE_TIME),DATA_SIZE,DATA_OWNER_NAME"
    
    or  
    
    iquest -z humgen --no-page "%s|%s|%s|%s|%s" "SELECT COLL_NAME,DATA_NAME,min(DATA_CREATE_TIME),sum(DATA_SIZE),DATA_OWNER_NAME"


    data_create_time can be slightly different on different replicates which would give an extra row.

    It could take zone as an option but likely we don't have access to others anyway.

    OPTIONS:
       -t --test                run unit test to check the program
       -v --verbose             Verbose. You can specify more then one -v to have more verbose
       -x --debug               debug
       -h --help                show this help
    
    Examples

EOF
}

authenticate(){
  # For access to iRods
  echo "authenticate"
}

fetchData(){
  # One query at the moment but when there is more data maybe get collections first and then 
  # storage used per collection
  echo "fetch"
}

matchOwnersToGroups(){
  # owners in iRods mapped to groups in linux
  echo "match"
}

checkDuplicates(){
  # see that file doesn't have duplicate data_id and coll_id
  # Group the records if it does. This could be done better by using 
  # distinct with sums and counts in the iRods query but that's not 
  # very clear. Maybe move to that.
  echo "check"
}

formatData(){
  # can't be done easily in iRods but we need to concatenate path from filename and collection name 
  # and produce a tab separated file with non * rows left blank
  #   filepath (base64 encoded) *
  #   size (bytes) *
  #   user (uid) *
  #   group (gid) *
  #   atime (epoch)
  #   mtime (epoch)
  #   ctime (epoch) *
  #   protection mode
  #   inode ID
  #   number of hardlinks
  #   device ID
  local infile 
  local outfile
  #infile fields are collectionname, filename,  createtime, size, owner
  infile=$1
  outfile=irods-data.txt
  #outfile fields are path, size, user, group, atime, mtime, ctime, protection mode, inode, hardlinks, device
  awk -F"|" '{print $1 "/" $2 "\t" $4  "\t" $5 "\t" $5 "\t" 0  "\t" 0 "\t" $3  "\t" 0  "\t" 0 "\t" 0}' $infile > $outfile


}




main(){
  echo "here"
  formatData $1
}
main $1
