#!/bin/ksh 

#######################################################################
#  slasvbatchselect.sh           
#      This script is used to invoke Batch Processor executable
#      depending upon Transaction Id supplied from command line 
#      
#      Runs daily - Monday thru Saturday
#          Time range and pace of program controled by SL_PROCESS_CNTL
#          valid values table
#  
#   Revision History:
#   06/22/2005 T. Meek        Changes for Autosys 
#   07/12/2005 A. Munter      Changes for new process id AUTOCALC
#   10/05/2005 T. Meek        Break out from slnbatchprocess.sh 
#   07/15/2010 T. Meek        Changed e-mail addresses
#   06/30/2014 T. Meek        Created from slasvbatchselect.sh to run on Linux
########################################################################

#TERM=hpterm
PATH=/bin:/usr/bin:/usr/local/bin

########################################################################
#   Set variables  
########################################################################
export ENVIRON={{ solar_env }}
export DBPARMS=/
export AS_ENV={{ mq_env }}
      
export AS_APP=SL
export LOGNAME=slbtch
#  if you run this script under your own UNIX id, you'll need to comment out these lines
#  . .fbcspg03.profile
  . {{ solar_app_path }}/soloar/scripts/env_setup.sh $AS_ENV $AS_APP
# 

export FILEPATH={{ solar_app_path }}/log/slasvbatchselect/
export PROCESSID=RNWLINVT
export OUTFILE=slasvbatchselect.out
export ERRFILE=slasvbatchselect.err 
export LOGFILE=slasvbatchselect.log
export SQLFILE={{ solar_app_path }}/solar/scripts/sly152sel-sl_process_ctrl-email.sql
export AS_ERLVL=AS_ERROR

echo "Environment is --" $ENVIRON > $FILEPATH$LOGFILE

export PROGEXE={{ solar_app_path }}/bin/slasvbatchprocessorv2

export USER_LIST=`sqlplus ${DBPARMS} @${SQLFILE} ${PROCESSID} | grep assurant.com`
echo $USER_LIST

########################################################################
# PACE pager stuff
########################################################################
export TMPFILE=slasvbatchselecttemp.log
export PACE=telalert@mom.assurant-inc.com
export PRIMARY="SolarFTPagerPri"
echo "Check slasvbatchselect.log--" $ENVIRON > $FILEPATH$TMPFILE

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

JOBSTRING="Batch Process Select"
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
#   Remove Log, Out, and Err files over 60 days old in the lower environments
#   Remove Log, Out, and Err files over 120 days old in prod
#   (this job runs twice a month in prod)
########################################################################

mv $FILEPATH$LOGFILE $FILEPATH$LOGFILE.`date +%Y%m%d_%H%M%S`
#chmod 666 $FILEPATH$LOGFILE.*

if [ $ENVIRON = "prod1" ]
then
   find $FILEPATH -mtime +120  -exec rm -f {} \;
else
   find $FILEPATH -mtime +60  -exec rm -f {} \;
fi

if [ -f $FILEPATH$TMPFILE ]
then
   rm $FILEPATH$TMPFILE
fi

cp $FILEPATH$OUTFILE  $FILEPATH$OUTFILE.`date +%Y%m%d_%H%M%S`
cp $FILEPATH$ERRFILE  $FILEPATH$ERRFILE.`date +%Y%m%d_%H%M%S`
rm $FILEPATH$OUTFILE
rm $FILEPATH$ERRFILE

if [ $Ret -eq 0 ]
then 
   exit 0
else
   exit 1
fi
