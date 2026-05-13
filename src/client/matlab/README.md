# OptArrow MATLAB Interface

This directory contains the general MATLAB client for sending optimization
models to the OptArrow Gateway using Apache Arrow IPC.

The current MATLAB path is intentionally narrow:

- MATLAB builds a plain model struct for LP or QP problems.
- Sparse matrices are serialized as COO arrays (`row`, `col`, `val`, `shape`).
- `optarrow.compute` converts the request to a flat Arrow IPC stream.
- The request is posted to the Gateway endpoint.
- The Arrow IPC response is decoded back into a MATLAB struct.

No Python interpreter is involved on the MATLAB client side. Python and Julia
are still used by the OptArrow services behind the Gateway.

When Apache Arrow MATLAB is not installed, the client can fall back to the
Gateway's JSON route (`/computeJSON`). JSON fallback is intended for setup
verification and compatibility; Arrow IPC remains the preferred path for large
sparse models.

## Files

- `interface/setOptArrowConfig.m`: Set global OptArrow runtime config.
- `interface/getOptArrowConfig.m`: Read global OptArrow runtime config.
- `interface/compute.m`: Generic Arrow IPC request/response call.
- `interface/solveLP.m`: LP convenience wrapper (`LPproblem` struct to OptArrow payload).
- `interface/solveQP.m`: QP convenience wrapper (`QPproblem` struct to OptArrow payload).
- `vendor/apache-arrow/`: Optional bundled Apache Arrow MATLAB builds.

The MATLAB functions are written for the `optarrow.*` package namespace. In an
installed copy, the files in `interface/` should be available on the MATLAB path
as the `+optarrow` package folder. Downstream integrations, such as COBRA
Toolbox adapters, should keep toolbox-specific conversion and solver-dispatch
logic outside this general MATLAB client.

## Requirements

- MATLAB R2023b or later.
- Apache Arrow MATLAB interface available on the MATLAB path.
- A running OptArrow Gateway, usually at `http://127.0.0.1:8000/compute`.

Arrow IPC is the preferred MATLAB transport. MATLAB must be able to create
Arrow record batches and Arrow IPC streams to use the high-throughput path. If
Arrow is unavailable and `transport` is set to `auto` or `json`, the client
posts the same logical request to `/computeJSON` using MATLAB's native JSON
support.

## Set Up Apache Arrow For MATLAB

These steps assume you are working from the OptArrow repository:

```bash
git clone https://github.com/optArrow/optArrow.git
cd optArrow
```

### 1. Try The Bundled Linux Build

On Linux x86_64, OptArrow includes an experimental bundled Apache Arrow MATLAB
build under:

```text
src/matlab/vendor/apache-arrow/linux-x86_64/arrow_matlab
```

From MATLAB, run:

```matlab
run scripts/setupMATLABArrow.m
```

The setup script first looks for the bundled Linux build. If it is found, it
adds it to the MATLAB path, verifies it by constructing an Arrow record batch,
and then saves the MATLAB path.

Verify manually with:

```matlab
arrow.recordBatch(table(["A"; "B"], [1; 2]))
```

If MATLAB prints a `RecordBatch`, Arrow is ready.

### 2. Build Arrow If The Bundled Build Is Not Compatible

If `setupMATLABArrow` cannot find a usable build, or if MATLAB reports a
`GLIBCXX_*` runtime error while loading the bundled MEX file, build Apache Arrow
and the MATLAB interface locally.

Install build prerequisites:

```bash
# Debian/Ubuntu
sudo apt install -y cmake build-essential

# macOS
xcode-select --install
brew install cmake
```

Then run:

```bash
./scripts/buildMATLABArrow.sh
```

The script clones Apache Arrow if needed, builds Arrow C++, builds the MATLAB
bindings, and installs them by default to:

```text
$HOME/arrow_no_s3
$HOME/arrow_matlab
```

After the build finishes, rerun the setup script from MATLAB:

```matlab
run scripts/setupMATLABArrow.m
```

Or add the source-built interface manually:

```matlab
addpath(fullfile(getenv('HOME'), 'arrow_matlab', 'arrow_matlab'));
savepath;
arrow.recordBatch(table(["A"; "B"], [1; 2]))
```

Optional S3-enabled build:

```bash
./scripts/buildMATLABArrow.sh --with-s3
```

The build paths can be customized with:

- `ARROW_REPO_DIR`
- `ARROW_CPP_INSTALL`
- `ARROW_MATLAB_INSTALL`

## Why Models Must Be Serialized

