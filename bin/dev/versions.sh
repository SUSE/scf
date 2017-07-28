#!/bin/bash
set -o errexit -o nounset

# Versions of the pieces pulled into SCF (outside of submodules).
# This file is sourced everywhere one or more of the versions are
# needed.

# Used in: bin/dev/install_tool.sh

export CFCLI_VERSION="6.21.1"
export FISSILE_VERSION="5.0.0+126.g9f731ea"
export HELM_VERSION="2.5.1"
export HELM_CERTGEN_VERSION="master"
export CERTSTRAP_VERSION="v1.0.1-11-g0e00d5c"
export KK_VERSION="576a42386770423ced46ab4ae9955bee59b0d4dd"
export KUBECTL_VERSION="1.5.4"
export K_VERSION="0.0.12"
export STAMPY_VERSION="0.0.0.22.gbb93bf3"
export UBUNTU_VERSION="14.04"

# For stampy we need the major+minor+patch as a separate value.
export STAMPY_MAJOR=$(echo "$STAMPY_VERSION" | sed -e 's/\.g.*//' -e 's/\.[^.]*$//')

# Notes
# splatform/bosh-cli - Unversioned docker pull

# Used in: .envrc

export FISSILE_STEMCELL_VERSION=${FISSILE_STEMCELL_VERSION:-42.2-15.g38c573e-29.12}

# Used in: bin/generate-dev-certs.sh

export GOLANG_VERSION=1.7

# Used in: make/include/versioning

export CF_VERSION=265

# Notes
# github.com/square/certstrap - Unversioned `go get`

# Show versions, if called on its own.
# # ## ### ##### ######## ############# #####################

if [ "X$(basename "$0")" = "Xversions.sh" ]
then
    echo cf '           =' $CF_VERSION
    echo cf-cli '       =' $CFCLI_VERSION
    echo fissile '      =' $FISSILE_VERSION
    echo go '           =' $GOLANG_VERSION
    echo helm '         =' $HELM_VERSION
    echo helm-certgen ' =' $HELM_CERTGEN_VERSION
    echo certstrap '    =' $CERTSTRAP_VERSION
    echo k '            =' $K_VERSION
    echo kk '           =' $KK_VERSION
    echo kubectl '      =' $KUBECTL_VERSION
    echo stampy '       =' $STAMPY_VERSION
    echo stemcell '     =' $FISSILE_STEMCELL_VERSION
    echo ubuntu '       =' $UBUNTU_VERSION
    echo
fi
