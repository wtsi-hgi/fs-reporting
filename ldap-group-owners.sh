#!/usr/bin/env bash

# Get LDAP group owners as JSON
# Colin Nolan <cn13@sanger.ac.uk>
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

get_owners() {
  # Get owners of group
  local group="$1"
  ldapsearch -xLLL -s base -b "cn=${group},ou=group,dc=sanger,dc=ac,dc=uk" owner \
  | awk 'BEGIN { FS = ": |[=,]" } $1 == "owner" { print $3 }'
}

main() {
  local -a groups=("$@")
  local -i delimit=0

  echo "{"

  for group in "${groups[@]}"; do
    (( delimit )) && echo ","

    echo "\"${group}\": ["
    get_owners "${group}" | sed 's/.*/"&"/' | paste -sd, -
    echo "]"

    delimit=1
  done

  echo "}"
}

main "$@"
