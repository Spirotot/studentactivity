#!/bin/bash

# Exit on error.
set -e

# This function checks to see if the arg passed is an integer.
is_int () {
    # https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
    if [ "$1" -eq "$1" ] 2>/dev/null; then
        return 0 # It is an int
    else
        return 1 # not a number
    fi
}

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]
do
    case "$1" in
        -p|--userpattern)               # Specify a username to search for. Wildcard '*' is allowed.
            USERPATTERN="^${2//\*/.*}"  # Replace all instances of '*' with '.*' for grep regex.
                                        # http://tldp.org/LDP/abs/html/string-manipulation.html
            shift
            ;;
        -s|--since)                     # See --since in last's man page. If last doesn't have --since,
            DATESINCE="$2"              # then this will default to a slow, hacky filtering mechanism using
            shift                       # Bash...
            ;;
        -u|--until)                     # See --until in last's man page. If last doesn't have --until,
            DATEUNTIL="$2"              # then this will default to a slow, hacky filtering mechanism using
            shift                       # Bash...
            ;;
        -b|--begin)                     # Specify the beginning of a numerical range for usernames
            USERSTART="$2"              # (compared to last characters of username). NOTE: the length of your
            shift                       # -b arg should match your -e arg (i.e. -b 01 -e 19)
            ;;
        -e|--end)                       # Specify the ending of a numerical range for username
            USEREND="$2"                # (compared to last characters of username). NOTE: the length of your
            shift                       # -e arg should match your -e arg (i.e. -b 007 -e 100)
            ;;
        -f|--file)                      # Specify a file for `last` (i.e. "/var/log/wtmp.1")
            LASTFILE="$2"
            shift
            ;;
        -t|--timestamp)                 # Display users who were logged in at a given time. See `man last`
            TIMESTAMP="$2"              # NOT YET IMPLEMENTED
            shift
            ;;
        -m|--mapping)                   # Path to a mapping file which will be used to display an alternate
            MAPPING="$2"                # string instead of the username in the output.
            shift
            ;;
        -a|--alphabetical)              # Sort output alphabetically. (Summary view is alphabetical
            ALPHABETICAL=1              # by default)
            ;;
        -n|--nologin)                   # Show users who have *not* logged in
            NOLOGIN=1
            ;;
        --summary)                      # Display a summary output, showing number of logins and duration for
            SUMMARY=1                   # each user.
            ;;
        *)
            echo "Unknown option: $1: $2"   # unknown option
            ;;
    esac

    shift # past argument or value
done

#echo "USERPATTERN=$USERPATTERN"
#echo "DATESINCE=$DATESINCE"
#echo "DATEUNTIL=$DATEUNTIL"
#echo "USERSTART=$USERSTART"
#echo "USEREND=$USEREND"
#echo "LASTFILE=$LASTFILE"
#echo "ALPHABETICAL=$ALPHABETICAL"
#echo "SUMMARY=$SUMMARY"
#echo "NOLOGIN=$NOLOGIN"
#echo "TIMESTAMP=$TIMESTAMP"

