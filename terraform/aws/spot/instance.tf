# # ## ###
## Section: Instance types: Spot instances

variable aws_instance_type {
    description = "AWS EC2 instance type for each node type"
    default = {
        "ucloud"       = "c4.xlarge" # spots /just for here, in case we have to increase
        "core"         = "t2.medium"
        "dea"          = "t2.medium"
        "dataservices" = "t2.medium"
        "controller"   = "t2.medium"
        "router"       = "t2.medium"
        "proxy"        = "c4.xlarge"
    }
}
