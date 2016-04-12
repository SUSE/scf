# # ## ###
## Section: Filesystem Bases

variable "fs_local_root" {
    default = "./container-host-files/"
}

variable "fs_host_root" {
    default = "/home/ubuntu"
}

# # ## ###
## Section: Locations for component state and log files.

#  Placed under /data, the directory the data volume is mounted at by
#  the "setup_blockstore_volume.sh" script.

variable "runtime_store_directory" {
    default = "/data/hcf/store"
}

variable "runtime_log_directory" {
    default = "/data/hcf/log"
}
