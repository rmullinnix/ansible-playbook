#!/bin/bash

#
# (C) Copyright 2013, MongoDB, Inc.
# chkconfig: 35 86 14
# description: A simple script to run MongoDB MMS server.
#

#
# Bail with an error message.
#
bail() {
    echo
    echo "ERROR: $1"
    echo "Exiting."
    exit 1
}

APP_DIR={{ inf_app_path}}/mongo/mms

. ${APP_DIR}/bin/init-functions


APP_NAME="mms-app"
APP_ENV="hosted"
APP_ID="bslurp"
BACKUP_BASE_PORT="{{ mms_backup_port }}"
BACKUP_BASE_SSL_PORT="{{ mms_backup_ssl_port }}"

# Number of MMS instances to bring up
INSTANCE_COUNT=1

#
# Determines which instance(s) is/are running.
#
status() {
    echo "Check Backup HTTP Server status"
    local idx="0"
    while [ $idx -lt ${INSTANCE_COUNT} ]; do
        local pid_file="${APP_DIR}/tmp/${APP_ID}-${idx}.pid"
        local pid=$( mms_pid $idx )
        echo -n "   Probing instance $idx..."
        if [ "${pid}" == "x" ]; then
            failure
            echo
            echo "     PID file not found: ${pid_file}"
            exit 3
        else
            local running=$( is_mms_running $pid )
            if [[ $running == "no" ]]; then
                failure
                echo
                echo "      The instance is not running."
                exit 1
            else
                success
                echo
                echo "      The instance is running."
            fi
        fi
        idx=$[ $idx+1 ]
    done
}

is_mms_web_server_running() {
    local port=$1
    netstat -nl | grep :${port} > /dev/null 2>&1
    if [[ $? == 0 ]]; then
        echo -n yes
    else
        echo -n no
    fi
}
