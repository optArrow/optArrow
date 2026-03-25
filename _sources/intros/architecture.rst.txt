Architecture Overview
=====================

.. figure:: ../_static/optarrow_architecture.png
   :align: center
   :width: 50%

The architecture of OptArrow is designed to facilitate seamless communication between Python and Julia optimization solvers.

Key components
--------------

1. **Gateway**: Entry point for optimization requests. It handles sessions and routes tasks to the selected solver backend.
2. **Python Engine**: Python-based optimization execution (for example with Pyomo) and Arrow-based payload handling.
3. **Julia Engine**: Julia-based optimization execution (for example with JuMP), using socket/TCP communication and Arrow IPC payloads.

These services can run independently, enabling flexible deployment and scaling.
