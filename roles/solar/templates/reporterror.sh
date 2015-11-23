#!/bin/bash

mutt -s "Thrift service crashed" -a /users/apps/fortis/{{ solr_env }}/log/Apr08.log mike.bunten@assurant.com < reporterrormsg.txt
