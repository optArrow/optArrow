MATLAB Interface for OptArrow
=============================

OptArrow includes a native MATLAB client under ``src/matlab``.

The interface communicates with the OptArrow HTTP gateway using the Apache
Arrow IPC format, supports LP and QP problems via sparse COO triplets, and
does not depend on any toolbox-specific schema. Application-specific
translation layers belong in the downstream project.

Arrow serialization is handled entirely inside MATLAB using the
**MATLAB Interface to Apache Arrow** — a native C++ add-on built from the
Apache Arrow source repository. No Python environment is required.

What Is Included
----------------

The MATLAB package provides these entry points under ``src/matlab/+optarrow``:

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Function
     - Purpose
   * - ``optarrow.setOptArrowConfig``
     - Configure the active endpoint, engine, backend solver, and timeout
   * - ``optarrow.getOptArrowConfig``
     - Inspect the active configuration
   * - ``optarrow.compute``
     - Serialize an LP/QP payload to Arrow IPC, POST it to the gateway,
       and return the decoded response struct
   * - ``optarrow.solveLP``
     - Convenience wrapper: accepts a plain MATLAB LP struct, builds the
       OptArrow payload, and calls ``compute``
   * - ``optarrow.solveQP``
     - Convenience wrapper for QP problems (adds the Hessian ``Q``
       field in COO format)

Prerequisites
-------------

MATLAB Version
^^^^^^^^^^^^^^

MATLAB **R2023b or later** is required. ``optarrow.compute`` uses
``matlab.net.http`` for HTTP and argument-block validation syntax introduced
in R2023b.

.. _native-addon:

MATLAB Interface to Apache Arrow
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The Arrow add-on is **not** available in MATLAB's Add-On Explorer. It must be
built once from the Apache Arrow source repository.

**Build requirements (macOS)**

.. code-block:: bash

   xcode-select --install        # C++20 compiler (Apple Clang)
   brew install cmake

**Build requirements (Linux)**

.. code-block:: bash

   sudo apt install -y cmake build-essential   # Debian/Ubuntu
   # or: sudo dnf install cmake gcc-c++        # Fedora/RHEL

**Step 1 — Build Arrow C++ without S3 support**

Building without S3 avoids a shared-library version conflict between MATLAB's
bundled AWS libraries and the AWS C SDK that the default Arrow build pulls in
from Anaconda or Homebrew.

.. code-block:: bash

   git clone https://github.com/apache/arrow.git
   cd arrow

   cmake -S cpp -B build_cpp \
     -DCMAKE_BUILD_TYPE=Release \
     -DCMAKE_INSTALL_PREFIX=$HOME/arrow_no_s3 \
     -DARROW_S3=OFF \
     -DARROW_WITH_RE2=OFF \
     -DARROW_CSV=ON \
     -DARROW_IPC=ON \
     -DARROW_COMPUTE=ON \
     -DARROW_BUILD_TESTS=OFF \
     -DxsimdSOURCE=BUNDLED

   cmake --build build_cpp --config Release -j$(nproc || sysctl -n hw.logicalcpu)
   cmake --build build_cpp --config Release --target install

**Step 2 — Build the MATLAB bindings against that Arrow**

.. code-block:: bash

   cmake -S matlab -B build_matlab \
     -DArrow_DIR=$HOME/arrow_no_s3/lib/cmake/Arrow \
     -DCMAKE_INSTALL_PREFIX=$HOME/arrow_matlab

   cmake --build build_matlab --config Release
   cmake --build build_matlab --config Release --target install

The installer automatically adds ``$HOME/arrow_matlab/arrow_matlab`` to
MATLAB's saved search path (``pathdef.m``). The next MATLAB session will pick
it up automatically. To use it in the current session:

.. code-block:: matlab

   addpath(genpath(fullfile(getenv('HOME'), 'arrow_matlab', 'arrow_matlab')));

**Step 3 — Verify**

.. code-block:: matlab

   arrow.recordBatch(table(["A"; "B"], [1; 2], 'VariableNames', {'name', 'val'}))

A successful result returns an ``arrow.tabular.RecordBatch`` object.

OptArrow Gateway
^^^^^^^^^^^^^^^^

The gateway must be running before any MATLAB call:

.. code-block:: bash

   cd <optArrow_repo>
   python src/run_server.py

Default endpoint: ``http://127.0.0.1:8000/compute``

Setup
-----

Add the MATLAB package to the path:

.. code-block:: matlab

   addpath(genpath(fullfile('<optArrow_repo>', 'src', 'matlab')));

Configure the client (call once per session or place in ``startup.m``):

.. code-block:: matlab

   cfg = struct( ...
       'endpoint',      'http://127.0.0.1:8000/compute', ...
       'engine',        'python', ...
       'backendSolver', 'HiGHS', ...
       'timeoutSec',    120);

   optarrow.setOptArrowConfig(cfg);

Inspect the resolved configuration at any time:

.. code-block:: matlab

   disp(optarrow.getOptArrowConfig())

Solve an LP
-----------

``optarrow.solveLP`` accepts a standard LP struct:

