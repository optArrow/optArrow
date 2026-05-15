# Future Contributor Notes

This note is intentionally kept at the repository root and is not linked from
the Sphinx documentation. It is meant as a maintainer handoff, not as published
user-facing website content.

## Project State

OptArrow is a cross-language optimization service. Its current stable shape is
a stateless request/response Gateway that accepts a full optimization model,
normalizes it, dispatches it to a Python or Julia solver path, and returns the
result.

The most important implemented path is:

1. Client sends an LP or QP request.
2. Gateway receives JSON or Apache Arrow IPC.
3. Controller builds the appropriate model and solver configuration.
4. Python or Julia engine solves the model.
5. Gateway returns JSON or Arrow IPC response.

The current architecture works best for one-shot LP/QP solves. It is not yet a
stateful iterative optimization system. Clients should assume each request sends
the full model.

## Boundaries To Preserve

Keep the repository boundaries clear:

- OptArrow owns the Gateway, engine dispatch, request schemas, solver adapters,
  Arrow IPC transport, and the general MATLAB client.
- Downstream projects own toolbox-specific adapters and solver-dispatch glue.

This separation matters because the MATLAB client is intended to be generic. It
should know how to serialize and send optimization models, but it should not
use specific toolboxes details.

## MATLAB And Arrow IPC

The MATLAB interface lives in `src/matlab/+optarrow/` — a MATLAB package
folder. Add `src/matlab` to the MATLAB path; MATLAB discovers the `+optarrow`
package automatically. Functions are called as `optarrow.compute(...)`,
`optarrow.solveLP(...)`, etc.

The client prefers native Apache Arrow IPC. It serializes sparse matrices as
COO arrays and sends a flat Arrow IPC stream to the Gateway. No Python
interpreter is involved on the MATLAB client side.

There is also a JSON fallback for environments where Apache Arrow MATLAB is not
installed. With `transport` set to `auto`, the client uses Arrow when available
and otherwise posts to `/computeJSON`. Treat JSON as a compatibility and setup
path; Arrow IPC remains the preferred transport for large sparse models.

**Arrow detection**: use `~isempty(which('arrow.recordBatch'))`, not
`exist('arrow.recordBatch', 'file') == 2`. The `exist` check only matches
plain M-files and misses MEX files and P-files installed by the Arrow add-on.

**COBRA numeric osense**: COBRA passes `osense = -1` (maximize) and `osense = 1`
(minimize) as numbers. The MATLAB client and the Python model constructors both
normalize numeric osense to the `'max'`/`'min'` strings that the solver backend
expects.

**`stat` field**: solver backends must return a normalized `stat` field
(`1`=optimal, `0`=infeasible, `2`=unbounded, `-1`=error). Downstream toolboxes
such as COBRA check `stat`, not just `status`, to determine whether the solve
succeeded. Both the Python Pyomo path (`opt_solver.py`) and the JSON controller
path (`routers.py`) now set this field.

Important files in `src/matlab/+optarrow/`:

- `checkSetup.m` — verify Gateway reachability and Arrow backend before solving
- `compute.m` — Arrow IPC or JSON request/response dispatch
- `solveLP.m` — LP convenience wrapper (accepts COBRA-style struct, handles COO)
- `solveQP.m` — QP convenience wrapper (same pattern, adds F/Q Hessian)
- `getOptArrowConfig.m` / `setOptArrowConfig.m` — global runtime config

Other important paths:

- `scripts/setupMATLABArrow.m`
- `scripts/buildMATLABArrow.sh`
- `src/matlab/vendor/apache-arrow/` — bundled Linux x86_64 Arrow MATLAB build

The bundled build may fail on some MATLAB installations because of C++ runtime
compatibility (`GLIBCXX_*` errors). When that happens, build Arrow MATLAB
locally with `scripts/buildMATLABArrow.sh`.

## Current Strengths

