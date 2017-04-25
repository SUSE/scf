FROM ubuntu:14.04

# Don't run mesg unless we have a tty; otherwise we'll get a warning from `docker run ... bash -l -c ...`
RUN perl -i -pe 's/mesg n/tty -s && mesg n/' /root/.profile

# Install packages for building ruby
RUN apt-get update
RUN apt-get install -y --force-yes \
    build-essential curl git sudo zlib1g-dev libssl-dev libreadline-dev libyaml-dev libxml2-dev libxslt-dev unzip

RUN echo 'gem: --no-rdoc --no-ri' >> /.gemrc
ENV RUBY_VERSION=2.2.3

# Install chruby, since we need to manage multiple versions of Ruby as CF transitions
RUN mkdir /tmp/chruby && \
    curl --silent --show-error --location https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz | \
        tar -xz --strip-components=1 -C /tmp/chruby && \
    make -C /tmp/chruby install && \
    rm -rf /tmp/chruby && \
    echo 'if test -n "${BASH_VERSION}" -o -n "${ZSH_VERSION}" ; then' >> /etc/profile.d/chruby.sh && \
    echo '    source /usr/local/share/chruby/chruby.sh'               >> /etc/profile.d/chruby.sh && \
    echo '    source /usr/local/share/chruby/auto.sh'                 >> /etc/profile.d/chruby.sh && \
    echo '    if chruby | grep --quiet ${RUBY_VERSION:-2.2.3} ; then' >> /etc/profile.d/chruby.sh && \
    echo '        chruby ruby-${RUBY_VERSION:-2.2.3}'                 >> /etc/profile.d/chruby.sh && \
    echo '    fi'                                                     >> /etc/profile.d/chruby.sh && \
    echo 'fi'                                                         >> /etc/profile.d/chruby.sh && \
    true

ADD ./versions.txt /root/versions.txt
ADD create-release.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/create-release.sh

# Install the ruby-install to manage ruby installation
RUN set -o errexit ; \
    mkdir /tmp/ruby-install ; \
    curl --silent --show-error --location https://github.com/postmodern/ruby-install/archive/v0.6.1.tar.gz | \
        tar -xz --strip-components=1 -C /tmp/ruby-install ; \
    make -C /tmp/ruby-install install ; \
    rm -rf /tmp/ruby-install

# Install the desired versions of ruby, and bundler for each
RUN bash --login -c '\
        set -o errexit ; \
        for version in $(cat /root/versions.txt) ; do \
            ruby-install ruby ${version} -- --disable-install-doc ; \
            source /etc/profile.d/chruby.sh ; \
            chruby ruby-${version} ; \
            gem install bundler ; \
            gem install bosh_cli -v 1.3202.0 --no-ri --no-rdoc ; \
            gem install mustache -v 1.0.3    --no-ri --no-rdoc ; \
        done \
    '
