
# How to use the MPC terraform setup.

## Files in the archive

* `mpc.tfvars.example`

  An example file demonstrating the variables the user can (and in
  some cases 'has to') modify to get a proper setup.

* `hcf.tf`

  The main terraform configuration, containing the fixed parts of the
  setup at the beginning, followed by a series of variables whose
  values are provided by HCF's `roles-manifest.yml`.

## Usage

* Copy `mpc.tfvars.example` to `mpc.tfvars` and then edit the
  configuration to suit the environment (openstack network, tenant,
  user, password, etc). See the comments in the file itself.

  Note: If a filename other than `mpc.tfvars` is chosen then all
  instances of `mpc.tfvars` in the commands below must be replaced
  with the actual name of the file.

* Source the file `openrc.sh` into the local environment.

  This file is supplied by MPC/Openstack when the user account was
  created.

* Run

```
   tf plan -var-file=mpc.tfvars .
```

  This checks that everything is ok. Terraform should __not__ ask for
  the value of any variable.

* Run

```
   tf apply -var-file=mpc.tfvars .
```

  to set up the specified configration.
