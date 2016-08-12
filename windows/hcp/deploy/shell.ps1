$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir 'common\utils.psm1')

echo @"

 To setup the network for HCP, run the following script:
  .\setup-networking.ps1
 Example:
  .\setup-networking.ps1 -?
  .\setup-networking.ps1 -k8MasterIP 172.31.22.219 -k8sServSubnet 172.16.0.0/16 -etcdKeyfile C:\net-setup\client.key -etcdCertFile C:\net-setup\client.cert -etcdCaFile C:\net-setup\ca.crt

 To install the Cloud Foundry Diego components for Windows run the following script:
  .\install-windows-hcf.ps1
 Exmaple:
  .\install-windows-hcf.ps1 -?
  .\install-windows-hcf.ps1 -hcfIdlPath C:\hcf-instance.json

"@
