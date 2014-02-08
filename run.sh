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

# Exit codes.
PARSE_ERROR=1
NO_CGMINER=2
CGMINER_NO_PARAM=3
SUCCESS=42

# Warnings.
NO_START="NULL"

# For starting cgminer.
export DISPLAY=:0
export GPU_MAX_ALLOC_PERCENT=100
export GPU_USE_SYNC_OBJECTS=1

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
    REGEX='^([A-Za-z_]+) ([0-9|a-zA-Z/:\+.]+)'

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
                cgminer_api_port ) CGMINER_API_PORT=$val;;
                cgminer_url ) CGMINER_URL=$val;;
                cgminer_user ) CGMINER_USER=$val;;
                cgminer_pass ) CGMINER_PASS=$val;;
                tc_timeout ) TC_TIMEOUT=$val;;
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

# Get the hash rate of the zeroth GPU, for checking results.
function getHashRate
{
    MHASH_REGEX='\"MHS av\":([0-9]+.[0-9][0-9])'
    response=`echo "{ \"command\":\"gpu\", \"parameter\":\"0\" }" | nc 127.0.0.1 $CGMINER_API_PORT`

    mhash=0
    [[ $response =~ $MHASH_REGEX ]] && \
        mhash=${BASH_REMATCH[1]}

    if (( $(echo "$mhash == 0" | bc -l) )); then
        echo $NO_START
    else
        echo $mhash
    fi
}

# Start cgminer for tweaking settings.
# $1 - Setting name
# $2 - Setting value
function startCgMiner
{
    case $1 in
        tc ) setting_key="thread-concurrency";;
        eng ) setting_key="gpu-engine";;
        mem ) setting_key="gpu-memclock";;
        * ) break;;
    esac
    setting_val=$2

    if [[ -z $setting_key || -z $setting_val ]]; then
        echo "Error: no settings supplied for cgminer to tweak!";
        exit $CGMINER_NO_PARAM
    fi

    CGMINER_CONNECTION="-o $CGMINER_URL -O $CGMINER_USER:$CGMINER_PASS"

    # Start the cgminer instance.
    nohup $CGMINER_DIR/./cgminer --scrypt $CGMINER_CONNECTION --$setting_key $setting_val --api-listen >/dev/null 2>/dev/null &
}

function getCurrentTime
{
    current=$(date +%s)
    echo $current
}

function getTargetTime
{
    current=$(getCurrentTime)
    target=$(($current+$TC_TIMEOUT))
    echo $target
}

function tuneThreadConcurrency
{
    minTC=$(getDatum thread_concurrency min)
    maxTC=$(getDatum thread_concurrency max)
    stepTC=$(getDatum thread_concurrency step)
    currentTC=$minTC
    lastTC=0

    while sleep 1; do
        echo -n "Attempting to start with TC $currentTC"
        startCgMiner tc $currentTC
        active=0

        targetTime=$(getTargetTime)
        while sleep 1; do
            echo -n "."
            if [[ $(getCurrentTime) -lt $targetTime ]]; then
                rate=$(getHashRate)
                if [[ $rate != $NO_START ]]; then
                    echo " [OK]"

                    # Kill the cgminer process, and wait until it exits.
                    kill $! >/dev/null 2>&1
                    while pgrep cgminer >/dev/null; do
                        sleep 1
                    done
                    active=1

                    # Break from the sleep 1 while loop.
                    break;
                fi
            else
                break;
            fi
        done

        if [[ $active -eq 0 ]]; then
            break;
        fi
        lastTC=$currentTC

        currentTC=$((currentTC+$stepTC))
        if [[ $lastTC -ge $maxTC ]]; then
            break;
        fi
    done

    # Tidy up, just in case.
    killall cgminer

    echo
    echo "TC: $lastTC"
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
    dateTime=`date +'%T on %x'`
    echo -e "Commencing configuration at $dateTime.\n"

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
        tuneThreadConcurrency
    fi
}

# Execute the main function.
main

# Tidy up dir on exit.
mv *.bin data/bin_files/

# Great success.
exit $SUCCESS
