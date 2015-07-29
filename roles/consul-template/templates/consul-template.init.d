#!/bin/bash
#
# consul        Manage the consul-template agent
#       
# chkconfig:   2345 95 95
# description: Consul-template is a tool sync the consul registry with a template file
# processname: consul-template
# config: /etc/consul-template.conf
# pidfile: /var/run/consul.pid
 
### BEGIN INIT INFO
# Provides:       consul-template
# Required-Start: $local_fs $network
# Required-Stop:
# Should-Start:
# Should-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:  0 1 6
# Short-Description: Manage the consul-template agent
# Description: Consul-template is a tool sync the consul registry with a template file
### END INIT INFO

. /etc/rc.status
rc_reset
 
prog="consul-template"
user="root"
exec="{{ inf_app_path }}/$prog/$prog"
pidfile="{{ pid_path }}/$prog.pid"
lockfile="{{ lock_path }}/subsys/$prog"
logfile="{{ inf_log_path }}/$prog.log"
confdir="{{ consul_template_config_dir }}"
 
export GOMAXPROCS=${GOMAXPROCS:-2}
 
start() {
    [ -x $exec ] || exit 5
    
    [ -f $conffile ] || exit 6
    [ -d $confdir ] || exit 6
 
    umask 033
 
    touch $logfile $pidfile
    chown $user:$user $logfile $pidfile
 
    ulimit -v unlimited

    echo -n $"Starting $prog: $1"

    ## holy shell shenanigans, batman!
    ## daemon can't be backgrounded.  we need the pid of the spawned process,
    ## which is actually done via runuser thanks to --user.  you can't do "cmd
    ## &; action" but you can do "{cmd &}; action".
    /sbin/start_daemon -f \
        -p $pidfile \
        -u $user \
		$exec -config $confdir 2>&1 >> $logfile & echo $! > $pidfile
    
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
