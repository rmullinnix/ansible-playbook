#!/bin/bash

CONFIGFILE="/etc/mongod.conf"
PIDFILE=`awk -F'[:=]' -v IGNORECASE=1 '/^[[:blank:]]*(processManagement\.)?pidfilepath[[:blank:]]*[:=][[:blank:]]*/{print $2}' "$CONFIGFILE" | tr -d "[:blank:]\"'"`
PID=$(cat $PIDFILE)

mongod={{ inf_app_path }}/mongo/mongod
if [ $PID -eq $(pidof $mongod) ]
  then
    $mongod --version
    exit 0
fi

exit 2
