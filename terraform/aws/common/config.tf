# # ## ###
## Section: Basic cluster config

variable "cluster_prefix" {
    description = "Prefix prepended to all cluster resources (volumes, hostnames, security groups)"
    default     = "hcf"
}

variable aws_region {
    description = "The region to operate the ucloud from"
    default     = "us-west-2"
}

variable aws_zone {
    description = "The availability zone (within the region) to operate the ucloud from"
    default     = "us-west-2c"
}