- LP and QP request paths exist for both Python and Julia engines.
- JSON (`/computeJSON`) and Arrow IPC (`/compute`) Gateway endpoints exist.
- All solver responses include a normalized `stat` field (`1`=optimal,
  `0`=infeasible, `2`=unbounded, `-1`=error) — required by toolboxes like COBRA.
- COBRA numeric `osense` (`-1`/`+1`) is normalized to `'max'`/`'min'` at both
  the MATLAB client layer and the Python model constructors.
- MATLAB can call the Gateway through Arrow IPC without using MATLAB's Python
  bridge. Detects Arrow via `which('arrow.recordBatch')` (works for MEX and
  P-files, unlike the older `exist(...,'file')==2` check).
- MATLAB falls back to `/computeJSON` when Arrow MATLAB is unavailable.
- `optarrow.checkSetup` provides a health-check call before solving: verifies
  MATLAB version, Arrow backend, and Gateway reachability.
- `optarrow.solveLP` and `optarrow.solveQP` hide COO serialization from callers.
- Reference fixtures and benchmark tests exist under `tests/fixtures/reference`
  and `tests/reference_benchmarks`.

## Known Gaps

- MILP and MIQP are not yet fully exposed as first-class OptArrow problem types.
- The Gateway does not expose persistent sessions, model caches, warm starts,
  basis reuse, or incremental model updates.
- Solver support varies by engine and problem type; there is no central matrix
  of which solver supports which problem type on which engine.
- MATLAB Arrow support depends on platform-specific native binaries or a local
  source build.
- Packaging and installation are still more source-oriented than end-user
  polished.

## Before Changing Behavior

Before changing request schemas, transport, or solver dispatch, check the full
path instead of only unit-level behavior:

```bash
poetry run pytest
pytest tests/reference_benchmarks -q
```

For Julia-specific coverage:

```bash
julia --project=src/service/optimization_service/julia tests/test_julia_lp.jl
julia --project=src/service/optimization_service/julia tests/test_julia_qp.jl
```

For MATLAB work:

1. Start the Gateway (`sh scripts/startAll.sh`).
2. Add `src/matlab` to the MATLAB path.
3. Run `optarrow.checkSetup()` — confirms Gateway reachability and Arrow backend.
4. If Arrow is available: verify `arrow.recordBatch(table(["A"; "B"], [1; 2]))`.
5. Run a small LP through `optarrow.solveLP` and confirm `result.stat == 1`.
6. If working on COBRA integration, run the COBRA-side OptArrow smoke tests
   (`testOptArrowBackend`, `testOptArrowEcoliCoreFBA`, etc.).

## Good First Maintenance Tasks

- Clarify which solvers support LP, QP, MILP, and MIQP in each engine and
  add that as a table in the docs.
- Add small contract tests for Arrow IPC request and response schemas.
- Add a short troubleshooting table for solver installation issues.
- Decide whether the public docs should describe only implemented behavior or
  also planned session-based architecture.
- The `src/matlab/interface/` directory is a leftover from the old layout before
  the `+optarrow` package was introduced. Verify it contains nothing of value
  and remove it.

## Design Direction

The likely next architectural step is not to replace the current stateless
design. A better path is to keep stateless solves as the default and add an
explicit session mode later.

A future session mode would need a clear lifecycle:

- create a model/session
- solve
- update bounds/objective/constraints
- solve again
- close the session

Until that exists, contributors should avoid implying that OptArrow reuses
solver state between requests.

## Handoff Advice

Prefer small, well-tested changes. The hardest bugs in this project tend to sit
at boundaries: MATLAB to Arrow, Arrow to Gateway, Gateway to Python or Julia,
and solver status back to a normalized response. When changing one boundary,
write down the contract and test both sides of it.

If you are unsure where a feature belongs, ask whether it is general OptArrow
behavior or a downstream toolbox adaptation. General transport, schemas, and
solver behavior belong here. Domain-specific integration details belong in the
downstream project.
