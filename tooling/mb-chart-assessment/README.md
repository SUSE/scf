# Assessing the minibroker database charts.

The main purpose of the tooling in this directory is to assess which
of the publicly available charts for the databases supported by
minibroker will work with SCF.

## How to use the tooling

The main entry point / script is `../bin/assess-minibroker-charts.rb`.

Note how this script is not in this subdirectory of `tooling/`, but in
the main tooling `bin/` directory.

The script and its helpers require:

  - A working `kubectl` command in the `PATH`, with its config
    pointing to
  - A working SCF+UAA cluster
  - A working `cf` client command in the `PATH`. The tooling will
    target it to the CAP cluster.
  - A working `patch` command in the `PATH`. For a vagrant box this
    means that is is necessary to run `sudo zypper install patch`
    before attempting an assessment.

Run the the script using

```
    /path/to/assess-minibroker-charts.rb --help
```

to get help about its options. Without `--help` the script runs with
the default configuration, i.e.

|Setting	|Value			|Option			|
|---		|---			|---			|
|CF namespace	|`cf`			|-n, --namespace	|
|Admin password	|(Vagrant standard)	|-p, --password		|
|Mode		|Full run		|-i, --incremental	|
|Work directory	|(Git root)/`_work/mb-chart-assessment`	|-w, --work-dir		|

The mode of `full run` means that all found charts are tested,
regardless of any previous results. Such a run takes about 2 days at
the moment.

An incremental run should be much faster. It is activated with option
`-i`. In this mode the script ignores all charts for which it has
results, indicating that they have been processed already.

This enables easy resumption of operation if the script was aborted,
be it a bug, or the user.

This also enables effective use from within a CI system, checking for
and processing only new charts as they are added to the stable.

All transient files and directories used by the script will be placed
into the work directory. The same is true for results.

During operation the script will print progress information to its
standard output.

Note that the testing of a single chart can take up to 10 minutes,
although the average looks to be about 4 to 5 minutes. With about 140
charts to test per engine on average, and four engines we are looking
at just shy of two days for a full assessment all engines.

## Tool internals, for the maintainer.

The entrypoint is

  - ../bin/assess-minibroker-charts.rb

Beyond the above we have a number of engine-dependent patch files in
the

  - `patches/`

directory which fix issues in the charts when used with minibroker.
Without these patches no chart will work.
