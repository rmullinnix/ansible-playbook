#!/bin/bash

#
# (C) Copyright 2013, MongoDB, Inc.
# chkconfig: 35 86 14
# description: A simple script to run MongoDB Backup HTTP server.
#

### BEGIN INIT INFO
# Provides:          mongodb-backup-http
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     3 5
# Default-Stop:      0 1 6
# Short-Description: MongoDB Management Service - Backup HTTP Server
# Description:       MongoDB Management Service - Backup HTTP Server
### END INIT INFO

#
# Bail with an error message.
#
bail() {
    echo
    echo "ERROR: $1"
    echo "Exiting."
    exit 1
}

APP_DIR={{ inf_app_path }}/mongo/mms

. ${APP_DIR}/bin/init-functions

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# CONFIGURATION NOTE:
# This script should be not be modified.
#
# The parameters below are defaults, which are overwritten
# by the editable configuration file at conf/mms.conf. Any
# configuration changes, such as to port or user, should
# be made in conf/mms.conf.
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

APP_NAME="mms-app"
APP_ENV="hosted"
APP_ID="bslurp"
APP_LOG_NAME="backup"
BACKUP_BASE_PORT={{ mms_backup_port }}
BACKUP_BASE_SSL_PORT={{ mms_backup_ssl_port }}
DEBUG_PORT=8091
LOG_PATH="{{ inf_log_path }}/mongo/mms"
LOG_NAME="backup-http-server"
SYSCONFIG="${APP_DIR}/conf/mms.conf"
JAVA_HOME="${APP_DIR}/jdk"

MMS_USER={{ mms_user }}

[[ -f "${SYSCONFIG}" ]] && . "${SYSCONFIG}"

[[ -z "${JAVA_HOME}" ]] && bail "JAVA_HOME not set."
[[ ! -d "${JAVA_HOME}" ]] && bail "JAVA_HOME set as ${JAVA_HOME} but does not exist."
[[ ! -x ${JAVA_HOME}/bin/${APP_NAME} ]] && bail "${JAVA_HOME}/bin/${APP_NAME} does not exist."

# Number of MMS instances to bring up
INSTANCE_COUNT=1

# Maximum number of seconds to wait for the process to start
PROCESS_PERIOD=10

# Maximum number of seconds to wait for a graceful server shutdown
GRACE_PERIOD=20

#
# Start the instance(s) running on the server.
#
start() {
    echo "Start Backup HTTP Server"
    local opts_array=(
        "-Duser.timezone=GMT"
        "-Dfile.encoding=UTF-8"
        "-Djava.net.preferIPv4Stack=true"
        "-Dsun.net.client.defaultReadTimeout=20000"
        "-Dsun.net.client.defaultConnectTimeout=10000"
        "-Dorg.eclipse.jetty.util.UrlEncoding.charset=UTF-8"
        "-Dorg.eclipse.jetty.server.Request.maxFormContentSize=4194304"
        "-Dserver-env=${APP_ENV}"
        "-Dapp-id=${APP_ID}"
        "-Dbase-port=${BACKUP_BASE_PORT}"
        "-DBSLURP.DEBUG.PORT=${DEBUG_PORT}"
        "-Dbase-ssl-port=${BACKUP_BASE_SSL_PORT}"
        "-Dapp-dir=${APP_DIR}"
        "-Dmms.extraPropFile=conf-mms.properties"
        "-Dxgen.webServerReuseAddress=true"
        "-Dmms.backup.enableBlockstoreSharding=false"
        "-Dmms.keyfile=${ENC_KEY_PATH}"
        "-XX:SurvivorRatio=32"
        "-XX:TargetSurvivorRatio=60"
        "-XX:MaxTenuringThreshold=15"
        "-XX:+UseConcMarkSweepGC"
        "-XX:+UseParNewGC"
        "-XX:+UseBiasedLocking"
        "-XX:MaxGCPauseMillis=10"
        "-XX:+CMSParallelRemarkEnabled"
        "-XX:-OmitStackTraceInFastThrow"
        "-classpath ${APP_DIR}/classes/mms.jar:${APP_DIR}/agent:${APP_DIR}/backup-agent-go:${APP_DIR}/data/unit:${APP_DIR}/conf/:${APP_DIR}/lib/*"
    )
    local jvm_opts=$( build_opts "${JAVA_MMS_BACKUP_OPTS}" opts_array[@] )
    local idx="0"
    while [[ $idx -lt ${INSTANCE_COUNT} ]]; do
        local log_file_base="${LOG_PATH}/${LOG_NAME}${idx}"
        local jvm_opts_instance="${jvm_opts} -Dlog_path=${log_file_base} -Dinstance-id=${idx}"
        local start_cmd="${JAVA_HOME}/bin/${APP_NAME} ${jvm_opts_instance} com.xgen.svc.core.ServerMain"
        local pid=$( mms_pid $idx )
        local running=$( is_mms_running $pid )

        if [[ $running == "yes" ]]; then
            echo -n "   Instance ${idx} is already running"
            failure
        else
            echo -n "   Instance ${idx} starting..."
            jvm "${start_cmd}" "${log_file_base}.log" "background"
            if wait_for_start ${idx} ${PROCESS_PERIOD}; then
                success
            else
                failure
                echo
                echo "   Check ${log_file_base}.log for errors"
                exit 1
            fi
        fi
        idx=$[ $idx+1 ]
        echo
    done
}

