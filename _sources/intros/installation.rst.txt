Installation and Quick Start
============================

If you are new to OptArrow, use this page as the shortest path from zero setup to your first successful request.

For the fastest onboarding flow, start here:

- :doc:`Quick Start (10 Minutes) <quickstart>`

Branch and repository layout
----------------------------

- ``main`` branch contains the source code for gateway, engines, and scripts used to run OptArrow.
- ``gh-pages`` branch (this docs site) contains generated documentation artifacts.

If you want to run OptArrow locally, clone and work from ``main``.

Prerequisites
-------------

- Git
- Python 3.10+
- ``pip``
- Julia 1.9+ (required when using the Julia engine)
- Optional but recommended: ``poetry`` (used in Python engine setup)

Get the source code
-------------------

.. code-block:: bash

    git clone git@github.com:optArrow/optArrow.git
    cd optArrow
    git checkout main

Quick start (first working request)
-----------------------------------

1. Start the backend services by following one of these setup guides:

    - :doc:`OptimizationServer (Julia) <julia_setup>`
    - :doc:`OptimizationServer (Python) <python_engine_setup>`

2. Run a ready tutorial request from the docs examples:

    - :doc:`LP Example: Production Optimization <../tutorials/lp_example1>`

3. Verify success:

    Check that services are listening on expected ports:

    .. code-block:: bash

        nc -zv 127.0.0.1 8000 8101 65432

    Send a quick health-style request to the JSON endpoint:

    .. code-block:: bash

        curl -i -X POST http://127.0.0.1:8000/computeJSON \
          -H "Content-Type: application/json" \
          -d '{"model":{"A":{"row":[0],"col":[0],"val":[1.0]},"b":[1.0],"c":[1.0],"lb":[0.0],"csense":["E"],"osense":"max"},"model_name":"smoke_test","engine":"julia","solver":{"solver_name":"HiGHS","solver_type":"LP","solver_params":{}}}'

    Expected result:

    - HTTP status ``200``
    - JSON response includes a solver status and solution fields

Common first-run checks
-----------------------

If service does not start, check startup logs and whether required ports are already in use:

.. code-block:: bash

    ./scripts/startAll.sh
    ss -ltnp | grep -E ':8000|:8101|:65432'

If dependencies may be missing, verify both Python and Julia environments:

.. code-block:: bash

    poetry --version
    poetry install --no-root
    julia --project=./src/service/optimization_service/julia -e "import Pkg; Pkg.instantiate()"

If requests fail, verify endpoint path and content type:

.. code-block:: bash

    curl -i http://127.0.0.1:8000/
    curl -i -X POST http://127.0.0.1:8000/computeJSON -H "Content-Type: application/json" -d '{}'

For Arrow IPC requests, confirm the header is:

.. code-block:: text

    Content-Type: application/vnd.apache.arrow.stream

Install dependencies
--------------------

For docs only (this documentation site):

.. code-block:: bash

    /bin/python -m pip install -r Documentation/requirements.txt

For runtime services, use the installation steps in:

- :doc:`OptimizationServer (Julia) <julia_setup>`
- :doc:`OptimizationServer (Python) <python_engine_setup>`

Build the HTML docs locally
---------------------------

.. code-block:: bash

    /bin/python -m sphinx -b html Documentation Documentation/_build/html

Open the generated site at ``Documentation/_build/html/index.html``.