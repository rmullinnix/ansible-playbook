#!/bin/bash

export LEVEL={{ solar_env }}
. {{ solar_app_path }}/soloar/scripts/env_setup.sh $1
cd {{ solar_app_path }}/bin
./slusvthrift $2 $3 $4 {{ solar_app_path }}/log 3 &

