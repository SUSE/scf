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

function has_command() {
    type "${1}" &> /dev/null ;
}

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

echo "Testing $(green "${category}")"

# swap accounting in /proc/cmdline
if having_category node ; then
    grep -wq "swapaccount=1" /proc/cmdline
    status "swapaccount enable"

    # docker info should not show aufs
    docker info 2> /dev/null | grep -vwq "Storage Driver: aufs"
    status "docker info should not show aufs"
fi

# kube-dns shows 4/4 ready
if having_category kube ; then
    kubectl get pods --namespace=kube-system --selector k8s-app=kube-dns 2> /dev/null | grep -Eq '([0-9])/\1 *Running'
    status "kube-dns should be running (show 4/4 ready)"
fi

# tiller-deploy shows 4/4 ready
if having_category kube ; then
    kubectl get pods --namespace=kube-system --selector name=tiller 2> /dev/null | grep -Eq '([0-9])/\1 *Running'
    status "tiller should be running (1/1 ready)"
fi

# ntp or systemd-timesyncd is installed and running
if having_category api node ; then
    pgrep -x ntpd >& /dev/null || pgrep -x chronyd >& /dev/null || systemctl is-active systemd-timesyncd >& /dev/null
    status "An ntp daemon or systemd-timesyncd must be installed and active"
fi

# At least one storage class exists in K8s
if having_category kube ; then
    test ! "$(kubectl get storageclasses 2>&1 | grep "No resources found.")"
    status "A storage class should exist in K8s"
fi

# privileged pods are enabled in K8s
if having_category api ; then
    kube_apiserver=$(pgrep -ax hyperkube | grep " apiserver " )
    [[ $kube_apiserver == *"--allow-privileged"* ]]
    status "Privileged must be enabled in 'kube-apiserver'"
fi

if having_category node ; then
    kubelet=$(pgrep -ax hyperkube | grep " kubelet " )
    [[ $kubelet == *"--allow-privileged"* ]]
    status "Privileged must be enabled in 'kubelet'"
fi

# override tasks infinity in systemd configuration
if having_category node ; then
    if has_command systemctl ; then
        test $(systemctl show containerd | awk -F= '/TasksMax/ { print substr($2,0,10) }') -gt $((1024 * 1024))
        status "TasksMax must be set to infinity"
    else
        test "$(awk '/processes/ {print $3}' /proc/"$(pgrep -x containerd)"/limits)" -gt 4096
        status "Max processes should be unlimited, or as high as possible for the system"
    fi
fi

exit $FAILED
