OptimizationServer (Julia)
==========================

This service receives LP/QP optimization problems encoded with Arrow IPC over TCP, solves them with JuMP backends, and returns Arrow IPC responses.

Project Structure
-----------------

.. code-block:: text

   julia/
   ├── api/
   │   └── socket_server.jl
   ├── model/
   │   ├── lp_model.jl
   │   └── qp_model.jl
   ├── service/
   │   ├── model_factory.jl
   │   ├── solver_factory.jl
   │   └── optimization_service.jl
   ├── utils/
   │   ├── io_utils.jl
   │   └── sparse_matrix.jl
   ├── engine.jl
   ├── Project.toml
   └── Manifest.toml

Getting Started
---------------

1. Install Julia from https://julialang.org/install/.
2. Verify installation:

.. code-block:: bash

   julia --version

3. Launch project mode from the Julia service directory:

.. code-block:: bash

   julia --project=.

4. Install dependencies from Julia package mode:

.. code-block:: text

   ]
   instantiate

5. Start the service:

.. code-block:: bash

   julia --project=. engine.jl

Expected startup log:

.. code-block:: text

   Julia Engine started on 127.0.0.1:65432
