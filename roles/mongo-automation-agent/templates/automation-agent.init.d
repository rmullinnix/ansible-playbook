#!/bin/bash
#
# automation-agent        Manage the automation-agent agent
#       
# chkconfig:   2345 95 95
# description: Mongodb automation agent for deployment and management of mongodb components
# processname: mongodb-mms-automation-agent
# config: /etc/sysconfig/automation-agent
# pidfile: /var/run/automation-agent.pid
 
### BEGIN INIT INFO
# Provides:       automation-agent
# Required-Start: $local_fs $network
# Required-Stop:
# Should-Start:
# Should-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:  0 1 6
# Short-Description: Manage the automation-agent agent
# Description: Mongodb automation agent for deployment and management of mongodb components
### END INIT INFO
. /etc/rc.status
rc_reset
 
prog="mongodb-mms-automation-agent"
user="{{ mms_user }}"
group="{{ mms_group }}"
exec="{{ inf_app_path }}/mongo/mms/agent/automation/$prog"
pidfile="{{ pid_path }}/$prog.pid"
lockfile="{{ lock_path }}/subsys/$prog"
logfile="{{ inf_log_path }}/mongo/mms/automation-agent.log"
conffile="{{ inf_app_path }}/mongo/mms/agent/automation/local.config"
 
# pull in sysconfig settings
[ -e /etc/sysconfig/$prog ] && . /etc/sysconfig/$prog
 
export GOMAXPROCS=${GOMAXPROCS:-2}
 
start() {
    [ -x $exec ] || exit 5
    
    [ -f $conffile ] || exit 6
    [ -d $confdir ] || exit 6
 
    umask 033
 
    touch $logfile $pidfile
    chown $user:$group $logfile $pidfile
 
    ulimit -v unlimited

    echo -n $"Starting $prog: $1"

    ## holy shell shenanigans, batman!
    ## daemon can't be backgrounded.  we need the pid of the spawned process,
    ## which is actually done via runuser thanks to --user.  you can't do "cmd
    ## &; action" but you can do "{cmd &}; action".
    /sbin/start_daemon -f \
        -p $pidfile \
        -u $user \
		$exec --config=$conffile 2>&1 >> $logfile & echo $! > $pidfile
    
    RETVAL=$?
    echo
    
    [ $RETVAL -eq 0 ] && touch $lockfile
    
    return $RETVAL
}
 
stop() {
    echo -n $"Shutting down $prog: "
    ## graceful shutdown with SIGINT
    /sbin/start-stop-daemon -K -p $pidfile -u $user -x $exec -s 2
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f $lockfile
    return $RETVAL
}
 
restart() {
    stop
    sleep 4
    start
}
 
reload() {
    echo -n $"Reloading $prog: "
    /sbin/start-stop-daemon -K -p $pidfile -u $user -x $exec -s 1
    RETVAL=$?
    return $RETVAL
}
 
force_reload() {
    restart
}
 
rh_status() {
    checkproc -p $pidfile $exec
    $exec version
    rc_status -v
}
 
rh_status_q() {
    rh_status >/dev/null 2>&1
}
 
case "$1" in
    start)
        $1
	rc_status -v
        ;;
    stop)
        $1
	rc_status -v
        ;;
    restart)
        $1
	rc_status -v
        ;;
    reload)
        $1
	rc_status -v
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|reload|force-reload}"
        exit 2
esac
 
rc_exit
