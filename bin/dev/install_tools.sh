#!/bin/bash
set -o errexit -o nounset
set -vx
# Get version information and set destination paths
. "$(dirname "$0")/../common/versions.sh"

SCF_BIN_DIR="${SCF_BIN_DIR:-output/bin}"

# Tool locations
s3="https://cf-opensusefs2.s3.amazonaws.com/fissile/${FISSILE_FLAVOR}"

# Tool versions
thefissile="fissile-$(echo "${FISSILE_VERSION}" | sed -e 's/+/%2B/')"

fissile_url="${fissile_url:-${s3}/${thefissile}.linux-amd64.tgz}"
stampy_url="${stampy_url:-https://github.com/SUSE/stampy/releases/download/${STAMPY_MAJOR}/stampy-${STAMPY_VERSION}.linux-amd64.tgz}"

mkdir -p "${SCF_BIN_DIR}"

export SCF_BIN_DIR="$(unset CDPATH ; cd "${SCF_BIN_DIR}" && pwd)"

echo "Fetching fissile $fissile_url ..."
wget -q "$fissile_url"   -O - | tar xz --to-stdout fissile > "${FISSILE_BINARY}.real"

echo "Fetching stampy $stampy_url ..."
wget -q "$stampy_url"   -O - | tar xz -C "${SCF_BIN_DIR}" stampy

echo "Making binaries executable ..."
chmod a+x "${FISSILE_BINARY}.real"
chmod a+x "${SCF_BIN_DIR}/stampy"

# Install wrapper script that sets FISSILE_TAG_EXTRA to current commit id
cp bin/fissile "${FISSILE_BINARY}"

echo "Installed: $("${FISSILE_BINARY}" version)"

echo "Pulling ruby bosh image ..."
docker pull "splatform/bosh-cli:${BOSH_CLI_VERSION:-latest}"

echo "Dev-tool installation done."
