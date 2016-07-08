# Running HCF on HCP via Vagrant #

This tutorial assumes you are going to run commands in 5 shell sessions:

1. ssh session to HCF vagrant box (in `~/hcf`)
2. ssh session to HCP master (in `~/hcp-developer`)
3. ssh session to HCP node (in `~/hcp-developer`)
4. ssh tunnel to HCP node (in `~/hcp-developer`)
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

### Start up the HCP vagrant boxes (#2) ###

It takes a while to start up HCP, so you want to start this early.  You need to
provide the address of the docker registry for HCF images; here we use a local
registry inside the HCF vagrant box:

```bash
tar xfz hcp-developer-1.0.xxx+master.hhhhhhhh.yyymmddhhmmss.tar.gz
cd hcp-developer
INSECURE_REGISTRY=192.168.77.77:5000 vagrant up --provider vmware_fusion
```

### Create a local Docker registry (#1) ###

Then push all the HCF images to it:

```bash
make registry
make tag IMAGE_REGISTRY=localhost:5000
make publish IMAGE_REGISTRY=localhost:5000
```

### Make sure HCP is running (#2) ###

Once the `vagrant up` command is complete, log into the master and verify that
all pods are running:

```bash
vagrant ssh master
kubectl get pods --namespace=hcp
```

You will see output like this:

```
vagrant@k8-master:~$ kubectl get pods --namespace=hcp
NAME              READY     STATUS             RESTARTS   AGE
ident-api-p6svw   1/1       Running            0          27m
ipmgr-ivexp       1/1       Running            0          27m
rpmgr-76ave       1/1       Running            0          27m
```

Take note of the `ipmgr` instance name, in this case `ipmgr-ivexp`, and then
view the logs like this:

```bash
kubectl logs -f ipmgr-ivexp --namespace=hcp
```

### Configure HCF with the host IP address (#5) ###

Use your host IP address for `DOMAIN` settings in the instance
definition file you're using. The examples have a "parameters" section
that sets this value.

### Generate HCP service definitions (#1) ###

Back inside the HCF vagrant box run:

```bash
make hcp IMAGE_REGISTRY=192.168.77.77:5000 ENV_DIR=$PWD/bin/settings-hcp
```

This generates the `hcf-hcp.json` file containing the HCP service definition for
the current set of roles.

### Register the service with HCP:

```bash
PORT=$(curl -Ss http://192.168.200.2:8080/api/v1/namespaces/hcp/services/ipmgr | jq --raw-output '.spec.ports[0].nodePort')
curl -H "Content-Type: application/json" -XPOST -d @/home/vagrant/hcf/hcf-hcp.json http://192.168.200.3:$PORT/v1/services
```

### Generate an instance definition (#1) ###

```bash
make hcp-instance IMAGE_REGISTRY=192.168.77.77:5000 ENV_DIR=$PWD/bin/settings-hcp
# or
make hcp-instance-ha IMAGE_REGISTRY=192.168.77.77:5000 ENV_DIR=$PWD/bin/settings-hcp/ha
```

Or instead of running `make hcp-instance`, you can use the `~/hcf/hcp/hcf-hcp-instance.json` sample configuration to create an instance of the newly registered service:

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

*NOTE*: Ensure that the `name`, `version`, and `vendor` fields in the instance definition match the same fields in the service definition.

Remember the `instance_id`, here `my-hcf-cluster`, which is the name to use when
talking to HCP about it.

To instantiate the service, post the instance definition to HCP:

```bash
curl -H "Content-Type: application/json" -XPOST -d @/home/vagrant/hcf/hcf-hcp-instance.json http://192.168.200.3:$PORT/v1/instances
```

where `$PORT` is set above.

### Follow the Kubernetes log (#2) ###

Once the instance definition has been posted there should be plenty of activity
on the log.

Alternatively, for just a list of events for this new instance, you can run:

```bash
kubectl get events --namespace=my-hcf-cluster --watch
```

### Setting up hcf-status on HCP (#3) ###

To install all the files necessary to run `hcf-status` you need to follow these steps:

```bash
cd hcp-developer
~/hcf/bin/install-hcf-status-on-hcp.sh
vagrant ssh node
# Then, inside the VM
sudo su
/home/vagrant/hcf/opt/hcf/bin/hcf-status
```

It takes a long time to start HCF on HCP in vagrant (up to 30 minutes).

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

### Forward host ports to HCP (#4) ###

The `setup_ports.sh` script will setup ssh forwarding ports from the host to the
HCF instance. The script does not return to the shell; press ^C to terminate
when you are done.

```bash
cd hcp-developer
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
cf push node-env
```
