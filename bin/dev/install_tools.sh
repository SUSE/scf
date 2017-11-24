#!/bin/bash
set -o errexit -o nounset
set -vx
# Get version information and set destination paths
. "$(dirname "$0")/../common/versions.sh"

SCF_BIN_DIR="${SCF_BIN_DIR:-output/bin}"

# Tool locations
s3="https://cf-opensusefs2.s3.amazonaws.com/fissile"

# Tool versions
thefissile="fissile-$(echo "${FISSILE_VERSION}" | sed -e 's/+/%2B/')"

fissile_url="${fissile_url:-${s3}/${thefissile}.linux-amd64.tgz}"
stampy_url="${stampy_url:-https://github.com/SUSE/stampy/releases/download/${STAMPY_MAJOR}/stampy-${STAMPY_VERSION}.linux-amd64.tgz}"
certstrap_url="${certstrap_url:-https://cf-opensusefs2.s3.amazonaws.com/certstrap/certstrap-${CERTSTRAP_VERSION}.linux-amd64.tgz}"

mkdir -p "${SCF_BIN_DIR}"

export SCF_BIN_DIR="$(unset CDPATH ; cd "${SCF_BIN_DIR}" && pwd)"

echo "Fetching fissile $fissile_url ..."
wget -q "$fissile_url"   -O - | tar xz --to-stdout fissile > "${FISSILE_BINARY}.real"

echo "Fetching stampy $stampy_url ..."
wget -q "$stampy_url"   -O - | tar xz -C "${SCF_BIN_DIR}" stampy

echo "Fetching certstrap from ${certstrap_url} ..."
wget -q "${certstrap_url}" -O - | tar -xzC "${SCF_BIN_DIR}" --overwrite certstrap

echo "Making binaries executable ..."
chmod a+x "${FISSILE_BINARY}.real"
chmod a+x "${SCF_BIN_DIR}/stampy"
chmod a+x "${SCF_BIN_DIR}/certstrap"

# Install wrapper script that sets FISSILE_TAG_EXTRA to current commit id
cp bin/fissile "${FISSILE_BINARY}"

echo "Installed: $("${FISSILE_BINARY}" version)"

echo "Pulling ruby bosh image ..."
docker pull "splatform/bosh-cli:${BOSH_CLI_VERSION:-latest}"

echo "Installing helm-certgen ..."

if [[ $(id -u) -eq 0 ]] && id -u vagrant &> /dev/null; then
  user=vagrant
else
  user=$(whoami)
fi

sudo -Eu $user bash << 'EOF'
  set -o errexit -o nounset
  helm_certgen_dir="$(mktemp -d)"
  trap "rm -rf '${helm_certgen_dir}'" EXIT
  git clone --branch "${HELM_CERTGEN_VERSION}" --depth 1 https://github.com/SUSE/helm-certgen.git "${helm_certgen_dir}"
  docker run --rm -v "${SCF_BIN_DIR}":/out:rw -v "${helm_certgen_dir}:/go/src/github.com/SUSE/helm-certgen:ro" "golang:${GOLANG_VERSION}" /usr/bin/env GOBIN=/out go get github.com/SUSE/helm-certgen

  if [[ $(stat -c '%u' "${SCF_BIN_DIR}/helm-certgen") -eq 0 ]]; then
    # The golang docker image is baked into the packer-built image. See packer/scripts/install-certstrap.sh if dependency on this image changes
    docker run --rm -v "${SCF_BIN_DIR}":/out:rw "golang:${GOLANG_VERSION}" /bin/chown "$(id -u):$(id -g)" /out/helm-certgen
  fi
  mkdir -p "${HOME}/.helm/plugins" # Necessary if we didn't run "helm init"

  rm -rf "${HOME}/.helm/plugins/certgen"
  
  mv --no-target-directory "${helm_certgen_dir}/plugin" "${HOME}/.helm/plugins/certgen"
  rm -rf "${helm_certgen_dir}"
EOF

echo "Dev-tool installation done."
