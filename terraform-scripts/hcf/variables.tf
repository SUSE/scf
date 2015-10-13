variable "registry_host" {
	default = "15.126.242.125:5000"
}

variable "container-host-count" {
	default = "1"
	# default really should be 3
	description = "Number of container hosts to create"
}

variable "key_file" {
	description = "Private key file for newly created hosts"
}

variable "cf-release" {
	default = "217"
}

variable "openstack_network_id" {}
variable "openstack_network_id" {}
variable "openstack_keypair" {}
variable "openstack_availability_zone" {}

variable "openstack_flavor_id" {
	default = "104"
}

variable "openstack_base_image_id" {
	default = "564be9dd-5a06-4a26-ba50-9453f972e483"
}

variable "openstack_floating_ip_pool" {
	default = "Ext-Net"
}

variable "dea_count" {
	default = "1"
}

variable "core_volume_size" {
	default = "40"
}

# Secrets
variable "droplet_directory_key" {
	default = "the_key"
}
variable "buildpack_directory_key" {
	default = "bd_key"
}
variable "staging_upload_user" {
	default = "username"
}
variable "staging_upload_password" {
	default = "password"
}
variable "bulk_api_password" {
	default = "password"
}
variable "db_encryption_key" {
	default = "the_key"
}
variable "ccdb_role_name" {
	default = "ccadmin"
}
variable "ccdb_role_password" {
	default = "admin_password"
}
variable "ccdb_role_tag" {
	default = "admin"
}

variable "uaadb_username" {
	default = "uaaadmin"
}
variable "uaadb_password" {
	default = "uaaadmin_password"
}

variable "domain" {
	default = "xip.io"
}

variable "loggregator_shared_secret" {
	default = "loggregator_endpoint_secret"
}

variable "nats_user" {
	default = "nats_user"
}
variable "nats_password" {
	default = "nats_password"
}

variable "router_ssl_cert_file" {}
variable "router_ssl_key_file" {}
variable "router_cipher_suites" {
	default = "TLS_RSA_WITH_RC4_128_SHA:TLS_RSA_WITH_AES_128_CBC_SHA"
}
variable "router_status_username" {
	default = "router_user"
}
variable "router_status_password" {
	default = "router_password"
}

variable "uaa_admin_client_secret" {
	default = "admin_secret"
}
variable "uaa_batch_username" {
	default = "batch_username"
}
variable "uaa_batch_password" {
	default = "batch_password"
}
variable "uaa_cc_client_secret" {
	default = "cc_client_secret"
}
variable "uaa_clients_app-direct_secret" {
	default = "app-direct_secret"
}
variable "uaa_clients_developer_console_secret" {
	default = "developer_console_secret"
}
variable "uaa_clients_notifications_secret" {
	default = "notification_secret"
}
variable "uaa_clients_login_secret" {
	default = "login_client_secret"
}
variable "uaa_clients_doppler_secret" {
	default = "doppler_secret"
}
variable "uaa_cloud_controller_username_lookup_secret" {
	default = "cloud_controller_username_lookup_secret"
}
variable "uaa_clients_gorouter_secret" {
	default = "gorouter_secret"
}
variable "uaa_scim_users" {
	default = "admin|fakepassword|scim.write,scim.read,openid,cloud_controller.admin,doppler.firehose"
}

