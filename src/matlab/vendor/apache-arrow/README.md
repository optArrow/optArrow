# Bundled Apache Arrow MATLAB Builds

This directory contains prebuilt Apache Arrow MATLAB interface packages used by
the OptArrow MATLAB adapter.

Current bundled platform:

- `linux-x86_64/arrow_matlab`

The package is expected to contain the Apache Arrow MATLAB `+arrow` package and
its native Linux MEX/shared library dependencies. `scripts/setupMATLABArrow.m`
automatically prefers this bundled Linux build on MATLAB `glnxa64`, then falls
back to `$HOME/arrow_matlab/arrow_matlab` when a bundled build is not available.

To add another platform, place the installed Arrow MATLAB package under a new
platform directory, for example:

- `macos-arm64/arrow_matlab`
- `macos-x86_64/arrow_matlab`
- `windows-x86_64/arrow_matlab`

Keep source-build support through `scripts/buildMATLABArrow.sh`; bundled
binaries are a convenience path, not the only supported installation method.
