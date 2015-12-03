variable "registry_host" {
	default = "15.126.242.125:5000"
}

variable "cluster-prefix" {
	description = "Prefix prepended to all cluster resources (volumes, hostnames, security groups)"
	default = "hcf"
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
variable "openstack_network_name" {}
variable "openstack_keypair" {}
variable "openstack_availability_zone" {}

variable "openstack_region" {
	default = "us-east"
}

variable "openstack_flavor_id" {
	default = {
		core = "103" # standard.large   8GB
		dea  = "102" # standard.medium  4GB
		test = "101" # standard.small   2GB
	}
}

variable "openstack_base_image_id" {
	default = {
		us-east = "564be9dd-5a06-4a26-ba50-9453f972e483"
		us-west = "43804523-7e3b-4adf-b6df-9d11d451c463"
	}
}

variable "openstack_floating_ip_pool" {
	default = "Ext-Net"
}

variable "dns_server" {
	default = "8.8.8.8"
}

variable "dea_count" {
	default = "1"
}

variable "core_volume_size" {
	default = "40"
}

# Default login
variable "cluster_admin_username" {}
variable "cluster_admin_password" {}
variable "cluster_admin_authorities" {
	default = "scim.write,scim.read,openid,cloud_controller.admin,doppler.firehose"
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
variable "uaadb_tag" {
	default = "admin"
}

variable "domain" {
	default = "xip.io"
}

variable "wildcard_dns" {
	default = 1
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

variable "monit_user" {
  default = "monit_user"
}
variable "monit_password" {
  default = "monit_password"
}
variable "monit_port" {
  default = "2822"
}

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

variable "doppler_zone" {
	default = "z1"
}

variable "traffic_controller_zone" {
	default = "z1"
}

variable "metron_agent_zone" {
	default = "z1"
}

variable "signing_key_passphrase" {
	default = "foobar"
}

variable "service_provider_key_passphrase" {
	default = "foobar"
}

variable "overlay_subnet" {
	default = "192.168.252.0/24"
}

variable "overlay_gateway" {
	default = "192.168.252.1"
}
