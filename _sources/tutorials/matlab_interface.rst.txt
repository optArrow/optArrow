MATLAB Interface for OptArrow
=============================

OptArrow includes a general MATLAB client for sending optimization models to
the OptArrow Gateway.

The preferred MATLAB transport is Apache Arrow IPC:

1. MATLAB builds a plain model struct for an LP or QP problem.
2. Sparse matrices are serialized as COO arrays: ``row``, ``col``, ``val``,
   and ``shape``.
3. ``optarrow.compute`` converts the request to a flat Arrow IPC stream.
4. The request is posted to the Gateway endpoint.
5. The Arrow IPC response is decoded back into a MATLAB struct.

No Python interpreter is involved on the MATLAB client side. Python and Julia
are still used by the OptArrow services behind the Gateway.

When Apache Arrow MATLAB is not installed, the client can fall back to the
Gateway's JSON route, ``/computeJSON``. JSON fallback is intended for setup
verification and compatibility. Arrow IPC remains the recommended path for
large sparse models.

Files
-----

The MATLAB client source is under ``src/matlab``:

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - File
     - Purpose
   * - ``+optarrow/setOptArrowConfig.m``
     - Set global OptArrow runtime config
   * - ``+optarrow/getOptArrowConfig.m``
     - Read global OptArrow runtime config
   * - ``+optarrow/checkSetup.m``
     - Verify Gateway reachability and Arrow backend availability
   * - ``+optarrow/compute.m``
     - Generic Arrow IPC or JSON request/response call
   * - ``+optarrow/solveLP.m``
     - LP convenience wrapper
   * - ``+optarrow/solveQP.m``
     - QP convenience wrapper
   * - ``vendor/apache-arrow/``
     - Optional bundled Apache Arrow MATLAB builds

The MATLAB functions use the ``optarrow.*`` package namespace. Add the
``src/matlab`` directory to the MATLAB path — MATLAB will automatically
discover the ``+optarrow`` package folder inside it.

Downstream integrations, such as COBRA Toolbox adapters, should keep
toolbox-specific conversion and solver-dispatch logic outside this general
MATLAB client.

Requirements
------------

- MATLAB R2023b or later.
- A running OptArrow Gateway, usually at
  ``http://127.0.0.1:8000/compute``.
- Apache Arrow MATLAB interface for the preferred Arrow IPC path.

If Arrow is unavailable and ``transport`` is set to ``auto`` or ``json``, the
client posts the same logical request to ``/computeJSON`` using MATLAB's native
JSON support.

Set Up Apache Arrow for MATLAB
------------------------------

These steps assume you are working from the OptArrow repository:

.. code-block:: bash

   git clone https://github.com/optArrow/optArrow.git
   cd optArrow

Try the Bundled Linux Build
^^^^^^^^^^^^^^^^^^^^^^^^^^^

On Linux x86_64, OptArrow includes an experimental bundled Apache Arrow MATLAB
build under:

.. code-block:: text

   src/matlab/vendor/apache-arrow/linux-x86_64/arrow_matlab

From MATLAB, run:

.. code-block:: matlab

   run scripts/setupMATLABArrow.m

The setup script first looks for the bundled Linux build. If it is found, it
adds it to the MATLAB path, verifies it by constructing an Arrow record batch,
and then saves the MATLAB path.

Verify manually with:

.. code-block:: matlab

   arrow.recordBatch(table(["A"; "B"], [1; 2]))

If MATLAB prints a ``RecordBatch``, Arrow is ready.

Build Arrow If Needed
^^^^^^^^^^^^^^^^^^^^^

If ``setupMATLABArrow`` cannot find a usable build, or if MATLAB reports a
``GLIBCXX_*`` runtime error while loading the bundled MEX file, build Apache
Arrow and the MATLAB interface locally.

Install build prerequisites:

.. code-block:: bash

   # Debian/Ubuntu
   sudo apt install -y cmake build-essential

   # macOS
   xcode-select --install
   brew install cmake

Then run:

.. code-block:: bash

   ./scripts/buildMATLABArrow.sh

The script clones Apache Arrow if needed, builds Arrow C++, builds the MATLAB
bindings, and installs them by default to:

