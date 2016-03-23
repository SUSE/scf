# How to use the AWS terraform setup.

## Files in the archive

* `aws.tfvars.example`

  An example file demonstrating the variables the user can (and in
  some cases 'has to') modify to get a proper setup.

* `hcf-aws.tf`

  The main terraform configuration, containing the fixed parts of the
  setup at the beginning, followed by a series of variables whose
  values are provided by HCF's `roles-manifest.yml`.

## Usage

* Copy `aws.tfvars.example` to `aws.tfvars` and then edit the
  configuration to suit the environment (keys, etc). See the
  comments in the file itself.

  Note: If a filename other than `aws.tfvars` is chosen then all
  instances of `aws.tfvars` in the commands below must be replaced
  with the actual name of the file.

* Ensure that the following variables for access to Amazon AWS in
  general are defined in the local environment, with the information
  of the user doing the access:

```bash
export AWS_ACCESS_KEY_ID="..." 
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-west-2"
```

  This information can be extracted from AWS when the user in question
  is created.

* Run

```bash
   terraform plan -var-file=aws.tfvars .
```

  This checks that everything is ok. Terraform should __not__ ask for
  the value of any variable.

* Run

```bash
   terraform apply -var-file=aws.tfvars .
```

  to set up the specified configration.


# Troublespots

## Certificates and other secrets

Until ENV_DIR support lands in the Makefile my workaround is to

```
  -DTR := --dtr=${IMAGE_REGISTRY} --dtr-org=${IMAGE_ORG} --hcf-version=${BRANCH} --hcf-prefix=${IMAGE_PREFIX}
  +DTR := --env-dir=${CURDIR}/bin --dtr=${IMAGE_REGISTRY} --dtr-org=${IMAGE_ORG} --hcf-version=${BRANCH} --hcf-prefix=${IMAGE_PREFIX}
```

in the Makefile to ensure that the generated `.tf` files contain the
certs data.

## Terraform

If you see

```
  Errors:
    * provider.aws: : invalid or unknown key: insecure
```

upgrade your installation of ```terraform``` to version 0.6.12 or
higher.

## ACL destruction

TF claims that it is sucessfully destroying the ACL.

It is not.

The ACL must be destroyed manually.

See next section for information about the AWS web console.

## AWS Web console

The important sections are EC2 and VPC.

   * (https://us-west-2.console.aws.amazon.com/vpc/home?region=us-west-2#acls:)[VPC]

      * Your VPC
      * Subnets
      * Internet Gateway
      * Network ACLs

   * (https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#Instances:sort=tag:Name)[EC2]

      *	Instances
      *	Security Groups
      *	Key Pairs

## Docker Trusted Registry

The account information (name, password) in the provided example
.tfvars file is __fixed__. Do __not change__ that part.
