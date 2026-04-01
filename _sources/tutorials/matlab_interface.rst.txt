MATLAB Interface for OptArrow
=============================

OptArrow now includes a real MATLAB interface under ``src/matlab``.

This interface is designed as a generic MATLAB client for OptArrow:

- it uses the OptArrow HTTP gateway
- it sends requests using Apache Arrow IPC
- it supports sparse LP transfer through COO triplets
- it stays generic and does not depend on any toolbox-specific model schema

For toolbox-specific integrations such as COBRA Toolbox, the translation layer
should live in the downstream project, while OptArrow remains a general
optimization service.

What Is Included
----------------

The MATLAB package currently provides these entry points:

- ``optarrow.setOptArrowConfig``: configure the active OptArrow endpoint,
  engine, backend solver, and timeout
- ``optarrow.getOptArrowConfig``: inspect the active configuration
- ``optarrow.compute``: submit a generic OptArrow payload
- ``optarrow.solveLP``: convenience wrapper for MATLAB LP structs

The supporting Python bridge is:

- ``src/matlab/py/optarrow_matlab_bridge.py``

This bridge serializes MATLAB payloads to Arrow IPC, posts them to the
OptArrow gateway, and decodes the response back into a MATLAB struct.

Prerequisites
-------------

1. MATLAB with Python integration enabled
2. A Python environment available to MATLAB via ``pyenv``
3. Python packages installed in that environment:

   - ``pyarrow``
   - ``requests``

4. The OptArrow gateway running, typically on ``http://127.0.0.1:8000/compute``
5. At least one OptArrow backend engine running, for example the Python engine

Recommended Usage
-----------------

The recommended way to use OptArrow from MATLAB is through the packaged MATLAB
namespace under ``src/matlab/+optarrow``.

Setup
^^^^^

.. code-block:: matlab

   repoRoot = "/path/to/OptArrow";
   addpath(genpath(fullfile(repoRoot, "src", "matlab")));

   pyenv("Version", "/path/to/python");

   cfg = struct( ...
       'name', 'optarrow', ...
       'engine', 'python', ...
       'backendSolver', 'HiGHS', ...
       'backendSolverType', 'LP', ...
       'backendOptions', struct(), ...
       'endpoint', 'http://127.0.0.1:8000/compute', ...
       'timeoutSec', 120);

   optarrow.setOptArrowConfig(cfg);

You can inspect the resolved configuration with:

.. code-block:: matlab

   disp(optarrow.getOptArrowConfig())

Solve an LP From MATLAB
^^^^^^^^^^^^^^^^^^^^^^^

``optarrow.solveLP`` accepts a generic LP struct with fields such as ``A``,
``b``, ``c``, ``lb``, ``ub``, ``csense``, and ``osense``.

.. code-block:: matlab

   LPproblem = struct();
   LPproblem.A = sparse([20 10; 10 20; 10 30]);
   LPproblem.b = [200; 120; 150];
   LPproblem.c = [5; 12];
   LPproblem.lb = [0; 0];
   LPproblem.ub = [1000; 1000];
   LPproblem.csense = ['L'; 'L'; 'L'];
   LPproblem.osense = -1;   % -1 = max, 1 = min

   result = optarrow.solveLP(LPproblem, struct( ...
       'modelName', 'matlab_lp_demo'));

   disp(result)

Internally, ``optarrow.solveLP``:

1. converts the MATLAB matrix to sparse COO triplets
2. normalizes objective and constraint senses
3. builds a generic OptArrow payload
4. sends the request through ``optarrow.compute``
5. returns the decoded response as a MATLAB struct

Submit a Generic Payload
^^^^^^^^^^^^^^^^^^^^^^^^

Use ``optarrow.compute`` if you already have an OptArrow-compatible request
payload and want full control over the request body.

.. code-block:: matlab

   payload = struct();
   payload.model = struct( ...
       'A', struct('row', [0 1], 'col', [0 1], 'val', [1 1]), ...
       'b', [1 1], ...
       'c', [2 3], ...
       'lb', [0 0], ...
       'ub', [10 10], ...
       'csense', {{'L'; 'L'}}, ...
       'osense', 'max');
   payload.model_name = 'generic_payload_demo';

   result = optarrow.compute(payload);
   disp(result)

Request Configuration
---------------------

``optarrow.setOptArrowConfig`` supports these main fields:

.. csv-table::
   :header: "Field", "Meaning"
   :widths: 30, 70

   "``engine``", "Backend engine name, such as ``python`` or ``julia``"
   "``backendSolver``", "Backend solver name, such as ``HiGHS``"
   "``backendSolverType``", "Problem class, such as ``LP``"
   "``backendOptions``", "Solver parameter struct"
   "``endpoint``", "Gateway URL, usually ``http://127.0.0.1:8000/compute``"
   "``timeoutSec``", "HTTP timeout in seconds"
   "``transport``", "Currently must be ``arrow``"

The current MATLAB interface is Arrow-only by design. It does not expose a
separate JSON transport path.

Low-Level HTTP Alternative
--------------------------

If needed, MATLAB can also send Arrow IPC bytes directly using
``matlab.net.http``. This is useful for debugging transport issues or for
advanced custom clients, but for normal usage the packaged interface above is
recommended.

.. code-block:: matlab

   fid = fopen('data.arrow', 'rb');
   data = fread(fid, Inf, '*uint8');
   fclose(fid);

   import matlab.net.http.*
   import matlab.net.http.field.*

   headers = [GenericField('Content-Type', 'application/vnd.apache.arrow.stream')];
   body = MessageBody();
   body.Payload = data;
   request = RequestMessage('POST', headers, body);

   response = request.send('http://127.0.0.1:8000/compute');

This route is lower-level than ``optarrow.compute`` and requires you to handle
Arrow request and response serialization yourself.

Notes
-----

- ``optarrow.solveLP`` is package namespace syntax from the ``+optarrow``
  folder, not object-oriented method dispatch.
- The MATLAB interface is generic and intentionally does not include
  COBRA-specific model translation.
- MATLAB currently reaches the Arrow gateway through a small Python bridge.
- For toolbox integrations, keep the OptArrow client generic and place any
  application-specific adaptation logic in the downstream project.
