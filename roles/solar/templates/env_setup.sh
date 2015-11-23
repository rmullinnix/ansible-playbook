#!/usr/bin/ksh

export SHL={{ system_high_level }}
export ORACLE_HOME={{ oracle_home }}

export ARCH_VERSION={{ arch_version }}
export XERCES_VERSION={{ xerces_version }}

export SL_VERSION={{ solar_version }}
export UT_VERSION={{ solar_version }}

#  get the hostname from the machine...
PRIMHOST=`hostname`
PMACH=${PRIMHOST}
export PMACH

export LEVEL={{ solar_env }}
export ORACLE_SID={{ oracle_sid }}
export TWO_TASK={{ oracle_sid }}
export ORA_LIB_DIR={{ oracle_lib }}
export PROCOB=procob32
export QUEUEMN={{ queuemn }}

echo "Setting environment to:" $LEVEL 

# Set up the necessary Oracle shell variables:
export PATH=$PATH:$ORACLE_HOME/bin
ORAENV_ASK=NO
. $ORACLE_HOME/bin/oraenv

# library directives
export CXXOPTS="+W2815 +W2009 +W2001 +W2028 +W690 +W829"
export LINK_ORA_LIBS="-L ${ORACLE_HOME}/${ORA_LIB_DIR} -L ${ORACLE_HOME}/precomp/${ORA_LIB_DIR}"
export LINK_REQ_ORA='-lclntsh'
export LPATH=/lib:/usr/lib:{{ solar_app_path }}/lib
export LIBRARY_PATH=${ORACLE_HOME}/lib:{{ solar_app_path }}/lib

# include directives
export SLINC=/users/src/Sl/$SL_VERSION/include
export UTINC=/users/src/Ut/$UT_VERSION/include
export FBINC={{ solar_app_path }}/include
export ARCHINC=/users/src/Arch/$ARCH_VERSION/include
export SRVRINC=/users/src/Ut/$UT_VERSION/include/srvr
export XERCESINC=/users/src/Xerces/$XERCES_VERSION/src

#export DEVINC=/users/src/$LEVEL/$SHL/include
#export SLINC=/users/src/$LEVEL/sl/include
#export UTINC=/users/src/$LEVEL/ut/include
#export SRVRINC=/users/src/$LEVEL/ut/include/srvr
#export SRVRINC=/users/src/Ut/$UT_VERSION/include/srvr:/users/src/Ut/$UT_VERSION/Include/Srvr

export INCLUDE="-I${SRVRINC} -I${UTINC} -I${FBINC} -I${XERCESINC} -I${SLINC}"
export CPLUS_INCLUDE_PATH="${ORACLE_HOME}/precomp/public:${ARCHINC}:${SRVRINC}:${UTINC}:${XERCESINC}:${SLINC}"
export C_INCLUDE_PATH="${ORACLE_HOME}/precomp/public:${ARCHINC}:${SRVRINC}:${UTINC}:${XERCESINC}:${SLINC}"
export SQLINCLUDE="include=${ORACLE_HOME}/precomp/${ORA_LIB_DIR} include=${ORACLE_HOME}/precomp/public include=${UTINC} include=${SLINC}"

export SRC=/users/src/$LEVEL/$SHL
export STARTUPCODE='/lib/crt.o /usr/lib/end.o'
export SL_PATH={{ solar_app_path }}/lib/

export SHLIB_PATH=/usr/lib:${ORACLE_HOME}/${ORA_LIB_DIR}:{{ solar_app_path }}/lib
export LD_LIBRARY_PATH=/usr/local/lib:${ORACLE_HOME}/lib:{{ solar_app_path }}/lib

# MMS environment variables
export AS_ENV={{ mq_env }}
export AS_USER=${LOGNAME}
export AS_INFORM=101
export AS_WARNING=102
export AS_ERROR=103
export AS_ERLVL=${AS_ERROR}
export AS_SITE=KC
export AS_APPL=SL
export AS_NSLST=NMSRVKCM\;NMSRVWBY\;NMSRVMKE

# Setup environment variables for MQSeries
export MQCHLLIB=/var/mqm
export MQCHLTAB=AMQCLCHL.TAB
export {{ mq_env }}NAMESERVER_QM={{ queuemn }}
export {{ mq_env }}NAMESERVER_IDQ=X0.SERVERDEF.IDQ
export {{ mq_env }}NAMESERVER_ODQ=X0.SERVERDEF.ODQ

# set default for creation of new files added 3/21/97 (Debe)
umask 002

# set stack size to unlimited
ulimit -s unlimited

# set PATH variable
#PATH=.:$PATH:/u01/scripts:$HOME

# Set erase character
# stty erase "^H"

# Do aliases
#. /u01/scripts/.fbcspg03.aliases

#  set the prompt string to include sid, machine "name" and current directory...
PS1='{$ORACLE_SID @ $PMACH} $PWD
[$1]:'

export PS1
