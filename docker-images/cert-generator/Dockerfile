FROM opensuse

RUN zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check obs://devel:languages:go devel:languages:go && \
    zypper --non-interactive --gpg-auto-import-keys refresh && \
    zypper --non-interactive install --no-confirm --from devel:languages:go go && \
    zypper --non-interactive install --no-confirm git vim && \
    go get github.com/square/certstrap && \
    rm -rf ~/go/{src,pkg} && \
    zypper clean -a

RUN mkdir /out
VOLUME /out
COPY generate-dev-certs.sh generate-certs.sh cert-generator.sh /

ENTRYPOINT ["/cert-generator.sh"]
