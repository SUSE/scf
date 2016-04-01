FROM tutum/mongodb:3.0
LABEL role=dev-service-mongodb

COPY run.sh /opt/hcf/
RUN chmod +x /opt/hcf/run.sh

ENTRYPOINT ["/opt/hcf/run.sh"]
CMD ["/run.sh"]