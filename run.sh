#!/bin/bash
#
# cgconfigure
#
# run.sh
#
# This script will attempt to automatically configure the parameters
# used by cgminer, in a vague attempt to make something a bit more
# palatable than just repeatedly editing and rebooting.
#

# $0        - file name
# $1        - value
function saveValue
{
    DATA_DIR="data"
    filePath=$DATA_DIR/$1
    touch $filePath
    echo $2 > $filePath
}

# $0        - file name
# return    - value
function loadValue
{
    filePath=$0/$1
    value=$(head -n 1 $filePath)
    return $value
}

# Parse the parameters from the options file, storing their values
# for use at various points throughout the program.
function parseOptions
{
    OPTIONS_FILE="options.conf"
    REGEX='^([A-Za-z_]+) ([0-9])'
    DEFAULT_KEY=""

    while read line
    do
        key=$DEFAULT_KEY
        if [[ ( $line =~ $REGEX ) ]]; then
            key=${BASH_REMATCH[1]}
            val=${BASH_REMATCH[2]}
        fi

        if [[ $key != $DEFAULT_KEY ]]; then
            case $key in
                hide_startup_message ) NO_STARTUP_MSG=$val;;
                * ) break;;
            esac
        fi
    done < $OPTIONS_FILE
}


function main
{
    # Read the options file into memory.
    parseOptions

    continue=false
    if [[ -z $NO_STARTUP_MSG || $NO_STARTUP_MSG == "0" ]]; then
        echo "Welcome to cgconfigure."
        echo -e "[Please edit params.conf to tweak basic parameter selection.]\n"

        echo "Start configuration now?"

        select yn in "Yes" "No"; do
            case $yn in
                Yes ) continue=true; break;;
                No ) exit;;
            esac
        done
    else
        continue=true
    fi


    if [ continue ]; then
        echo "ASDIOHASDOIJ"
    fi
}

# Execute the main function.
main
