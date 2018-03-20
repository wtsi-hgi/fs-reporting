# Get filesystem cost per terabyte year
# Christopher Harrison <ch12@sanger.ac.uk>

declare -A _FS_COSTS=(
  [lustre]="150"

  # TODO Find costs
  # [nfs]=...
  # [warehouse]=...
  # [irods]=...
)

get_fs_cost() {
  local fs_type="$1"

  if ! [[ ${_FS_COSTS["${fs_type}"]+_} ]]; then
    >&2 echo "No costing data for \"${fs_type}\" filesystems"
    exit 1
  fi

  echo "${_FS_COSTS["${fs_type}"]}"
}
