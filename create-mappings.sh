#!/usr/bin/env bash

# Create Sanger-Specific Mappings
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

create_pi_mapping() {
  # Create group to PI user ID mapping from LDAP and heuristics
  # TODO
  true
}

create_user_mapping() {
  # Create user mapping from the passwd database
  getent passwd | awk 'BEGIN { FS = ":"; OFS = "\t" } { print $4, $1, $5 }'
}

create_group_mapping() {
  # Create group mapping from the group database
  getent group | awk 'BEGIN { FS = ":"; OFS = "\t" } { print $3, $1 }'
}

main() {
  local -i force=0
  while (( $# )); do
    if [[ "$1" == "--force" ]]; then
      force=1
    fi
  done

  local pi_map="${WORK_DIR}/gid-pi_uid.map"
  local user_map="${WORK_DIR}/uid-user.map"
  local group_map="${WORK_DIR}/gid-group.map"

  # Warn the user if mappings already exist without --force supplied
  if ! (( force )); then
    if [[ -e "${pi_map}" ]] || [[ -e "${user_map}" ]] || [[ -e "${group_map}" ]]; then
      >&2 echo "Some or all mappings already exist. Either back them up, or rerun this with the --force option."
      exit 1
    fi
  fi

  # Delete old mappings
  rm -f "${pi_map}" "${user_map}" "${group_map}"

  create_pi_mapping    > "${pi_map}"
  create_user_mapping  > "${user_map}"
  create_group_mapping > "${group_map}"
}

main "$@"
