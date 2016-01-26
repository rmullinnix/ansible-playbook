#!/usr/bin/env bash

#
# Linux, Solaris 10+, and AIX 5.x+ init script for Mulesoft Tcat Server 7.
#
# chkconfig: 2345 96 14
# description: Mulesoft Tcat Server 7.
# processname: tcat7
# config: {{ tcat_home }}/conf/Catalina/localhost/tcat-env.conf
#
# Copyright (c) 2009-2011 Mulesoft, Inc.  All rights reserved.
#
# ----------------------------------------------------------------------
#

# Source function library.
if [ -f /etc/rc.d/init.d/functions ]; then
    . /etc/rc.d/init.d/functions
fi

# Build the environment file path, in the same directory as the init script.
READLINK="`which readlink`"
BASENAME="`which basename`"
DIRNAME="`which dirname`"
if [[ $READLINK =~ ^/ ]]; then
    LINK="`$READLINK -f $0`"
else
    PRG="$0"
    while [ -h "$PRG" ]; do
        ls=`ls -ld "$PRG"`
        link=`expr "$ls" : '.*-> \(.*\)$'`
        if expr "$link" : '/.*' > /dev/null; then
            PRG="$link"
        else
            PRG=`dirname "$PRG"`/"$link"
        fi
    done
    LINK=$PRG
fi
TCAT_ENV="`$DIRNAME $LINK`/tcat-env.conf"

# Get the service name from the name of the init script.
SCRIPT_DIR="`$DIRNAME $0`"
if [[ $SCRIPT_DIR =~ /etc/rc\d*..d ]]; then
    # Resolve symlink paths like /etc/rc6.d/S96tcat7
    ls=`ls -ld "$0"`
    LINK=`expr "$ls" : '.*-> \(.*\)$'`
    if ! expr "$LINK" : '/.*' > /dev/null; then
        LINK=`dirname "$0"`/"$LINK"
    fi
    SERVICE_NAME="`$BASENAME $LINK`"
else
    SERVICE_NAME="`$BASENAME $0`"
fi

# Source the app config file, if it exists (console users can modify this).
[ -r "$TCAT_ENV" ] && . "${TCAT_ENV}"

# Source the Tcat overrides config file, if it exists (console users cannot modify this).
[ -r "{{ tcat_home }}/conf/tcat-overrides.conf" ] && . "{{ tcat_home }}/conf/tcat-overrides.conf"

# The path to the Tomcat start/stop script.
#TOMCAT_SCRIPT=$CATALINA_HOME/conf/Catalina/localhost/catalina.sh
TOMCAT_SCRIPT=$CATALINA_BASE/conf/Catalina/localhost/catalina.sh


# If TOMCAT_USER is not set, use "tomcat".
if [ -z "$TOMCAT_USER" ]; then
    TOMCAT_USER="{{ tomcat_user }}"
fi

# Since this init script will run $TOMCAT_SCRIPT, no environment
# settings should be defined here anymore.  Please use the
# {{ tcat_home }}/conf/Catalina/localhost/tcat-env.conf file instead.

let RETVAL=0
JVM_PID="0"
JVM_RUNNING="false"

