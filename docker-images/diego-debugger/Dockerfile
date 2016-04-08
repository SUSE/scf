FROM ubuntu:14.04
LABEL role=diego-debugger

RUN apt-get update

RUN apt-get install wget -y

RUN wget https://github.com/pivotal-cf-experimental/veritas/releases/download/latest/veritas -O /usr/bin/veritas

RUN chmod +x /usr/bin/veritas

RUN veritas completions >> /root/.bashrc

RUN echo 'echo -e $BBS_CLIENT_CRT > /root/bbs.crt' >> /root/.bashrc
RUN echo 'echo -e $BBS_CLIENT_KEY > /root/bbs.key' >> /root/.bashrc

RUN echo 'export BBS_ENDPOINT=https://${DIEGO_DATABASE_HOST}:8889' >> /root/.bashrc
RUN echo 'export BBS_CERT_FILE=/root/bbs.crt' >> /root/.bashrc
RUN echo 'export BBS_KEY_FILE=/root/bbs.key' >> /root/.bashrc
