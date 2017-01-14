# Setting up the combination of HCF on HCP on AWS

## AWS

* Under the federated system you have __two__ accounts, one for
  non-production develeopment (__nonprod-dev__), and for production
  work (__prod__).

* Get the AWS keys (access and secret) for the __nonprod-dev__ account.
  You can find them under the __IAM__ service on AWS.  
  (The DNS setup used to require the prod account, but can now be done under the dev account.)  
  You will need to put them in `~/.aws/credentials` as that is where cloudstrap will look.
  
  The credentials file looks like this:
  ```
  [default]
  aws_access_key_id = AXXXXXXXXXXXXXXXXXXX
  aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  ```

* Ask DevOps to create a __Hosted Zone__ for you. Our standard for the
  name of the zone is `<yourname>.stacktest.io`. This will be refered
  to as __(HZ)__ in the following text.

  This is where the DNS entries will go later.

## Cloudstrap

* Cloudstrap is a helper tool to automate the whole bootstrap process
  for HCP, starting from setting up the k8 cluster to initializing it
  and starting HCP/HSM.  

  For more information, you can find
  [its github repo here](https://github.com/hpe-cloud-garage/cloudstrap),
  but you do not need to clone it.  

  As of this guide, latest version is `0.48.0.pre`.

* Install the cloudstrap gem: `gem install --pre cloudstrap`

  The installed commands are

  |-|-|
  |cloudstrap		|Create a cluster|
  |cloudstrap-config	|Show the complete configuration|
  |cloudstrap-cache	|Show the AWS parts cloudstrap knows about|
  |cloudstrap-dns	|Checks the DNS setup|
  |cloudstrap-env	|Shows the bootstrap configuration
  |cloudstrap-teardown	|Tears a cloudstrap config down|
  |cloudstrap-versions	|Show current vs latest versions of cloudstrap and related tools|

* If `cloudstrap-versions` does not show the latest versions of `hcp`,
  `hsm`, etc. in use it is time to update. See the
      [HCP Release Notes](https://github.com/hpcloud/cnap/wiki/HCP-Release-Notes)
  and [HSM Release Notes](https://github.com/hpcloud/cnap/wiki/HSM-Release-Notes)
  for the relevant links and instructions.




* Create a `config.yaml` in the cluster management directory. Contents should look similar to

  ```
	---
	domain_name: x.from-the.cloud
	region: us-east-1
	hcp_bootstrap_package_url: https://dev.stackato.com/downloads/hcp/bootstrap/hcp-bootstrap_0.10.17-0-g00c31fc_amd64.deb

	minimum_availability_zones: 1
	maximum_availability_zones: 1

	master_count:  1
	node_count:    3
	gluster_count: 2
  ```

  Do not change the region. That is the region __dev__ is allowed to use.

  The domain name has to be your host zone (see previous points).

  Keep the `hcp_bootstrap_package_url` in sync with your `hcp`.
  See above for the link to the HCP release notes which has the link to use.

  Increment the `maximum_availability_zones` for multi-AZ setup.

* Get a `bootstrap.properties` file, and place it next to the
  `config.yaml`. That is actually a template Cloudstrap will fill in,
  for use by the HCP bootstrap process.

  This means that the original blank template should be saved, and
  whenever a new cluster is made start from that blank file.

  A good source of a proper blank template is the file
  `cmd/bootstrap/sample_bootstrap.properties` in the repository
  `hpcloud/hdp-resource-manager`.

  No editing is needed, just copy this file to `bootstrap.properties`.

* Run `cloudstrap`. Be sure to use your __dev__ account.

  When it fails, run it again, until it suceeds. The app saves
  information about the things it creates in a `.cache` subdirectory
  of the CWD. Each run will check that cache and reuse the
  already-made parts.

  The command `cloudstrap-cache` prints the contents of this cache in
  a readable format. While normally some fancy formatting is used this
  can be disabled by directing the output into a file or pipe.

* By setting the environment variable
  `BOOTSTRAP_WITHOUT_HUMAN_OVERSIGHT` to `true` before invoking
  cloudstrap, cloudstrap will run the HCP bootstrap by itself.

  Without that variable cloudstrap will only setup and configure the
  jumpbox and then tell the user how to run bootstrap themselves.

* Note, when bootstrap fails a simple redo via cloudstrap is not
  possible.  It is necessary to tear the partial cluster down (see
  later section) before re-starting the setup.

* After the setup completed (including bootstrap) read the log (you
  have redirected the output into a `|tee LOG`, have you?!) to find
  the IP address of the __jump box__. Look near the end, for a line
  containing `ubuntu@IP-ADDRESS`.  The `IP-ADDRESS` is what we want.

* `export JUMPBOX_IP=<IP-ADDRESS>` just for convenience.

* Run the command `scp -i .ssh/*/!(*.pub) ubuntu@$JUMPBOX_IP:bootstrap-*.log`

  The directory `.ssh` contains the ssh key-pair created by Cloudstrap
  for access to the jump box. Two files, one ending in `.pub`. We want
  the other, the private key for the `scp`.

  (Note to cloudstrap: Give the private key a nice extension as well,
  to make the above command a bit easier (*.key, or some such))

* The log file the previous step pulled from the jump box contains the username
  and password of the HCP instance. Look for lines containing `password`.  
  (It also contains information about DNS entries if you need to create them manually.)

* You can now run `cloudstrap-dns`, which will set the DNS entries automatically.
  As of this version, it doesn't read the region from config.yaml so you'll need to
  add it as an environment variable: `export AWS_REGION=us-east-1`

## Teardown

* To tear a cluster down run the tool `cloudstrap-teardown` with the
  name of the VPC created during setup.

  This name can be found via `cloudstrap-cache`. For example

  ```
	vpc=$(bin/cloudstrap-cache | awk '/vpc_id/ { print $2 }')
	cloudstrap-teardown $vpc
  ```

* __Note!__

  * I am told that it is necessary to manually delete the ELBs before
    invoking the tool. They are found under `EC2 / Load Balancing /
    Load Balancers`

  * The tool may fail to delete the VPC (possibly due to timeouts).

    If that happens it is necessary to manually delete the instances
    of the cluster, and possibly the VPC itself before invoking the
    tool again.

* After `cloudstrap-teardown` was run successfully delete either the
  entire cluster directory, or just the `.ssh` and `.cache`
  sub-directories.

* We are now ready to setup a new cluster. See previous section.


## HCP

* With Cloudstrap done and the DNS entries made HCP should be reachable.
  Try

  ```
  hcp api https://hcp.(HCPDomainName):443 --skip-ssl-validation
  hcp login -u (USER) -p (PASSWORD)
  ```

  The username and password to use are also in the `bootstrap-*.log`
  we got in the previous section, just after the DNS information.

* The HSM service management should also be available.
  Try

  ```
  hsm api https://hsm.(HCPDomainName):443 --skip-ssl-validation
  hsm login -u (USER) -p (PASSWORD)
  ```

## HCF

Do you want an instance of a released HCF version, or of your own branch?

### Using an already released SDL (for regular HCF versions):

* `hsm get-service stackato.hpe.hcf` to find all available SDL versions

* Get the `instance.json` (IDL) corresponding to your version from the 
  [HCF Release Notes](https://github.com/hpcloud/cnap/wiki/HCF-Release-Notes)
  
  Make sure to set the parameters of the `instance.json`. Set `DOMAIN` to `hcf.<HCP Domain>` 
  and the cluster admin password to what you want.
  
* `hsm create-instance stackato.hpe.hcf <product version> -i instance.json --sdl-version <sdl version>`

* `hsm list-instances` to check the name and the status of your instance

* Once done and running, you need to create a DNS entry to your HCF instance.

  `hsm get-instance <instance name>` will give you component information of your instance.  
  Find the `router` service, and copy the associated "Location" URL. It looks like this:  
  `a224b7c27ad3111e6835106db8afc919-623876513.us-east-1.elb.amazonaws.com:80`  
  (In HCF versions prior to 1.2.17, this will be the `ha-proxy` service instead)
  
  On AWS, under the Route 53 service, find your Hosted Zone and create this DNS entry:  
  `*.hcf.<HCP domain name>. CNAME <router location URL>`
  
* Give it a minute to update the DNS records, then you should be able to connect to your HCF instance:  
  `cf api https://api.hcf.williamg.stacktest.io --skip-ssl-validation`
  

### Getting the SDL and IDL of a custom branch:

* Use jenkins to build the images for the branch B you wish to test.

* Checkout HCF, go to branch B.

* Edit the `DOMAIN` in `bin/settings/network.env`, and disable the
  `unset DOMAIN` commands in `bin/settings/hcp/hosts.env` and
  `bin/settings/hcp/network.env`

  Using the (HCPDomain) for `DOMAIN` should be ok.

* Start a vagrant box pointing to your checkout holding branch B

* Run the command

  ```
  bin/generate-dev-certs.sh -e bin/settings/ -e bin/settings/hcp/ bin/settings/certs.env
  ```

  to generate the proper certs for the HCP environment.

* Run the command `make hcp-dist` to generate the service and instance
  definitions. (`.json` files).

* Take the resulting zip file over to the directory where cloudstrap
  was used to set things up, create a directory `output`, and unpack
  the zip in that directory.

* __...__ TODO: Upload the service definition, create an instance,
  play with the resulting HCF.
