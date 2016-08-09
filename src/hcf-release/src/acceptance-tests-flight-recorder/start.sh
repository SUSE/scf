/usr/local/bin/redis-server /usr/local/etc/redis/redis.conf &
sleep 2
/usr/local/etc/flightrecorder > /dev/null &
sleep 1
watch -c /usr/local/etc/check.sh
