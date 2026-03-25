LP Example: Production Optimization
===================================

This tutorial illustrates how to model and solve a real-world linear programming (LP) problem using the **OptArrow** optimization engine. The example is based on a classic production optimization problem where multiple products must be manufactured using limited resources to **maximize profit** while respecting **resource**, **demand**, and **capacity** constraints.

Problem Overview
----------------

A factory has a limited stock of raw materials:

- 200 units of **Raw Material A**
- 120 units of **Raw Material B**
- 150 units of **Raw Material C**

The factory produces two types of products: **Product X** and **Product Y**.

.. list-table:: Resource usage and profit
   :header-rows: 1

   * - Resource Usage
     - Product X
     - Product Y
   * - Material A (units)
     - 20
     - 10
   * - Material B (units)
     - 10
     - 20
   * - Material C (units)
     - 10
     - 30
   * - Profit per unit
     - 5
     - 12

Mathematical Formulation
------------------------

The LP problem can be formulated as follows:

**Objective**: 
Maximize profit

.. math::

   Z = 5x + 12y

where $x$ is the number of Product X produced and $y$ is the number of Product Y produced.
**Subject to**:

.. math::

   \begin{aligned}
   20x + 10y &\leq 200 \quad &\text{(Material A constraint)} \\
   10x + 20y &\leq 120 \quad &\text{(Material B constraint)} \\
   10x + 30y &\leq 150 \quad &\text{(Material C constraint)} \\
   x, y &\geq 0 \quad &\text{(Non-negativity constraints)}
   \end{aligned}

General LP Formulation
----------------------

The LP problem should be structured as:

**Objective**: Maximize $c^T x$
where $c$ is the profit vector and $x$ is the production vector.

**Subject to**:

.. math::

   Ax = b; \quad lb \leq x \leq ub

where $A$ is the resource usage matrix, $b$ is the resource availability vector, and $lb$, $ub$ are the lower and upper bounds on the production quantities.

.. math::

   c =
   \begin{bmatrix}
   5 \\
   12
   \end{bmatrix},
   \quad
   x =
   \begin{bmatrix}
   x \\
   y
   \end{bmatrix},
   \quad
   A =
   \begin{bmatrix}
   20 & 10 \\
   10 & 20 \\
   10 & 30
   \end{bmatrix},
   \quad
   b =
   \begin{bmatrix}
   200 \\
   120 \\
   150
   \end{bmatrix}
   \quad
   lb =
   \begin{bmatrix}
   0 \\
   0
   \end{bmatrix}

Solving with OptArrow
---------------------

The following code illustrates how this linear program can be defined and solved using **OptArrow** in Python:

A is the matrix in Coordinate(COO) format, which is a sparse matrix format suitable for large matrices. The `row`, `col`, and `val` lists represent the non-zero entries of the matrix.

.. code-block:: python

   ipc_dict = {
     "model": {
       "A": {
         "row": [0, 0, 1, 1, 2, 2],
         "col": [0, 1, 0, 1, 0, 1],
         "val": [20, 10, 10, 20, 10, 30]
       },
       "b": [200, 120, 150],
       "c": [5, 12],
       "lb": [0, 0],
       "csense": ["L", "L", "L"], # 'L' for less than or equal to constraints
       "osense": "max"
     },
     "model_name": "product_mix_lp",
     "engine": "julia", # Using Julia as the optimization engine, also supports Python
     "solver": {
       "solver_name": "HiGHS", # Using HiGHS solver for LP problems, also supports other solvers
       "solver_type": "LP", # Specify the solver type as LP
       "solver_params": {} # Additional solver parameters can be added here
     }
   }

Using Arrow IPC Stream Bytes Format
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: python

   import pyarrow as pa
   import requests
   
   # Convert the dictionary to an Arrow table for IPC serialization
   pa_arrays = [pa.array([v]) for v in ipc_dict.values()]
   table = pa.Table.from_arrays(pa_arrays, names=list(ipc_dict.keys()))
   
   # Serialize the table to IPC stream bytes
   sink = pa.BufferOutputStream()
   with pa.ipc.new_stream(sink, table.schema) as writer:
       writer.write(table)
   ipc_bytes = sink.getvalue().to_pybytes()
   
   # Send the IPC stream bytes to the server
   headers = {"Content-Type": "application/vnd.apache.arrow.stream"}
   response = requests.post("http://localhost:8000/compute", data=ipc_bytes, headers=headers)
   
   # Check if the response is successful
   if response.status_code != 200:
       print(f"Error: {response.status_code} - {response.text}")
   # response is ipc stream
   reader = pa.ipc.open_stream(response.content)
   result_table = reader.read_all()
   result_dict = {name: result_table.column(name).to_pylist() for name in result_table.column_names}
   print(result_dict)

Using JSON
^^^^^^^^^^

.. code-block:: python

   headers = {"Content-Type": "application/json"}
   response = requests.post("http://localhost:8000/computeJSON", json=ipc_dict, headers=headers)
   print(response.json())
