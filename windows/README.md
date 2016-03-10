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

## Troubleshooting

- Error to ignore when running `vagrant up`:
```
==> default: Running provisioner: file...
==> default: Running provisioner: shell...
    default: Running: vagrant-install-wrapper.ps1 as c:\tmp\vagrant-shell.ps1
==> default: del : Cannot remove item C:\Windows\Temp\WinRM_Elevated_Shell.log: The process
==> default: cannot access the file 'C:\Windows\Temp\WinRM_Elevated_Shell.log' because it
==> default: is being used by another process.
==> default: At C:\tmp\vagrant-elevated-shell.ps1:19 char:3
==> default: +   del $out_file
==> default: +   ~~~~~~~~~~~~~
==> default:     + CategoryInfo          : WriteError: (C:\Windows\Temp\WinRM_Elevated_Shel
==> default:    l.log:FileInfo) [Remove-Item], IOException
==> default:     + FullyQualifiedErrorId : RemoveFileSystemItemIOError,Microsoft.PowerShell
==> default:    .Commands.RemoveItemCommand
==> default: Diego Windows installation finished.
```

-  If the 'NoCompatibleCell' error is thrown when pushing a windows app, try the following steps:
 1. Run `vagrant rdp` and use the 'vagrant' username and 'vagrant' password to get a remote desktop connection.
 2. Make sure the docker DNS and CF components are IP accessible by running `ping api.hcf`
 3. Make sure that all diego services are running with this powershell snippet:
```
Get-Service   "consul", "metron", "rep", "CF Containerizer", "CF GardenWindows"
Start-Service   "consul", "metron", "rep", "CF Containerizer", "CF GardenWindows" -PassThru
```

- To search the logs for Containerizer and GardenWindows use:
```
Get-EventLog Application | %{ $_.message} | sls 'error'
```

- To search the logs for consul, rep, and metron use:
```
cat C:\diego\logs\* | sls 'error'
```
