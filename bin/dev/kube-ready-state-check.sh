#!/bin/bash

function usage() {
    cat <<EOF
Usage: $(basename "${0}") [options] [category]

  -h: Displays this help message

  Supported categories: all, api, kube, node
  Defaults to: all
EOF
}

while getopts "h" opt; do
    case $opt in
	h)
	    usage
	    exit
	    ;;
    esac
done

shift $((OPTIND-1))

category="${1:-all}"
case ${category} in
    all|api|kube|node)
	: # ok, nothing to do
	;;
    *) usage
	exit 1
	;;
esac

#Script to determine is the K8s host is "ready" for cf deployment
FAILED=0
SCF_DOMAIN=${SCF_DOMAIN:-cf-dev.io}

function green() {
    printf "\033[32m%b\033[0m\n" "$1"
}

function red() {
    printf "\033[31m%b\033[0m\n" "$1"
}

function verified() {
    green "Verified: $1"
}

function trouble() {
    red "Configuration problem detected: $1"
}

function status() {
    if [ $? -eq 0 ]; then
	verified "$1"
    else
	trouble "$1"
	FAILED=1
    fi
}

function having_category() {
    # `all` matches always
    set -- all "$@"
    case "$@" in
	*${category}*)
	    return 0
	    ;;
    esac
    return 1
}

echo "Testing $(green $category)"

# cgroup memory & swap accounting in /proc/cmdline
if having_category node ; then
    grep -wq "cgroup_enable=memory" /proc/cmdline
    status "cgroup_enable memory"

    grep -wq "swapaccount=1" /proc/cmdline
    status "swapaccount enable"

    # docker info should show overlay2
    docker info 2> /dev/null | grep -wq "Storage Driver: overlay2"
    status "docker info should show overlay2"
fi

# kube-dns shows 4/4 ready
if having_category kube ; then
    kubectl get pods --namespace=kube-system --selector k8s-app=kube-dns | grep -Eq '([0-9])/\1 *Running'
    status "kube-dns should shows 4/4 ready"
fi

# ntp is installed and running
if having_category api kube node ; then
    systemctl is-active ntpd >& /dev/null || systemctl is-active systemd-timesyncd >& /dev/null
    status "ntp or systemd-timesyncd must be installed and active"
fi

# At least one storage class exists in K8s
if having_category kube ; then
    test $(kubectl get storageclasses |& wc -l) -gt 1
    status "A storage class should exist in K8s"
fi

# privileged pods are enabled in K8s
if having_category api ; then
    kube_apiserver=$(systemctl status kube-apiserver -l | grep "/usr/bin/hyperkube apiserver" )
    [[ $kube_apiserver == *"--allow-privileged"* ]]
    status "Privileged must be enabled in 'kube-apiserver'"
fi

if having_category node ; then
    kubelet=$(systemctl status kubelet -l | grep "/usr/bin/hyperkube kubelet" )
    [[ $kubelet == *"--allow-privileged"* ]]
    status "Privileged must be enabled in 'kubelet'"
fi

# dns check for the current hostname resolution
if having_category api ; then
    IP=$(host -tA "${SCF_DOMAIN}" | awk '{ print $NF }')
    /sbin/ifconfig | grep -wq "inet addr:$IP"
    status "dns check"
fi

# override tasks infinity in systemd configuration
if having_category node ; then
    systemctl cat containerd | grep -wq "TasksMax=infinity"
    status "TasksMax must be set to infinity"
fi

exit $FAILED
