
ceph-authtool \
    --create-keyring XXXX.ceph.client.admin.keyring \
    --gen-key \
    -n client.admin \
    --set-uid=0 \
    --cap mon 'allow *' \
    --cap osd 'allow *' \
    --cap mds 'allow *' \
    --cap mgr 'allow *'
