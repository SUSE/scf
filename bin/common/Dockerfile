FROM opensuse/leap

RUN zypper ar http://download.opensuse.org/update/leap/15.1/oss/openSUSE:Leap:15.1:Update.repo
RUN zypper ref
RUN zypper in -y wget tar gzip git make docker ruby2.5 perl

#ADD install_tools.sh /tmp/tools/install_tools.sh
#ADD versions.sh /tmp/tools/versions.sh
#ADD build.sh /tmp/tools/build.sh

#RUN /tmp/tools/install_tools.sh

RUN wget https://github.com/SUSE/stampy/releases/download/0.0.0/stampy-0.0.0.22.gbb93bf3.linux-amd64.tgz
RUN tar xvf stampy-*.tgz
RUN chmod +x stampy
RUN mv stampy /usr/bin/

WORKDIR "/workdir"
