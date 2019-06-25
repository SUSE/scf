#!/bin/sh

if test -z "${AZ_LABEL_NAME}"
then
    echo "AZ: No label configured"
    echo "AZ: Skipping"
else
    # AZ override processing is in effect.

    # Locate the kubectl binary.
    kubectl="/var/vcap/packages/kubectl/bin/kubectl"

    # Determine the name of the kube worker node this container is
    # executing on.

    node="$("${kubectl}" get pod "$(hostname)" -o jsonpath='{.spec.nodeName}')"

    echo "AZ: Configured ${AZ_LABEL_NAME}"
    echo "AZ: Node...... ${node}"

    # Determine the AZ of the kube worker node and make this
    # information available to the container, scripts, and binaries of
    # the diego-cell instance group.

    # Note that $AZ_LABEL_NAME may contain dots, which is why we use go-template instead of jsonpath here:
    NODE_AZ=$("${kubectl}" get node "${node}" -o "go-template={{index .metadata.labels \"${AZ_LABEL_NAME}\"}}")

    if test -z "${NODE_AZ}"
    then
        echo "AZ: No information found"
        echo "AZ: Skipping"
    else
        # Propagate the found AZ information into cloudfoundry

        echo "AZ: Found..... ${NODE_AZ}"
        export KUBE_AZ="${NODE_AZ}"
    fi
fi