The Gateway accepts Arrow IPC bytes. MATLAB structs, sparse matrices, and cell
arrays cannot be sent directly over HTTP as MATLAB objects. Before posting a
request, the MATLAB client serializes the optimization model into Arrow-friendly
columns.

For sparse matrices, the interface uses COO form:

```matlab
[row, col, val] = find(A);
model.A = struct( ...
    'row', row(:)' - 1, ...
    'col', col(:)' - 1, ...
    'val', val(:)', ...
    'shape', [size(A, 1), size(A, 2)]);
```

Rows and columns are zero-based because the Gateway and Python/Julia engine
side expect zero-based matrix coordinates. Vector fields such as `b`, `c`,
`lb`, `ub`, and `csense` are packed as Arrow list columns. Solver options are
packed as parallel key/value string lists.

Most users should call `optarrow.solveLP` or `optarrow.solveQP`; these wrappers
build the serialized model payload for you. Use `optarrow.compute` directly
only when you already have an OptArrow payload struct.

A direct `optarrow.compute` payload should include:

- `problem_type`: `LP` or `QP`.
- `engine`: backend engine name, for example `python` or `julia`.
- `solver_name`: backend solver name, for example `HiGHS` or `Gurobi`.
- `model_name`: label used by the backend for logging/debugging.
- `time_limit`: solver time limit in seconds.
- `solver_params`: backend option struct.
- `model`: serialized LP/QP model struct.

## Configure The MATLAB Client

Start the OptArrow Gateway first. From the repository root, one common local
path is:

```bash
sh scripts/startAll.sh
```

Then configure MATLAB:

```matlab
cfg = struct( ...
    'engine', 'python', ...
    'backendSolver', 'HiGHS', ...
    'backendSolverType', 'LP', ...
    'backendOptions', struct(), ...
    'endpoint', 'http://127.0.0.1:8000/compute', ...
    'timeoutSec', 120, ...
    'transport', 'auto');

optarrow.setOptArrowConfig(cfg);
```

Supported MATLAB transports:

- `auto`: use Arrow IPC when Apache Arrow MATLAB is installed, otherwise JSON.
- `arrow`: require Arrow IPC and fail if Apache Arrow MATLAB is unavailable.
- `json`: always use `/computeJSON`.

For JSON fallback, `optarrow.compute` rewrites a configured `/compute` or
`/cobra/compute` endpoint to `/computeJSON`.

## Solve An LP

```matlab
LPproblem = struct();
LPproblem.A = sparse([20 10; 10 20; 10 30]);
LPproblem.b = [200; 120; 150];
LPproblem.c = [5; 12];
LPproblem.lb = [0; 0];
LPproblem.ub = [1000; 1000];
LPproblem.csense = ['L'; 'L'; 'L'];
LPproblem.osense = -1;  % -1=max, 1=min

result = optarrow.solveLP(LPproblem, struct('modelName', 'matlab_lp'));
disp(result)
```

## Solve A QP

```matlab
QPproblem = struct();
QPproblem.F = sparse([2 0; 0 2]);
QPproblem.c = [-2; -5];
QPproblem.A = sparse([1 1]);
QPproblem.b = 3;
QPproblem.lb = [0; 0];
QPproblem.csense = 'E';
QPproblem.osense = 1;

result = optarrow.solveQP(QPproblem, struct('modelName', 'matlab_qp'));
disp(result)
```

## Expected Response

The decoded response is a MATLAB struct. Common fields include:

- `success`: logical success flag.
- `status`: backend status text.
- `stat`: normalized numeric status (`1` optimal, `0` infeasible, `2` unbounded, `-1` error).
- `obj_val`: objective value.
- `solution`: primal solution vector.
- `dual`: constraint duals, when available.
- `rcost`: reduced costs, when available.
- `slack`: constraint slack, when available.
- `method`: backend method label, when available.
- `time`: backend solve time, when available.

## Troubleshooting

- If MATLAB cannot find `arrow.recordBatch`, run `scripts/setupMATLABArrow.m`.
- If the bundled Arrow build fails with `GLIBCXX_*`, build Arrow locally with
  `./scripts/buildMATLABArrow.sh`.
- If Arrow is not available and you only need a compatibility path, configure
  `transport` as `auto` or `json`.
- If HTTP requests fail, confirm the Gateway is running and the configured
  `endpoint` matches the server route.
- If a sparse model gives incorrect dimensions, include `shape` in the COO
  matrix struct or use `optarrow.solveLP` / `optarrow.solveQP` to build it.
- If `optarrow.*` functions are not found, confirm the installed MATLAB client
  is on the path as a `+optarrow` package.
