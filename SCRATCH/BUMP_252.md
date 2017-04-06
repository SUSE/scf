# Intermediate results in bumping HCF to CF 252

 * [Release notes](https://github.com/cloudfoundry/cf-release/releases/tag/v252)

Fetched, cloned and compared `cf`, `diego`, `garden-runc`, and
`cflinuxfs2-rootfs` releases.  Ignored `cf-networking` (not used by us,
so far), and `Stemcell` information.

Running `fissile diff` reported no changes for the `garden-runc` and
`cflinuxfs2-rootfs` releases.

The `cf` and `diego` releases had changes. See `DELTA-cf-release.txt`
and `DELTA-diego-release.txt`

The file `MODDED` contains the set of added, removed, or changed
properties, with comments for separation and notes.

The file `LOCATIONS.txt` provides information where the properties
were found in the releases (templates and specs), plus descriptions,
defaults, and notes about possible handling.

An issue I saw was that a number of the *new* properties reported by
`fissile diff` were not found in the new releases at all, in no file.
Examples:

 * cf.cloud_controller_ng.cc.diego.pid_limit
 * cf.cloud_controller_ng.cc.diego.temporary_local_tps
 * cf.cloud_controller_ng.cc.loggregator.internal_url

On the other hand, `diff` also reported these properties without the
prefix `cf.cloud_controller_ng`, i.e. as

 * cc.diego.pid_limit
 * cc.diego.temporary_local_tps
 * cc.loggregator.internal_url

and in these forms they were properly found. Similarly for the prefix
`cf.cloud_controller_worker`.

Do I misunderstand the output of `fissile diff` here ?
A bug in `fissile diff` ?
Something else ?

It feels a bit as if `diff` reports properties under their proper
names, and also under names where release and job name are used as
prefix to the proper name ?!

Table: Attached Files

|File			|Notes								|
|---			|---								|
|DELTA-cf-release.txt	|Output of `fissile diff`					|
|DELTA-diego-release.txt|Output of `fissile diff`					|
|MODDED			|DELTA reduced to properties, with annotations			|
|LOCATIONS.txt		|MODDED annotated with using files, x-refs, possible actions	|
|PROP.txt		|LOCATIONS.txt reduced to properties with action annotations	|
|PROP_TABLE.txt		|PROP.txt reformatted to table of properties and actions	|
|ACTION.txt		|PROP_TABLE.txt reduced to properties with actual actions	|

Summary of ACTION.txt:

 * 2 dropped properties to check the manifest, opinions for use
 * 6 new secrets to generate
 * 1 property with a changed value to investigate
 * 1 property to provide an opinion for, or expose
