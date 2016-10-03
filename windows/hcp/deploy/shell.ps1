$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir 'common\utils.psm1')

Write-Output @"
Version:1.0.0.7x

 To setup the network for HCP, run the following script:
  .\setup-networking.ps1

 Parameters:
    [-hcpMasterIP] <string>            - (Required) Private IP of the Kubernetes master.
    [-hcpKeypairFile] <string>         - (Required) Kubernetes master user SSH key file path.
    [-hcpMasterSshUser] <string>]      - Kubernetes master SSH username. (Default: ubuntu)
    [-flannelUserPassword] <string>]   - Kubernetes flannel username.
    [-flannelInstallDir] <string>]     - Kubernetes install directory. (Default: C:/flannel)
    [-k8sQueryPeriod] <string>]        - Polling time for WinK8s connector. (Default: 1s)
    [-httpProxy] <string>]             - The HTTP proxy that is going to be setup on the Windows Virtual Machine.
    [-httpsProxy] <string>]            - The HTTPS proxy that is going to be setup on the Windows Virtual Machine.
    [-noProxy] <string>]               - Comma separated list of domains/IPs that are going to bypass the proxy.

 Example:
  .\setup-networking.ps1 -?
  .\setup-networking.ps1 -hcpMasterIP 172.31.22.219 -httpProxy http://my-proxy:8080 -httpsProxy http://my-proxy:8080 -noProxy "127.0.0.1,10.*.*.*,172.16.*.*,192.168.*.*"

 To install the Cloud Foundry Diego components for Windows run the following script:
  .\install-windows-hcf.ps1

 Parameters:
    [-HCPInstanceId] <string>               - (Required) The id of the HCF instance.
    [-CloudFoundryAdminUsername] <string>   - (Required) An Cloud Foundry admin user account.
    [-CloudFoundryAdminPassword] <string>   - (Required) Password for Cloud Foundry admin user.
    [-SkipSslValidation]                    - Determine if it should skip the Certificate Validation. (Default: false)

 Exmaple:
  .\install-windows-hcf.ps1 -?
  .\install-windows-hcf.ps1 -HCPInstanceId hcf-instance -CloudFoundryAdminUsername admin -CloudFoundryAdminPassword changeme -SkipSslValidation
"@
