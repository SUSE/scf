# Running HFC on UCP via Vagrant #

This tutorial assumes you are going to run commands in 5 shell sessions:

1. ssh session to HCF vagrant box (in `~/hcf`)
2. ssh session to UCP master (in `~/ucp-developer`)
3. ssh session to UCP node (in `~/ucp-developer`)
4. ssh tunnel to UCP node (in `~/ucp-developer`)
5. local shell

Each heading below includes the shell id (#x) at the end.

## Start up the HCF vagrant box (#1) ##

You need a running HCF vagrant box with all images already compiled:

```bash
cd hcf
vagrant up --provider vmware_fusion
vagrant ssh
# Then, inside the VM
cd hcf
make vagrant-prep
```

### Start up the UCP vagrant boxes (#2) ###

It takes a while to start up UCP, so you want to start this early.  You need to
provide the address of the docker registry for HCF images; here we use a local
registry inside the HCF vagrant box:

```bash
tar xfz ucp-developer-1.0.xxx+master.hhhhhhhh.yyymmddhhmmss.tar.gz
cd ucp-developer
INSECURE_REGISTRY=192.168.77.77:5000 vagrant up --provider vmware_fusion
```

### Create a local Docker registry (#1) ###

Then push all the HCF images to it:

```bash
make registry
make tag IMAGE_REGISTRY=localhost:5000
make publish IMAGE_REGISTRY=localhost:5000
```

### Make sure UCP is running (#2) ###

Once the `vagrant up` command is complete, log into the master and verify that
all pods are running:

```bash
vagrant ssh master
kubectl get pods --namespace=ucp
```

You will see output like this:

```
vagrant@k8-master:~$ kubectl get pods --namespace=ucp
NAME              READY     STATUS             RESTARTS   AGE
ident-api-p6svw   1/1       Running            0          27m
ipmgr-ivexp       1/1       Running            0          27m
rpmgr-76ave       1/1       Running            0          27m
```

Take note of the `ipmgr` instance name, in this case `ipmgr-ivexp`, and then
view the logs like this:

```bash
kubectl logs -f ipmgr-ivexp --namespace=ucp
```

### Configure HCF with the host IP address (#5) ###

Use your host IP address for `PUBLIC_IP` and `DOMAIN` settings in the instance
definition file you're using. The examples have a "parameters" section that
sets these values.

### Generate UCP service definitions (#1) ###

Back inside the HCF vagrant box run:

```bash
make ucp IMAGE_REGISTRY=192.168.77.77:5000 ENV_DIR=`pwd`/bin
```

This generates the `hcf-ucp.json` file containing the UCP service definition for
the current set of roles. Register the service with UCP:

```bash
curl -H "Content-Type: application/json" -XPOST -d @/home/vagrant/hcf/hcf-ucp.json http://192.168.200.3:30000/v1/services
```

### Generate an instance definition (#1) ###

You can use the `~/hcf/ucp/hcf-ucp-instance.json` sample configuration to create
an instance of the newly registered service:

```json
{
    "name": "hcf",
    "version": "0.0.0",
    "vendor": "HPE",
    "labels": ["my-hcf-cluster"],
    "instance_id": "my-hcf-cluster",
    "description": "HCF test cluster"
}
```

Remember the `instance_id`, here `my-hcf-cluster`, which is the name to use when
talking to UCP about it.

To instantiate the service, post the instance definition to UCP:

```bash
curl -H "Content-Type: application/json" -XPOST -d @/home/vagrant/hcf/ucp/hcf-ucp-instance.json http://192.168.200.3:30000/v1/instances
```

### Follow the Kubernetes log (#2) ###

Once the instance definition has been posted there should be plenty of activity
on the log.

Alternatively, for just a list of events for this new instance, you can run:

```bash
kubectl get events --namespace=my-hcf-cluster --watch
```

### Setting up hcf-status on UCP (#3) ###

To install all the files necessary to run `hcf-status` you need to follow these steps:

```bash
cd ucp-developer
~/hcf/bin/install-hcf-status-on-ucp.sh
vagrant ssh node
# Then, inside the VM
sudo su
/home/vagrant/hcf/opt/hcf/bin/hcf-status
```

It takes a long time to start HCF on UCP in vagrant (up to 30 minutes).

Use `docker ps --filter label=role=XXX` to find HCF containers to interact with, e.g.

```bash
docker exec -it $(docker ps -a -q --filter label=role=api) bash
```

Here is a bash function to display the full Monit status for a container:

```bash
get-container-id() { docker ps -a -q --filter=name="k8s_${1}\\..*my-hcf-cluster" ; }
enter() { docker exec -t -i $(get-container-id "$1") /bin/bash ; }
m() { docker exec -t $(get-container-id "$1") curl -u monit_user:monit_password http://localhost:2822/_status ; }

m api
```

### Forward host ports to UCP (#4) ###

The `setup_ports.sh` script will setup ssh forwarding ports from the host to the
HCF instance. The script does not return to the shell; press ^C to terminate
when you are done.

```bash
cd ucp-developer
sudo ./setup_ports.sh my-hcf-cluster `ipconfig getifaddr en0`
```

### Push a sample app (#5) ###

Check `hcf-status` (shell #3) to make sure HCF is all up and running, and then
target it from the host:

```bash
cd node-env
cf api --skip-ssl-validation https://api.`ipconfig getifaddr en0`.nip.io
cf auth admin changeme
cf create-org hpe
cf target -o hpe
cf create-space myspace
cf target -o hpe -s myspace
cf push
```
