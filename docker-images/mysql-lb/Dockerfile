FROM haproxy:1.5
LABEL role=mysql-lb
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
EXPOSE 3306
COPY override-docker-entrypoint.sh /
ENTRYPOINT ["/override-docker-entrypoint.sh"]