#
# Stop the instance(s) running on the server.
#
stop() {
    echo "Stop Backup HTTP Server"
    local idx="0"
    while [[ $idx -lt ${INSTANCE_COUNT} ]]; do
        echo -n "   Instance $idx stopping"
        local pid_file="${APP_DIR}/tmp/${APP_ID}-${idx}.pid"
        local pid=$( mms_pid $idx )
        if [[ "${pid}" == "x" ]]; then
            failure
            echo
            echo "      PID file not found: ${pid_file}"
        else
            local running=$( is_mms_running $pid )
            if [[ $running == "no" ]]; then
                failure
                echo
                echo "      Not running"
            else
                echo
                echo -n "      Trying graceful shutdown"
                kill $pid 1>/dev/null 2>&1
                local timer=0
                while [[ $timer -lt $GRACE_PERIOD && $running == "yes" ]]; do
                    echo -n "."
                    sleep 1
                    running=$( is_mms_running $pid )
                    timer=$[ $timer+1 ]
                done
                if [[ $running == "yes" ]]; then
                    failure
                    echo
                    echo -n "      Still alive, killing..."
                    kill -9 ${pid} 1>/dev/null 2>&1
                    success
                else
                    success
                fi
                echo

                if [[ -f ${pid_file} ]]; then
                    rm ${pid_file}
                fi
            fi
        fi
        idx=$[ $idx+1 ]
    done
}

#
# Restarts all instances.
#
restart() {
  stop
  start
}

#
# Alias for start.
#
run() {
  start
}

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

#
# Wait for the process and web server to start
#
wait_for_start() {
    local idx=$1
    local process_start_timeout=$2

    local counter=0
    while [ $counter -lt $process_start_timeout ]; do
        local pid=$( mms_pid $idx )
        local process_running=$( is_mms_running $pid )

        if [[ $process_running == "yes" ]]; then
            break
        fi

        sleep 5
        echo -n .
        let counter=counter+5
    done

    local counter=0
    local configured_base_port=$BACKUP_BASE_PORT
    if get_use_ssl; then
        let configured_base_port=$BASE_SSL_PORT
    fi
    while true; do
        local port=$(($configured_base_port + $idx))
        local process_running=$( is_mms_running $pid )
        local web_running=$( is_mms_web_server_running $port )

        if [[ $process_running == "no" ]]; then
            return 1
        fi

        if [[ $web_running == "yes" ]]; then
            return 0
        fi

        sleep 5
        echo -n .
        let counter=counter+5
    done
}

get_use_ssl() {
    grep '^mms.https.PEMKeyFile=.\+$' ${APP_DIR}/conf/conf-mms.properties > /dev/null 2>&1
    return $?
}

#
# Fire up the JVM.
#
jvm() {
    local jvm_cmd="$1"
    local log_file="$2"
    local background="$3"
    local daemon_cmd="/sbin/start_daemon"
    touch ${log_file}
    chown ${MMS_USER} ${log_file}
    daemon_cmd="${daemon_cmd} -f -u ${MMS_USER}"
    # If the output redirection is appended to the cmd variable, then nohup will
    # output an annoying message to the terminal about where it will send its output.
    # It only seems to be a problem on Ubuntu.
    if [[ "${background}" == "background" ]]; then
        ${daemon_cmd} nohup ${jvm_cmd} >> ${log_file} 2>&1 &
    else
        ${daemon_cmd} ${jvm_cmd} >> ${log_file} 2>&1
    fi
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

is_mms_web_server_running() {
    local port=$1
    netstat -nl | grep :${port} > /dev/null 2>&1
    if [[ $? == 0 ]]; then
        echo -n yes
    else
        echo -n no
    fi
}

build_opts() {
    local opts="$1"
    local arr="${!2}"
    for opt in "${arr[@]}"; do
        opts="${opts} ${opt}"
    done
    echo -n $opts
}

case "$1" in
    start|stop|restart|run|status)
        $1
        ;;
    *)
        echo $"Usage: $0 {start|stop|restart|run|status}"
        exit 2
        ;;
esac
