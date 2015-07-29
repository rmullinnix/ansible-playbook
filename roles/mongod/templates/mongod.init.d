#!/bin/bash

# mongod - Startup script for mongod

### BEGIN INIT INFO
# Provides:       mongod
# Required-Start: $network
# Required-Stop: $network
# Default-Start:  2 3 5
# Default-Stop:   0 1 6
# Short-Description: Mongod
# Description:    Mongod
### END INIT INFO

# Source function library.
. /etc/rc.status
rc_reset

# things from mongod.conf get there by mongod reading it


# NOTE: if you change any OPTIONS here, you get what you pay for:
# this script assumes all options are in the config file.
CONFIGFILE="{{ etc_conf }}/mongod.conf"
OPTIONS=" -f $CONFIGFILE"
SYSCONFIG="/etc/sysconfig/mongod"

PIDDIR="{{ pid_path }}/mongodb"
PIDFILEPATH=`awk -F'[:=]' -v IGNORECASE=1 '/^[[:blank:]]*(processManagement\.)?pidfilepath[[:blank:]]*[:=][[:blank:]]*/{print $2}' "$CONFIGFILE" | tr -d "[:blank:]\"'"`

mongod={{ inf_app_path}}/mongo/mongod

MONGO_USER={{ mongo_user }}
MONGO_GROUP={{ mongo_group }}

if [ -f "$SYSCONFIG" ]; then
    . "$SYSCONFIG"
fi

# Handle NUMA access to CPUs (SERVER-3574)
# This verifies the existence of numactl as well as testing that the command works
NUMACTL_ARGS="--interleave=all"
if which numactl >/dev/null 2>/dev/null && numactl $NUMACTL_ARGS ls / >/dev/null 2>/dev/null
then
    NUMACTL="$(which numactl) $NUMACTL_ARGS"
else
    NUMACTL=""
fi

start()
{

  # Make sure the default pidfile directory exists
  if [ ! -d $PIDDIR ]; then
    install -d -m 0755 -o $MONGO_USER -g $MONGO_GROUP $PIDDIR
  fi

  umask 033
  touch $PIDFILEPATH
  chown $MONGO_USER:$MONGO_GROUP $PIDFILEPATH

  # Recommended ulimit values for mongod or mongos
  # See http://docs.mongodb.org/manual/reference/ulimit/#recommended-settings
  #
  ulimit -f unlimited
  ulimit -t unlimited
  ulimit -v unlimited
  ulimit -n 64000
  ulimit -m unlimited
  ulimit -u 64000

  echo -n "Starting mongod: "
  $NUMACTL /sbin/start_daemon -u "$MONGO_USER" -p "$PIDFILEPATH" $mongod $OPTIONS >/dev/null 2>&1

  RETVAL=$?
  [ $RETVAL -eq 0 ] && touch {{ lock_path }}/subsys/mongod && chmod 644 $PIDFILEPATH
  return $RETVAL
}

stop()
{
  echo -n "Stopping mongod: "
  mongo_killproc "$PIDFILEPATH" $mongod
  RETVAL=$?
  [ $RETVAL -eq 0 ] && rm -f {{ lock_path }}/subsys/mongod
  return $RETVAL
}

restart () {
	stop
	start
}

# Send TERM signal to process and wait up to 300 seconds for process to go away.
# If process is still alive after 300 seconds, send KILL signal.
# Built-in killproc() (found in /etc/init.d/functions) is on certain versions of Linux
# where it sleeps for the full $delay seconds if process does not respond fast enough to
# the initial TERM signal.
mongo_killproc()
{
  local pid_file=$1
  local procname=$2
  local -i delay=300
  local -i duration=10
  local pid=`pidofproc -p "${pid_file}" ${procname}`

  kill -TERM $pid >/dev/null 2>&1
  usleep 100000
  local -i x=0
  while [ $x -le $delay ] && checkproc -p "${pid_file}" ${procname}; do
    sleep $duration
    x=$(( $x + $duration))
  done

  kill -KILL $pid >/dev/null 2>&1
  usleep 100000

  rm -f "${pid_file}"

  checkproc -p "${pid_file}" ${procname}
  local RC=$?
  RC=$((! $RC))
  return $RC
}

RETVAL=0

case "$1" in
  start)
    start
    rc_status -v
    ;;
  stop)
    stop
    rc_status -v
    ;;
  restart|reload|force-reload)
    restart
    rc_status -v
    ;;
  condrestart)
    [ -f {{ lock_path }}/subsys/mongod ] && restart || :
    rc_status
    ;;
  status)
    echo -n "Checking for mongod:"
    checkproc -p "$PIDFILEPATH" $mongod
    rc_status -v
    ;;
  *)
    echo "Usage: $0 {start|stop|status|restart|reload|force-reload|condrestart}"
    exit 1
esac

rc_exit
