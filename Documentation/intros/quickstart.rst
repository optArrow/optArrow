Quick Start (10 Minutes)
========================

Use this guide if you want to run OptArrow today with minimum setup.

1) Clone the source repository
------------------------------

.. code-block:: bash

   git clone git@github.com:optArrow/optArrow.git
   cd optArrow
   git checkout main

2) Install dependencies
-----------------------

.. code-block:: bash

   pipx install poetry
   poetry install --no-root
   julia --project=./src/service/optimization_service/julia -e "import Pkg; Pkg.instantiate()"

3) Start services
-----------------

.. code-block:: bash

   ./scripts/startAll.sh

Expected open ports include ``8000`` (gateway), ``8101`` (Python engine), and ``65432`` (Julia engine).

Verify ports explicitly:

.. code-block:: bash

   nc -zv 127.0.0.1 8000 8101 65432

4) Send your first request
--------------------------

Use the full runnable example in:

- :doc:`LP Example: Production Optimization <../tutorials/lp_example1>`

5) Verify success
-----------------

Run a minimal JSON smoke test:

.. code-block:: bash

   curl -i -X POST http://127.0.0.1:8000/computeJSON \
     -H "Content-Type: application/json" \
     -d '{"model":{"A":{"row":[0],"col":[0],"val":[1.0]},"b":[1.0],"c":[1.0],"lb":[0.0],"csense":["E"],"osense":"max"},"model_name":"smoke_test","engine":"julia","solver":{"solver_name":"HiGHS","solver_type":"LP","solver_params":{}}}'

Expected output:

- HTTP status ``200``
- Response JSON contains solver status and a solution payload

Troubleshooting
---------------

If startup fails, verify dependencies and listening ports:

.. code-block:: bash

   poetry install --no-root
   julia --project=./src/service/optimization_service/julia -e "import Pkg; Pkg.instantiate()"
   ss -ltnp | grep -E ':8000|:8101|:65432'

If request fails, confirm endpoint and content type:

.. code-block:: bash

   curl -i http://127.0.0.1:8000/
   curl -i -X POST http://127.0.0.1:8000/computeJSON -H "Content-Type: application/json" -d '{}'
