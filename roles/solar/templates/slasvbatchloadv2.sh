#!/bin/ksh 

#######################################################################
#  slasvbatchload.sh           
#      This script is used to invoke Batch Processor executable
#      depending upon Transaction Id supplied from command line 
#      
#      Runs once a month-Autosys job names P3SLMRB1 and P3SLMRB2
#          Time range and pace of program controled by SL_PROCESS_CNTL
#          valid values table
#  
#   Revision History:
#   06/22/2005 T. Meek        Changes for Autosys 
#   07/12/2005 A. Munter      Changes for new process id AUTOCALC 
#   10/05/2005 T. Meek        Break out from slnbatchprocess.sh
#   01/30/2008 T. Meek        Add environment to subject line of e-mail
#   02/12/2008 T. Meek        Process id will be passed in along with environment 
#                             and err, out and log file names will be adjusted
#                             according to process id
#   04/06/2010 T. Meek        change e-mail addresses
#   07/15/2010 T. Meek        change e-mail addresses
#   07/01/2014 T. Meek        Created from slasvbatchload.sh to run on Linux
########################################################################

TERM=hpterm
PATH=/bin:/usr/bin:/usr/local/bin

########################################################################
#   Set variables  
########################################################################
export ENVIRON={{ solar_env }}
export DBPARMS=/
export AS_ENV={{ mq_env }}

case "$2"
in
      RNWLLOAD )  export PROCESSID=RNWLLOAD
                  export OUTFILE=slasvbatchload.out
                  export ERRFILE=slasvbatchload.err 
                  export LOGFILE=slasvbatchload.log;;

      RNWLLOAD1 ) export PROCESSID=RNWLLOAD1
                  export OUTFILE=slasvbatchload1.out
                  export ERRFILE=slasvbatchload1.err 
                  export LOGFILE=slasvbatchload1.log;;

      RNWLLOAD2 ) export PROCESSID=RNWLLOAD2
                  export OUTFILE=slasvbatchload2.out
                  export ERRFILE=slasvbatchload2.err 
                  export LOGFILE=slasvbatchload2.log;;

      * )   echo "You entered an invalid process id."
            echo "Valid process ids are RNWLLOAD, RNWLLOAD1, RNWLLOAD2."
            exit 6;;
esac

export AS_APP=SL
export LOGNAME=slbtch

#  if you run this script under your own UNIX id, you'll need to comment out these lines
#  . .fbcspg03.profile
  . {{ solar_app_path }}/soloar/scripts/env_setup.sh $AS_ENV $AS_APP
# 

export FILEPATH={{ solar_app_path }}/log/slasvbatchload/
echo "Environment is --" $ENVIRON > $FILEPATH$LOGFILE
echo "Process id is $PROCESSID"
export SQLFILE={{ solar_app_path }}/solar/scripts/sly152sel-sl_process_ctrl-email.sql
export AS_ERLVL=AS_ERROR

export AS_USER=autosys
export PROGEXE={{ solar_app_path }}/bin/slasvbatchprocessor

export USER_LIST=`sqlplus ${DBPARMS} @${SQLFILE} ${PROCESSID} | grep assurant.com`
echo $USER_LIST

########################################################################
# PACE pager stuff
########################################################################
export TMPFILE=slasvbatchloadtemp.log
export PACE=telalert@mom.assurant-inc.com
export PRIMARY="SolarFTPagerPri"
echo "Check slasvbatchload.log--" $ENVIRON > $FILEPATH$TMPFILE

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

JOBSTRING="Load Cases"
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
