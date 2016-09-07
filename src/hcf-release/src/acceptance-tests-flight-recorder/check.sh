#!/bin/bash
export TERM=linux

NORMAL='\033[0m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'

SOURCE_FILE=/var/vcap/packages/acceptance-tests-flight-recorder/config/source_to_check.txt
SOURCE_ITEMS=
FLIGHT_RECORDER_LOG_PATH=/var/vcap/sys/log/flight-recorder.log

#check if the source file exists
function checkSource {
        if [ ! -f $SOURCE_FILE ]; then
                return 1
        fi;
        SOURCE_ITEMS=$(cat $SOURCE_FILE)
        return 0
}

if ! checkSource ; then
        echo "Could not find $SOURCE_FILE with the files to search"
        exit 255
fi


#iterate through the logs to search for source
function sourceInLog {
        SOURCE=$1
	log=`cat /var/vcap/sys/log/flight-recorder.log  | grep "\"hostname\":\"${SOURCE}\"" | wc -l`
        if [ $log -gt 0 ]; then
            return 0
        fi
        return 1
}


#check to see if each element in SOURCE_FILE has a key in flight recorder
#thus, is forwarding logs to this flightrecorder
for i in `seq 1 $1`;
        do
     clear
          count=0
          for source in $SOURCE_ITEMS; do
                COLOR=$RED
           if sourceInLog $source; then
                COLOR=$GREEN
           else
                 count=$((count+1))
           fi;
     echo -e "${COLOR}$source${NORMAL}"
   done
   echo "Number of failing service ${count}"
   [ $count -eq 0 ] && exit 0
   sleep 1
done
exit 1
