# Sanger-Specific Scripts

## `create-mappings.sh`

Create PI, group and user mapping files for the Human Genetics
Programme, taking an optional `--force` parameter to overwrite any
mappings that already exist.

Note that this script relies on special fields set in LDAP records,
which may not be available or up-to-date, so its output might need
manual curation.

## `bootstrap.sh`

Set up the execution environment such that everything required to
produce the final output is available.
