FROM andyshinn/dnsmasq:2.76

LABEL role=dev-dns

ENTRYPOINT ["dnsmasq", "-k", "-p", "8600", "-q", "--log-facility=-"]
