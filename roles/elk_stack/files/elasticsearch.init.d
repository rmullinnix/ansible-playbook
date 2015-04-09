#!/bin/bash
#
# elasticsearch   json storage engine for full text search
#       
# chkconfig:   2345 95 95
# description: elasticsearch integrates with logstash for central storage of log messages
# processname: elasticsearh
# config: /usrelasticsearh/current/config
# pidfile: /var/run/elasticsearch.pid

### BEGIN INIT INFO
# Provides:          elasticsearch
# Required-Start:
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 6
# Short-Description: Starts elasticsearch
# Description:       Starts elasticsearch using start-stop-daemon
### END INIT INFO
 
. /etc/rc.status
rc_reset

# You may need to change these
USER=nanolog   		  # the user you used to run the elastic search install command
GROUP=nanotech  	  # the group you used to run the elastic search install command
JAVA_HOME=/usr/bin/java   # Where java lives

### BEGIN user-configurable settings
NAME=elasticsearch
DESC=elasticsearch
ES_HOME=/usr/nano/elasticsearch/current
PID_FILE=/var/run/$NAME.pid
LOCK_FILE=/var/lock/subsys/$NAME
LOG_DIR=$ES_HOME/logs
DATA_DIR=$ES_HOME/data
CONFIG_FILE=$ES_HOME/config/elasticsearch.yml
ES_MIN_MEM=256m
ES_MAX_MEM=2g
WORK_DIR=/tmp/$NAME
DAEMON=$ES_HOME/bin/elasticsearch
DAEMON_OPTS="-p $PID_FILE -Des.config=$CONFIG_FILE -Des.path.home=$ES_HOME -Des.path.logs=$LOG_DIR -Des.path.data=$DATA_DIR -Des.path.work=$WORK_DIR"
### END user-configurable settings

start() {
    [ -x $DAEMON ] || exit 5
    
    [ -f $CONFIG_FILE ] || exit 6
    [ -d $DATA_DIR ] || exit 7
 
    umask 077
 
    mkdir -p $LOG_DIR $DATA_DIR $WORK_DIR
    chown -R $USER:$GROUP $LOG_DIR $DATA_DIR $WORK_DIR
    touch $PID_FILE
    chown $USER:$GROUP $PID_FILE
 
    ulimit -v unlimited

    echo -n $"Starting $prog: $1"

    ## holy shell shenanigans, batman!
    ## daemon can't be backgrounded.  we need the pid of the spawned process,
    ## which is actually done via runuser thanks to --user.  you can't do "cmd
    ## &; action" but you can do "{cmd &}; action".
    /sbin/start_daemon -f \
        -p $PID_FILE \
        -u $USER \
		$DAEMON $DAEMON_OPTS & echo $! > $PID_FILE
    
    RETVAL=$?
    echo
    
    [ $RETVAL -eq 0 ]  && touch $LOCK_FILE
    
    return $RETVAL
}
 
stop() {
    echo -n $"Shutting down $prog: "
    ## graceful shutdown with SIGINT
    /sbin/start-stop-daemon -K -p $PID_FILE -u $USER
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f $LOCK_FILE
    return $RETVAL
}
 
restart() {
    stop
    start
}
 
reload() {
    echo -n $"Reloading $prog: "
    ${0} stop
    sleep 0.5
    ${0} start
}
 
force_reload() {
    restart
}
 
rh_status() {
    checkproc -p $PID_FILE $DAEMON
    $DAEMON -v
    rc_status -v
}
 
rh_status_q() {
    rh_status >/dev/null 2>&1
}
 
case "$1" in
    start)
        $1
        ;;
    stop)
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|bootstrap|reload|force-reload}"
        exit 2
esac
 
exit $?

. /etc/rc.status
rc_reset
 
prog="kibana"
user="nanolog"
group="nanotech"
exec="/usr/nano/kibana/current/bin/$prog"
pidfile="/var/run/$prog.pid"
logfile="/usr/nano/log/$prog.log"
confdir="/usr/nano/kibana/current/config"
 
start() {
    [ -x $exec ] || exit 5
    
    [ -d $confdir ] || exit 6
 
    umask 077
 
    touch $logfile $pidfile
    chown $user:$group $logfile $pidfile
 
    ulimit -v unlimited

    echo -n $"Starting: $1"

    ## holy shell shenanigans, batman!
    ## daemon can't be backgrounded.  we need the pid of the spawned process,
    ## which is actually done via runuser thanks to --user.  you can't do "cmd
    ## &; action" but you can do "{cmd &}; action".
    /sbin/start_daemon -f \
        -p $pidfile \
        -u $user \
		$exec --quiet &
    
    RETVAL=$?
    echo
    
    [ $RETVAL -eq 0 ]
    
    return $RETVAL
}
 
stop() {
    echo -n $"Shutting down $prog: "
    ## graceful shutdown with SIGINT
    /sbin/start-stop-daemon -K -p $pidfile -u $user
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f $lockfile
    return $RETVAL
}
 
restart() {
    stop
    start
}
 
reload() {
    echo -n $"Reloading $prog: "
    /sbin/start-stop-daemon -K -p $pidfile -u $user -x $exec -s 9
    echo
}
 
force_reload() {
    restart
}
 
rh_status() {
    checkproc -p $pidfile $exec
    $exec --version
    rc_status -v
}
 
rh_status_q() {
    rh_status >/dev/null 2>&1
}
 
case "$1" in
    start)
        $1
        ;;
    stop)
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        $1
        ;;
    bootstrap)
        start $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|bootstrap|reload|force-reload}"
        exit 2
esac
 
exit $?
