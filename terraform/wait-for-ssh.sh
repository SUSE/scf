#!/bin/sh

ip="$1"
label="$2"
ok="\033[0;32;1mReached $label $ip/22\033[0m"
fail="\033[0;31;1mFailed to reach $label $ip/22\033[0m"

for i in `seq 20`
do
    nc $ip 22 < /dev/null > /dev/null 2>&1 && echo "${ok} @$i" && exit 0
    sleep 10
done
echo "$fail"
exit 1
