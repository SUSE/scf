# Setting up the combination of HCF on HCP on AWS

## AWS

* Under the federated system you have __two__ accounts, one for
  non-production develeopment (__nonprod-dev__), and for production
  work (__prod__).

* Get the AWS keys (access and secret) for both. While most of the
  work has to happen under __dev__ the DNS setup must be done under
  __prod__.

* Ask DevOps to create a __Hosted Zone__ for you. Our standard for the
  name of the zone is `<yourname>.stacktest.io`. This will be refered
  to as __(HZ)__ in the following text.

  This were the DNS entries will go later.

## Cloudstrap

* Cloudstrap is a helper tool to automate the whole bootstrap process
  for HCP, starting from setting up the k8 cluster to initializing it
  and starting HCP/HSM.

* Get it from `git@github.com:hpe-cloud-garage/cloudstrap`

* Follow the install instructions in its `README.org`. Do not start anything yet.

* Create a `config.yaml` in the checkout directory. Contents should be

  ```
	---
	region: us-east-1
	hdp_bootstrap_origin: https://s3-us-west-2.amazonaws.com/hcp-concourse
	hdp_bootstrap_version: 1.2.52+master.24b7b25.20160920215359
	properties_seed_url: ''
  ```

  Do not change the region. That is the region __dev__ is allowed to use.

  The `properties_seed_url` entry cannot be changed either. Without it
  cloudstrap will throw a Contract validation error at you.

  The `hdp_bootstrap_version` entry determines the version of HCP
  getting installaed and initialized. This must be changed as needed.

* Get a `bootstrap.properties` file, place it next to the
  `config.yaml`. That is actually a template Cloudstrap will fill in,
  for use by the HCP bootstrap process.

  Mark has a good one.

  The main thing to add/change in that template is the __HCPDomainName__.
  Following Mark's example I set that to __aws.hcp.(HZ)__.

* Run `cloudstrap`. Be sure to use your __dev__ account.

  When it fails, run it again, until it suceeds. The app saves
  information about the things it creates in a `.cache` subdirectory
  of the CWD. Each run will check that cache and reuse the
  already-made parts.

  Errors to expect on the first runs are

  ```
  The (entity) ID '(bla)' does not exist
  ```

  This looks to be a race condition, where Cloudstrap is faster than
  AWS, i.e. it provisions X and then does something else with X, but
  AWS has not completed creating X yet.

  Another error to ignore is

  ```
  bootstrap_agent.rb:356:in `map': undefined method `public_ip' for nil:NilClass (NoMethodError)
  ```
  
* When cloudstrap is done read the log (you have redirected the output
  into a `|tee LOG`, have you?!) to find the IP address of the __jump
  box__. Look near the end, for a line containing `ubuntu@IP-ADDRESS`.
  The `IP-ADDRESS` is what we want.

* Run the command `scp -i .ssh/*/*(^.pub) ubuntu@IP-ADDRESS:bootstrap-*.log`

  The directory `.ssh` contains the ssh key-pair created by Cloudstrap
  for access to the jump box. Two files, one ending in `.pub`. We want
  the other, the private key for the `scp`.

  (Note to cloudstrap: Give the private key a nice extension as well,
  to make the above command a bit easier (*.key, or some such))

* The log file the previous step pulled from the jump box contains the
  information about the DNS entries we have to create in our __(HZ)__.

  Look for lines containing the chosen HCPDomain.

  Entering the DNS entries must be done under your __prod__ account.
  Currently we have no tool that, except the AWS console.

  __Note:__ All the `A` records must be entered as `Alias`es.

## HCP

* With Cloudstrap done and the DNS entries made HCP should be reachable.
  Try

  ```
  hcp api https://hcp.(HCPDomainName):443
  hcp login (USER) -p (PASSWORD)
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
