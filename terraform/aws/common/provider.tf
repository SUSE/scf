# # ## ###
## Section: AWS ucloud

provider "aws" {
    region   = "${var.aws_region}"
    insecure = "${var.skip_ssl_validation}"
}
