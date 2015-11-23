#!/bin/ksh 

#######################################################################
#  slasvbatchmultilinephil.sh           
#      This script is used to invoke Batch Multiline Philosophy Process
#      
#      Runs daily - Monday thru Sunday
#  
#   Revision History:
#   01/13/2010 E. Branson      Initial Development
########################################################################

# If copying a scripts from Unix, create a v2 version and check it into 
# scriptsv2 in TFS. Do all the TODOs. 

#TERM=hpterm
PATH=/bin:/usr/bin:/usr/local/bin

# TODO: Change dvelop4/D4 and intg4/N4 to dvelop1/D1 and intg1/N1
########################################################################
#   Set variables  
########################################################################
export ENVIRON={{ solar_env }}
export DBPARMS=/
export AS_ENV={{ mq_env }}

# TODO: Change autosys to slbtch
export AS_APP=SL
export LOGNAME=slbtch

# TODO: Replace the following 4 lines in the Unix script with the following
#  if you run this script under your own UNIX id, you'll need to comment out these lines
#  . .fbcspg03.profile
  . {{ solar_app_path }}/soloar/scripts/env_setup.sh $AS_ENV $AS_APP
# 

export FILEPATH={{ solar_app_path }}/log/slasvbatchmultilinephil/
export PROCESSID=RNWLMLPH1
export OUTFILE=slasvbatchmultilinephil.out
export ERRFILE=slasvbatchmultilinephil.err 
export LOGFILE=slasvbatchmultilinephil.log
export SQLFILE={{ solar_app_path }}/solar/scripts/sly152sel-sl_process_ctrl-email.sql
export AS_ERLVL=AS_ERROR

echo "Environment is --" $ENVIRON > $FILEPATH$LOGFILE

# TODO: Change slasvbatchprocessor to slasvbatchprocessorv2
export PROGEXE={{ solar_app_path }}/bin/slasvbatchprocessorv2

export USER_LIST=`sqlplus ${DBPARMS} @${SQLFILE} ${PROCESSID} | grep assurant.com`
echo $USER_LIST

########################################################################
# PACE pager stuff
########################################################################
export TMPFILE=slasvbatchmultilinephiltmp.log
export PACE=telalert@mom.assurant-inc.com
export PRIMARY="SolarFTPagerPri"
echo "Check slasvbatchmultilinephil.log--" $ENVIRON > $FILEPATH$TMPFILE

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

# TODO: Replace the Unix mailx code with the following
JOBSTRING="Batch Multiline Philosophy"
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
