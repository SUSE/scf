# Changelog

## [Unreleased]

## [2.12.3] - 2018-08-22

### Added
- Allow HA for cc-clock and syslog-scheduler roles (2 default/3 max)

### Changed
- Changed internal ports to avoid privileged ports in Kubernetes, though diego-cell and nfs-broker containers still rely on privileged access
- Bumped cf-deployment to 2.7.0
- Bumped capi-release to 1.61.0
- Bumped cf-syslog-drain-release to 7.0
- Bumped cflinuxfs2-release to 1.227.0
- Bumped consule-release to 195
- Bumped diego-release to 2.12.1
- Bumped routing-release to 0.179.0
- Bumped uaa-release to 60.2
- Bumped loggregator to 103
- Bumped SLE12 & openSUSE stacks

### Fixed
- syslog-adapter added to syslog adapter cert

## [2.12.2] - 2018-08-16

## Changed
- Bumped SLE12 & openSUSE stacks

## [2.12.1] - 2018-08-15

### Changed
- Bumped SLE12 & openSUSE stacks

## [2.12.0] - 2018-08-14

### Added
- App-autoscaler included (off by default)
- Groot-btrfs now available
- Enabled cloud controller security events
- nfs-broker can now be HA

### Changed
- Realigned cf role composition more inline with upstream
- mysql-proxy role has been merged into the mysql role
- diego-locket role merged into diego-api
- log-api role combines loggregator and syslog-rlp roles
- Renamed syslog-adapter role to adapter
- Removed processes list from all roles
- Removed duplicate routing_api.locket.api_location property
- Bumped garden-runc-release to 1.15.1 to rely on go-nats
- Bumped ruby-buildpack to 1.7.21.1
- Bumped SLE12 & openSUSE stacks
- Bumped kubectl to 1.9.6
- Bumped cf-cli to 6.37.0

### Fixed
- INTERNAL_CA_KEY not included in every pod by default
- Better mechanism for waiting on MySQL

## [2.11.0] - 2018-06-26

### Added
- Certificate expiration now configurable
- Added support for manual rotation of cloud controller database keys
- New active/passive role management for pods
- Exposed router.client_cert_validation property

### Changed
- Bumped cf-deployment to 1.36
- Bumped UAA to v59
- Bumped diego-release to 2.8.0
- Bumped SLE12 & openSUSE stacks
- Bumped ruby-buildpack to 1.7.18.2
- Bumped go-buildpack to 1.8.22.1
- Bumped kubectl to 1.8.2
- Use namespace for helm install name

### Fixed
- Load balancer for Azure now usable
- Updated role manifest validation to let secrets generator use KUBE_SERVICE_DOMAIN_SUFFIX without configuring HA itself
- SCF_LOG_PORT now set to default of 514
- Fixed issue during upgrade whereby USB did not receive updated password info
- Patched monit_rsyslogd timestamp

## [2.10.1] - 2018-05-17 

### Changed
- Disabled optional consul role

### Fixed
- Immutable config variables will not be regenerated

## [2.10.0] - 2018-05-16

### Added
- cfdot added to all diego roles

### Changed
- Bumped SLE12 & openSUSE stacks
- Rotateable secrets are now immutable

### Fixed
- Upgrades for legacy versions that were using an older secrets generation model
- Upgrades will handle certificates better by having the required SAN metadata
- Apps will come back up and run after upgrade

## [2.9.0] - 2018-05-07

### Added
- The previous CF/UAA bumps should be considered minor updates, not patch releases, so we will bump this verison in light of the changes in 2.8.1 and rely on this as part of future semver

### Changed
- Bump PHP buildpack to v4.3.53.1 to address MS-ISAC ADVISORY NUMBER 2018-046

### Fixed
- Fixed string interpolation issue

## [2.8.1] - 2018-05-04

### Added
- Enabled router.forwarded_client_cert variable for router
- New syslog roles can have anti-affinity
- mysql-proxy healthcheck timeouts are configurable 

### Changed
- Bumped UAA to v56.0
- Bumped cf-deployment to v1.21
- Bumped SLE12 & openSUSE stacks
- Removed time stamp check for rsyslog

### Fixed
- MySQL HA scaling up works better

## [2.8.0] - 2018-04-03

### Added
- Added mysql-proxy for UAA
- Exposed more log variables for UAA

### Changed
- Bumped SLE12 stack
- Bumped fissile to 5.2.0+6
- Variable kube.external_ip now changed to kube.external_ips

### Fixed
- Addressed issue with how pods were indexed with invalid formatting 

## [2.7.3] - 2018-03-23
### Added
- TCP routing ports are now configurable and can be templatized
- CPU limits can now be set
- Kubernetes annotations enabled so operators can specify which nodes particular roles can run on

### Changed
- Bumped fissile to 5.1.0+128

### Fixed
- Changed how secrets are generated for rotation after 2.7.1 and 2.7.2 ran into problems during upgrades

## [2.7.2] - 2018-03-07
### Changed
- Bumped fissile to 5.1.0+89

## [2.7.1] - 2018-03-06
### Added
- Allow more than one IP address for external IPs
- MySQL now a clustered role
- More configurations for UAA logging level

### Changed
- To address CVE-2018-1221, bumped CF Deployment to 1.15 and routing-release to 0.172.0
- Bumped UAA to v55.0
- Bumped SLE12 & openSUSE stacks
- Bumped buildpack versions to latest

### Fixed
- Make the cloud controller clock role wait until the API is ready

## [2.7.0] - 2018-02-09
### Added
- Add ability to rename immutable secrets

### Changed
- Bump to CF Deployment (1.9.0), using CF Deployment not CF Release from now on
- Bump UAA to v53.3
- Update CATS to be closer to what upstream is using
- Make RBAC the default in the values.yaml (no need to specify anymore)
- Increase test brain timeouts to stop randomly failing tests
- Remove unused SANs from the generated TLS certificates
- Remove the dependency on jq from stemcells

### Fixed
- Fix duplicate buildpack ids when starting Cloud Foundry
- Fix an issue in the vagrant box where compilation would fail due
  to old versions of docker.
- Fix an issue where diego cell could not mount nfs in persi
- Fix many problems reported with the syslog forwarding implementation

## [2.6.11] - 2018-01-17
### Changed
- Helm charts now are published by ci with the correct registry.

## [2.6.10-rc3] - 2018-01-05
### Changed
- Combine variables controlling openSUSE vs SLES builds.

## [2.6.9-rc2] - 2018-01-05
### Changed
- Helm versions no longer include the build information in the semver
- Which stemcell is used is no longer governed by CI but by make files
- Jenkins now prevents overwriting of artifacts
- Prevent use of unconfigured stacks

### Fixed
- Fix mutual TLS when HA mode is true (fixes HA deployment problems)
- Fix ruby app deployment problem (missing libmysqlclient in stack)
- Fix configgin having insufficient permissions to configure HA deploy
- Fix issue where buildpacks couldn't upload because blobstore size limits
