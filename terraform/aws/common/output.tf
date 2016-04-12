# # ## ###
## Section: Cloud API - Exported to user

# output "environment" {
#     value = "${null_resource.rm_configuration.triggers.rm_configuration}"
# }

output "floating_ip" {
    value = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}"
}

output "floating_domain" {
    value = "${null_resource.PUBLIC_IP.triggers.PUBLIC_IP}.nip.io"
}

