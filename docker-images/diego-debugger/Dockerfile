FROM ubuntu:14.04
LABEL role=diego-debugger

RUN apt-get update

RUN apt-get install wget -y

RUN wget https://github.com/pivotal-cf-experimental/veritas/releases/download/latest/veritas -O /usr/bin/veritas

RUN chmod +x /usr/bin/veritas

RUN veritas completions >> /root/.bashrc

# Use HCP secrets if they exist
RUN echo 'if [ -r /etc/secrets/bbs-client-crt ]; then \
            printf %b "$(cat /etc/secrets/bbs-client-crt)" > /root/bbs.crt; \
          else \
            echo -e $BBS_CLIENT_CRT > /root/bbs.crt; \
          fi' >> /root/.bashrc
RUN echo 'if [ -r /etc/secrets/bbs-client-key ]; then \
            printf %b "$(cat /etc/secrets/bbs-client-key)" > /root/bbs.key; \
          else \
            echo -e $BBS_CLIENT_KEY > /root/bbs.key; \
          fi' >> /root/.bashrc

RUN echo 'export BBS_ENDPOINT=https://${DIEGO_DATABASE_HOST}.${HCP_SERVICE_DOMAIN_SUFFIX}:8889' >> /root/.bashrc
RUN echo 'export BBS_CERT_FILE=/root/bbs.crt' >> /root/.bashrc
RUN echo 'export BBS_KEY_FILE=/root/bbs.key' >> /root/.bashrc

ENTRYPOINT ["tail", "-f", "/dev/null"]
