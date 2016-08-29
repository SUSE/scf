# stackato-windows

----------

# Summary
A collection of scripts used for building and installing Windows components on HCF wiht HCP.

# Building
To build the installer, run the following command in a Powershell terminal on Windows box:

```
git clone https://hithub.com/hpcloud/hcf
cd windows\hcp\package
.\package.ps1
```
The output of the build is a self-extractable executable : *helion-windows.exe*

#Installing

To run the installer you need to provide three mandatory parameters and one optional parameter:

__Mandatory parameters__

* HCPInstanceId
* CloudFoundryAdminUsername
* CloudFoundryAdminPassword

__Optional parameter__

* SkipCertificateValidation (default value is _$false_)
