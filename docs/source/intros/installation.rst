Installation Guide
===================

Overview
--------

OptArrow consists of two main components:

1. **Python Backend** — The OptArrow Gateway server with LP/QP solver engines
2. **MATLAB Interface** — Native Apache Arrow IPC serialization for MATLAB communication

The MATLAB component requires the **MATLAB Interface to Apache Arrow**. On Linux
x86_64, OptArrow can use the bundled experimental build. Other platforms, or
Linux systems where the bundled build is not compatible, can build the interface
from source.

Quick Start
-----------

Linux/macOS
^^^^^^^^^^^

Prerequisites
"""""""""""""

**Linux:**

.. code-block:: bash

   sudo apt install -y cmake build-essential

**macOS:**

.. code-block:: bash

   xcode-select --install
   brew install cmake

Step 1: Add Arrow to the MATLAB Search Path
"""""""""""""""""""""""""""""""""""""""""""

From MATLAB:

.. code-block:: matlab

   run scripts/setupMATLABArrow.m

On Linux x86_64, this first looks for the bundled build at
``src/matlab/vendor/apache-arrow/linux-x86_64/arrow_matlab``. If no bundled
build is available for the current platform, it falls back to
``$HOME/arrow_matlab/arrow_matlab``.

.. note::

   The bundled Linux build is experimental. If MATLAB reports a ``GLIBCXX_*``
   error while loading ``gateway.mexa64``, MATLAB is using a C++ runtime older
   than the one used to build the bundled binary. In that case, use the source
   build path below.

Step 2: Build Arrow Only If Needed
""""""""""""""""""""""""""""""""""

If the setup step cannot find a compatible Arrow MATLAB interface, build it from
source.

From the ``optArrow`` repository:

.. code-block:: bash

   ./scripts/buildMATLABArrow.sh

This script will:

- Clone Apache Arrow repository
- Build Arrow C++ (Release mode, ~5-10 minutes)
- Build MATLAB bindings
- Install to ``$HOME/arrow_no_s3`` and ``$HOME/arrow_matlab``

**Optional:** Enable S3 support:

.. code-block:: bash

   ./scripts/buildMATLABArrow.sh --with-s3

Step 3: Add the Source Build to MATLAB Search Path
""""""""""""""""""""""""""""""""""""""""""""""""""

From MATLAB:

.. code-block:: matlab

   run scripts/setupMATLABArrow.m

Or manually:

.. code-block:: matlab

   addpath(fullfile(getenv('HOME'), 'arrow_matlab', 'arrow_matlab'));
   savepath;

Step 4: Verify Installation
""""""""""""""""""""""""""""

From MATLAB, verify Arrow is working:

.. code-block:: matlab

   arrow.recordBatch(table(["A";"B"], [1;2]))

Expected output: A ``RecordBatch`` with 2 rows and 2 columns.

Manual Build (Step-by-Step)
---------------------------

If the automated script encounters issues, follow these manual steps.

Build Apache Arrow C++
^^^^^^^^^^^^^^^^^^^^^^

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

   cmake --build build_cpp --config Release --parallel
   cmake --build build_cpp --config Release --target install

Build MATLAB Bindings
^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   cmake -S matlab -B build_matlab \
     -DArrow_DIR=$HOME/arrow_no_s3/lib/cmake/Arrow \
     -DCMAKE_INSTALL_PREFIX=$HOME/arrow_matlab

   cmake --build build_matlab --config Release --parallel
   cmake --build build_matlab --config Release --target install

Add to MATLAB Search Path
^^^^^^^^^^^^^^^^^^^^^^^^^

From MATLAB:

.. code-block:: matlab

   addpath('$HOME/arrow_matlab/arrow_matlab');
   savepath;

Verify Installation
^^^^^^^^^^^^^^^^^^^

.. code-block:: matlab

   arrow.recordBatch(table(["A";"B"], [1;2]))

Environment Variables
---------------------

Customize installation paths using environment variables:

.. list-table::
   :header-rows: 1

   * - Variable
     - Purpose
     - Default
   * - ``ARROW_REPO_DIR``
     - Apache Arrow repository location
     - ``$HOME/arrow``
   * - ``ARROW_CPP_INSTALL``
     - Arrow C++ installation path
     - ``$HOME/arrow_no_s3``
   * - ``ARROW_MATLAB_INSTALL``
     - Arrow MATLAB installation path
     - ``$HOME/arrow_matlab``

Example:

.. code-block:: bash

   export ARROW_CPP_INSTALL=$HOME/my_arrow_cpp
   export ARROW_MATLAB_INSTALL=$HOME/my_arrow_matlab
   ./scripts/buildMATLABArrow.sh

Troubleshooting
---------------

Arrow Interface Not Found
^^^^^^^^^^^^^^^^^^^^^^^^^^

**Error:**
    ``Error using checkOptArrowSetup: "MATLAB Interface to Apache Arrow" is not installed.``

**Solution:**

1. Verify Arrow MATLAB directory exists:

   .. code-block:: bash

      ls -la $HOME/arrow_matlab/arrow_matlab

2. If not found, run the build script:

   .. code-block:: bash

      ./scripts/buildMATLABArrow.sh

3. From MATLAB, add the path:

   .. code-block:: matlab

      addpath(fullfile(getenv('HOME'), 'arrow_matlab', 'arrow_matlab'));
      savepath;

MATLAB Not Found
^^^^^^^^^^^^^^^^

**Error:**
    ``MATLAB not found. Please ensure MATLAB is installed and in PATH.``

**Solution:**

Check if MATLAB is in your PATH:

.. code-block:: bash

   which matlab

If not found, add to your shell profile (``~/.bashrc`` or ``~/.zshrc``):

.. code-block:: bash

   export PATH="/usr/local/MATLAB/R2026a/bin:$PATH"

Then reload:

.. code-block:: bash

   source ~/.bashrc

CMake Cannot Add MATLAB Search Path
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Error:**
    ``Failed to add the installation directory to the MATLAB Search Path. This may be due to the current user lacking necessary filesystem permissions.``

**Solution:**

This is normal if the system MATLAB toolbox directory is not writable. Add the path manually from MATLAB:

.. code-block:: matlab

   addpath(fullfile(getenv('HOME'), 'arrow_matlab', 'arrow_matlab'));
   savepath;

Compiler Not Found
^^^^^^^^^^^^^^^^^^

**Linux:**

.. code-block:: bash

   sudo apt install -y build-essential

**macOS:**

.. code-block:: bash

   xcode-select --install

Build Slow or Out of Memory
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Reduce parallel build jobs:

.. code-block:: bash

   cmake --build build_cpp --config Release -j2

Docker
------

For a reproducible environment with all dependencies pre-installed:

.. code-block:: bash

   docker build -f matlab.dockerfile -t optarrow-matlab .
   docker run -it optarrow-matlab matlab

Next Steps
----------

After Arrow is installed:

1. **Start the OptArrow Gateway:**

   .. code-block:: bash

      cd optArrow-main
      python src/run_server.py

2. **Run MATLAB Tests:**

   .. code-block:: matlab

      cd cobratoolbox-optarrow/src/base/solvers/optarrow
      runtests testOptArrowEcoliCoreFBA

3. **Try the Demo:**

   See ``examples/`` directory for sample usage.

References
----------

- `Apache Arrow MATLAB Documentation <https://github.com/apache/arrow/tree/main/matlab>`_
- `Apache Arrow GitHub <https://github.com/apache/arrow>`_
- `OptArrow GitHub <https://github.com/optarrow/optarrow>`_
- `COBRA Toolbox <https://github.com/opencobra/cobratoolbox>`_
