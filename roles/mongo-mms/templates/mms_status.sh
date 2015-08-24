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
APP_ID="mms"
BASE_PORT="8080"
BASE_SSL_PORT="8443"
LOG_PATH="/var/log/mongodb"
SYSCONFIG="${APP_DIR}/conf/mms.conf"
JAVA_HOME="${APP_DIR}/jdk"


# Number of MMS instances to bring up
INSTANCE_COUNT=1

#
# Determines which instance(s) is/are running.
#
status() {
    echo "Check MMS status"
    local idx="0"
    local final_exit_code=0
    while [ $idx -lt ${INSTANCE_COUNT} ]; do
        local pid_file="${APP_DIR}/tmp/${APP_ID}-${idx}.pid"
        local pid=$( mms_pid $idx )
        echo -n "   Probing instance $idx..."
        if [ "${pid}" == "x" ]; then
            failure
            echo
            echo "     PID file not found: ${pid_file}"
            final_exit_code=3
        else
            local running=$( is_mms_running $pid )
            if [[ $running == "no" ]]; then
                failure
                echo
                echo "      The instance is not running."
                final_exit_code=1
            else
                success
                echo
                echo "      The instance is running."
            fi
        fi
        idx=$[ $idx+1 ]
    done

    exit $final_exit_code
}

mms_pid() {
    local instance=$1
    local pid_file="${APP_DIR}/tmp/${APP_ID}-${instance}.pid"
    if [[ ! -f ${pid_file} ]]; then
        echo "x"
    else
        cat ${pid_file}
    fi
}

is_mms_running() {
    local pid=$1
    ps -e -o pid,command | grep "$APP_NAME" | awk '{print $1}' | grep -q "^${pid}$"
    if [[ $? == 0 ]]; then
        echo -n yes
    else
        echo -n no
    fi
}
