# # ## ###
## Section: AMI selection

variable "amazon_images" {
    description = "Amazon AMIs of plain/vanilla Ubuntu 14.04 LTS ebs:hvm"
    # Note: t2.medium (see above) does not support AMIs using instance-store.
    # Note: t2.medium (see above) does not support AMIs using vir-type != HVM.
    # See
    #   https://cloud-images.ubuntu.com/locator/ec2/
    # for website to find such images
    default = {
        us-east-1      = "" # Northern Virginia
        us-west-2      = "ami-21b85141" # Oregon
        us-west-1      = "" # Northern California
        eu-west-1      = "" # Ireland
        eu-central-1   = "" # Frankfurt
        ap-southeast-1 = "" # Singapore
        ap-southeast-2 = "" # Sydney
        ap-northeast-1 = "" # Tokyo
        sa-east-1      = "" # Sao Paulo
    }
}
