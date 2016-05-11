# # ## ###
## Section: Disk information: Sizes, Devices, ...

# Name of the device handling the disk/volume given to setup_blockstore.sh
# for formatting as ext4 and mounted in the VM under /data.

variable "core_volume_device_data" {
    default = "/dev/xvdf"
}

# Name of the device handling the disk/volume given to configure_docker.sh
# for use with LVM and the device-mapper storage-driver of docker.

variable "core_volume_device_mapper" {
    default = "/dev/xvdg"
}

variable "core_volume_size_data" {
    default = "40"
}

variable "core_volume_size_mapper" {
    default = "70"
}

