#!/bin/ksh 

#######################################################################
#  slasvbatchrnwlltr4.sh           
#      This script is used to invoke Batch Renewal Letter 4
#      
#      Runs daily - Monday thru Sunday
#  
#   Revision History:
#   01/13/2010 A. Munter      Initial Development
#   01/21/2010 M. Bunten      Changed to get e-mail ids from SL_PROCESS_CTRL
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
# . .fbcspg03.profile
  . {{ solar_app_path }}/soloar/scripts/env_setup.sh $AS_ENV $AS_APP
# 

export FILEPATH={{ solar_app_path }}/log/slasvbatchrnwlltr/
export PROCESSID=RNWLLTR4
export OUTFILE=slasvbatchrnwlltr4.out
export ERRFILE=slasvbatchrnwlltr4.err 
export LOGFILE=slasvbatchrnwlltr4.log
export SQLFILE={{ solar_app_path }}/solar/scripts/sly152sel-sl_process_ctrl-email.sql
export AS_ERLVL=AS_ERROR

echo "Environment is --" $ENVIRON > $FILEPATH$LOGFILE

export PROGEXE={{ solar_app_path }}/bin/slasvbatchprocessorv2

export USER_LIST=`sqlplus ${DBPARMS} @${SQLFILE} ${PROCESSID} | grep assurant.com`
echo $USER_LIST

########################################################################
# PACE pager stuff
########################################################################
export TMPFILE=slasvbatchrnwlltr4tmp.log
export PACE=telalert@mom.assurant-inc.com
export PRIMARY="SolarFTPagerPri"
echo "Check slasvbatchrnwlltr4.log--" $ENVIRON > $FILEPATH$TMPFILE

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

JOBSTRING="Batch Renewal Letter 4"
if [ $Ret -eq 0 ] 
then
   echo "****$JOBSTRING Completed Successfully****"
   mutt -s "****$JOBSTRING Succeeded in $ENVIRON with RC $Ret ****" -a $FILEPATH$LOGFILE -- $USER_LIST
else
   if [ $ENVIRON = "prod1" ]
   then
      echo "****$JOBSTRING - Error occurred!****"
      mutt -s "****$JOBSTRING in $ENVIRON Error****" $USER_LIST < $FILEPATH$LOGFILE
      mutt -s "$PRIMARY" $PACE < $FILEPATH$TMPFILE
   else
      echo "****$JOBSTRING - Error occurred!****"
      mutt -s "****$JOBSTRING in $ENVIRON Error****" $USER_LIST < $FILEPATH$LOGFILE
   fi
fi

########################################################################
#   Rename Log, Out, and Err files by appending current date, and set permissions
#   Remove Log files over 30 days old
########################################################################

mv $FILEPATH$LOGFILE $FILEPATH$LOGFILE.`date +%Y%m%d_%H%M%S`
chmod 666 $FILEPATH$LOGFILE.*
find $FILEPATH -mtime +30  -exec rm -f {} \;

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
