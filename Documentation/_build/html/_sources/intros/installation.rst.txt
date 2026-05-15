Installation and Overall Setup
==============================

Overall Setup
-------------

OptArrow Computation Service
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

OptArrow is an optimization integration engine designed to seamlessly connect the Python and Julia ecosystems.
It addresses the technical and structural challenges of building scalable, high-performance optimization pipelines
across languages.

This setup can also be used from MATLAB through the packaged client under
``src/matlab``.

Requirements
~~~~~~~~~~~~

- Python ``>= 3.12`` (recommended)
- Julia ``>= 1.11`` (recommended)
- ``poetry`` for dependency and environment management (recommended best practice)

Currently supported solvers:

- GLPK (not supported for QP problems)
- GUROBI
- HiGHS
- Mosek
- Hypatia (Julia only)

Make sure solver executables are installed and available in your system ``PATH``.

1. Clone the repository
-----------------------

If you are not using Docker, clone the source code first:

.. code-block:: bash

    git clone https://github.com/Digital-Metabolic-Twin-Centre/OptArrow.git
    cd OptArrow

2. Install Python and Julia
---------------------------

2.1 Install Python (>=3.12 recommended)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Windows
^^^^^^^

- Download the installer from Python.org Downloads.
- During installation, check ``Add Python to PATH``.
- Verify installation:

.. code-block:: bash

    python --version

macOS
^^^^^

Use Homebrew:

.. code-block:: bash

    brew install python@3.12

Or download directly from Python.org.

Verify installation:

.. code-block:: bash

    python3 --version

Linux (Debian/Ubuntu)
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    sudo apt update
    sudo apt install -y python3.12 python3.12-venv python3.12-dev
    python3.12 --version

Linux (Fedora/RHEL)
^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    sudo dnf install python3.12 python3.12-devel
    python3.12 --version

2.2 Install Julia (>=1.11 recommended)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Windows / macOS / Linux (generic)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

- Download binaries from Julia Downloads.
- Extract and place Julia in your preferred folder.
- Add the Julia ``bin/`` directory to ``PATH``:

  - Windows: System Environment Variables
  - Linux/macOS: ``~/.bashrc`` or ``~/.zshrc``

Verify installation:

.. code-block:: bash

    julia --version

Linux (Debian/Ubuntu quick install)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    curl -fsSL https://install.julialang.org | sh

macOS (Homebrew)
^^^^^^^^^^^^^^^^

.. code-block:: bash

    brew install julia

3. Install dependencies
-----------------------

3.1 Install pipx
~~~~~~~~~~~~~~~~

``pipx`` installs Python applications in isolated environments and is recommended for installing ``poetry``.

General:

.. code-block:: bash

    pipx install poetry

Windows
^^^^^^^

Make sure Python 3.12+ is installed and added to ``PATH``.
In PowerShell:

.. code-block:: powershell

    py -m pip install --user pipx
    py -m pipx ensurepath

Restart PowerShell (or your terminal), then verify:

.. code-block:: bash

    pipx --version

macOS
^^^^^

Install via Homebrew:

.. code-block:: bash

    brew install pipx
    pipx ensurepath

Or via pip:

.. code-block:: bash

    python3 -m pip install --user pipx
    python3 -m pipx ensurepath

Restart your terminal (or run ``source ~/.zshrc``), then verify:

.. code-block:: bash

    pipx --version

Linux (Debian/Ubuntu)
^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    sudo apt update
    sudo apt install -y python3.12 python3.12-venv python3-pip
    python3.12 -m pip install --user pipx
    python3.12 -m pipx ensurepath
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
    source ~/.bashrc
    pipx --version

Fedora / RHEL
^^^^^^^^^^^^^

.. code-block:: bash

    sudo dnf install pipx
    pipx ensurepath

3.2 Install Python dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install ``poetry`` first (via ``pipx``), then install project dependencies from the project root:

.. code-block:: bash

    pipx install poetry
    poetry install --no-root

Using ``pip`` directly (or other dependency managers) is not recommended, to avoid environment inconsistency.

3.3 Install Julia dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Launch Julia in project mode:

.. code-block:: bash

    julia --project=./src/service/optimization_service/julia

Then instantiate dependencies in the Julia REPL:

.. code-block:: text

    julia> ]
    (pkg) instantiate

4. Start all service instances (engines + gateway)
---------------------------------------------------

Start all services:

.. code-block:: bash

    sh scripts/startAll.sh

Start services individually:

- Gateway only:

  .. code-block:: bash

      sh scripts/startServer.sh

- Python engine only:

  .. code-block:: bash

      sh scripts/startPyEngine.sh

- Julia engine only:

  .. code-block:: bash

      sh scripts/startJulia.sh

5. Services are ready
---------------------

Optional: MATLAB Client Setup
-----------------------------

MATLAB **R2023b or later** is required. Arrow IPC serialization is handled
natively in MATLAB using the **MATLAB Interface to Apache Arrow**, which must
be built once from the Apache Arrow source repository. See the full build
instructions in :doc:`../tutorials/matlab_interface`.

Once the add-on is installed:

1. Add the MATLAB client to your path:

   .. code-block:: matlab

      addpath(genpath(fullfile(repoRoot, 'src', 'matlab')));

2. Configure the OptArrow client:

   .. code-block:: matlab

      cfg = struct( ...
          'endpoint',      'http://127.0.0.1:8000/compute', ...
          'engine',        'python', ...
          'backendSolver', 'HiGHS', ...
          'timeoutSec',    120);
      optarrow.setOptArrowConfig(cfg);

3. Continue with the full guide in :doc:`../tutorials/matlab_interface`.

After services are running and communicating, run the following Python example to solve a simple LP problem via the JSON endpoint:

.. code-block:: python

    import requests

    payload = {
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
            "csense": ["L", "L", "L"],
            "osense": "max"
        },
        "model_name": "product_mix_lp",
        "engine": "python",
        "solver": {
            "solver_name": "HiGHS",
            "solver_type": "LP",
            "solver_params": {}
        }
    }

    response = requests.post(
        "http://localhost:8000/computeJSON",
        json=payload,
        headers={"Content-Type": "application/json"}
    )
    print(response.json())

Expected output:

.. code-block:: text

    {'success': True, 'solution': [6.0, 3.0], 'status': 'optimal', 'stat': 1, 'obj_val': 66.0}

6. Alternative: Start services with Docker
------------------------------------------

Docker can run services in isolated containers for production-style deployments.

Gateway service (``server.dockerfile``):

.. code-block:: bash

    docker build -t gateway-server -f server.dockerfile .
    docker run -d --net=host gateway-server

Python engine service (``py_engine.dockerfile``):

.. code-block:: bash

    docker build -t py-engine-server -f py_engine.dockerfile .
    docker run -d --net=host py-engine-server

Julia engine service (``julia_engine.dockerfile``):

.. code-block:: bash

    docker build -t julia-engine-server -f julia_engine.dockerfile .
    docker run -d --net=host julia-engine-server

Start all services together with Compose:

.. code-block:: bash

    docker compose -f compose.yaml up

More Information
----------------

Configure service ports
~~~~~~~~~~~~~~~~~~~~~~~

See ``config.yaml`` for service IP/port configuration.
If ports are changed, update Dockerfiles accordingly so the correct ports are exposed.

Scripts in ``./scripts``
~~~~~~~~~~~~~~~~~~~~~~~~

``envSetup.sh`` can be used to install dependencies on Debian-based Linux systems.
Other scripts start individual services, and ``startAll.sh`` starts all services locally.

Extending the code
~~~~~~~~~~~~~~~~~~

See :doc:`Contributing <contributing>`.
