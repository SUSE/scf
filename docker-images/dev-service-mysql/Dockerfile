FROM centurylink/mysql:5.5
LABEL role=dev-service-mysql

COPY run.sh /opt/hcf/
RUN chmod +x /opt/hcf/run.sh

ENTRYPOINT ["/opt/hcf/run.sh"]
CMD ["/usr/local/bin/run"]