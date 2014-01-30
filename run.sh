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


function main
{
    echo "Welcome to cgconfigure."
    echo -e "[Please edit params.conf to tweak basic parameter selection.]\n"

    echo "Start configuration now?"

    continue=false
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) continue=true; break;;
            No ) exit;;
        esac
    done

    if [ continue ]; then
        echo "ASDIOHASDOIJ"
    fi
}

# Execute the main function.
main
