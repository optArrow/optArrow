Overall Setup
=============

If you are new to OptArrow, use this page as the shortest path from zero setup to your first successful request.

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

    - HTTP responses return status ``200``.
    - Response body can be decoded as Arrow IPC (or JSON for ``/computeJSON``).
    - Returned object includes solver status and solution vectors.

Common first-run checks
-----------------------

- If service does not start, confirm engine ports are free and dependencies are installed.
- If request fails, verify endpoint path and ``Content-Type`` header.
- For Arrow IPC requests, ensure the payload is a valid IPC stream.

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