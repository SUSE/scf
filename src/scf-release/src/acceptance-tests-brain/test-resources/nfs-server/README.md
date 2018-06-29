# NFS server for Docker
Docker nfs-server based on CentOS. To use, run the image as follows:

```
# Enable NFS modules
sudo modprobe nfs
sudo modprobe nfsd

docker run -d --name nfs \
    -v "/home/toaster/tools/nfs_share:/exports/foo" \
    -p 111:111/tcp \
    -p 111:111/udp \
    -p 662:662/udp \
    -p 662:662/tcp \
    -p 875:875/udp \
    -p 875:875/tcp \
    -p 2049:2049/udp \
    -p 2049:2049/tcp \
    -p 32769:32769/udp \
    -p 32803:32803/tcp \
    -p 892:892/udp \
    -p 892:892/tcp \
    --privileged \
    splatform/nfs-test-server /exports/foo
```

You can then mount NFS shares:

```
# mount <CONTAINER_IP>:/exports/foo /mnt/foo
```
