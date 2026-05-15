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

## Boundaries To Preserve

Keep the repository boundaries clear:

- OptArrow owns the Gateway, engine dispatch, request schemas, solver adapters,
  Arrow IPC transport, and the general MATLAB client.
- Downstream projects own domain-specific adapters and solver-dispatch glue.

The MATLAB client is intended to be generic. It should know how to serialize
and send optimization models, but it should not encode domain-specific
conventions from any particular toolbox.

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

**Numeric objective sense**: some clients pass `osense` as a number (`-1` for
maximize, `+1` for minimize). The MATLAB client and the Python model
constructors both normalize numeric osense to the `'max'`/`'min'` strings that
the solver backend expects. Keep this normalization at the boundary layer, not
inside the solver itself.

**`stat` field**: solver backends must return a normalized `stat` field
(`1`=optimal, `0`=infeasible, `2`=unbounded, `-1`=error). Clients use `stat`
to determine whether the solve succeeded. Both the Python Pyomo path
(`opt_solver.py`) and the JSON controller path (`routers.py`) set this field.

Important files in `src/matlab/+optarrow/`:

- `checkSetup.m` — verify Gateway reachability and Arrow backend before solving
- `compute.m` — Arrow IPC or JSON request/response dispatch
- `solveLP.m` — LP convenience wrapper (accepts a standard LP struct, handles COO)
- `solveQP.m` — QP convenience wrapper (same pattern, adds F/Q Hessian)
- `getOptArrowConfig.m` / `setOptArrowConfig.m` — global runtime config

Other important paths:

- `scripts/setupMATLABArrow.m`
- `scripts/buildMATLABArrow.sh`
- `src/matlab/vendor/apache-arrow/` — bundled Linux x86_64 Arrow MATLAB build

The bundled build may fail on some MATLAB installations because of C++ runtime
compatibility (`GLIBCXX_*` errors). When that happens, build Arrow MATLAB
locally with `scripts/buildMATLABArrow.sh`.

## Optimization Problem Types

Understanding the four categories below is important for deciding what OptArrow
currently supports well, where it has workarounds, and what would require
architectural additions.

### 1. Single (One-Shot) Optimization

A single model is built, sent to the solver, and a single result is returned.
The client does not need to call the solver again.

**Examples**: one LP to size a network, one QP to fit a model to data.

**OptArrow support**: fully supported. This is the primary design target. The
stateless request/response Gateway is a natural fit.

---

### 2. Iterative Independent Optimization (Embarrassingly Parallel)

Many independent optimization problems are solved, one per scenario, sample,
or parameter point. There is no dependency between the individual problems —
each can run concurrently.

**Examples**: Monte Carlo sensitivity analysis, parameter sweeps, scenario
enumeration, cross-validation folds.

**OptArrow support**: supported through repeated independent calls. Because
each request is stateless and self-contained, the client can dispatch many
requests in parallel to the same Gateway or to multiple Gateway instances. No
session state is needed. The main scaling lever is horizontal: run more Gateway
or engine workers.

**Practical note**: if the number of parallel problems is large, consider
batching requests or running multiple Gateway processes behind a load balancer.
OptArrow does not yet have a native batch endpoint, so orchestration currently
lives on the client side.

---

### 3. Sequential Soft-Dependent Optimization

Problems are solved in sequence, and each solve's result influences the next
problem's parameters, but the dependency is loose enough that re-submitting a
fresh model each time is acceptable. A warm start from the previous solution
would help performance but is not strictly required for correctness.

**Examples**: outer-loop parameter estimation where each inner LP updates
bounds for the next; iterative re-weighting in robust regression; network flow
problems where capacities are updated between rounds.

**OptArrow support**: partially supported. The client can submit a full,
updated model for each iteration — the current stateless design handles this
correctly. What is missing is warm starting: the Gateway discards all solver
state after each response, so the solver restarts cold for every request. For
many problem sizes this is acceptable. For large-scale or many-iteration loops
it can be a significant cost.

