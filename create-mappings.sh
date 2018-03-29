#!/usr/bin/env bash

# Create Sanger Human Genetics Programme Mappings
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

TAB="	"

get_humgen_groups() {
  # Get the list of active humgen groups, with their PI's username and
  # Unix group ID, respectively, as tab-delimited values
  ldapsearch -xLLL -s one -b "ou=group,dc=sanger,dc=ac,dc=uk" "(sangerHumgenProjectActive=TRUE)" cn sangerProjectPI gidNumber \
  | awk '
    BEGIN {
      FS = ": |[,=]"
      OFS = "\t"

      group = pi = gid = ""
    }

    $1 == "cn"              { group = $2 }
    $1 == "sangerProjectPI" { pi = $3 }
    $1 == "gidNumber"       { gid = $2 }

    !$0 && group && pi && gid {
      print group, pi, gid
      group = pi = gid = ""
    }
  '
}

get_pis() {
  # Get the active humgen group PI Unix user IDs as tab-delimited values
  get_humgen_groups | cut -f2 | sort | uniq \
  | xargs -n1 -I{} ldapsearch -xLLL -s base -b "uid={},ou=people,dc=sanger,dc=ac,dc=uk" uid uidNumber \
  | awk '
    BEGIN {
      FS = ": "
      OFS = "\t"

      user = uid = ""
    }

    $1 == "uid"       { user = $2 }
    $1 == "uidNumber" { uid = $2 }

    !$0 && user && uid {
      print user, uid
      user = uid = ""
    }
  '
}

create_pi_mapping() {
  # Create group to PI user ID mapping from LDAP
  join -t"${TAB}" -12 -21 <(get_humgen_groups | sort -t"${TAB}" -k2,2) <(get_pis) \
  | awk 'BEGIN { FS = OFS = "\t" } { print $3, $4 "  # " $2 ": " $1 }'
}

create_user_mapping() {
  # Create all user mapping from LDAP
  ldapsearch -xLLL -s one -b "ou=people,dc=sanger,dc=ac,dc=uk" uid cn uidNumber \
  | awk '
    BEGIN {
      FS = ": "
      OFS = "\t"

      user = uid = name = ""
    }

    $1 == "uid"       { user = $2 }
    $1 == "uidNumber" { uid = $2 }
    $1 == "cn"        { name = gensub(/,? \[.+]$/, "", "g", $2) }

    !$0 && user && uid && name {
      print uid, user, name
      user = uid = name = ""
    }
  '
}

create_group_mapping() {
  # Create humgen group mapping from LDAP
  get_humgen_groups | awk 'BEGIN { FS = OFS = "\t" } { print $3, $1 }'
}

main() {
  local -i force=0
  while (( $# )); do
    if [[ "$1" == "--force" ]]; then
      force=1
    fi
    shift
  done

  local pi_map="${WORK_DIR}/gid-pi_uid.map"
  local user_map="${WORK_DIR}/uid-user.map"
  local group_map="${WORK_DIR}/gid-group.map"

  # Warn the user if mappings already exist without --force supplied
  if ! (( force )); then
    if [[ -e "${pi_map}" ]] || [[ -e "${user_map}" ]] || [[ -e "${group_map}" ]]; then
      >&2 echo "Some or all mappings already exist. Either back them up, or rerun this with --force"
      exit 1
    fi
  fi

  # Delete old mappings
  rm -f "${pi_map}" "${user_map}" "${group_map}"

  echo "Creating Human Genetics Programme group to PI mapping..."
  create_pi_mapping > "${pi_map}"

  echo "Creating user mapping..."
  create_user_mapping > "${user_map}"

  echo "Creating Human Genetics Programme group mapping..."
  create_group_mapping > "${group_map}"

  echo "All done :)"
}

main "$@"
