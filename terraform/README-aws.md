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
