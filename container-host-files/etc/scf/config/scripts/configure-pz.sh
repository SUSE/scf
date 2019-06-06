#!/bin/sh

if test -z "${PZ_LABEL_NAME}"
then
    echo "PZ: No label configured"
    echo "PZ: Skipping"
else
    # PZ override processing is in effect.

    # Locate the kubectl binary.
    kubectl="/var/vcap/packages/kubectl/bin/kubectl"

    # Determine the name of the kube worker node this container is
    # executing on.

    node="$("${kubectl}" get pod "$(hostname)" -o jsonpath='{.spec.nodeName}')"

    echo "PZ: Configured ${PZ_LABEL_NAME}"
    echo "PZ: Node...... ${node}"

    # Determine the PZ of the kube worker node and make this
    # information available to the container, scripts, and binaries of
    # the diego-cell instance group.

    QUERY="jsonpath={.metadata.labels.${PZ_LABEL_NAME}}"
    NODE_PZ=$("${kubectl}" get node "${node}" -o "${QUERY}")

    if test -z "${NODE_PZ}"
    then
        echo "PZ: No information found"
        echo "PZ: Skipping"
    else
        # Propagate the found PZ information into cloudfoundry

        echo "PZ: Found..... ${NODE_PZ}"
        export KUBE_PZ="${NODE_PZ}"
    fi
fi
