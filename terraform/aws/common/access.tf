# # ## ###
## Section: ucloud access configuration

variable "public_key_file" {
	description = "Public key file for the AWS key pair to import"
}

variable "private_key_file" {
	description = "Private key file for the AWS key pair to import. Used to configure host connection"
}

variable "skip_ssl_validation" {
    default     = "false"
    description = "Skip SSL validation when interacting with AWS"
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.cluster_prefix}-admin-key"
  public_key = "${file("${var.public_key_file}")}"
}
