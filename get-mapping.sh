# Strip comments from mapping file and sort by column
# Christopher Harrison <ch12@sanger.ac.uk>

TAB="	"

get_mapping() {
  local mapping_file="$1"
  local sort_column="${2-1}"

  sed '/^\s*#/d;/^\s*$/d;s/\s*#.*//' "${mapping_file}" \
  | sort -t"${TAB}" -k"${sort_column}b,${sort_column}"
}
