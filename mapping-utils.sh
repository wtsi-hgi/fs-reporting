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
  # Filter tab-delimited data by value on a specific field; return a
  # non-zero exit code if nothing is output
  local value="$1"
  local field="${2-2}"  # Default 2: Organisational tag in aggregated data

  awk -F"${TAB}" -v VALUE="${value}" -v FIELD="${field}" '
    BEGIN { output = 0 }
    $FIELD == VALUE { output = 1; print }
    END { if (!output) exit 1 }
  '
}

map_to() {
  # Map aggregated input to specified mapping
  local mapping="$1"

  sort -t"${TAB}" -k3b,3 \
  | join -t"${TAB}" -13 -21 \
         -o "1.1 1.2 2.2 1.4 1.5 1.6 1.7" \
         - <(get_mapping "${mapping}")
}
