#!/bin/bash
set -e
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
    key="$1"

    #echo "KEY: $key"

    case $key in
        -p|--userpattern) # Specify a username to search for. Wildcard '*' is allowed.
            USERPATTERN="^${2//\*/.*}" # Replace all instances of '*' with '.*' for grep regex.
                                        # http://tldp.org/LDP/abs/html/string-manipulation.html
            shift # past argument
            ;;
        -s|--since) # See --since in last's man page.
            DATESINCE="$2"
            shift # past argument
            ;;
        -u|--until) # See --until in last's man page.
            DATEUNTIL="$2"
            shift # past argument
            ;;
        -b|--begin) # Specify the beginning of a numerical range for usernames (compared to last characters of username)
            USERSTART="$2"
            shift # past argument
            ;;
        -e|--end) # Specify the ending of a numerical range for username (compared to last characters of username)
            USEREND="$2"
            shift # past argument
            ;;
        -f|--file) # Specify a file for `last` (i.e. "/var/log/wtmp.1")
            LASTFILE="$2"
            shift # past argument
            ;;
        -t|--timestamp) # Display users who were logged in at a given time. See `man last`
            TIMESTAMP="$2"
            shift
            ;;
        -m|--mapping)           # Path to a mapping file which will be used to display an alternate string instead
            MAPPING="$2"        # of the username.
            shift
            ;;
        -a|--alphabetical) # Sort output alphabetically, or not. (Summary view is alphabetical by default)
            ALPHABETICAL=1
            ;;
        -n|--nologin) # Show users who have *not* logged in
            NOLOGIN=1
            ;;
        --summary) # Display a summary output with useful information.
            SUMMARY=1
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

if [ X$USERPATTERN = X ]; then
    echo "No user pattern specified, defaulting to listing 'all' users."
    USERPATTERN='.*'
fi

if [ ! X$USERSTART = X -o ! X$USEREND = X ]; then
    if ! is_int $USERSTART; then
        echo "One of your 'start' or 'end' is not an integer."
        exit 1
    fi

    if ! is_int $USEREND; then
        echo "One of your 'start' or 'end' is not an integer."
        exit 1
    fi

    # Check to see if lengths of variables are the same.
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

if [ X"$LASTFILE" = X ]; then
    LASTCMD="last"
else
    if [ -e "$LASTFILE" ]; then # Should we also check if the file is readable..?
        LASTCMD="last -f \"$LASTFILE\""
    else
        echo "Error: \"$LASTFILE\" does not exist."
        exit 1
    fi
fi

if [ ! X$DATESINCE = X ]; then
    LASTCMD="$LASTCMD --since $DATESINCE"
fi

if [ ! X$DATEUNTIL = X ]; then
    LASTCMD="$LASTCMD --until $DATEUNTIL"
fi

LASTCMD="$LASTCMD -F | grep -w \"$USERPATTERN\""

if [ "$ALPHABETICAL" = 1 -o "$SUMMARY" = 1 ]; then
    LASTCMD="$LASTCMD | sort"
fi

echo "LASTCMD=$LASTCMD"

# Cross-platform 'replace newline' with sed: https://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed

OLDIFS=$IFS
IFS=$'\n'

lastoutput=$(eval $LASTCMD)
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

if [ "$NOLOGIN" = 1 ]; then
    # https://stackoverflow.com/questions/11165182/bash-difference-between-two-lists
    # Compares usernames in /etc/passwd to users that we saw in `last`, and displays items which appear
    # *only* in /etc/passwd (i.e. those who do not have a login entry).
    # lastlog | grep "Never logged in" | grep "$USERPATTERN" | awk '{print $1}'

    # We don't use lastlog so that we can compare against the filtered list we already have, instead of filtering again...
    output="$(comm -23 <(grep "$USERPATTERN" /etc/passwd | awk -F":" '{print $1}' | sort) <(echo "$output" | awk '{print $1}' | sort | uniq))"
    if [ ! X"$MAPPING" = X ]; then
        if [ -e "$MAPPING" ]; then
            for line in `cat "$MAPPING"`; do
                f_username=$(echo $line | awk -F":" '{print $1}')
                f_replacement=$(echo $line | awk -F": " '{print $2}')

                output="${output//$f_username/$f_replacement}"

            done
        fi
    fi
    echo "$output"
    exit
fi

if [ "$SUMMARY" = 1 ]; then
    last_output=$output
    FORMAT="%-14s %-14s %-14s"
    output=$(printf "$FORMAT" "USER" "LOGINS" "DURATION")$'\n'
    cur_duration=0
    num_logins=0
    cur_user=""
    for line in $last_output; do
        cur_user=$(echo $line | cut -f1 -d" ")
        login_date=$(echo $line | awk -F" " '{print $5,$6,$7,$8}')
        logout_date=$(echo $line | awk -F" " '{print $11,$12,$13,$14}')
        if [[ $(echo $logout_date | tr -d ' ')  == *in ]]; then
            logout_date=$(date +%s)
        else
            logout_date=$(date -u -d "$logout_date" +%s)
        fi
        login_date=$(date -u -d "$login_date" +%s)

        tmp_duration=$(echo "$logout_date - $login_date" | bc)

        if [ "$cur_user" = "$tmp_user" -o "$tmp_user" = "" ]; then
            cur_duration="$tmp_duration + $cur_duration"
            num_logins=$(expr $num_logins + 1)
        else
            output="$output$(printf $FORMAT "$tmp_user" "$num_logins" "$(date -u -d @$(echo $cur_duration | bc) +%T)")"$'\n'
            cur_duration=$tmp_duration
            num_logins=0
        fi
        tmp_user=$cur_user
    done

    #printf "$cur_user: $num_logins logins, total duration of $(date -u -d @$(echo $cur_duration | bc) +%T)\n"
    output="$output$(printf $FORMAT "$tmp_user" "$num_logins" "$(date -u -d @$(echo $cur_duration | bc) +%T)")"$'\n'
fi

if [ ! X"$MAPPING" = X ]; then
    if [ -e "$MAPPING" ]; then
        for line in `cat "$MAPPING"`; do
            f_username=$(echo $line | awk -F":" '{print $1}')
            f_replacement=$(echo $line | awk -F": " '{print $2}')

            output="${output//$f_username/$f_replacement}"

        done
    fi
fi
echo "$output"

IFS=$OLDIFS

