# Changelog

## [Unreleased]

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
