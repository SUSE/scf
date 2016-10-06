#used for initial config
MAIN_CONFIG="90-vcap.conf"
RSYSLOG_CONF_DIR="/etc/rsyslog.d"

#used for adding individual logs
BACKUP_WATCH_DIR=/var/vcap/sys/log #in case no ENV variable is set for RSYSLOG_FORWARDER_WATCH_DIR
RSYSLOG_CONF_PREFIX=91-vcap
RSYSLOG_CONF_DIR=/etc/rsyslog.d
IGNORE_DIR="gocode"
TARGET_NAME=
TARGET_BASENAME=

SCRIPT_FILE=/usr/sbin/forward_logfiles.sh
PB_OUT=/var/log/pb.out

if [ ! -f $SCRIPT_FILE ]; then
	echo "#log forwarding script" > $PB_OUT
fi

if [ -z "${RSYSLOG_FORWARDER_WATCH_DIR:-}" ]; then
        RSYSLOG_FORWARDER_WATCH_DIR=$BACKUP_WATCH_DIR
        echo "RSYSLOG_FORWARDER_WATCH_DIR not set. Using default $BACKUP_WATCH_DIR" >> $PB_OUT
fi

if [ ! -d "$RSYSLOG_FORWARDER_WATCH_DIR" ]; then
        echo "$RSYSLOG_FORWARDER_WATCH_DIR is not a valid directory" >> $PB_OUT
fi

function appendToCron {
	echo appending to cron
        if [ ! -z "${HCP_FLIGHTRECORDER_HOST:-}" ]; then
                if [ -z "${HCP_FLIGHTRECORDER_PORT:-}" ]; then
                        HCP_FLIGHTRECORDER_PORT=514
                fi
                crontab -l > tempcrontab
                echo "export _HCP_FLIGHT_RECORDER=$HCP_FLIGHTRECORDER_HOST:$HCP_FLIGHTRECORDER_PORT" >> $SCRIPT_FILE
                echo "export RSYSLOG_FORWARDER_WATCH_DIR=$RSYSLOG_FORWARDER_WATCH_DIR" >> $SCRIPT_FILE
                cat $0 >> $SCRIPT_FILE
                echo "*/1 * * * * bash $SCRIPT_FILE >> /dev/null 2>&1" >> tempcrontab
                crontab tempcrontab
        else

                echo "HCP_FLIGHTRECORDER_HOST env var missing. Not adding log forwarding to cron." >> $SCRIPT_FILE
                exit 0
        fi
}

#check if cron has something in it
if crontab -l &>/dev/null ; then
        #put the script in cron if it is not there already
        if ! { crontab -l | grep forward_logfiles.sh ; } ; then
                appendToCron
        fi
else
        echo "#creating cron conf as it does not exist yet" >> $PB_OUT
        appendToCron
fi


#create the file that will forward all messages to flight recorder
function initialConfig {

        if ! cat <<-EOF | sed 's@^\s*@@' >$RSYSLOG_CONF_DIR/$MAIN_CONFIG ; then
                module(load="imfile" mode="polling")
                \$template RFC5424Format,"<13>%protocol-version% 2016-07-20T09:03:00.329650+00:00 %HOSTNAME% %app-name% - - - %msg%\n"
                \$ActionFileDefaultTemplate RFC5424Format
                \$RepeatedMsgReduction on
                \$ActionQueueType LinkedList
                *.* @${HCP_FLIGHTRECORDER_HOST}:${HCP_FLIGHTRECORDER_PORT}
                :app-name, contains, "vcap" ${HOME}
	EOF
                echo "Rsyslog forwarder: Could not create $MAIN_CONFIG in $RSYSLOG_CONF_DIR" >> $PB_OUT
                exit 0
        fi

        if [[ ! -f "$RSYSLOG_CONF_DIR/$MAIN_CONFIG" ]]; then
                echo "Rsyslog forwarder: File $MAIN_CONFIG not found in $RSYSLOG_CONF_DIR" >> $PB_OUT
                exit 0
        fi
}

#search is there are more logs to be monitored by rsyslog
function searchTargetDir {
        filesAdded=1
        for file in $1/*
        do
                if [ -d $file ]; then
                        ignored=false
                        for ignore in $IGNORE_DIR
                        do
                                if [[ $file == $RSYSLOG_FORWARDER_WATCH_DIR/$ignore ]]; then
                                        echo "Ignoring $file directory"
                                        ignored=true
                                fi
                        done;
                        if [ $ignored == false ]; then
                                if searchTargetDir $file; then
                                        filesAdded=0
                                fi
                        fi
                else
                        if [ "${file: -4}" == ".log" ]; then
                                targetName $file
                                if checkConfigExists $file; then
                                        echo $TARGET_NAME exists
                                else
                                        echo "Creating $TARGET_NAME"
                                        createTargetConf $file
                                        filesAdded=0
                                fi
                        fi
                fi
        done
        return $filesAdded
}

#Create the rsyslog configuration file inside rsysconf.d
function createTargetConf {
        cat <<-EOF | sed 's@^\s*@@' >${TARGET_NAME}
            \$InputFileName ${1}
            \$InputFileTag vcap-${TARGET_BASENAME}
            \$InputFileStateFile ${TARGET_BASENAME}_state
            \$InputFileFacility local7
            \$InputRunFileMonitor
	EOF
}

function targetName {
        filename=$(basename $1)
        TARGET_BASENAME="${filename%.*}"
}

function checkConfigExists {
        TARGET_NAME=$RSYSLOG_CONF_DIR/$RSYSLOG_CONF_PREFIX-$TARGET_BASENAME.conf
        if [ -f $TARGET_NAME ]; then
                return 0
        else
                return 1
        fi
}

#check if the forwarding conf is set up
if [ ! -f $RSYSLOG_CONF_DIR/$MAIN_CONFIG ]; then
      if [ -z $HCP_FLIGHTRECORDER_HOST ]; then
              echo "HCP_FLIGHTRECORDER_HOST not set" >> $PB_OUT
              exit 0
      fi
      if [ -z $HCP_FLIGHTRECORDER_PORT ]; then
	      HCP_FLIGHTRECORDER_PORT=514
      fi
      _HCP_FLIGHT_RECORDER=$HCF_FLIGHTRECORDER_HOST:$HCF_FLIGHTRECORDER_PORT
      echo creating initial config for forwarding
      initialConfig
else
      echo initial config for forwarding exists
fi

#make sure the logs configs are added to rsyslog.d folder
if searchTargetDir $RSYSLOG_FORWARDER_WATCH_DIR; then
        if test -r /var/run/rsyslog.pid; then
                if test -d /proc/$(cat /var/run/rsyslog.pid); then
                        service rsyslog restart
                fi
        fi
fi
