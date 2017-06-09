
## Step 1 - Stemcell

Right now this assumes we're using the same stemcell for uaa as we use for scf.

```bash
cd ~/hcf
make docker-deps
```

## Step 2 - Storage class

Create a storage class

```yaml
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: persistent
provisioner: kubernetes.io/host-path
```

```bash
kubectl create -f storage-class.yml
```

## Step 3 - UAA

We're going to build `uaa-fissile-release` in the vagrant box, so we're going to
setup a few prerequisites first:

```bash
# Setup rbenv and the required ruby
sudo zypper addrepo http://download.opensuse.org/repositories/devel:languages:ruby:extensions/openSUSE_Leap_42.2/devel:languages:ruby:extensions.repo
sudo zypper in rbenv
rbenv install 2.3.1
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
rbenv global 2.3.1
gem install --no-ri --no-doc --no-format-executable bosh_cli bundle
rbenv rehash
```

### Step 3.a - Build

First, generate the certs for `scf`:

```bash
~/hcf/bin/generate-dev-certs.sh [NAMESPACE YOU WILL USE FOR SCF] ~/hcf/bin/settings/certs.env  
```

Then, copy the certs from `scf`
```bash
cp ~/hcf/bin/settings/certs.env ./env/
```

```bash
cd [UAA FISSILE RELEASE DIR]
make releases images kube-configs
```

### Step 3.b - Deploy

```bash
kubectl create namespace uaa && \
kubectl create -n uaa -f ./kube/bosh/ && \
kubectl create -n uaa -f kube-test/exposed-ports.yml
```

## Step 4 - SCF

### Step 4.a - Configure

Edit `kube/bosh-task/post-deployment-setup.yml`, and set the `apiVersion` to be
`batch/v1` (second line in the file).

### Step 4.b - Deploy

```bash
cd ~/hcf
make vagrant-prep kube
kubectl create namespace scf && \
kubectl create -n scf -f ./kube/bosh/ && \
kubectl create -n scf -f ./kube/bosh-task/post-deployment-setup.yml
```