.. list-table::
   :header-rows: 1
   :widths: 15 15 70

   * - Field
     - Type
     - Meaning
   * - ``A``
     - sparse or dense matrix
     - Constraint matrix (m × n)
   * - ``b``
     - double vector
     - Right-hand side (length m)
   * - ``c``
     - double vector
     - Objective coefficients (length n)
   * - ``lb``
     - double vector
     - Variable lower bounds
   * - ``ub``
     - double vector
     - Variable upper bounds
   * - ``csense``
     - char array or cell of chars
     - Per-row sense: ``'E'`` (=), ``'L'`` (≤), ``'G'`` (≥)
   * - ``osense``
     - numeric or char
     - ``-1`` or ``'max'`` to maximise; ``1`` or ``'min'`` to minimise

Example — product-mix LP:

.. code-block:: matlab

   optarrow.setOptArrowConfig(struct( ...
       'endpoint',      'http://127.0.0.1:8000/compute', ...
       'backendSolver', 'HiGHS'));

   LP = struct();
   LP.A      = sparse([20 10; 10 20; 10 30]);
   LP.b      = [200; 120; 150];
   LP.c      = [5; 12];
   LP.lb     = [0; 0];
   LP.ub     = [1000; 1000];
   LP.csense = ['L'; 'L'; 'L'];
   LP.osense = -1;    % maximise

   result = optarrow.solveLP(LP, struct('modelName', 'product_mix'));
   fprintf('obj = %.4f\n', result.obj_val);
   disp(result.solution)

Solve a QP
----------

``optarrow.solveQP`` extends the LP struct with a symmetric Hessian ``Q``:

.. code-block:: matlab

   QP        = struct();
   QP.A      = sparse([1 1]);
   QP.b      = 4;
   QP.c      = [-1; -2];
   QP.lb     = [0; 0];
   QP.ub     = [10; 10];
   QP.csense = 'L';
   QP.osense = 1;                      % minimise
   QP.Q      = sparse([2 0; 0 2]);     % ½ xᵀQx objective term

   result = optarrow.solveQP(QP, struct('modelName', 'qp_demo'));
   disp(result.solution)

``Q`` is converted to upper-triangular COO triplets and sent alongside the
LP fields in the same Arrow IPC record batch.

Submit a Generic Payload
------------------------

Use ``optarrow.compute`` directly when you want full control over the request:

.. code-block:: matlab

   payload = struct();
   payload.problem_type  = 'LP';
   payload.engine        = 'python';
   payload.solver_name   = 'HiGHS';
   payload.model_name    = 'my_lp';
   payload.time_limit    = 300;
   payload.solver_params = struct();

   payload.model.A      = struct('row', int64([0;1]), 'col', int64([0;1]), ...
                                 'val', [1.0;1.0], 'shape', int64([2,2]));
   payload.model.b      = [1.0; 1.0];
   payload.model.c      = [2.0; 3.0];
   payload.model.lb     = [0.0; 0.0];
   payload.model.ub     = [10.0; 10.0];
   payload.model.csense = {'L'; 'L'};
   payload.model.osense = 'max';

   result = optarrow.compute(payload);
   disp(result)

Response Struct
---------------

``optarrow.compute`` always returns a scalar struct with these fields:

.. list-table::
   :header-rows: 1
   :widths: 20 15 65

   * - Field
     - Type
     - Meaning
   * - ``success``
     - logical
     - ``true`` when the solver found a solution
   * - ``status``
     - char
     - Solver termination string, e.g. ``'optimal'``
   * - ``stat``
     - double
     - Numeric status code: ``1`` = optimal, ``0`` = infeasible,
       ``2`` = unbounded, ``-1`` = error/other
   * - ``obj_val``
     - double
     - Optimal objective value
   * - ``solution``
     - double vector
     - Primal solution (length n)
   * - ``dual``
     - double vector
     - Dual variables / shadow prices (length m)
   * - ``rcost``
     - double vector
     - Reduced costs (length n)
   * - ``slack``
     - double vector
     - Constraint slack ``b − A·x`` (length m)
   * - ``method``
     - char
     - Solver algorithm used, when reported
   * - ``time``
     - double
     - Wall-clock solve time in seconds, when reported

Configuration Reference
-----------------------

``optarrow.setOptArrowConfig`` accepts a struct with any of these fields:

.. csv-table::
   :header: "Field", "Default", "Meaning"
   :widths: 25, 30, 45

   "``endpoint``", "``http://127.0.0.1:8000/compute``", "Gateway URL"
   "``engine``", "``python``", "Backend engine (``python`` or ``julia``)"
   "``backendSolver``", "``''``", "Solver name (``HiGHS``, ``Gurobi``, …)"
   "``backendSolverType``", "``''``", "Problem class (``LP`` or ``QP``)"
   "``backendOptions``", "``struct()``", "Key-value solver parameters"
   "``timeoutSec``", "``120``", "HTTP connect + response timeout (seconds)"
   "``transport``", "``arrow``", "Must be ``arrow``"

All fields have defaults, so passing a partial struct is fine.

Notes
-----

- All functions use MATLAB package namespace syntax (``optarrow.compute``,
  not object method dispatch). They live inside the ``+optarrow`` folder.
- The ``transport`` field must always be ``'arrow'``; there is no JSON
  transport path in the MATLAB client.
- The gateway engine ``'python'`` routes to the in-process Python solver;
  no separate gRPC process is required.
