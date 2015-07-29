#!/bin/bash
#
# kibana        Dashboard tool for log viewing
#       
# chkconfig:   2345 95 95
# description: Kibana is a tool for creating dashboards from log data stored in elasticsearch
# processname: kibana
# config: /usr/nano/kibana/current/config
# pidfile: /var/run/kibana.pid
 
### BEGIN INIT INFO
# Provides:       kibana
# Required-Start: $local_fs $network
# Required-Stop:
# Should-Start:
# Should-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:  0 1 6
# Short-Description: Manage the kibana daemon
# Description: Kibana is a tool for creating dashboards from log data stored in elasticsearch
### END INIT INFO
. /etc/rc.status
rc_reset
 
prog="kibana"
user="{{ kibana_user }}"
group="{{ kibana_group }}"
exec="{{ inf_app_path }}/kibana/current/bin/$prog"
pidfile="{{ pid_path }}/$prog.pid"
logfile="{{ inf_log_path }}/$prog.log"
confdir="{{ inf_app_path }}/kibana/current/config"
 
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
		$exec --quiet & echo $! > $pidfile
    
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
    {{ inf_app_path }}/kibana/current/bin/kibana_status {{ kibana_port }}
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
