#! /bin/bash

wait_for_event()
{
    # syntax: wait_for_event TIMEOUT SHELL-COMMAND
    #
    # Executes SHELL-COMMAND every second upto TIMEOUT seconds 
    # until it runs succesfully. E.g., to wait for file creation:
    #
    # wait_for_event 5 stat my-file

    timeout=$1
    shift

    counter_seconds=0
    while [[ $counter_seconds -lt $timeout ]]
    do
        if "$@" > /dev/null 2>&1
        then
            return 0
        else
            counter_seconds=$(($counter_seconds + 1))
            sleep 1
        fi
    done

    echo "Event did no succeed in $timeout s: $@"
    exit 1
}

