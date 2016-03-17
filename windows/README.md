## Installation

- Make sure the hcf-infrastructure vagrant box in the parent directory is up and all roles are running (use `hcf-status` to check the status).
- Go to 'windows' directory `cd windows`
- Run `vagrant up`

## Sample .Net App

To push a sample .NET application that uses the windows cell use the following snippet:
```
git clone https://github.com/cloudfoundry-incubator/NET-sample-app
cd NET-sample-app/ViewEnvironment

cf push dotnet-env -s windows2012R2 -b http://buildpack.url.ignored.on.windows
```

## How to install windows_app_lifecycle with buildpacks support

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

Use following example to push an app that uses the git url buildpack support:
```
git clone https://github.com/cloudfoundry-incubator/NET-sample-app
cd NET-sample-app/ViewEnvironment

cf push dotnet-env -s windows2012R2 -b https://github.com/hpcloud/cf-iis8-buildpack
```

## How to run Windows Acceptance Tests (WATS)

Windows acceptance tests can be run from OS X or a Linux box with access to HCF and golang installed.
The test suite require approximately 8 GiB of RAM for the Windows Cell. The default config only has 2 GiB, so increasing the RAM or over committing is necessary.

To increate the RAM change the vb.memory in the Windows Vagrant file form `vb.memory = "2048"` to `vb.memory = "8192"`. After the change, run `vagrant reload` for the Windows Cell to restart the VM.

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

The current Windows 2012 R2 Vagrant box is build with [Packer](https://www.packer.io/) with the base packer template from:  
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
 2. Make sure the docker DNS server is running and CF components are accessible. To check if Windows Cell can ping the CF Cloud Controller use: `ping api.hcf`
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
