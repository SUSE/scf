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
  For more information, you can find [its github repo here](https://github.com/hpe-cloud-garage/cloudstrap),
  but you do not need to clone it.  
  As of this guide, latest version is `0.37.6.pre`.

* Install the cloudstrap gem: `gem install --pre cloudstrap`

* Create a `config.yaml` in the checkout directory. Contents should be

  ```
	---
	region: us-east-1
	hdp_bootstrap_origin: https://s3-us-west-2.amazonaws.com/hcp-concourse
	hdp_bootstrap_version: 1.2.52+master.24b7b25.20160920215359
	properties_seed_url: '-'
  ```

  Do not change the region. That is the region __dev__ is allowed to use.

  The `hdp_bootstrap_version` entry determines the version of HCP
  getting installed and initialized. This must be changed as needed.  
  
  You might also need to change the `hdp_bootstrap_origin` url if you are
  using an internal release. The `hdp_bootstrap_origin` and `hdp_bootstrap_version`
  entries combine to create the download link of HCP. In the above example:  
  `https://s3-us-west-2.amazonaws.com/hcp-concourse/hcp-bootstrap_1.2.52+master.24b7b25.20160920215359_amd64.deb`  
  Check out the [HCP Release Notes](https://github.com/hpcloud/cnap/wiki/HCP-Release-Notes)
  to find the download link for the version you want.

  The `properties_seed_url` is an URL to your `bootstrap.properties` seed file.
  If you have a local `bootstrap.properties` file in your working directory, cloudstrap
  will ignore this URL and use your local file. However, it still cannot be omitted
  or an empty string. Putting a bogus value is fine. (`-`)

* Get a `bootstrap.properties` file, place it next to the
  `config.yaml`. That is actually a template Cloudstrap will fill in,
  for use by the HCP bootstrap process.
  
  Although cloudstrap does not read the values of this `bootstrap.properties`,
  as of `0.37.6.pre`, it is still required.

  Here is a good one from Eric:
  
  ```
  Provider=AWS
  NodeCount=2
  AWS.AccessKey=
  AWS.SecretKey=
  AWS.Region=us-east-1
  AWS.AvailabilityZones=us-east-1e
  AWS.MasterInstanceType=t2.medium
  AWS.NodeInstanceType=m4.xlarge
  AWS.GlusterFSInstanceType=t2.medium
  AWS.Windows2012R2InstanceType=m4.xlarge
  AWS.LinuxAMI=ami-8fe79998
  AWS.Windows2012R2AMI=ami-8d0acfed
  AWS.KeyFileContents=
  AWS.KeypairFile=/home/ubuntu/.ssh/id_rsa
  AWS.Keypair=
  AWS.JumpboxCIDR=0.0.0.0/0
  AWS.VPCID=vpc-ba3d01dd
  AWS.PublicSubnetIDsAndAZ=subnet-7727da4b:us-east-1e
  AWS.PrivateSubnetIDsAndAZ=subnet-7327da4f:us-east-1e
  OpenStack.CACertFile=<<Path to PEM formatted CACert used to authenticate the OpenStack APIs>>
  OpenStack.AuthURL=<<OpenStack Keystone URL e.g. https://MyHelionCloud.example.com:5000/v3>>
  OpenStack.Username=<<OpenStack Keystone Username>>
  OpenStack.Password=<<OpenStack Keystone Password>>
  OpenStack.DomainID=<<OpenStack Keystone Domain ID>>
  OpenStack.DomainName=<<OpenStack Keystone Domain Name>>
  OpenStack.TenantID=<<OpenStack Keystone Project ID>>
  OpenStack.TenantName=<<OpenStack Keystone Project Name>>
  OpenStack.RegionName=<<OpenStack Keystone Region to use>>
  OpenStack.AvailabilityZone=<<OpenStack Nova availability zone to use>>
  OpenStack.LinuxImageID=<<OpenStack Glance Image ID for Ubuntu 14.04>>
  OpenStack.Windows2012R2ImageID=<<OpenStack Glance Image ID for Microsoft Windows Server 2012R2>>
  OpenStack.MasterFlavorID=<<OpenStack Nova Flavor ID to use>>
  OpenStack.NodeFlavorID=<<OpenStack Nova Flavor ID to use>>
  OpenStack.GlusterFSFlavorID=<<OpenStack Nova Flavor ID to use>>
  OpenStack.Windows2012R2FlavorID=<<OpenStack Nova Flavor ID to use>>
  OpenStack.Keypair=<<OpenStack Nova Keypair Name (must exist in Nova)>>
  OpenStack.KeypairFile=<<Path to PEM formatted private key, matching the keypair provided to Nova>>
  OpenStack.JumpboxCIDR=<<IP OF M/C RUNNING COMMAND FROM>>/32
  OpenStack.NetworkID=<<OpenStack Neutron network ID to use>>
  OpenStack.SubnetID=<<OpenStack Neutron subnet ID to use>>
  OpenStack.PoolName=<<OpenStack Neutron external network name to use>>
  OpenStack.PoolID=<<OpenStack Neutron external network ID to use>>
  VSphere.Username=
  VSphere.Password=
  VSphere.Server=
  VSphere.Insecure=
  VSphere.NetworkName=
  VSphere.LBVIPAllocationStart=
  VSphere.LBVIPAllocationEnd=
  VSphere.LBVirtualRouterID=
  VSphere.CIDataISO=
  VS phere.Datastore=
  VSphere.Datacenters=
  VSphere.Cluster=
  VSphere.KeypairFile=
  VSphere.LinuxVMDKSource=
  VSphere.Windows2012R2VMDKSource=
  VSphere.DiskType=<<eager_zeroed, lazy, or thin>>
  VSphere.MasterNumVCPUs=
  VSphere.MasterMemoryMB=
  VSphere.NodeNumVCPUs=
  VSphere.NodeMemoryMB=
  VSphere.GlusterFSNumVCPUs=
  VSphere.GlusterFSMemoryMB=
  VSphere.Windows2012R2NumVCPUs=
  VSphere.Windows2012R2MemoryMB=
  HCPDomainName=hcf.yourname.stacktest.io
  LDAP.URI=ldap://52.87.217.102
  LDAP.BindUserDN=cn=admin,ou=Users,dc=test,dc=com
  LDAP.BindPassword=afbcc51d-0cd2-4e73-bff6-1d1958103ab7
  LDAP.UserSearchBase=ou=Users,dc=test,dc=com
  LDAP.UserSearchFilter=cn={0}
  LDAP.GroupSearchBase=ou=scopes,dc=test,dc=com
  LDAP.GroupSearchFilter=member={0}
  LDAP.ProviderName=arthur
  ```

  I'm not sure if cloudstrap actually needs it, but for safety, I would set 
  the __HCPDomainName__ to your chosen domain name.

* Run `cloudstrap`. Be sure to use your __dev__ account.

  When it fails, run it again, until it suceeds. The app saves
  information about the things it creates in a `.cache` subdirectory
  of the CWD. Each run will check that cache and reuse the
  already-made parts.

  Errors to expect on the first runs are

  ```
  The (entity) ID '(bla)' does not exist
  ```
  
  or 
 
  ```
  Your Jumpbox is in a state other than running
  ```

  This looks to be a race condition, where Cloudstrap is faster than
  AWS, i.e. it provisions X and then does something else with X, but
  AWS has not completed creating X yet.  
  Try again after a couple minutes and it should work.

  Another error to ignore is

  ```
  bootstrap_agent.rb:356:in `map': undefined method `public_ip' for nil:NilClass (NoMethodError)
  ```
  
* When cloudstrap is done read the log (you have redirected the output
  into a `|tee LOG`, have you?!) to find the IP address of the __jump
  box__. Look near the end, for a line containing `ubuntu@IP-ADDRESS`.
  The `IP-ADDRESS` is what we want.

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