start() {
    echo -n "Starting $SERVICE_NAME: "

    checkJvmRunning
    if [ "$JVM_RUNNING" == "true" ]; then
        echo -n "\"$SERVICE_NAME\" JVM process already running. "
    else
        if [[ "`uname`" =~ "AIX" ]]; then
            cat ${CATALINA_BASE}/conf/Catalina/localhost/tcat-env.conf | grep " (SR"
            if [ $? -eq 0 ]; then
                # Remove spaces and the start option from the tcat-env.conf file.
                sed -e 's/ (SR/(SR/g' ${CATALINA_BASE}/conf/Catalina/localhost/tcat-env.conf > /tmp/tcat-env.conf.${SERVICE_NAME}.temp
                sed -e 's/ FP/FP/g' /tmp/tcat-env.conf.${SERVICE_NAME}.temp > /tmp/tcat-env.conf.${SERVICE_NAME}.new
                sed -e 's/Bootstrap start/Bootstrap/g' /tmp/tcat-env.conf.${SERVICE_NAME}.new > ${CATALINA_BASE}/conf/Catalina/localhost/tcat-env.conf
                rm /tmp/tcat-env.conf.${SERVICE_NAME}.temp
                rm /tmp/tcat-env.conf.${SERVICE_NAME}.new
            fi
        fi

        # Raise the process's maximum number of file descriptors to 8192.
        if [ "${UID}" == "0" ]; then
            # Raise the process's maximum number of file descriptors to 8192.
            ulimit -n 8192 || :
        fi

        # Exit with an explanation if our JAVA_HOME isn't found.
        if [ ! -d "$JAVA_HOME" ] && [ ! -d "$JRE_HOME" ]; then
            echo "JAVA_HOME of $JAVA_HOME not found."
            echo "See ${TCAT_ENV}"
            if [ -f /etc/rc.d/init.d/functions ]; then
                echo -n "Starting $SERVICE_NAME: "
                echo_failure
                echo
            fi
            if [ "$SMF_FMRI" ]; then
                return 96; # Solaris SMF_EXIT_ERR_CONFIG
            fi
            return 1
        fi

        # Set JSSE_HOME -- it fixes some security issues.
        JSSE_HOME="$JAVA_HOME"
        if [ "$JSSE_HOME" == "" ]; then
            JSSE_HOME="$JRE_HOME"
        fi
        if [ -d "$JAVA_HOME/jre" ] && [ -r "$JAVA_HOME/jre" ]; then
            JSSE_HOME="$JAVA_HOME/jre"
        fi

        # Start Tomcat, running as the $TOMCAT_USER.
        if [ "$EUID" != "0" ]; then
            # We're already a non-root user so just exec the script.
            bash -c "set -a; \
                SERVICE_NAME=$SERVICE_NAME; . $TCAT_ENV; \
                [ -r "{{ tcat_home }}/conf/tcat-overrides.conf" ] && \
                    . {{ tcat_home }}/conf/tcat-overrides.conf; \
                JSSE_HOME=\"$JSSE_HOME\" \
                cd $CATALINA_BASE; $TOMCAT_SCRIPT start" >/dev/null 2>&1
        else
            if [ -f /etc/rc.d/init.d/functions -a -x /sbin/runuser ]; then
                runuser -s /bin/bash - $TOMCAT_USER \
                    -c "set -a; \
                    SERVICE_NAME=$SERVICE_NAME; . $TCAT_ENV; \
                    [ -r "{{ tcat_home }}/conf/tcat-overrides.conf" ] && \
                        . {{ tcat_home }}/conf/tcat-overrides.conf; \
                    JSSE_HOME=\"$JSSE_HOME\" \
                    cd $CATALINA_BASE; $TOMCAT_SCRIPT start" >/dev/null 2>&1
            else
                [[ "`uname -s`" =~ "Linux" ]] && SU_BASH='-s /bin/bash'
                [[ "`uname -s`" =~ "SunOS" ]] && SU_BASH=''
                su $TOMCAT_USER $SU_BASH -c "set -a; \
                    SERVICE_NAME=$SERVICE_NAME; . $TCAT_ENV; \
                    [ -r "{{ tcat_home }}/conf/tcat-overrides.conf" ] && \
                        . {{ tcat_home }}/conf/tcat-overrides.conf; \
                    JSSE_HOME=\"$JSSE_HOME\" \
                    cd $CATALINA_BASE; $TOMCAT_SCRIPT start" >/dev/null 2>&1
            fi
        fi
        disown -a

        let RETVAL=$?

        # If the return value is zero, then the attempt to start it is
        # good so far.
        if [ $RETVAL -eq 0 ]; then
            # Sleep some seconds while Tomcat begins to start, then check it.
            sleep 7
            checkJvmRunning
            if [ "$JVM_RUNNING" == "false" ]; then
                let RETVAL=1
            fi
        fi
    fi

    # Output "[  OK  ]" or "[  FAILED  ]"
    if [ $RETVAL -eq 0 ]; then
        if [ -f /etc/rc.d/init.d/functions ]; then
            echo_success
            echo
        else
            echo "[  OK  ]"
        fi
    else
        if [ -f /etc/rc.d/init.d/functions ]; then
            echo_failure
            echo
        else
            echo "[  FAILED  ]"
        fi
    fi

    return $RETVAL
}

