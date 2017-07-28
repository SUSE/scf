#!/bin/bash
set -o errexit -o nounset

# Get version information and set destination paths
. "$(dirname "$0")/../common/versions.sh"

if id -u vagrant >& /dev/null; then
  SCF_BIN_DIR="${SCF_BIN_DIR:-/usr/local/bin}"
else
  SCF_BIN_DIR="${SCF_BIN_DIR:-output/bin}"
fi

# Tool locations
s3="https://cf-opensusefs2.s3.amazonaws.com/fissile"

# Tool versions
thefissile="fissile-$(echo "${FISSILE_VERSION}" | sed -e 's/+/%2B/')"

fissile_url="${fissile_url:-${s3}/${thefissile}.linux-amd64.tgz}"
stampy_url="${stampy_url:-https://github.com/SUSE/stampy/releases/download/${STAMPY_MAJOR}/stampy-${STAMPY_VERSION}.linux-amd64.tgz}"

mkdir -p "${SCF_BIN_DIR}"

SCF_BIN_DIR="$(cd "${SCF_BIN_DIR}" && pwd)"

echo "Fetching fissile $fissile_url ..."
wget -q "$fissile_url"   -O - | tar xz --to-stdout fissile > "${FISSILE_BINARY}"

echo "Fetching stampy $stampy_url ..."
wget -q "$stampy_url"   -O - | tar xz -C "${SCF_BIN_DIR}" stampy

echo "Making binaries executable ..."
chmod a+x "${FISSILE_BINARY}"
chmod a+x "${SCF_BIN_DIR}/stampy"

echo "Installed: $("${FISSILE_BINARY}" version)"

echo "Pulling ruby bosh image ..."
docker pull splatform/bosh-cli

echo "Installing helm-certgen ..."
helm_certgen_dir="$(mktemp -d)"
trap "rm -rf '${helm_certgen_dir}'" EXIT
git clone --branch "${HELM_CERTGEN_VERSION}" --depth 1 https://github.com/SUSE/helm-certgen.git "${helm_certgen_dir}"
docker run --rm -v "${SCF_BIN_DIR}":/out:rw -v "${helm_certgen_dir}:/go/src/github.com/SUSE/helm-certgen:ro" "golang:${GOLANG_VERSION}" /usr/bin/env GOBIN=/out go get github.com/SUSE/helm-certgen
if [[ $(stat -c '%u' "${SCF_BIN_DIR}/helm-certgen") -eq 0 ]]; then
  docker run --rm -v "${SCF_BIN_DIR}":/out:rw "golang:${GOLANG_VERSION}" /bin/chown "$(id -u):$(id -g)" /out/helm-certgen
fi
mkdir -p "${HOME}/.helm/plugins" # Necessary if we didn't run `helm init`
rm -rf "${HOME}/.helm/plugins/certgen"
mv --no-target-directory "${helm_certgen_dir}/plugin" "${HOME}/.helm/plugins/certgen"
rm -rf "${helm_certgen_dir}"

echo "Dev-tool installation done."
