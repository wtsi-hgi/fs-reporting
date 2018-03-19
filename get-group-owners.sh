#!/usr/bin/env bash

# Get LDAP group owners as JSON
# Colin Nolan <cn13@sanger.ac.uk>
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

surround() {
  # Surround lines from stdin
  local l="$1"
  local r="${2-$l}"
  sed "s/.*/${l}&${r}/"
}

delimit() {
  # Comma-delimit lines from stdin
  paste -sd, -
}

get_owners() {
  # Get owners of group
  local group="$1"
  ldapsearch -xLLL -s base -b "cn=${group},ou=group,dc=sanger,dc=ac,dc=uk" owner \
  | awk 'BEGIN { FS = ": |[=,]" } $1 == "owner" { print $3 }'
}

main() {
  # JSONise lists of group members
  # FIXME This will return invalid JSON for non-existent groups
  local -a groups=("$@")

  for group in "${groups[@]}"; do
    echo -n "\"${group}\":"
    get_owners "${group}" | surround \" | delimit | surround \[ \]
  done | delimit | surround \{ \}
}

main "$@"
