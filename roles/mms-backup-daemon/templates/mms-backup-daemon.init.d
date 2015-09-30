#!/bin/bash

#
# (C) Copyright 2013, MongoDB, Inc.
# chkconfig: 35 86 14
# description: A simple script to run MongoDB Backup Daemon.
#

### BEGIN INIT INFO
# Provides:          mongodb-mms-backup-daemon
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     3 5
# Default-Stop:      0 1 6
# Short-Description: MongoDB Management Service - Backup Daemon
# Description:       MongoDB Management Service - Backup Daemon
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

APP_DIR="{{ inf_app_path }}/mongo/mms-backup-daemon"

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
APP_ID="bgrid"
LOG_PATH="{{ inf_log_path }}/mongo/mms"
LOG_NAME="backup-daemon"
SYSCONFIG="${APP_DIR}/conf/daemon.conf"
JAVA_HOME="${APP_DIR}/jdk"
KILL_PORT=8640
BASE_PORT=27500
QUERYABLE_BASE_PORT=27700
DEBUG_PORT=8090

MMS_USER={{ mms_user }}

[[ -f "${SYSCONFIG}" ]] && . "${SYSCONFIG}"

[[ -z "${JAVA_HOME}" ]] && bail "JAVA_HOME not set."
[[ ! -d "${JAVA_HOME}" ]] && bail "JAVA_HOME set as ${JAVA_HOME} but does not exist."
[[ ! -x ${JAVA_HOME}/bin/${APP_NAME} ]] && bail "${JAVA_HOME}/bin/${APP_NAME} does not exist."

# The daemon expects these as system properties. For simplicity they are in the
# regular configuration file and extracted here.
get_daemon_root_directory() {
    echo `grep '^rootDirectory' ${APP_DIR}/conf/conf-daemon.properties | cut -d = -f 2`
}

get_daemon_num_workers() {
    echo `grep '^numWorkers' ${APP_DIR}/conf/conf-daemon.properties | cut -d = -f 2`
}

get_daemon_release_directory() {
    echo `grep '^mongodb.release.directory' ${APP_DIR}/conf/conf-daemon.properties | cut -d = -f 2`
}

get_daemon_release_autodownload() {
    grep '^mongodb.release.autoDownload=true$' ${APP_DIR}/conf/conf-daemon.properties > /dev/null 2>&1
    return $?
}

# Application configurations (Do not modify)
JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -Dserver-env=${APP_ENV} -Dapp-id=${APP_ID}"
JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -Dlog_path=${LOG_PATH}/${LOG_NAME} -Dmms.extraPropFile=conf-daemon.properties"

JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -DDAEMON.ROOT.DIRECTORY=`get_daemon_root_directory`"
JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -Dnum.workers=`get_daemon_num_workers`"
JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -DDAEMON.BASE.PORT=${BASE_PORT} -DDAEMON.KILL.PORT=${KILL_PORT} -DDAEMON.DEBUG.PORT=${DEBUG_PORT}"
JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -DDAEMON.QUERYABLE.BASE_PORT=${QUERYABLE_BASE_PORT} -DDAEMON.QUERYABLE.MAX_MOUNTS=20"

JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -DDAEMON.MONGODB.RELEASE.DIR=`get_daemon_release_directory`"
JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -Dmms.keyfile=${ENC_KEY_PATH}"

JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -Dmms.backup.enableBlockstoreSharding=false"

if get_daemon_release_autodownload; then
    JAVA_MMS_OPTS="${JAVA_MMS_OPTS} -DDAEMON.MONGODB.RELEASE.AUTODOWNLOADAPP=${APP_DIR}/bin/mongodb-fetch"
fi


JAVA_MMS_CLASSPATH="-classpath ${APP_DIR}/classes/mms.jar:${APP_DIR}/conf/:${APP_DIR}/lib/*"

