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

# Error codes.
PARSE_ERROR=1
SUCCESS=42

# $0 - file name
# $1 - value
function saveValue
{
    DATA_DIR="data"
    filePath=$DATA_DIR/$1
    touch $filePath
    echo $2 > $filePath
}

# $0 - file name
# return - value
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

# Parser for the config file.
# Will catch basic syntax errors and exit appropriately.
function parseParams
{
    PARAMS_FILE="params.conf"
    COMMENT_REGEX='^#'
    NAME_REGEX='^([A-Za-z_]+)$'
    OPTION_REGEX='([A-Za-z]+):[ ]*([0-9]*)$'
    OPEN_SCOPE_REGEX='^\{$'
    CLOSE_SCOPE_REGEX='^\}$'

    # Declare the data map.
    declare -A paramData

    currentParam=""
    inParam=false
    lineNum=0
    while read line
    do
        lineNum=$((lineNum+1))

        # Ignore comments.
        [[ $line =~ $COMMENT_REGEX ]] && \
            continue

        # Scope comprehension.
        [[ $line =~ $OPEN_SCOPE_REGEX ]] && \
            inParam=true
        [[ $line =~ $CLOSE_SCOPE_REGEX ]] && \
            inParam=false

        if [[ $line =~ $NAME_REGEX ]]; then
            if ! $inParam; then
                name=${BASH_REMATCH[1]}
                currentParam=$name
            else
                echo "Error in $PARAMS_FILE: Mismatched braces near line $lineNum!"
                exit $PARSE_ERROR
            fi
        elif [[ $line =~ $OPTION_REGEX ]]; then
            if $inParam; then
                key=${BASH_REMATCH[1]}
                val=${BASH_REMATCH[2]}

                mapKey=$currentParam:$key
                paramData[$mapKey]=$val
            else
                echo "Error in $PARAMS_FILE: Mismatched braces near line $lineNum!"
                exit $PARSE_ERROR
            fi
        fi
    done < $PARAMS_FILE
}

# $0 - param name
# $1 - param property (e.g. min/max)
function getDataParam
{
    
}

function main
{
    # Read the options file into memory.
    parseOptions

    # Parse the default parameters from the config file.
    parseParams

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
        echo "TODO: The actual program."
    fi
}

# Execute the main function.
main

exit $SUCCESS