.. code-block:: text

   $HOME/arrow_no_s3
   $HOME/arrow_matlab

After the build finishes, rerun the setup script from MATLAB:

.. code-block:: matlab

   run scripts/setupMATLABArrow.m

Or add the source-built interface manually:

.. code-block:: matlab

   addpath(fullfile(getenv('HOME'), 'arrow_matlab', 'arrow_matlab'));
   savepath;
   arrow.recordBatch(table(["A"; "B"], [1; 2]))

Optional S3-enabled build:

.. code-block:: bash

   ./scripts/buildMATLABArrow.sh --with-s3

The build paths can be customized with ``ARROW_REPO_DIR``,
``ARROW_CPP_INSTALL``, and ``ARROW_MATLAB_INSTALL``.

Why Models Must Be Serialized
-----------------------------

The Gateway accepts Arrow IPC bytes on ``/compute``. MATLAB structs, sparse
matrices, and cell arrays cannot be sent directly over HTTP as MATLAB objects.
Before posting a request, the MATLAB client serializes the optimization model
into Arrow-friendly columns.

For sparse matrices, the interface uses COO form:

.. code-block:: matlab

   [row, col, val] = find(A);
   model.A = struct( ...
       'row', row(:)' - 1, ...
       'col', col(:)' - 1, ...
       'val', val(:)', ...
       'shape', [size(A, 1), size(A, 2)]);

Rows and columns are zero-based because the Gateway and Python/Julia engine
side expect zero-based matrix coordinates. Vector fields such as ``b``, ``c``,
``lb``, ``ub``, and ``csense`` are packed as Arrow list columns. Solver options
are packed as parallel key/value string lists.

Most users should call ``optarrow.solveLP`` or ``optarrow.solveQP``; these
wrappers build the serialized model payload. Use ``optarrow.compute`` directly
only when you already have an OptArrow payload struct.

Check Gateway Setup
-------------------

Before solving, verify the Gateway is reachable and that the correct Arrow
backend is selected:

.. code-block:: matlab

   report = optarrow.checkSetup();
   disp(report)

Or with an explicit endpoint and a hard error on failure:

.. code-block:: matlab

   report = optarrow.checkSetup( ...
       'http://127.0.0.1:8000/cobra/compute', ...
       struct('throwOnError', true));

The returned ``report`` struct includes:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Field
     - Meaning
   * - ``ok``
     - ``true`` when all checks pass
   * - ``endpoint``
     - Resolved Gateway URL
   * - ``httpStatus``
     - HTTP status code returned by the Gateway (0 if unreachable)
   * - ``arrowBackend``
     - ``'native'`` when Apache Arrow MATLAB is installed and working,
       ``'json'`` when falling back to the JSON route
   * - ``failures``
     - Cell array of error messages (empty when ``ok`` is true)

Configure The MATLAB Client
---------------------------

Start the OptArrow Gateway first. From the repository root, one common local
path is:

.. code-block:: bash

   sh scripts/startAll.sh

Then configure MATLAB:

.. code-block:: matlab

   cfg = struct( ...
       'engine', 'python', ...
       'backendSolver', 'HiGHS', ...
       'backendSolverType', 'LP', ...
       'backendOptions', struct(), ...
       'endpoint', 'http://127.0.0.1:8000/compute', ...
       'timeoutSec', 120, ...
       'transport', 'auto');

   optarrow.setOptArrowConfig(cfg);

Supported MATLAB transports:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Transport
     - Behavior
   * - ``auto``
     - Use Arrow IPC when Apache Arrow MATLAB is installed; otherwise use JSON
   * - ``arrow``
     - Require Arrow IPC and fail if Apache Arrow MATLAB is unavailable
   * - ``json``
     - Always use ``/computeJSON``

For JSON fallback, ``optarrow.compute`` rewrites a configured ``/compute`` or
``/cobra/compute`` endpoint to ``/computeJSON``.

Solve an LP
-----------

Maximise ``5x + 12y`` subject to three inequality constraints:

