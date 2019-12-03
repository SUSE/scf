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

function blue() {
    printf "\033[34m%b\033[0m\n" "$1"
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

if has_command crictl ; then
    # cri-o based system
    green "cri-o system, will not have docker"
    crio=1
else
    crio=0
fi

# swap should be accounted
if having_category node ; then
    # https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt - section 2.4.
    dir="/sys/fs/cgroup/memory"
    test -e "${dir}/memory.memsw.usage_in_bytes" && test -e "${dir}/memory.memsw.limit_in_bytes"
    status "swap should be accounted"
fi

# docker info should not show aufs
if having_category node ; then
    if [ $crio -eq 0 ] ; then
        docker info 2> /dev/null | grep -vwq "Storage Driver: aufs"
        status "docker info should not show aufs"
    fi
fi

# kernel must be >= 3.19
if having_category kube ; then
    min_ver="3.19"
    ver_check_rc=0
    for i in $(kubectl get nodes --no-headers -o=custom-columns=NODES:.status.nodeInfo.kernelVersion); do
        if test "$(printf '%s\n%s\n' "$i" "$min_ver" | sort -V | head -n 1)" != "$min_ver" ; then
            ver_check_rc=1
            break
        fi
    done
    if [[ $ver_check_rc -ne 0 ]]; then
        false
    fi
    status "nodes should have kernel version $min_ver or higher"
fi

# kube auth
if having_category kube ; then
    kubectl auth can-i get pods --namespace=kube-system &> /dev/null
    status "authenticate with kubernetes cluster"
fi

# kube-dns shows all pods ready
if having_category kube ; then
    kubectl get pods --namespace=kube-system --selector k8s-app=kube-dns 2> /dev/null | grep -Eq '([0-9])/\1 *Running'
    status "all kube-dns pods should be running (show N/N ready)"
fi

# tiller-deploy shows all pods ready
if having_category kube ; then
    kubectl get pods --namespace=kube-system --selector name=tiller 2> /dev/null | grep -Eq '([0-9])/\1 *Running'
    status "all tiller pods should be running (N/N ready)"
fi

# ntp or systemd-timesyncd is installed and running
if having_category api node ; then
    pgrep -x ntpd >& /dev/null || pgrep -x chronyd >& /dev/null || systemctl is-active systemd-timesyncd >& /dev/null
    status "An ntp daemon or systemd-timesyncd must be installed and active"
fi

# At least one storage class exists in K8s
if having_category kube ; then
    test ! "$(kubectl get storageclasses 2>&1 | grep -e "No resources found." -e "Unable to connect to the server")"
    status "A storage class should exist in K8s"
fi

# privileged pods are enabled in K8s
if having_category api ; then
    pgrep -ax 'hyperkube|apiserver|kube-apiserver' | grep apiserver | grep --silent -- --allow-privileged
    status "Privileged must be enabled in 'kube-apiserver'"
fi

if having_category node ; then
    pgrep -ax 'hyperkube|kubelet' | grep kubelet | grep --silent -- --allow-privileged
    status "Privileged must be enabled in 'kubelet'"
fi

# override tasks infinity in systemd configuration
if having_category node ; then
    if has_command systemctl ; then
        if systemctl cat --quiet containerd.service >/dev/null 2>/dev/null ; then
            test $(systemctl show containerd | awk -F= '/TasksMax/ { print substr($2,0,10) }') -gt $((1024 * 1024))
            status "TasksMax must be set to infinity"
        else
            blue "containerd.service not available, no task limits to verify"
        fi
    else
        if pgrep -x containerd ; then
            test "$(awk '/processes/ {print $3}' /proc/"$(pgrep -x containerd)"/limits)" -gt 4096
            status "Max processes should be unlimited, or as high as possible for the system"
        else
            blue "containerd not available, no task limits to verify"
        fi
    fi
fi

exit $FAILED
