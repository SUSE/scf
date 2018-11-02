#!/bin/sh

if test -z "${AZ_LABEL_NAME}"
then
    echo AZ: No label configured
    echo AZ: Skipping
else
    # AZ override processing is in effect.

    # Locate the kubectl binary.
    ##
    # Attention! This only works because of us having/using a common
    # layer which contains all the packages, regardless of their use
    # within a specific role. This gives the diego-cell access to
    # things it normally is not using at all. Here this is the
    # `kubectl` cli originally added for use by the
    # `acceptance-tests-brain`.

    kubectl="$(ls /var/vcap/packages-src/*/bin/kubectl | head -n 1)"

    # Determine the name of the kube worker node this container is
    # executing on.

    node="$($kubectl get pod $(hostname) -o jsonpath='{.spec.nodeName}')"

    echo AZ: Configured ${AZ_LABEL_NAME}
    echo AZ: Node...... ${node}

    # Determine the AZ of the kube worker node and make this
    # information available to the container, scripts, and binaries of
    # the diego-cell instance group.

    QUERY="jsonpath={.metadata.labels.${AZ_LABEL_NAME}}"
    NODE_AZ=$($kubectl get node $node -o "${QUERY}" || true)

    if test -z "${NODE_AZ}"
    then
	echo AZ: No information found
	echo AZ: Skipping
    else
	# Propagate the found AZ information into cloudfoundry

	echo AZ: Found..... ${NODE_AZ}
        export KUBE_AZ="${NODE_AZ}"
    fi
fi
