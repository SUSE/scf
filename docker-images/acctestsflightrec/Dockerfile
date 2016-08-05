FROM redis
LABEL role=acctestsflightrec
COPY start.sh /usr/local/etc/start.sh
COPY check.sh /usr/local/etc/check.sh
COPY redis.conf /usr/local/etc/redis/redis.conf
COPY flightrecorder /usr/local/etc/flightrecorder
COPY redis_pass.txt /usr/local/etc/redis_pass.txt
COPY role-manifest.yml /usr/local/etc/role-manifest.yml
RUN apt-get update && apt-get install jq && apt-get -y install python
ADD http://pyyaml.org/download/pyyaml/PyYAML-3.11.tar.gz /usr/local/etc/
RUN tar -xvf /usr/local/etc/PyYAML-3.11.tar.gz -C /usr/local/etc/
RUN cd /usr/local/etc/PyYAML-3.11 && python setup.py install && cd .. && python2.7 -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < role-manifest.yml > role-manifest.json
RUN cd /usr/local/etc && cat role-manifest.json | jq '.roles[] |  select (.run."flight-stage" != "manual") | select(.type != "bosh-task") | select(.type != "docker") | .name' | sort | xargs echo > source_to_check.txt
ENV REDIS_PASSWORD_FILE /usr/local/etc/redis_pass.txt
ENV TERM xterm
CMD ["bash" ,"/usr/local/etc/start.sh"]
