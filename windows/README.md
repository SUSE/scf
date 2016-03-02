## Requirements

### 1. Add windows2012R2 stack to CF
You can run this commands in vagrant hcf box:
```
cf api --skip-ssl-validation https://api.192.168.77.77.nip.io && \
cf auth admin changeme && \
cf curl /v2/stacks -X POST  -d '{"name":"windows2012R2","description":"Windows Server 2012 R2"}'
```

### 2. Install a DNS server to allow other components to access the .hcf domain
Until this gets backed-in into the hcf-infrastructure repo, this docker DNS service
based on consul can be used:
```
docker run  -p 192.168.77.77:53:8600/udp --net=hcf -d --restart=always \
  --name dnsb voxxit/consul agent -data-dir /data -server -bootstrap \
  -client=0.0.0.0 -recursor=127.0.0.11
```

To test the DNS server run:
```
dig api.hcf @192.168.77.77
```

To stop the DNS server run:
```
docker rm -f dnsb
```

## Optional Features

### Install windows_app_lifecycle with buildpacks support

Download the release from Github ( https://github.com/hpcloud/windows_app_lifecycle/releases ) into hcf-infrastructure folder.

Copy the new lifecycle in the diego-access container from the hcf console:
```
cd ~/hcf
docker cp diego-access:/var/vcap/packages/windows_app_lifecycle/windows_app_lifecycle.tgz windows_app_lifecycle.tgz.bak
docker cp windows_app_lifecycle.tgz diego-access:/var/vcap/packages/windows_app_lifecycle/windows_app_lifecycle.tgz
```

To restore the backup:
```
docker cp windows_app_lifecycle.tgz.bak diego-access:/var/vcap/packages/windows_app_lifecycle/windows_app_lifecycle.tgz
```

Restart rep from the windows box to invalidate the cache.

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
 1. Run `vagrant rdp` and use the 'vagrant' username and 'vagrant' password credentials to get a remote desktop connection.
 2. Make sure the docker DNS and CF components are IP accessible by running `ping api.hcf`
 3. Make sure that all diego services are running with this powershell snippet:
```
Get-Service   "CF Consul", "CF Metron", "CF Containerizer", "CF GardenWindows", "rep"
Start-Service "CF Consul", "CF Metron", "CF Containerizer", "CF GardenWindows", "rep"
Get-Service   "CF Consul", "CF Metron", "CF Containerizer", "CF GardenWindows", "rep"
```

- To search for 'error' or other strings in diego's components logs use:
```
Get-EventLog Application | %{ $_.message} | sls error
cat C:\diego-logs\rep.log | sls error
```