#
# Start the instance running on the server.
#
start() {
    preFlightCheck
    local start_cmd="${JAVA_HOME}/bin/${APP_NAME} ${JAVA_MMS_OPTS} ${JAVA_MMS_CLASSPATH} com.xgen.svc.brs.grid.Daemon"
    echo -n "Start Backup Daemon..."

    if `is_instance_running`; then
        failure
        echo
        echo "   Backup Daemon is already running."
    else
        jvm "${start_cmd}" `get_log` "background"
        if [[ $? != 0 ]]; then
            failure
            echo
            echo "   Check `get_log` for errors"
            exit 1
        fi
        success
        echo
    fi
}

#
# Stop the instance running on the server.
#
stop() {
        echo -n "Stop Backup Daemon"
    if `is_instance_running`; then
        local start_cmd="${JAVA_HOME}/bin/${APP_NAME} ${JAVA_MMS_OPTS} -Dkill.daemon=true ${JAVA_MMS_CLASSPATH} com.xgen.svc.brs.grid.Daemon"
        jvm "${start_cmd}" `get_log` "foreground"
        if [[ $? != 0 ]]; then
            failure
            echo
            echo "   Backup Daemon failed to stop"
            exit 1
        fi
        success
        echo
    else
        failure
        echo
        echo "   Backup Daemon is not running."
    fi
}

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
# Run preFlightCheck to look for configuration errors.
#
preFlightCheck() {
    local opts_array=(
        "-Dmms.extraPropFile=conf-daemon.properties"
        "-Duser.timezone=GMT"
        "-Dfile.encoding=UTF-8"
        "-Dserver-env=${APP_ENV}"
        "-Dapp-id=${APP_ID}"
        "-Dmms.keyfile=${ENC_KEY_PATH}"
        "-DDAEMON.MONGODB.RELEASE.DIR=`get_daemon_release_directory`"
        "-Dlog_path=${LOG_PATH}/${LOG_NAME}"
        "-Xmx256m"
        "-XX:-OmitStackTraceInFastThrow"
        "-Dcore.preflight.class=com.xgen.svc.brs.grid.BackupDaemonPreFlightCheck"
        "-classpath ${APP_DIR}/classes/mms.jar:${APP_DIR}/conf:${APP_DIR}/lib/*"
    )

    if get_daemon_release_autodownload; then
        opts_array+=("-DDAEMON.MONGODB.RELEASE.AUTODOWNLOADAPP=${APP_DIR}/bin/mongodb-fetch")
    fi

    local jvm_opts=$( build_opts "" opts_array[@] )
    local start_cmd="${JAVA_HOME}/bin/${APP_NAME} ${jvm_opts} com.xgen.svc.core.PreFlightCheck"
    local daemon_cmd="start_daemon"
    daemon_cmd="${daemon_cmd} -f -u ${MMS_USER}"

    ${daemon_cmd} ${start_cmd}
    if [[ $? != 0 ]]; then
        exit 1
    fi
    echo
}

#
# Fire up the JVM.
#
jvm() {
    local jvm_cmd="$1"
    local log_file="$2"
    local background="$3"
    local daemon_cmd="start_daemon"
    touch ${log_file}
    chown ${MMS_USER} ${log_file}
    daemon_cmd="${daemon_cmd} -f -u ${MMS_USER}"
    # If the output redirection is appended to the cmd variable, then nohup will
    # output an annoying message to the terminal about where it will send its output.
    # It only seems to be a problem on Ubuntu.
    ${daemon_cmd} nohup ${jvm_cmd} >> ${log_file} 2>&1 &
    sleep 3
    ps -p $! > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        wait $!
        return $?
    fi
}

get_log() {
    echo "${LOG_PATH}/${LOG_NAME}.log"
}

is_instance_running() {
    netstat -nl | grep :${KILL_PORT} > /dev/null 2>&1
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

    echo $"Usage: $0 {start|stop|restart|run|status}";
    exit 2;
esac
