# Changelog

## [Unreleased]

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
