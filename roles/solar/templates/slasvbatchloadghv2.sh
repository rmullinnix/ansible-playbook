#!/bin/ksh 

#######################################################################
#  slasvbatchloadgh.sh           
#      This script is used to invoke Batch Processor executable
#      depending upon Transaction Id supplied from command line 
#      
#      Runs once a month-Autosys job name P3SLMGHL
#          Time range and pace of program controled by SL_PROCESS_CNTL
#          valid values table
#  
#   Revision History:
#   10/15/2009 T. Meek        Initial development - cloned from slasvbatchload.sh
#   04/06/2010 T. Meek        change e-mail addresses
#   07/15/2010 T. Meek        change e-mail addresses
#   07/01/2014 T. Meek        Created from slasvbatchloadgh.sh to run on Linux
########################################################################

#TERM=hpterm
PATH=/bin:/usr/bin:/usr/local/bin

########################################################################
#   Set variables  
########################################################################
export ENVIRON={{ solar_env }}
export DBPARMS=/
export AS_ENV={{ mq_env }}

export PROCESSID=RNWLLOADGH
export OUTFILE=slasvbatchloadgh.out
export ERRFILE=slasvbatchloadgh.err 
export LOGFILE=slasvbatchloadgh.log

export FILEPATH={{ solar_app_path }}/log/slasvbatchloadgh/
export DATAPATH={{ solar_app_path }}/data/
export DATAPATH2={{ solar_app_path }}/data/slnload/
export SQLFILE={{ solar_app_path }}/solar/scripts/sly152sel-sl_process_ctrl-email.sql

echo "Environment is --" $ENVIRON > $FILEPATH$LOGFILE
echo "Process id is $PROCESSID"

export AS_APP=SL
export LOGNAME=slbtch
#  if you run this script under your own UNIX id, you'll need to comment out these lines
#  . .fbcspg03.profile
  . {{ solar_app_path }}/soloar/scripts/env_setup.sh $AS_ENV $AS_APP
# 
export AS_ERLVL=AS_ERROR
export AS_USER=autosys
export PROGEXE={{ solar_app_path }}/bin/slasvbatchprocessor
export DATAFILE=slnreext.dat

########################################################################
# PACE pager stuff
########################################################################
export TMPFILE=slasvbatchloadghtemp.log
export PACE=telalert@mom.assurant-inc.com
export PRIMARY="SolarFTPagerPri"
echo "Check slasvbatchloadgh.log--" $ENVIRON > $FILEPATH$TMPFILE

########################################################################
# Execute program, check result and send log file
#   Program Input Parameters must be in specified order
#      PROGEXE      argv[0] = program executable
#      AS_ENV       argv[1] = Environment
#      PROCESSID    argv[2] = Process Id 
#      FILEPATH     argv[3] = Path for files
#      LOGFILE      argv[4] = Log File 
#      DBPARMS      argv[5] = DB connect parms userid/password
#########################################################################

$PROGEXE $AS_ENV $PROCESSID $FILEPATH $LOGFILE $DBPARMS
Ret=$?

JOBSTRING="GH Load Cases"
if [ $Ret -eq 0 ] 
then
   echo "****$JOBSTRING Completed Successfully****"
   mutt -s "****$JOBSTRING Succeeded in $ENVIRON with RC $Ret ****" -a $FILEPATH$LOGFILE -- $USER_LIST
else
   if [ $ENVIRON = "prod1" ]
   then
      echo "****$JOBSTRING - Error occurred!****"
      mutt -s "****$JOBSTRING in $ENVIRON Error****" $USER_LIST < $FILEPATH$LOGFILE
   else
      echo "****$JOBSTRING - Error occurred!****"
      mutt -s "****$JOBSTRING in $ENVIRON Error****" $USER_LIST < $FILEPATH$LOGFILE
   fi
fi 

########################################################################
#   Rename Log, Out, and Err files by appending current date, and set permissions
#   Remove Log files over 90 days old (this runs only once a month, so
#   save the last 3 runs)
########################################################################

mv $FILEPATH$LOGFILE $FILEPATH$LOGFILE.`date +%Y%m%d_%H%M%S`
mv $DATAPATH$DATAFILE $DATAPATH2$DATAFILE.`date +%Y%m%d_%H%M%S`
chmod 666 $FILEPATH$LOGFILE.*
find $FILEPATH -mtime +90  -exec rm -f {} \;

if [ -f $FILEPATH$TMPFILE ]
then
   rm $FILEPATH$TMPFILE
fi

cp $FILEPATH$OUTFILE  $FILEPATH$OUTFILE.`date +%Y%m%d_%H%M%S`
cp $FILEPATH$ERRFILE  $FILEPATH$ERRFILE.`date +%Y%m%d_%H%M%S`
rm $FILEPATH$OUTFILE
rm $FILEPATH$ERRFILE
rm $FILEPATH$OUTFILE

if [ $Ret -eq 0 ]
then 
   exit 0
else
   exit 1
fi
