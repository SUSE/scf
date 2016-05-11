# # ## ###
## Section: Core provisioner: Proxy setup, no operation, proxying is disabled.

resource "null_resource" "core_setup_proxy" {
    depends_on = [ "null_resource.core_setup_prep" ]

    triggers = {
        dummy = "dummy"
    }

    provisioner "local-exec" {
        command = "printf '\\033[0;31;1m ==> No proxying <== \\033[0m\\n'"
    }
}
