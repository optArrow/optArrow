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

4) Send your first request
--------------------------

Use the full runnable example in:

- :doc:`LP Example: Production Optimization <../tutorials/lp_example1>`

5) Verify success
-----------------

- Request returns HTTP ``200``
- Response includes solver status and solution values

Troubleshooting
---------------

- If startup fails, check dependency installation and whether ports are already in use.
- If request fails, verify endpoint path and content type.