stop() {
    echo -n "Stopping $SERVICE_NAME: "

    checkJvmRunning
    if [ "$JVM_RUNNING" == "true" ]; then

        # Exit with an explanation if our JAVA_HOME isn't found.
        if [ ! -d "$JAVA_HOME" ] && [ ! -d "$JRE_HOME" ]; then
            echo "JAVA_HOME of $JAVA_HOME not found."
            echo "See ${TCAT_ENV}"
            echo -n "Stopping $SERVICE_NAME: "
            if [ -f /etc/rc.d/init.d/functions ]; then
                echo_failure
                echo
            else
                echo "[  FAILED  ]"
            fi
            if [ "$SMF_FMRI" ]; then
                return 96; # Solaris SMF_EXIT_ERR_CONFIG
            fi
            return 1
        fi

        # Stop Tomcat, running as the $TOMCAT_USER.  We also unset any
        # JVM memory switches -- the stop client shouldn't start with those.
        if [ "$EUID" != "0" ]; then
            # We're already a non-root user so just exec the script.
            bash -c "set -a; \
                SERVICE_NAME=$SERVICE_NAME; . $TCAT_ENV; \
                [ -r "{{ tcat_home }}/conf/tcat-overrides.conf" ] && \
                    . {{ tcat_home }}/conf/tcat-overrides.conf; \
                shopt -s extglob; \
                export JAVA_OPTS=\"\${JAVA_OPTS//-Xm[sx]+([0-9])[mM]}\"; \
                shopt -u extglob; $TOMCAT_SCRIPT stop" &>/dev/null
        else
            if [ -f /etc/rc.d/init.d/functions -a -x /sbin/runuser ]; then
                runuser -s /bin/bash - $TOMCAT_USER \
                    -c "set -a; \
                    SERVICE_NAME=$SERVICE_NAME; . $TCAT_ENV; \
                    [ -r "{{ tcat_home }}/conf/tcat-overrides.conf" ] && \
                        . {{ tcat_home }}/conf/tcat-overrides.conf; \
                    shopt -s extglob; \
                    export JAVA_OPTS=\"\${JAVA_OPTS//-Xm[sx]+([0-9])[mM]}\"; \
                    shopt -u extglob; $TOMCAT_SCRIPT stop" &>/dev/null
            else
                [[ "`uname -s`" =~ "Linux" ]] && SU_BASH='-s /bin/bash'
                [[ "`uname -s`" =~ "SunOS" ]] && SU_BASH=''
                su $TOMCAT_USER $SU_BASH -c \
                    "set -a; \
                    SERVICE_NAME=$SERVICE_NAME; . $TCAT_ENV; \
                    [ -r "{{ tcat_home }}/conf/tcat-overrides.conf" ] && \
                        . {{ tcat_home }}/conf/tcat-overrides.conf; \
                    shopt -s extglob; \
                    export JAVA_OPTS=\"\${JAVA_OPTS//-Xm[sx]+([0-9])[mM]}\"; \
                    shopt -u extglob; $TOMCAT_SCRIPT stop" &>/dev/null
            fi
        fi

        let RETVAL=$?

        if [ $RETVAL -eq 0 ]; then

            checkJvmRunning
            if [ "$JVM_RUNNING" == "true" ]; then
                if [ ! $SHUTDOWN_WAIT ]; then
                    let SHUTDOWN_WAIT=5;
                fi

                # Loop here until either Tomcat shuts down on its own, or
                # until we've waited longer than SHUTDOWN_WAIT seconds.
                let count=0
                until [ "`ps -p $JVM_PID | grep -c $JVM_PID`" == "0" ] ||
                      [ $count -gt $SHUTDOWN_WAIT ]
                do
                    if [ $count -eq 0 ]; then
                        echo
                    fi
                    echo "Waiting for processes to exit.."
                    sleep 1
                    let count=$count+1
                done

                if [ $count -gt $SHUTDOWN_WAIT ]; then
                    # Tomcat is still running, so we'll send the JVM a
                    # SIGTERM signal and wait again.
                    echo "Sending the Tomcat processes a SIGTERM asking them" \
                         "to shut down gracefully.."
                    /bin/kill -15 $JVM_PID &>/dev/null

                    # Loop here until either Tomcat shuts down on its own, or
                    # until we've waited longer than SHUTDOWN_WAIT seconds.
                    let count=0
                    until [ "`ps -p $JVM_PID | grep -c $JVM_PID`" \
                          == "0" ] || [ $count -gt $SHUTDOWN_WAIT ]
                    do
                        echo "Waiting for processes to exit.."
                        sleep 1
                        let count=$count+1
                    done

                    if [ $count -gt $SHUTDOWN_WAIT ]; then
                        # Tomcat is still running, and just won't shut down.
                        # We'll kill the JVM process by sending it a SIGKILL
                        # signal and wait again for the JVM process to die.
                        echo "Killing processes which didn't stop after" \
                         "$SHUTDOWN_WAIT seconds."
                        /bin/kill -9 $JVM_PID &>/dev/null

                        # Loop here until either Tomcat shuts down on its own,
                        # or until we've waited longer than SHUTDOWN_WAIT
                        # seconds.
                        let count=0
                        until [ "`ps -p $JVM_PID | grep -c $JVM_PID`" \
                              == "0" ] || [ $count -gt $SHUTDOWN_WAIT ]
                        do
                            echo "Waiting for processes to exit.."
                            sleep 1
                            let count=$count+1
                        done

                        if [ $count -gt $SHUTDOWN_WAIT ]; then
                            # The JVM process won't shut down even with a
                            # SIGKILL, so there is something really wrong.
                            echo "The \"$SERVICE_NAME\" JVM process is wedged and" \
                                "won't shut down even when it is"
                            echo "sent a SIGKILL."
                            echo "Process ID $JVM_PID."

                            # Right here we may want to email an administrator.

                            let RETVAL=1
                            if [ "$SMF_FMRI" ]; then
                                return 98; # Solaris SMF_EXIT_MON_OFFLINE
                            fi
                        fi
                    fi

                    # We need to sleep here to make sure the JVM process dies.
                    sleep 2
                fi
            fi
        fi
    fi

    # Output "[  OK  ]" or "[  FAILED  ]"
    if [ $RETVAL -eq 0 ]; then
        if [ -f /etc/rc.d/init.d/functions ]; then
            echo_success
            echo
        else
            echo "[  OK  ]"
        fi
    else
        if [ -f /etc/rc.d/init.d/functions ]; then
            echo_failure
            echo
        else
            echo "[  FAILED  ]"
        fi
    fi

    return $RETVAL
}

