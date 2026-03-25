Benchmark testing
=================

In order to do benchmark testing, use the source code from `benchmark` branch, this includes extra benchmark outputs such as compute time, RAM usage and CPU percentage output. 

The unit tests in that branch can write .csv outputs to list the benchmark test results, and they are organized into different .csv files based on engines and problem types.

Use this to switch branch and execute test:

.. code-block:: bash

   
   git checkout benchmark
   poetry run pytest -s
   

You can find the benchmark output files under the project root directory.
