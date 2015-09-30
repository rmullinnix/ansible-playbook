#!/bin/bash

KILL_PORT=8640

#
# Get status of instance running on the server.
#
status() {
    echo -n "Check Backup Daemon status"
    if `is_instance_running`; then
        success
        echo
        echo "   Backup Daemon Process is running."
    else
        failure
        echo
        echo "   Backup Daemon is not running."
        exit 1
    fi
}

is_instance_running() {
    netstat -nl | grep :${KILL_PORT} > /dev/null 2>&1
}