# Some sanity checking...
if [ ! X$USERSTART = X -o ! X$USEREND = X ]; then
    if ! is_int $USERSTART; then
        echo "One of your 'start' or 'end' is not an integer."
        exit 1
    fi

    if ! is_int $USEREND; then
        echo "One of your 'start' or 'end' is not an integer."
        exit 1
    fi

    # Check to see if lengths of variables are the same. If they're not, things get annoying.
    if [ ! ${#USERSTART} = ${#USEREND} ]; then
        echo "Length of 'start' and 'end' differ, or you did not provide a value for one of the arguments."
        exit 1
    fi

    if [ $USERSTART -gt $USEREND ]; then
        echo "'start' is greater than 'end'."
        exit 1
    fi
    SEQUENCELEN=${#USERSTART}
fi

#echo "SEQUENCELEN=$SEQUENCELEN"

# Did the user specify a wtmp file?
if [ X"$LASTFILE" = X ]; then
    LASTCMD="last"
else
    # Check to see if the specified last file exists.
    if [ -e "$LASTFILE" ]; then # Should we also check if the file is readable..?
        LASTCMD="last -f \"$LASTFILE\"" # If a wtmp file is specified, ammend the command used for last.
    else
        echo "Error: \"$LASTFILE\" does not exist."
        exit 1
    fi
fi

# The following if-statement will check to see if last supports the --since and --until arguments.
# If it does not, then it will set LAST_DATE_ACTION, which will be checked later to see if filtering
# should be done in Bash (since last doesn't support it).
LAST_DATE_ACTION=0
if [ ! X"$DATESINCE" = X -o ! X"$DATEUNTIL" = X ]; then
    LAST_DATE_ACTION=1

    # Need to unset -e, since this following last command might fail...
    set +e
    last --since > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        if [ ! X"$DATESINCE" = X ]; then
            LASTCMD="$LASTCMD --since $DATESINCE"
        fi

        if [ ! X"$DATEUNTIL" = X ]; then
            LASTCMD="$LASTCMD --until $DATEUNTIL"
        fi
    else
        LAST_DATE_ACTION=1
    fi

    # Re-set -e...
    set -e
fi

LASTCMD="$LASTCMD -F"

if [ ! X$USERPATTERN = X ]; then
    LASTCMD="$LASTCMD | grep -w \"$USERPATTERN\""
fi

LASTCMD="$LASTCMD | grep -v \"wtmp.* begins\" | grep -v reboot"

if [ "$ALPHABETICAL" = 1 -o "$SUMMARY" = 1 ]; then
    LASTCMD="$LASTCMD | sort"
fi

echo "LASTCMD=$LASTCMD"

# Make for loops use '\n' as the delimeter, instead of whitespace.
IFS=$'\n'

# Actually run the last command that we've built up.
lastoutput=$(eval $LASTCMD)

# If a 'beginning' and 'end' pattern is set, filter the users who aren't within the
# specified sequence...
if [ ! X$SEQUENCELEN = X ]; then
    for line in $lastoutput; do
        # var1=$(echo $STR | cut -f1 -d-)
        username=$(echo $line | cut -f1 -d" ")


        lastchars=${username:(-$SEQUENCELEN)}
        if is_int $lastchars; then
            if [ $lastchars -ge $USERSTART -a $lastchars -le $USEREND ]; then
                output=$output$line$'\n'
            fi
        fi
    done
else
    output=$lastoutput
fi

# As previously mentioned, if last doesn't support date filtering, but the user wants to do date filtering,
# we'll do date filtering... but it'll be in Bash, and therefore, it'll be slow.
if [ $LAST_DATE_ACTION -eq 1 ]; then
    lastoutput=$output
    output=""
    SINCE_SECONDS=0
    if [ ! X"$DATESINCE" = X ]; then
        SINCE_SECONDS=$(date -u -d "$DATESINCE 23:59:59" +%s)
    fi

    UNTIL_SECONDS=9999999999
    if [ ! X"$DATEUNTIL" = X ]; then
        UNTIL_SECONDS=$(date -u -d "$DATEUNTIL 00:00:00" +%s)
    fi

    for line in $lastoutput; do
        login_date=$(echo $line | awk -F" " '{print $5,$6,$7,$8}')
        logout_date=$(echo $line | awk -F" " '{print $11,$12,$13,$14}')
        if [[ $(echo $logout_date | tr -d ' ')  == *in ]]; then
            logout_date=$(date +%s)
        else
            logout_date=$(date -u -d "$logout_date" +%s)
        fi

        login_date=$(date -u -d "$login_date" +%s)
        if [ "$login_date" -ge "$SINCE_SECONDS" -o "$logout_date" -ge "$SINCE_SECONDS" ] && [ "$login_date" -le "$UNTIL_SECONDS" -o "$logout_date" -le "$UNTIL_SECONDS" ]; then
                output=$output$line$'\n'
        fi
    done
fi

# If what the user wants is to see who *hasn't* logged in, this is where the magic happens.
# The following code compares usernames in /etc/passwd to users that we saw in `last`, and
# displays items which appear *only* in /etc/passwd (i.e. those who do not have a login entry).
if [ "$NOLOGIN" = 1 ]; then
    # https://stackoverflow.com/questions/11165182/bash-difference-between-two-lists
    # lastlog | grep "Never logged in" | grep "$USERPATTERN" | awk '{print $1}'

    # We don't use the `lastlog` command so that we can just compare against the filtered list we already have
    # instead of filtering all that stuff again...
    output="$(comm -23 <(grep "$USERPATTERN" /etc/passwd | awk -F":" '{print $1}' | sort) <(echo "$output" | awk '{print $1}' | sort | uniq))"

    # If the user has specified a mapping file, we should use it before we display the output to the user...
    if [ ! X"$MAPPING" = X ]; then
        if [ -e "$MAPPING" ]; then
            for line in `cat "$MAPPING"`; do
                f_username=$(echo $line | awk -F":" '{print $1}')
                f_replacement=$(echo $line | awk -F": " '{print $2}')

                output="${output//$f_username/$f_replacement}"

            done
        fi
    fi

    # Display the output, which should contain only the users who haven't logged in for the given time period.
    # Note that --summary, if specified, is ignored... since there would be nothing to summarize, anyway!
    echo "$output"
    exit
fi

# If the user wants the summary view...
if [ "$SUMMARY" = 1 ]; then
    last_output=$output
    FORMAT="%-14s %-14s %-14s %-14s"
    output=$(printf "$FORMAT" "USER" "LOGINS" "DURATION" "LAST_LOGIN")$'\n'
    cur_duration=0
    num_logins=0
    last_login=0
    cur_user=""
    for line in $last_output; do
        cur_user=$(echo $line | cut -f1 -d" ")
        login_date=$(echo $line | awk -F" - " '{print $1}' | awk -F" " '{print $(NF-3),$(NF-2),$(NF-1),$NF}')

        if [[ $(echo $login_date | tr -d ' ') == *in ]]; then
            login_date=$(echo $line | awk -F" " '{print $(NF-6),$(NF-5),$(NF-4),$(NF-3)}')
        fi


        logout_date=$(echo $line | awk -F" - " '{print $2}' | awk -F" " '{print $2,$3,$4,$5}')
        #logout_date=$(echo $line | awk -F" " '{print $11,$12,$13,$14}')

        # Basically, convert all timestamps to seconds, for easy comparisons...
        if [[ $(echo $logout_date | tr -d ' ')  == *in ]] || [ X"$(echo $logout_date | tr -d ' ')" = X ]; then # If the user is still logged in,
            logout_date=$(date +%s)                             # default to 'now()'
        else
            logout_date=$(date -u -d "$logout_date" +%s)        # Else, use their logout date.
        fi
        login_date=$(date -u -d "$login_date" +%s)

        # Find the user's duration for this particular session.
        tmp_duration=$(echo "$logout_date - $login_date" | bc)

        num_logins=$(expr $num_logins + 1)
        if [ "$cur_user" = "$tmp_user" -o "$tmp_user" = "" ]; then
            cur_duration="$tmp_duration + $cur_duration"
        else
            output="$output$(printf $FORMAT "$tmp_user" "$num_logins" "$(date -u -d @$(echo $cur_duration | bc) +%T)" "$(date -u -d @$last_login)")"$'\n'
            cur_duration=$tmp_duration
            num_logins=0
            last_login=0
        fi
        tmp_user=$cur_user
        tmp_last_login=$(date -u -d @"$login_date" +%s)
        if [ $tmp_last_login -gt $last_login ]; then
            last_login=$tmp_last_login
        fi
    done
    num_logins=$(expr $num_logins + 1)
    output="$output$(printf $FORMAT "$cur_user" "$num_logins" "$(date -u -d @$(echo $cur_duration | bc) +%T)" "$(date -u -d @$tmp_last_login)")"$'\n'
fi

# If the user has specified a mapping file, we should use it before we display the output to the user...
if [ ! X"$MAPPING" = X ]; then
    if [ -e "$MAPPING" ]; then
        for line in `cat "$MAPPING"`; do
            f_username=$(echo $line | awk -F":" '{print $1}')
            f_replacement=$(echo $line | awk -F": " '{print $2}')

            output="${output//$f_username/$f_replacement}"

        done
    fi
fi

# Yee haw, we made it. Show the user what they wanted!
echo "$output"