**Workaround today**: re-submit the full updated model each iteration and
accept the cold-start overhead. For LP, HiGHS re-solves from scratch but is
typically fast enough.

**Future path**: expose an optional basis/incumbent hint field in the request
schema so the client can pass the previous solution as a starting point, even
without server-side state.

---

### 4. Sequential Hard-Dependent Optimization

Each iteration depends tightly on the internal solver state from the previous
one — basis reuse, warm start from an interior point, branch-and-bound node
information, or incremental constraint/variable addition. Re-solving from
scratch each iteration is either incorrect or prohibitively expensive.

**Examples**: online re-optimization where columns or rows are added
incrementally; branch-and-bound with custom branching logic that must continue
from a specific node; parametric LP where the objective or RHS is swept and
each step requires the previous optimal basis; sensitivity analysis that
mutates the model in place.

**OptArrow support**: not currently supported. The stateless architecture
cannot reuse solver state between requests.

**Future path**: a session mode with an explicit lifecycle:

1. `POST /session` — create a named session, load the model once.
2. `POST /session/{id}/solve` — solve and return result; state is retained.
3. `POST /session/{id}/update` — update bounds, objective, or constraints.
4. `POST /session/{id}/solve` — re-solve from the retained basis.
5. `DELETE /session/{id}` — release solver resources.

This requires changes to the Gateway (session store, lifecycle management),
engine adapters (expose basis read/write), and the client (session ID
handling). Keep stateless solves as the default; sessions should be opt-in.

---

## Current Strengths

- LP and QP request paths exist for both Python and Julia engines.
- JSON (`/computeJSON`) and Arrow IPC (`/compute`) Gateway endpoints exist.
- All solver responses include a normalized `stat` field (`1`=optimal,
  `0`=infeasible, `2`=unbounded, `-1`=error).
- Numeric objective sense from client code is normalized to `'max'`/`'min'`
  at both the MATLAB client layer and the Python model constructors.
- MATLAB can call the Gateway through Arrow IPC without a Python bridge.
  Arrow detection uses `which('arrow.recordBatch')`, which works for MEX and
  P-files.
- MATLAB falls back to `/computeJSON` when Arrow MATLAB is unavailable.
- `optarrow.checkSetup` provides a health-check: verifies MATLAB version,
  Arrow backend, and Gateway reachability.
- `optarrow.solveLP` and `optarrow.solveQP` hide COO serialization from callers.
- Reference fixtures and benchmark tests exist under `tests/fixtures/reference`
  and `tests/reference_benchmarks`.

## Known Gaps

- MILP and MIQP are not yet fully exposed as first-class OptArrow problem types.
- Sequential hard-dependent optimization (session mode) is not supported.
  See the Optimization Problem Types section above.
- There is no native batch endpoint; parallel independent solves are
  orchestrated on the client side.
- Solver support varies by engine and problem type; there is no central table
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

## Good First Maintenance Tasks

- Clarify which solvers support LP, QP, MILP, and MIQP in each engine and
  add that as a table in the docs.
- Add small contract tests for Arrow IPC request and response schemas.
- Add a short troubleshooting table for solver installation issues.
- Add a native batch endpoint for parallel independent solves.
- The `src/matlab/interface/` directory is a leftover from the old layout
  before the `+optarrow` package was introduced. Verify it contains nothing
  of value and remove it.

## Handoff Advice

Prefer small, well-tested changes. The hardest bugs in this project tend to sit
at boundaries: client to Arrow, Arrow to Gateway, Gateway to Python or Julia,
and solver status back to a normalized response. When changing one boundary,
write down the contract and test both sides of it.

If you are unsure where a feature belongs, ask whether it is general OptArrow
behavior or a downstream domain adaptation. General transport, schemas, and
solver behavior belong here. Domain-specific integration details belong in the
downstream project.
