#!/usr/bin/env bash

# Get filesystem cost per terabyte year
# Christopher Harrison <ch12@sanger.ac.uk>

# n.b., This doesn't need to be any prettier :P

set -euo pipefail

main() {
  local fs_type="$1"

  case "${fs_type}" in
    "lustre")
      echo "150"
      ;;

    "nfs")
      # TODO Find cost...
      echo "??"
      ;;

    "warehouse")
      # TODO Find cost...
      echo "??"
      ;;

    "irods")
      # TODO Find cost...
      echo "??"
      ;;

    *)
      exit 1
      ;;
  esac
}

main "$@"
