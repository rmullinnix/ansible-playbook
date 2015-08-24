#!/bin/bash

#
# (C) Copyright 2013, MongoDB, Inc.
# chkconfig: 35 86 14
# description: A simple script to run MongoDB MMS server.
#

### BEGIN INIT INFO
# Provides:          mongodb-mms
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     3 5
# Default-Stop:      0 1 6
# Short-Description: MongoDB Management Service
# Description:       MongoDB Management Service
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

APP_DIR={{ inf_app_path}}/mongo/mms

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
APP_ID="mms"
BASE_PORT="{{ mms_port }}"
BASE_SSL_PORT="{{ mms_ssl_port }}"
LOG_PATH="{{ inf_log_path }}/mongo/mms"
SYSCONFIG="${APP_DIR}/conf/mms.conf"
JAVA_HOME="${APP_DIR}/jdk"

ME=$(whoami)
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
    ensureKey
    preFlightCheck
    migrate
    echo "Start MMS server"
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
        "-Dbase-port=${BASE_PORT}"
        "-Dbase-ssl-port=${BASE_SSL_PORT}"
        "-Dapp-dir=${APP_DIR}"
        "-Dxgen.webServerReuseAddress=true"
        "-Dmms.keyfile=${ENC_KEY_PATH}"
        "-XX:SurvivorRatio=12"
        "-XX:MaxTenuringThreshold=15"
        "-XX:CMSInitiatingOccupancyFraction=62"
        "-XX:+UseCMSInitiatingOccupancyOnly"
        "-XX:+UseConcMarkSweepGC"
        "-XX:+UseParNewGC"
        "-XX:+UseBiasedLocking"
        "-XX:+CMSParallelRemarkEnabled"
        "-XX:-OmitStackTraceInFastThrow"
        "-classpath ${APP_DIR}/classes/mms.jar:${APP_DIR}/agent:${APP_DIR}/agent/backup:${APP_DIR}/agent/monitoring:${APP_DIR}/agent/automation:${APP_DIR}/data/unit:${APP_DIR}/conf/:${APP_DIR}/lib/*"
    )
    local jvm_opts=$( build_opts "${JAVA_MMS_UI_OPTS}" opts_array[@] )
    local idx="0"
    while [[ $idx -lt ${INSTANCE_COUNT} ]]; do
        local log_file_base="${LOG_PATH}/${APP_ID}${idx}"
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

    "${APP_DIR}/bin/mongodb-backup-http" start
}

#
# Stop the instance(s) running on the server.
#
stop() {
    echo "Stop MMS server"
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

    "${APP_DIR}/bin/mongodb-backup-http" stop
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

    "${APP_DIR}/bin/mongodb-backup-http" status
    local exit_code=$?
    if [[ $exit_code -gt $final_exit_code ]]; then
        final_exit_code=$exit_code
    fi
    exit $final_exit_code
}

#
# Run preFlightCheck to look for configuration errors.
#
preFlightCheck() {
    # Hard-coded to the first instance. Nohting gets written in this
    # file, but logback requires it to exist.
    local log_file_base="${LOG_PATH}/${APP_ID}0"
    local opts_array=(
        "-Duser.timezone=GMT"
        "-Dfile.encoding=UTF-8"
        "-Dserver-env=${APP_ENV}"
        "-Dapp-id=${APP_ID}"
        "-Dmms.keyfile=${ENC_KEY_PATH}"
        "-Dlog_path=${log_file_base}"
        "-Xmx256m"
        "-XX:-OmitStackTraceInFastThrow"
        "-Dcore.preflight.class=com.xgen.svc.mms.MmsPreFlightCheck"
        "-classpath ${APP_DIR}/classes/mms.jar:${APP_DIR}/conf:${APP_DIR}/lib/*"
    )
    local jvm_opts=$( build_opts "" opts_array[@] )
    local start_cmd="${JAVA_HOME}/bin/${APP_NAME} ${jvm_opts} com.xgen.svc.core.PreFlightCheck"
    local daemon_cmd="/sbin/start_daemon"
    daemon_cmd="${daemon_cmd} -f -u ${MMS_USER}"

    ${daemon_cmd} ${start_cmd}
    if [[ $? != 0 ]]; then
        exit 1
    fi
    echo
}

#
# Run migrations.
#
migrate() {
    echo "Migrate MMS data"
    echo -n "   Running migrations..."
    local log_file_base="${LOG_PATH}/${APP_ID}-migration"
    local opts_array=(
        "-Duser.timezone=GMT"
        "-Dfile.encoding=UTF-8"
        "-Dmms.migrate=all"
        "-Dserver-env=${APP_ENV}"
        "-Dapp-id=${APP_ID}"
        "-Dmms.keyfile=${ENC_KEY_PATH}"
        "-Dlog_path=${log_file_base}"
        "-Xmx256m"
        "-XX:-OmitStackTraceInFastThrow"
        "-classpath ${APP_DIR}/classes/mms.jar:${APP_DIR}/conf:${APP_DIR}/lib/*"
    )
    local jvm_opts=$( build_opts "" opts_array[@] )
    local start_cmd="${JAVA_HOME}/bin/${APP_NAME} ${jvm_opts} com.xgen.svc.common.migration.MigrationRunner"
    jvm "${start_cmd}" "${log_file_base}.log" "foreground"
    if [[ $? != 0 ]]; then
        failure
        echo
        echo "   Check ${log_file_base}.log for errors"
        exit 1
    fi
    success
    echo
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
    local configured_base_port=$BASE_PORT
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
