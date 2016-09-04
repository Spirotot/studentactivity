# Student Activity

## Overview/Requirements

`sa.sh` ("sa" == "Student Activity") is a script that wraps the `last` command
with some additional functionality and user-friendliness. Namely, it provides
filtering options for searching/reducing the output of the `last` command.

This script was designed with these minimum requirements in mind:
* Show number of times a given user has logged in.
* Show the cumulative duration of a user's sessions.
* Ability to show who has not logged in.
* Filtering capabilities
    * Wildcards
    * Numerical sequences (i.e. u01 - u25)
    * By period/time (i.e. since August 20 until yesterday)

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

Example mapping output:

```
spirotot: Fields, Aaron
u123: Jim
player4: Sam
```

Example `sa.sh` output without mapping file:

```
>$ ./sa.sh -p spirotot --summary
USER           LOGINS         DURATION       LAST_LOGIN    
spirotot       118            07:30:07       Sun Sep  4 08:32:46 UTC 2016
```

Example `sa.sh` output with mapping file:

```
>$ ./sa.sh -p spirotot --summary --mapping map.txt
USER           LOGINS         DURATION       LAST_LOGIN    
Fields, Aaron       118            07:30:07       Sun Sep  4 08:32:46 UTC 2016
```

## Known Bugs
* I don't think the cumulative duration is always calculated correctly when
  using the `--summary` option.
* The `--summary` option currently does not print the range of dates for which
  it is displaying output. This can be confusing when using in conjunction with
  the `--file` flag, as the `LAST_LOGIN` column will *not* show the user's
  actual last login, but instead the last login contained in the wtmp file
  specified.

## Future Directions
* Add option to automatically parse all `wtmp` files in `/var/log`, although
  this could be very slow.
* Add some kind of chart/graph to show login/logout dates/times/durations.
* Add "groups" feature, where an instructor can specify which students belong to
  him (in a fashion similar to the mapping file), and all other students will be
  filtered out.
* This would be a totally different tool/script, but related: it would be
  interesting to create/configure a tool that will automatically log commands
  entered by a user. The `script/scriptreplay` tools come to mind, but it would
  be interesting to see if timestamps can be pulled from this for
  graphing/charting purposes.
