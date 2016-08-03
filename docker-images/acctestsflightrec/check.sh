#!/bin/bash

NORMAL='\033[0m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'

SOURCE_FILE=/usr/local/etc/source_to_check.txt
SOURCE_ITEMS=
REDIS_PASS_FILE=$REDIS_PASSWORD_FILE

#check if redis pass file is set
if [ -z $REDIS_PASS_FILE ]; then
	echo "Redis pass is not known"
	exit 255
fi

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

if [ ! -f $REDIS_PASS_FILE ]; then
        echo "Could not find $REDIS_PASS_FILE"
        exit 255
fi

#iterate through the keys in redis to search for source
function sourceInRedisKeys {
        SOURCE=$1
        redis_keys=$(redis-cli -a $redis_pass keys \*)

        for key in $redis_keys; do
                if [ $key == $SOURCE ]; then
                        return 0
                fi
        done
        return 1
}

redis_pass=$(cat $REDIS_PASS_FILE)

#check to see if each element in SOURCE_FILE has a key in redis
#thus, is forwarding logs to this flightrecorder
for source in $SOURCE_ITEMS; do
        COLOR=$RED
        if sourceInRedisKeys $source; then
                COLOR=$GREEN
        fi;
        echo -e "${COLOR}$source${NORMAL}"
done

