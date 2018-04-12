# Get filesystem cost per terabyte year
# Christopher Harrison <ch12@sanger.ac.uk>

# Average cost across filesystem types is approximately £75/TiB Year;
# FastNFS is slightly more expensive than Lustre and iRODS is multiplied
# by the approximate average number of replicas (i.e., 2)
declare -A _FS_COSTS=(
  [lustre]="75"
  [nfs]="75"
  [warehouse]="75"
  [irods]="150"
)

get_fs_cost() {
  local fs_type="$1"

  if ! [[ ${_FS_COSTS["${fs_type}"]+_} ]]; then
    >&2 echo "No costing data for \"${fs_type}\" filesystems"
    exit 1
  fi

  echo "${_FS_COSTS["${fs_type}"]}"
}
