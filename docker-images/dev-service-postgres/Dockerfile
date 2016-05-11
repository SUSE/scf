FROM postgres:9.4
LABEL role=dev-service-postgres

COPY run.sh /opt/hcf/
RUN chmod +x /opt/hcf/run.sh

ENTRYPOINT ["/opt/hcf/run.sh"]
CMD ["postgres"]