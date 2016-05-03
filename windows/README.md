## Installation

For a new installation use the following steps:
- Make sure the hcf-infrastructure vagrant box in the parent directory is up and all roles are running (use `hcf-status` to check the status).
- Go to 'windows' directory `cd windows`
- Run `vagrant up`

To upgrade an existing Windows Vagrant box, without destroying the box, use the following steps:
- Go to 'windows' directory `cd windows`
- Make sure the box is running `vagrant up`
- Run `vagrant provision`

## How to push a Windows App

To push a sample .NET application that uses the windows cell use the following snippet:
```
git clone https://github.com/cloudfoundry-incubator/NET-sample-app
cd NET-sample-app/ViewEnvironment

cf push dotnet-env -s win2012r2
```

To push a simple command line app with a custom buildpack use the following snippet:
```
mkdir ping-app
cd ping-app
echo ping  -t  8.8.8.8  >  run.bat

cf push ping-app  -s win2012r2  -m 64M --health-check-type none  -b https://github.com/hpcloud/cf-exe-buildpack

cf logs ping-app --recent
```

(Experimental) To push an app that uses the Pivotal Greenhouse staging process use the  `https://github.com/stefanschneider/windows_app_lifecycle` buidlpack from the "buildpack-extraction" branch. This should provide complete compatibility with any app that runs on upstream CloudFoundry with Greenhouse.
Example:
```
git clone https://github.com/cloudfoundry-incubator/NET-sample-app
cd NET-sample-app/ViewEnvironment

cf push dotnet-env -s win2012r2 -b https://github.com/stefanschneider/windows_app_lifecycle#buildpack-extraction
```

## How to patch the Diego cluster with a custom windows_app_lifecycle

Download and copy the new lifecycle in the diego-access container from the hcf vagrant VM:
```
cd /tmp
wget https://ci.appveyor.com/api/buildjobs/lufj2q4f7dmyunp6/artifacts/output/windows_app_lifecycle-8970681.tgz  -O windows_app_lifecycle.tgz

# create a backup first
docker cp diego-access:/var/vcap/packages/windows_app_lifecycle/windows_app_lifecycle.tgz windows_app_lifecycle.tgz.bak

docker cp windows_app_lifecycle.tgz diego-access:/var/vcap/packages/windows_app_lifecycle/windows_app_lifecycle.tgz
```

To restore the backup use:
```
docker cp windows_app_lifecycle.tgz.bak diego-access:/var/vcap/packages/windows_app_lifecycle/windows_app_lifecycle.tgz
```

Restart rep from the windows box to invalidate the windows_app_lifecycle cache.

## How to run Windows Acceptance Tests (WATS)

Windows acceptance tests can be run from OS X or a Linux box with access to HCF and golang installed.
The test suite requires approximately 8 GiB of RAM for the Windows Cell. The default config only has 2 GiB, so increasing the RAM or over committing is necessary.

To increase the RAM change the vb.memory in the Windows Vagrant file form `vb.memory = "2048"` to `vb.memory = "8192"`. After the change, run `vagrant reload` for the Windows Cell to restart the VM.

To overcommit the Windows Cell capacity to 8 GiB without increasing the actual VM RAM, change the config line `$env:REP_MEMORY_MB = "auto"` to `$env:REP_MEMORY_MB = "8192"` in install-diego.ps1. After the change, run `vagrant provision` for the Windows Cell to apply the new config value.

Run this snippet to clone the WATS repo and start the testing:

```
git clone https://github.com/cloudfoundry/wats
cd wats

cat > scripts/wats_hcf_config.json <<EOL
{
  "api": "api.192.168.77.77.nip.io",
  "admin_user": "admin",
  "admin_password": "changeme",
  "apps_domain": "192.168.77.77.nip.io",
  "secure_address": "192.168.77.77:80",
  "skip_ssl_validation": true
}
EOL

NUM_WIN_CELLS=1 scripts/run_wats.sh scripts/wats_hcf_config.json
```

## Rebuild Windows Vagrant box

The current Windows 2012 R2 Vagrant box is built with [Packer](https://www.packer.io/) with the base packer template from:  
https://github.com/stefanschneider/packer-windows.

The above packer template is a fork from: https://github.com/joefitzgerald/packer-windows with the following changes:
 - Built with a retail iso
 - Installed with GVLK key
 - Sysprep

Requirements for building the Windows Vagrant box:
 - Retail Windows Server 2012 R2 ISO from MSDN
 - VirtualBox and/or VMware Workstation/Fusion
 - Packer


 Use this sample snippet to build the image for VirtualBox:
 ```
 packer build \
  -var iso_url=~/software/en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso  \
  -var iso_checksum=865494e969704be1c4496d8614314361d025775e  \
  -var iso_checksum_type=sha1  \
  -only virtualbox-iso \
   windows_2012_r2.json
 ```

 Use this sample snippet to build the image for VMware Workstation / Fusion:
 ```
 packer build \
  -var iso_url=~/software/en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso  \
  -var iso_checksum=865494e969704be1c4496d8614314361d025775e  \
  -var iso_checksum_type=sha1  \
  -only vmware-iso \
   windows_2012_r2.json
 ```

Other open source packer templates that could potentially be compatible:
 - https://github.com/mwrock/packer-templates
 - https://github.com/boxcutter/windows

## Troubleshooting

-  If the 'NoCompatibleCell' error is thrown when pushing a windows app, try the following steps:
 1. Run `vagrant rdp` and use the 'vagrant' username and 'vagrant' password to get a remote desktop connection to the Vagrant Windows Cell.
 2. Make sure the docker DNS server is running and CF components are accessible. To check if the Windows Cell can ping the CF Cloud Controller use: `ping api.hcf`
 3. Make sure that all required services are running. To check status and start services use:
```
Get-Service   "consul", "metron", "rep", "CF Containerizer", "CF GardenWindows"
Start-Service   "consul", "metron", "rep", "CF Containerizer", "CF GardenWindows" -PassThru
```

- To search in the logs of Containerizer and GardenWindows use:
```
Get-EventLog Application | %{ $_.message} | sls 'error'
```

- To search in the logs of consul, rep, and metron use:
```
cat C:\diego\logs\* | sls 'error'
```

- To reinstall and configure all Windows Diego services again use: `vagrant provision`

## Setup and run windows with HTTP proxy for testing purposes

- Run an instance of Squid as a docker container in HCF Vagrant box
```
docker run  --name squid  -d  --restart=always \
--publish 3128:3128  sameersbn/squid:3.3.8-12
```

- Set HTTP proxy environment variables configs in `bin/dev-settings.env`
```
HTTP_PROXY=http://192.168.77.77:3128
http_proxy=http://192.168.77.77:3128
HTTPS_PROXY=http://192.168.77.77:3128
https_proxy=http://192.168.77.77:3128
NO_PROXY=.hcf,127.0.0.1
```

- Create a Cloud Foundry security group with access to the proxy server
```
echo '[{"protocol":"tcp","destination":"192.168.77.77","ports":"3128"}]' > /tmp/proxy-security-group.json
cf create-security-group http_proxy /tmp/proxy-security-group.json
cf bind-running-security-group http_proxy
cf bind-staging-security-group http_proxy
```

- Internet access can be disabled on the Windows Vagrant box with:
`route delete 0.0.0.0`