.. code-block:: matlab

   LPproblem = struct();
   LPproblem.A      = sparse([20 10; 10 20; 10 30]);
   LPproblem.b      = [200; 120; 150];
   LPproblem.c      = [5; 12];
   LPproblem.lb     = [0; 0];
   LPproblem.ub     = [1000; 1000];
   LPproblem.csense = ['L'; 'L'; 'L'];
   LPproblem.osense = -1;  % -1=max, 1=min

   result = optarrow.solveLP(LPproblem, struct('modelName', 'matlab_lp'));
   disp(result)

Expected output:

.. code-block:: text

      success: 1
       status: 'optimal'
         stat: 1
      obj_val: 66
     solution: [6 3]

Solve a QP
----------

Minimise ``x² + y² - 2x - 5y`` subject to ``x + y = 3``.  The ``ub``
field is optional; ``optarrow.solveQP`` defaults it to ``1e30``.

.. code-block:: matlab

   QPproblem = struct();
   QPproblem.F      = sparse([2 0; 0 2]);
   QPproblem.c      = [-2; -5];
   QPproblem.A      = sparse([1 1]);
   QPproblem.b      = 3;
   QPproblem.lb     = [0; 0];
   QPproblem.csense = 'E';
   QPproblem.osense = 1;  % minimise

   result = optarrow.solveQP(QPproblem, struct('modelName', 'matlab_qp'));
   disp(result)

Expected output:

.. code-block:: text

      success: 1
       status: 'optimal'
         stat: 1
      obj_val: -7.125
     solution: [0.75 2.25]

Submit a Generic Payload
------------------------

A direct ``optarrow.compute`` payload should include:

- ``problem_type``: ``LP`` or ``QP``.
- ``engine``: backend engine name, for example ``python`` or ``julia``.
- ``solver_name``: backend solver name, for example ``HiGHS`` or ``Gurobi``.
- ``model_name``: label used by the backend for logging/debugging.
- ``time_limit``: solver time limit in seconds.
- ``solver_params``: backend option struct.
- ``model``: serialized LP/QP model struct.

Example:

.. code-block:: matlab

   payload = struct();
   payload.problem_type = 'LP';
   payload.engine = 'python';
   payload.solver_name = 'HiGHS';
   payload.model_name = 'my_lp';
   payload.time_limit = 300;
   payload.solver_params = struct();

   payload.model.A = struct( ...
       'row', int64([0; 1]), ...
       'col', int64([0; 1]), ...
       'val', [1.0; 1.0], ...
       'shape', int64([2, 2]));
   payload.model.b = [1.0; 1.0];
   payload.model.c = [2.0; 3.0];
   payload.model.lb = [0.0; 0.0];
   payload.model.ub = [10.0; 10.0];
   payload.model.csense = {'L'; 'L'};
   payload.model.osense = 'max';

   result = optarrow.compute(payload);
   disp(result)

Response Struct
---------------

The decoded response is a MATLAB struct. Common fields include:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Field
     - Meaning
   * - ``success``
     - Logical success flag
   * - ``status``
     - Backend status text
   * - ``stat``
     - Normalized numeric status: ``1`` optimal, ``0`` infeasible,
       ``2`` unbounded, ``-1`` error
   * - ``obj_val``
     - Objective value
   * - ``solution``
     - Primal solution vector
   * - ``dual``
     - Constraint duals, when available
   * - ``rcost``
     - Reduced costs, when available
   * - ``slack``
     - Constraint slack, when available
   * - ``method``
     - Backend method label, when available
   * - ``time``
     - Backend solve time, when available

Troubleshooting
---------------

- If MATLAB cannot find ``arrow.recordBatch``, run
  ``scripts/setupMATLABArrow.m``.
- If the bundled Arrow build fails with ``GLIBCXX_*``, build Arrow locally
  with ``./scripts/buildMATLABArrow.sh``.
- If Arrow is not available and you only need a compatibility path, configure
  ``transport`` as ``auto`` or ``json``.
- If HTTP requests fail, confirm the Gateway is running and the configured
  ``endpoint`` matches the server route.
- If a sparse model gives incorrect dimensions, include ``shape`` in the COO
  matrix struct or use ``optarrow.solveLP`` / ``optarrow.solveQP`` to build it.
- If ``optarrow.*`` functions are not found, confirm the installed MATLAB
  client is on the path as a ``+optarrow`` package.
