# Mapping utility functions
# Christopher Harrison <ch12@sanger.ac.uk>

TAB="	"

get_mapping() {
  # Strip comments from mapping file and sort by column
  local mapping_file="$1"
  local sort_column="${2-1}"

  sed '/^\s*#/d;/^\s*$/d;s/\s*#.*//' "${mapping_file}" \
  | sort -t"${TAB}" -k"${sort_column}b,${sort_column}"
}

filter_by() {
  # Filter input data by type
  local type="$1"
  awk -F"${TAB}" -v TYPE="${type}" '$2 == TYPE { print }'
}

map_to() {
  # Map input to specified mapping
  local mapping="$1"

  sort -t"${TAB}" -k3b,3 \
  | join -t"${TAB}" -13 -21 \
         -o "1.1 1.2 2.2 1.4 1.5 1.6 1.7" \
         - <(get_mapping "${mapping}")
}
