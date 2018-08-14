FROM centos:centos7

MAINTAINER Martin Nagy <nagy.martin@gmail.com>

ENV container=docker

RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \
    yum -y --setopt=tsflags=nodocs install rpcbind nfs-utils && \
    mkdir -p /exports && \
    yum clean all
COPY run-mountd.sh /

VOLUME ["/exports"]

RUN echo 'RPCRQUOTADOPTS="-p 875"' >> /etc/sysconfig/nfs
RUN echo 'LOCKD_TCPPORT="32803"' >> /etc/sysconfig/nfs
RUN echo 'LOCKD_UDPPORT="32769"' >> /etc/sysconfig/nfs
RUN echo 'RPCMOUNTDOPTS="-p 892"' >> /etc/sysconfig/nfs
RUN echo 'STATDARG="-p 662 -o 2020"' >> /etc/sysconfig/nfs

EXPOSE 111/tcp 111/udp 662/udp 662/tcp 875/udp 875/tcp 2049/udp 2049/tcp 32769/udp 32803/tcp 892/udp 892/tcp

ENTRYPOINT ["/run-mountd.sh"]
