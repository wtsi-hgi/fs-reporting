# Sanger/Human Genetics Programme Specific Scripts

A convenience script that submits the entire pipeline to the cluster,
with Sanger-specific mappings and environment setup, is available as
`build.sh`. It takes any number of command line arguments, all of which
represent the users/e-mail addresses to which the final report should be
sent. (If no arguments are provided, then the current user will be
used.) A copy of the report will also exist in the `reports`
subdirectory of this repository.

Internally, it uses the following:

## `create-mappings.sh`

Create PI, group and user mapping files for the Human Genetics
Programme, taking an optional `--force` parameter to overwrite any
mappings that already exist.

Note that this script relies on special fields set in LDAP records,
which may not be available or up-to-date, so its output might need
manual curation.

## `bootstrap.sh`

Set up the execution environment such that everything required to
produce the final output is available. This includes:

* Build tools and dependencies (including a localised R library)
* Environment variables
