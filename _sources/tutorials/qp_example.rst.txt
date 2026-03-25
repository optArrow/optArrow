QP Example
==========

Consider solving the following **Quadratic Programming (QP)** problem:

Objective:
^^^^^^^^^^

Minimize the quadratic function:

.. math::

   z = x_1 - 2x_2 + 4x_3 + x_1^2 + 2x_2^2 + 3x_3^2 + x_1 x_3

Subject to constraints:
^^^^^^^^^^^^^^^^^^^^^^^

.. math::

   \begin{aligned}
   3x_1 + 4x_2 - 2x_3 &\leq 10 \\
   -3x_1 + 2x_2 + x_3 &\geq 2 \\
   2x_1 + 3x_2 + 4x_3 &= 5 \\
   0 \leq x_1 &\leq 5 \\
   1 \leq x_2 &\leq 5 \\
   0 \leq x_3 &\leq 5
   \end{aligned}

General QP Formulation
----------------------

The general form of a Quadratic Programming (QP) problem can be expressed as:

**Objective**: Minimize

.. math::

   \frac{1}{2} x^T Q x + c^T x

**Subject to**:

.. math::

   Ax = b,
   
   Gx \leq h,
   
   lb \leq x \leq ub

So:

.. math::

   x = \begin{bmatrix}
   x_1 \\
   x_2 \\
   x_3
   \end{bmatrix},
   \quad
   Q = \begin{bmatrix}
   2 & 0 & 1 \\
   0 & 4 & 0 \\
   1 & 0 & 6
   \end{bmatrix},
   \quad
   c = \begin{bmatrix}
   1 \\
   -2 \\
   4
   \end{bmatrix}

.. math::

   A = \begin{bmatrix}
   2 & 3 & 4
   \end{bmatrix},
   \quad
   b = \begin{bmatrix}
   5
   \end{bmatrix}

.. math::

   G = \begin{bmatrix}
   3 & 4 & -2 \\
   3 & -2 & -1
   \end{bmatrix},
   h = \begin{bmatrix}
   10 \\
   -2
   \end{bmatrix}

.. math::

   lb = \begin{bmatrix}
   0 \\
   1 \\
   0
   \end{bmatrix},
   ub = \begin{bmatrix}
   5 \\
   5 \\
   5
   \end{bmatrix}

where:
- $Q$ is a symmetric matrix representing the quadratic coefficients.
- $c$ is a vector representing the linear coefficients.
- $A$, $G$, $lb$, and $ub$ are defined as per the problem constraints.

.. code-block:: python

   ipc_dict = {
       "model": {
           "Q": {
               "row": [0, 0, 2, 1, 2],
               "col": [0, 2, 0, 1, 2],
               "val": [2, 1, 1, 4, 6]
           },
           "c": [1, -2, 4],
           "A": {
               "row": [0, 0, 0],
               "col": [0, 1, 2],
               "val": [2, 3, 4]
           },
           "b": [5],
           "G": {
               "row": [0, 0, 0, 1, 1, 1],
               "col": [0, 1, 2, 0, 1, 2],
               "val": [3, 4, -2, 3, -2, -1]
           },
           "h": [10, -2],
           "lb": [0, 1, 0],
           "ub": [5, 5, 5],
           "osense": "min"
       },
       "model_name": "QP-tutorial",
       "engine": "julia",
       "solver": {
           "solver_name": "HiGHS",
           "solver_type": "QP",
           "solver_params": {}
       }
   }

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

.. code-block:: python

   headers = {"Content-Type": "application/json"}
   response = requests.post("http://localhost:8000/computeJSON", json=ipc_dict, headers=headers)
   print(response.json())
