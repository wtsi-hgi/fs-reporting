#!/usr/bin/env bash

set -ef -o pipefail

groups=$@

module purge
module add hgi/ldapvi/latest

if [[ ! -r ~/.ldapvirc ]]; then
    >&2 echo "~/.ldapvirc not readable" 
    exit 1
fi

declare -a parsedGroups
for group in "$@"; do
    parsedGroups[${#parsedGroups[@]}]=$(
        echo -n "\"${group}\":"
        echo -n $(ldapvi --out "(&(cn=${group})(objectClass=posixGroup))" | grep -e ^owner | grep -Po '(?<=uid=)([^,]*)' | jq -R . | jq -s '.')
        echo -n ""
    )
done
echo "{$(IFS=, ; echo "${parsedGroups[*]}")}" | jq "."
