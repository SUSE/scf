output "api_endpoint" {
    value = "https://api.${openstack_networking_floatingip_v2.hcf-core-host-fip.address}.${var.domain}"
}
