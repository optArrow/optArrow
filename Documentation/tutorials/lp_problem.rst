Linear Programming (LP) Problems in OptArrow
============================================

OptArrow provides a high-performance and lightweight optimization service that leverages Apache Arrow's IPC format for communication. This document outlines how to format and send a Linear Programming (LP) problem to the OptArrow engine using Python, based on the standard LP form.

Standard LP Form
----------------

The LP problem should be structured as:

**Objective**: Maximize 

.. math::

   c^T x

**Subject to**:

.. math::

     Ax = b \quad \text{(equality constraints)}
   
     lb \leq x \leq ub \quad \text{(bounds)}

Model Components
^^^^^^^^^^^^^^^^

* **A**: Constraint matrix, stored as a sparse COO matrix with three columns: `row`, `col`, and `val`
* **b**: Right-hand side vector
* **c**: Objective function coefficients
* **lb**: Lower bounds for each variable (optional)
* **ub**: Upper bounds for each variable (optional)
* **osense**: Objective sense, either "min" or "max" (optional, default is "min")
* **csense**: Constraint sense list (e.g., `["E", "L", "G"]` for =, <=, >=). Optional, defaults to all equality constraints

IPC Request Structure (`ipc_dict`)
----------------------------------

The message sent to OptArrow should be a Python dictionary structured as follows before being serialized to Arrow IPC format:

.. code-block:: python

   ipc_dict = {
       "model": model_data,       # The LP model specification (see below)
       "model_name": "test_lp",   # Optional: name or tag for the model
       "engine": "julia",         # The backend engine used for solving (e.g., "julia")
       "solver": solver_config    # Solver configuration (see below)
       "time_limit": 60           # Optional: time limit in seconds
   }

`model` (Required)
^^^^^^^^^^^^^^^^^^

A dictionary describing the LP model in the following format:

.. code-block:: python

   model_data = {
       "A": {
           "row": [...],      # List of row indices (0-based) for the sparse constraint matrix
           "col": [...],      # List of column indices (0-based)
           "val": [...]       # List of corresponding values for each (row, col) pair
       },
       "b": [...],            # RHS vector
       "c": [...],            # Objective function coefficients
       "lb": [...],           # (Optional) Lower bounds for each variable
       "ub": [...],           # (Optional) Upper bounds for each variable
       "osense": "min",       # (Optional) Objective sense: "min" or "max" (default: "min")
       "csense": [...]        # (Optional) List of constraint senses: "E", "L", "G"
   }

`solver` (Required)
^^^^^^^^^^^^^^^^^^^

A dictionary specifying the solver and optional parameters:

.. code-block:: python

   solver = {
       "solver_name": "HiGHS",     # Name of the solver
       "solver_type": "LP",        # Type of solver (e.g., LP, QP)
       "solver_params": {          # (Optional) Solver-specific parameters
           "primal_feasibility_tolerance": 1e-06
       }
   }

`time_limit` (Optional)
^^^^^^^^^^^^^^^^^^^^^^^

An optional time limit for solving the optimization model, specified in seconds, default is 300.
This parameter is passed directly to the solver and controls how long it is allowed to run before stopping.

For solvers that support time limits, the solver will attempt to return the best feasible solution found so far when the time limit is reached.
If no feasible solution is found before the time limit, the solver may still return an infeasibility status or no solution.

`model_name` (Optional)
^^^^^^^^^^^^^^^^^^^^^^^

A human-readable identifier for logging or debugging purposes.

`engine` (Required)
^^^^^^^^^^^^^^^^^^^

Specifies the backend system to be used for computation. Currently supports `"julia"` and `"python"`.

Data Packaging with Apache Arrow
--------------------------------

Before sending a request to OptArrow, you need to convert the model data into an Arrow `Table` and encode it as an IPC stream:

.. code-block:: python

   ipc_table = dict_to_pa_table(ipc_dict)
   
   sink = pa.BufferOutputStream()
   with pa.ipc.new_stream(sink, ipc_table.schema) as writer:
       writer.write(ipc_table)
   
   ipc_bytes = sink.getvalue().to_pybytes()

Sending the Request
-------------------

Send the encoded model as an HTTP POST request with the appropriate content type:

.. code-block:: python

   headers = {
       "Content-Type": "application/vnd.apache.arrow.stream"
   }
   
   response = requests.post(url, data=ipc_bytes, headers=headers)

Response
--------

The response will be an Arrow IPC stream containing the solution or error message. You can deserialize it using:

.. code-block:: python

   reader = pa.ipc.open_stream(response.content)
   result_table = reader.read_all()

Notes
-----

* Make sure that all optional fields are included only when necessary.
* The OptArrow server expects a well-formed Arrow IPC stream; mismatches in schema may lead to server errors.
* Typical solvers supported include HiGHS and Ipopt, etc.
