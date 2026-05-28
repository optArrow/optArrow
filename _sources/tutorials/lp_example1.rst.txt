LP Example: Production Optimization
====================================

This tutorial illustrates how to model and solve a linear programming (LP) problem using OptArrow. The example maximizes profit from two products given limited resources.

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

**Objective**: Maximize profit

.. math::

   Z = 5x + 12y

where :math:`x` is the number of Product X produced and :math:`y` is the number of Product Y produced.

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

**Objective**: Maximize :math:`c^T x`
where :math:`c` is the profit vector and :math:`x` is the production vector.

**Subject to**:

.. math::

   Ax \leq b; \quad lb \leq x \leq ub

where :math:`A` is the resource usage matrix, :math:`b` is the resource availability vector, and :math:`lb`, :math:`ub` are the lower and upper bounds on the production quantities.

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

The following code illustrates how this LP can be defined and solved using OptArrow in Python.

The constraint matrix ``A`` is provided in Coordinate (COO) sparse format — the ``row``, ``col``, and ``val`` lists represent the non-zero entries of the matrix.

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
       "ub": [1000, 1000],
       "csense": ["L", "L", "L"],  # L = <=,  E = =,  G = >=
       "osense": "max"
     },
     "model_name": "product_mix_lp",
     "engine": "python",  # "python" or "julia"
     "solver": {
       "solver_name": "HiGHS",
       "solver_type": "LP",
       "solver_params": {}
     }
   }

Using JSON via ``/computeJSON``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The simplest way to submit the problem. All values must be plain Python lists
(not NumPy arrays); call ``.tolist()`` on any NumPy array before submitting.

.. code-block:: python

   import requests

   response = requests.post(
       "http://localhost:8000/computeJSON",
       json=ipc_dict,
       headers={"Content-Type": "application/json"}
   )

   if response.status_code == 200:
       result = response.json()
       print("Objective value:", result.get("obj_val"))
       print("Solution:", result.get("solution"))
       print("Status:", result.get("status"))
       print("stat:", result.get("stat"))   # 1=optimal, 0=infeasible, 2=unbounded
   else:
       print("Error:", response.text)

Expected output:

.. code-block:: text

   Objective value: 66.0
   Solution: [6.0, 3.0]
   Status: optimal
   stat: 1

Using Apache Arrow IPC via ``/compute``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The Arrow IPC path is more efficient for large sparse models. The model
dictionary is serialized into an Arrow IPC stream before being posted.

.. code-block:: python

   import pyarrow as pa
   import requests

   # Serialize the model dictionary to an Arrow IPC stream
   pa_arrays = [pa.array([v]) for v in ipc_dict.values()]
   table = pa.Table.from_arrays(pa_arrays, names=list(ipc_dict.keys()))

   sink = pa.BufferOutputStream()
   with pa.ipc.new_stream(sink, table.schema) as writer:
       writer.write(table)
   ipc_bytes = sink.getvalue().to_pybytes()

   # Send the IPC stream to the Gateway
   response = requests.post(
       "http://localhost:8000/compute",
       data=ipc_bytes,
       headers={"Content-Type": "application/vnd.apache.arrow.stream"}
   )

   # Decode the Arrow IPC response
   if response.status_code == 200:
       result_table = pa.ipc.open_stream(response.content).read_all()
       print("Objective value:", result_table["obj_val"][0])
       print("Status:", result_table["status"][0])
       print("Solution:", result_table["solution"][0])
   else:
       print("Error:", response.status_code, response.text)
