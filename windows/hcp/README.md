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
