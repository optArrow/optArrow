LP Example: FBA analysis for ecoli model
========================================

This example solves a **linear programming (LP)** problem to perform flux balance analysis (FBA) on the E. coli core metabolic model using the OptArrow solver backend.

FBA identifies a steady-state flux distribution that maximizes biomass production,
subject to stoichiometric and flux constraints.

Step 1 : Parse the `.mat` model file
------------------------------------

You can load a `.mat` model from local storage or download it from a public database,
such as the `BiGG Models database <http://bigg.ucsd.edu/>`_.

.. code-block:: python

   from scipy.io import loadmat
   from scipy import sparse
   import numpy as np
   import requests
   import pyarrow as pa
   
   # Option 1: Download model from BiGG (if not already downloaded)
   url = "http://bigg.ucsd.edu/static/models/e_coli_core.mat"
   filename = "e_coli_core.mat"
   response = requests.get(url)
   with open(filename, "wb") as f:
       f.write(response.content)
   
   # Option 2: Use local file instead
   # filename = "path/to/your/model.mat"
   
   # Load .mat file
   mat = loadmat(filename)
   
   # # Extract first non-system key as model name (exclude system keys like '__header__', etc.)
   model_names = [key for key in mat.keys() if not key.startswith('__')]
   model_name = model_names[0]
   
   # Unwrap model struct, the actual model object is wrapped in a 1x1 ndarray
   model_data = mat[model_name]
   if isinstance(model_data, np.ndarray) and model_data.shape == (1, 1):
       model = model_data[0, 0]
   else:
       model = model_data

Step 2: Load the stoichiometric matrix and constraints
------------------------------------------------------

The core components for the LP problem are:
- `S`: stoichiometric matrix (m x n)
- `b`: RHS of equality constraints (`S @ v = b`)
- `c`: objective coefficients (biomass reaction)
- `lb`, `ub`: lower and upper bounds for each flux variable

The matrix `S` is converted to sparse COO format.

.. code-block:: python

   # Flatten the model fields into a dictionary
   mat_dict = {field: model[field] for field in model.dtype.names}
   
   # Extract LP components
   S = sparse.coo_matrix(mat_dict['S'])
   b = mat_dict['b'].flatten()
   c = mat_dict['c'].flatten()
   lb = mat_dict['lb'].flatten()
   ub = mat_dict['ub'].flatten()

Step 3: Prepare model dictionary for OptArrow
---------------------------------------------

Transform the data into a dictionary compatible with the OptArrow solver API.

- The matrix `A` corresponds to `S`, encoded in COO format with row/col/val.
- `osense`: Objective sense, `"max"` for biomass maximization.

.. code-block:: python

   # computational model data
   A ={
       "row" : S.row,
       "col" : S.col,
       "val" : S.data,
   }
   model_data = {
       "A": A,
       "b": b,
       "c": c,
       "lb": lb,
       "ub": ub,
       "osense": "max",
   }
   
   # You can use either "Python" or "Julia" as the engine
   engine = "Python"
   
   # Solver configuration
   solver_type = "LP"
   solver_name = "HiGHS"
   solver_params = {"presolve":"on", "infinite_cost":1e+18}
   
   solver = {
       "solver_name": solver_name,
       "solver_type": solver_type,
       "solver_params": solver_params
   }
   
   # Prepare the IPC dictionary for OptArrow
   ipc_dict = {
       "model": model_data,
       "model_name": model_name,
       "engine": engine,
       "solver": solver
   }

Step 4: Solve the LP
--------------------

Make sure the OptArrow service is running. Here in the example the service is running on localhost and can be accessed via 'http://localhost:8000`.

Using Apache Arrow IPC binary stream via `/compute`
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This format is more efficient for large-scale model transfer and preferred in high-performance systems.

.. code-block:: python

   # Prepare Arrow IPC stream
   pa_arrays = [pa.array([v]) for v in ipc_dict.values()]
   ipc_tables = pa.Table.from_arrays(pa_arrays, names=list(ipc_dict.keys()))
   
   # Serialize to Arrow stream
   sink = pa.BufferOutputStream()
   with pa.ipc.new_stream(sink, ipc_tables.schema) as writer:
       writer.write(ipc_tables)
   ipc_bytes = sink.getvalue().to_pybytes()
   
   # Send request
   headers = {
           "Content-Type": "application/vnd.apache.arrow.stream"
       }
   response = requests.post("http://localhost:8000/compute", data=ipc_bytes, headers=headers)
   
   # Handle the response
   if response.status_code == 200:
       response_data = response.content
       response_table = pa.ipc.open_stream(response_data).read_all()
       print("Objective value:", response_table['obj_val'][0])
       print("Status:", response_table['status'][0])
       print("Solution:", response_table['solution'][0])
   else:
       response_data = response.content
       response_table = pa.ipc.open_stream(response_data).read_all()
       print("Error message:", response_table['error_message'][0])

Optional: Solve the LP using JSON via `/computeJSON`
----------------------------------------------------

If the model is small, you can also use JSON format for simplicity.
Since the data parsed from the `.mat` file is np.ndarray, it needs to be converted to Python native lists for JSON serialization.

.. code-block:: python

   A ={
       "row" : S.row.tolist(),
       "col" : S.col.tolist(),
       "val" : S.data.tolist(),
   }
   model_data = {
       "A": A,
       "b": b.tolist(),
       "c": c.tolist(),
       "lb": lb.tolist(),
       "ub": ub.tolist(),
       "osense": "max",
   }
   
   ipc_dict = {
       "model": model_data,
       "model_name": model_name,
       "engine": engine,
       "solver": solver
   }

.. code-block:: python

   headers = {
           "Content-Type": "application/json"
       }
   
   # Send the request to OptArrow backend
   response = requests.post("http://localhost:8000/computeJSON", json=ipc_dict, headers=headers)
   
   # Handle the response
   if response.status_code == 200:
       result = response.json()
       objective_value = result.get("obj_val", None) # objective value is returned as "obj_val"
       solution = result.get("solution", None) # solution is returned as "solution"
       status = result.get("status", None) # status of the optimization
       print("Objective Value:", objective_value)
       print("Solution:", solution)
       print("Status:", status)
   else:
       print("Error:", response.text)
