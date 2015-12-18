How to update HCF configs

* Generate the configs:

<pre>

    cd .../hcf-infrastructure/upgrades/config/analyze
    bin/analyze -j ~/disk1/hpcloud/cf-release-217 -k ~/disk1/hpcloud/cf-release-222 \
        -o /home/ericp/git/hpcloud/hcf-infrastructure/config-opinions/cf-v217 \
        -p spec/fixtures/cf-v222 -t spec/fixtures/hcf-cf-v217 -u spec/fixtures/hcf-cf-v222 \
        -v overrides.tfvars template_file.domain.rendered=1.2.3.4.xip.io \
        > config-diffs.txt
    
    scp config-diffs.txt ubuntu@15.125.1.2:

</pre>

See bin/analyze for an explanation of the arguments 

* Build the go script:

<pre>

    cd ../update
    go build
    scp update ubuntu@15.125.1.2:

</pre>

* And on the remote node:

<pre>

    ./update http://`get_ip`:8501 config-diffs.txt

</pre>

If you want to back up the consul database before running this,

<pre>

    cp -r /data/cf-consul/consul_agent ~/

</pre>




