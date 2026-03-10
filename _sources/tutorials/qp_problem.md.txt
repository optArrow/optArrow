# Quadratic Programming (QP) Problems in OptArrow

OptArrow provides an efficient optimization service using the Apache Arrow IPC format for inter-process communication. This document explains how to structure and send a Quadratic Programming (QP) problem to the OptArrow engine using Python.

## Standard QP Form

The QP problem should be structured as:

**Objective**: Minimize

$$
\frac{1}{2} x^T Q x + c^T x
$$

**Subject to**:

$$
Ax = b \quad \text{(equality constraints)}

Gx \leq h \quad \text{(inequality constraints)}

lb \leq x \leq ub \quad \text{(bounds)}
$$


### Model Components

* **Q**: Quadratic coefficient matrix (symmetric), stored as a sparse COO format with `row`, `col`, `val`
* **c**: Linear objective vector
* **A**: (Optional) Equality constraint matrix (sparse COO)
* **b**: (Optional) Right-hand side of equality constraints
* **G**: (Optional) Inequality constraint matrix (sparse COO)
* **h**: (Optional) Right-hand side of inequality constraints
* **lb**: (Optional) Lower bounds for each variable
* **ub**: (Optional) Upper bounds for each variable
* **osense**: (Optional) Objective sense: "min" or "max" (default is "min")

## IPC Request Structure (`ipc_dict`)

The message to OptArrow should be structured as follows:

```python
ipc_dict = {
    "model": model_data,       # The QP model data structure (see below)
    "model_name": "test_qp",   # Optional: model identifier
    "engine": "julia",         # Engine used for computation
    "solver": solver_config    # Solver configuration
    "time_limit": 60           # Optional: time limit in seconds (default is 300)
}
```

### `model` (Required)

QP model structured as a dictionary:

```python
model_data = {
    "Q": {
        "row": [...],     # Row indices for Q (symmetric matrix)
        "col": [...],     # Column indices for Q
        "val": [...]      # Values at (row, col)
    },
    "c": [...],           # Linear coefficients
    "A": {              # (Optional) Equality matrix
        "row": [...],
        "col": [...],
        "val": [...]
    },
    "b": [...],           # (Optional) RHS of equality constraints
    "G": {                # (Optional) Inequality matrix
        "row": [...],
        "col": [...],
        "val": [...]
    },
    "h": [...],           # (Optional) RHS of inequality constraints
    "lb": [...],          # (Optional) Lower bounds
    "ub": [...],          # (Optional) Upper bounds
    "osense": "min"       # (Optional) "min" or "max"
}
```

### `solver` (Required)

```python
solver = {
    "solver_name": "Gurobi",       # Example solver name
    "solver_type": "QP",         # Solver type
    "solver_params": {            # (Optional) solver-specific params
        "FeasibilityTol": 1e-5
    }
}
```
### `time_limit` (Optional)

An optional time limit for solving the optimization model, specified in seconds, default is 300.
This parameter is passed directly to the solver and controls how long it is allowed to run before stopping.

For solvers that support time limits, the solver will attempt to return the best feasible solution found so far when the time limit is reached.
If no feasible solution is found before the time limit, the solver may still return an infeasibility status or no solution.

### `model_name` (Optional)

For logging or traceability.

### `engine` (Required)

Specifies the backend system to be used for computation. Currently supports `"julia"` and `"python"`.

## Data Packaging with Apache Arrow

```python
ipc_table = dict_to_pa_table(ipc_dict)

sink = pa.BufferOutputStream()
with pa.ipc.new_stream(sink, ipc_table.schema) as writer:
    writer.write(ipc_table)

ipc_bytes = sink.getvalue().to_pybytes()
```

## Sending the Request

```python
headers = {
    "Content-Type": "application/vnd.apache.arrow.stream"
}

response = requests.post(url, data=ipc_bytes, headers=headers)
```

## Response

```python
reader = pa.ipc.open_stream(response.content)
result_table = reader.read_all()
```

## Notes

* Ensure symmetric structure in Q.
* G and h are optional; omit them for pure equality-constrained QP.
* Schema consistency is crucial; use Arrow types that match server expectations.
* Typical QP solvers include Gurobi, and Mosek.

