# Student Activity

## Overview

`sa.sh` ("sa" == "Student Activity") is a script that wraps the `last` command
with some additional functionality and user-friendliness. Namely, it provides
filtering options for searching/reducing the output of the `last` command.

## Usage

`./sa.sh [-p USERPATTERN] [-s DATESINCE] [-u DATEUNTIL] [-b NUM] [-e NUM] [-f
FILE] [-m MAPPINGFILE] [-a] [-n] [--summary]`

Optional arguments:
* `--p|--userpattern USERPATTERN`: Specify a pattern to filter users against.
  `*` (asterisks) are wildcards.
* `-s|--since DATESINCE`: Show entries since `DATESINCE`. Terms like `yesterday`
  and `-1week` are valid. See `man last`, and/or `man date` for format
  specifics.
* `-u|--until DATEUNTIL`: Show entries before `DATEUNTIL`. Terms like
  `yesterday` and `-1week` are valid. See `man last`, and/or `man date` for
  format specifics.
* `-b|--begin NUM`: Filter usernames that are between a numerical range (i.e.
  `p000` through `p999`). Specifies the beginning of the range. Requires
  `-e|--end` option, and requires arguments to for both to be the same number of
  characters (e.g. '-b 005' and '-e 155')
* `-e|--end NUM`: Filter usernames that are between a numerical range (i.e.
  `p000` through `p999`). Specifies the end of the range. Requires `-b|--begin`
  option, and requires arguments to for both to be the same number of characters
  (e.g. '-b 005' and '-e 155')
* `-f|--file FILE`: Manually specify which file `last` should parse.
* `-m|--mapping FILE`: Path to a "mapping" file, which is used to replace
  non-friendly system usernames with friendly human names. See the Mapping
  section for more details.
* `-a|--alphabetical`: Sort the output alphabetically. This option is implied
  when using the `--summary` option.
* `-n|--nologin`: Display only users that have _not_ logged in.
* `--summary`: Display summarized output, showing number of logins and
  cumulative duration of sessions for each user.
  
## Mapping File

This file is used to provide a mapping of a friendly human name to a username
used on the system. It is a plain-text file, and each line should be formatted
as follows: `[system_name]: [friendly_name]`

Example:

```
spirotot: Fields, Aaron
u123: Jim
player4: Sam
```
