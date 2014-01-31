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
NO_CGMINER=2
SUCCESS=42

# Declare the data map for parsing parameters from the config file.
declare -A paramData

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
    REGEX='^([A-Za-z_]+) ([0-9|a-z/]+)'

    while read line
    do
        unset key
        if [[ ( $line =~ $REGEX ) ]]; then
            key=${BASH_REMATCH[1]}
            val=${BASH_REMATCH[2]}
        fi

        if [ -n $key ]; then
            case $key in
                hide_startup_message ) NO_STARTUP_MSG=$val;;
                cgminer_install_dir ) CGMINER_DIR=$val;;
                * ) ;;
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

                mapKey=$currentParam-$key
                paramData[$mapKey]=$val
            else
                echo "Error in $PARAMS_FILE: Mismatched braces near line $lineNum!"
                exit $PARSE_ERROR
            fi
        fi
    done < $PARAMS_FILE
}

# $1 - param name
# $2 - param property (e.g. min/max)
function getDatum
{
    assembledKey=$1-$2
    echo ${paramData[$assembledKey]}
}

function main
{
    # Read the options file into memory.
    parseOptions

    # At this point, we should have a cgminer install dir set.
    foundCgMiner=false
    if [[ -z $CGMINER_DIR ]]; then
        echo "Warning: no cgminer config file supplied! Will attempt to find automatically..."
    else
        # Check this is the install dir.
        if $($CGMINER_DIR/./cgminer --version >/dev/null 2>&1); then
            foundCgMiner=true
        else
            echo "Warning: cgminer install dir set incorrectly in config file."
        fi
    fi

    # Last ditch attempt to auto-find cgminer with type.
    if ! $foundCgMiner; then
        REGEX='is ([a-z/]+)'

        cgminerDir=$(type cgminer) && \
            [[ $cgminerDir =~ $REGEX ]] && \
                CGMINER_DIR=${BASH_REMATCH[1]}
    fi

    if [[ -z $CGMINER_DIR ]]; then
        echo "Error: Unable to locate cgminer. Please check config file and ensure it is installed."
        exit $NO_CGMINER
    fi

    echo "cgminer install found at $CGMINER_DIR"

    # Parse the default parameters from the config file.
    parseParams

    # TODO: REMOVE
    # Testing getDatum
    val=$(getDatum gpu_engine min)
    echo Value: $val

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

# Great success.
exit $SUCCESS
