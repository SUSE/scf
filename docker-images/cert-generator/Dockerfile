FROM opensuse

RUN zypper --non-interactive addrepo --gpgcheck --refresh --priority 120 --check obs://devel:languages:go devel:languages:go && \
    zypper --non-interactive --gpg-auto-import-keys refresh && \
    zypper --non-interactive install --no-confirm --from devel:languages:go go && \
    zypper --non-interactive install --no-confirm git vim && \
    go get github.com/square/certstrap && \
    zypper clean -a

RUN mkdir /scf-settings /uaa-settings /out
COPY generate-dev-certs.sh /
COPY generate-certs.sh /
COPY cert-generator.sh /
COPY scf-settings/* /scf-settings/
COPY uaa-settings/* /uaa-settings/


ENTRYPOINT ["/cert-generator.sh"]
