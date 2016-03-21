
# How to use the MPC terraform setup.

## Files in the archive

* mpc-example.tfvars

  An example file demonstrating the variables the user can (and in
  some cases 'has to') modify to get a proper setup.

* hcf.tf

  The main terraform configuration, containing the fixed parts of the
  setup at the beginning, followed by a series of variables whose
  values are provided by HCF's roles-manifest.yml.

## Usage

* Copy mpc-example.tfvars to a file of your choice, and edit the
  configuration to suit the environment (openstack network, tenant,
  user, password, etc).

  In the following text it is assumed that this file is named FOO.

  If a different name was chosen all instances of FOO below must be
  replaced with the actual name of the fil.e


* Source the openrc.sh into the local environment.

* Run

```
   tf plan -var-file=FOO .
```

  This checks that everything is ok. Terraform should __not__ ask for
  the value of any variable.

* Run

```
   tf apply -var-file=FOO .
```

  to set up the specified configration.
