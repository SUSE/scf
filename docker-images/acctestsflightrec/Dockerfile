FROM redis
LABEL role=acctestsflightrec
COPY start.sh /usr/local/etc/start.sh
COPY check.sh /usr/local/etc/check.sh
COPY source_to_check.txt /usr/local/etc/source_to_check.txt
COPY redis.conf /usr/local/etc/redis/redis.conf
COPY flightrecorder /usr/local/etc/flightrecorder
COPY redis_pass.txt /usr/local/etc/redis_pass.txt
ENV REDIS_PASSWORD_FILE /usr/local/etc/redis_pass.txt
CMD ["bash" ,"/usr/local/etc/start.sh"]
