# Get LDAP group owners as JSON
# Colin Nolan <cn13@sanger.ac.uk>
# Christopher Harrison <ch12@sanger.ac.uk>

_surround() {
  # Surround lines from stdin
  local l="$1"
  local r="${2-$l}"
  sed "s/.*/${l}&${r}/"
}

_delimit() {
  # Comma-delimit lines from stdin
  paste -sd, -
}

_get_owners() {
  # Get owners of group
  local group="$1"
  ldapsearch -xLLL -s base -b "cn=${group},ou=group,dc=sanger,dc=ac,dc=uk" owner \
  | awk 'BEGIN { FS = ": |[=,]" } $1 == "owner" { print $3 }'
}

get_group_owners() {
  # JSONise lists of group members
  # FIXME This will return invalid JSON for non-existent groups
  local -a groups=("$@")

  for group in "${groups[@]}"; do
    echo -n "\"${group}\":"
    _get_owners "${group}" | _surround \" | _delimit | _surround \[ \]
  done | _delimit | _surround \{ \}
}
