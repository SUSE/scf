FROM alexjh/consul

LABEL role=windows-dns

ENTRYPOINT [ "/bin/consul" ]

CMD ["agent", "-data-dir", "/data", "-server", "-bootstrap", "-client=0.0.0.0", "-recursor=127.0.0.11"]
