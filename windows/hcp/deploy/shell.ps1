$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

Import-Module -DisableNameChecking (Join-Path $currentDir 'common\utils.psm1')

Write-Output @"
Version:1.0.0.7x

 To setup the network for HCP, run the following script:
  .\setup-networking.ps1

 Parameters:
    [-k8MasterIP] <string>              - (Required) Private IP of the Kubernetes master.
    [-etcdKeyFile] <string>             - (Required) Path to ETCD key file.
    [-etcdCertFile] <string>            - (Required) Path to ETCD client cert file.
    [-etcdCaFile] <string>              - (Required) Path to ETCD CA cert file.
    [[-k8sPort] <int>]                  - Kubernetes service port. (Default: 8080)
    [[-etcdPort] <int>]                 - Kubernetes ETCD port. (Default: 2379)
    [[-flannelUserPassword] <string>]   - Kubernetes flannel username.
    [[-flannelInstallDir] <string>]     - Kubernetes install directory. (Default: C:/flannel)
    [[-k8sQueryPeriod] <string>]        - Polling time for WinK8s connector. (Default: 1s)
    [[-httpProxy] <string>]             - The HTTP proxy that is going to be setup on the Windows Virtual Machine.
    [[-httpsProxy] <string>]            - The HTTPS proxy that is going to be setup on the Windows Virtual Machine.
    [[-noProxy] <string>]               - Comma separated list of domains/IPs that are going to bypass the proxy.
    [[-k8sServSubnet] <string>]         - Subnet of the Kubernetes services. (default 172.16.0.0/16)
    [[-k8sAllowedSubnet] <string>]      - The subnet of the kubernetes nodes that will be added to the route.

 Example:
  .\setup-networking.ps1 -?
  .\setup-networking.ps1 -k8MasterIP 172.31.22.219 -k8sServSubnet 172.16.0.0/16 -etcdKeyFile C:\net-setup\client.key -etcdCertFile C:\net-setup\client.cert -etcdCaFile C:\net-setup\ca.crt -httpProxy http://my-proxy:8080 -httpsProxy http://my-proxy:8080 -noProxy "127.0.0.1,10.*.*.*,172.16.*.*,192.168.*.*"

 To install the Cloud Foundry Diego components for Windows run the following script:
  .\install-windows-hcf.ps1

 Parameters:
    [-HCPInstanceId] <string>               - (Required) The id of the HCF instance.
    [-CloudFoundryAdminUsername] <string>   - (Required) An Cloud Foundry admin user account.
    [-CloudFoundryAdminPassword] <string>   - (Required) Password for Cloud Foundry admin user.
    [-SkipCertificateValidation]            - Determine if it should skip the Certificate Validation. (Default: false)

 Exmaple:
  .\install-windows-hcf.ps1 -?
  .\install-windows-hcf.ps1 -HCPInstanceId hcf-instance -CloudFoundryAdminUsername admin -CloudFoundryAdminPassword changeme -SkipCertificateValidation
"@
