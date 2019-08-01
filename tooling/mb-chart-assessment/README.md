# Assessing the minibroker database charts.

The main purpose of the tooling in this directory is to assess which
of the publicly available charts for the databases supported by
minibroker will work with CAP.

## How to use the tooling

The main entry point / script is `../bin/assess-minibroker-charts`.

Note how this script is not in this subdirectory of `tooling/`, but in
the main tooling `bin/` directory.

The script and its helpers require:

- A working `kubectl` command in the `PATH`, with its config pointing to
- A working CAP cluster
- A working `cf` client command in the `PATH`. The tooling will target it to the CAP cluster.

Run the the script using

```
    /path/to/assess-minibroker-charts password namespace? flag
```

All arguments can be left out. Their defaults are

  - password = `changeme`
  - namespace = `cf`
  - flag = `1` == Start a fresh run.

Setting the flag to `0` activates `resume` mode where the script
ignores all charts for which it has log files, indicating that they
have been processed already.

This enables easy resumption of operation if the script was aborted,
be it a bug, or the user.

All files and directories used by the script will be placed into the
sub directory `_work/` of the current working directory, and all with
have the prefix `dbe-` in their names.

During operation the script will print progress information to its
standard output.

Note that the testing of a single chart can take up to 10 minutes,
although the average looks to be about 4 to 5 minutes. With about 140
charts to test per engine on average, and four engines we are looking
at just shy of two days for a full assessment all engines.

After the assessments is done run the script `../bin/assessment-to-yaml`.

This secondary entrypoint will convert the base results into
yaml-structured data listing the engines and working charts.

This yaml data is printed to the standard output, to be directed into
a file at the user's discretion and needs.

Result statistics will be printed to the standard error.

## Tool internals, for the maintainer.

The two entrypoints are are

  - ../bin/assess-minibroker-charts
  - ../bin/assessment-to-yaml

Both are shell scripts.
The second entrypoint is self-contained.
The first uses the shell and ruby scripts in this directory to perform its purpose.

  - `get-charts-for-engine.rb`: Using the master index of charts as input it pulls
    out the information for the supported databases
  - `get-chart-listing.rb`: Goes over the per-engine yaml and makes a list of the
    charts (versions, archive location).
  - `make-chart-index.rb`: Creates a helm repository index for each chart of each
    engine, referencing just that chart.
  - `assess-single-chart`: Runs the assessment process for a single chart of an
    engine.
  - `local-chart-repository`: Used by the assessment process to start and stop a
    helm repository referencing a single chart of an engine.

Beyond the above we have a number of engine-dependent patch files in the

  - `patches/`

directory which fix issues in the charts when used with
minibroker. Without these patches no chart will work.

The script `local-chart-repository` determines the patch to use and
applies it as part of setting up a helm repository for a chart.
