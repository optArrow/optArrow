OptimizationServer (Python)
===========================

This service receives LP/QP optimization problems and solves them with Pyomo backends, returning results through the OptArrow API interface.

Project Structure
-----------------

.. code-block:: text

   python/pyomo/
   ├── problems/
   │   ├── lp_problem.py
   │   └── qp_problem.py
   ├── controller/
   │   └── arrow_rpc_server.py
   ├── service/
   │   └── cobra_solver.py
   └── objects/
       ├── base_problem.py
       ├── problem_factory.py
       ├── solver_factory.py
       └── solver.py

Getting Started
---------------

1. Install Python dependencies from the project root:

.. code-block:: bash

   poetry install --no-root

2. Install required solvers as needed (for example HiGHS, Gurobi, Ipopt).

3. Start the Python engine:

.. code-block:: bash

   ./scripts/startPyEngine.sh

Expected startup log:

.. code-block:: text

   INFO:     Server running at grpc://0.0.0.0:8101

To launch all components (gateway + engines), use:

.. code-block:: bash

   ./scripts/startAll.sh