getJvmPid() {
    PS='ps'
    if [[ "`uname -s`" =~ "SunOS" ]] && \
        ([ "`uname -r`" == "5.10" ] || [ "`uname -r`" == "5.9" ]); then
        PS='/usr/ucb/ps'
    fi

    if [[ "`uname`" =~ "AIX" ]];then
        JVM_PID="`$PS awwx | grep \"Dcatalina.base=$CATALINA_BASE \" | \
            grep -v grep | head -n 1 | awk '{print $1}'`"
    elif [ $LEGACY ]; then
        JVM_PID="`$PS awwx | grep \"Dcatalina.base=$CATALINA_BASE \" | \
            grep -v grep | head -n 1 | cut -c -6`"
    else
        JVM_PID="`$PS awwx | grep \"tcat.service=$SERVICE_NAME \" | \
            grep -v grep | head -n 1 | cut -c -6`"
    fi
    # Remove any spaces in the pid string.
    JVM_PID=${JVM_PID// /}
}

checkJvmRunning() {
    getJvmPid
    if [ "$JVM_PID" != "" ]; then
        JVM_RUNNING="true"
    else
        JVM_RUNNING="false"
    fi
}

interruptHandler() {
    return 0
}
trap interruptHandler HUP TERM QUIT INT ABRT ALRM TSTP KILL

# See how we were called.
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        if [ $RETVAL -eq 0 ]; then
            start
        fi
        ;;
    status)
        checkJvmRunning
        if [ "$JVM_RUNNING" == "true" ]; then
            echo "$SERVICE_NAME (pid $JVM_PID) is running."
            let RETVAL=0
        else
            echo "$SERVICE_NAME is not running."
            let RETVAL=1
        fi
        exit $RETVAL
        ;;
    condrestart)
        # If it's already running, restart it, otherwise don't start it.
        checkJvmRunning
        if [ "$JVM_RUNNING" == "true" ]; then
            stop
            if [ $RETVAL -eq 0 ]; then
                start
            fi
        fi
        ;;
    restartlegacy)
        let LEGACY=1
        stop
        let LEGACY=0
        start
        ;;
    *)
        echo "Usage: $SERVICE_NAME {start|stop|restart|status|condrestart}"
        let RETVAL=1
        exit $RETVAL
esac

exit $RETVAL
