# Architecture Overview

```{figure} ../_static/optarrow_architecture.png
:align: center
:width: 50%
```

The architecture of OptArrow is designed to facilitate seamless communication between Python and Julia optimization solvers. It consists of the following key components:

1. **Gateway**: The entry point for all optimization requests. It handles incoming requests, manages sessions, and routes tasks to the appropriate solver. It also provides a unified interface that abstracts the differences between Python and Julia, allowing users to switch between solvers with minimal code changes.

2. **Python Engine**: It serves as the Python-based optimization engine, leveraging libraries like Pyomo. It uses Apache Arrow Flight RPC for efficient data transfer and communication with the Gateway. This engine is designed to handle various optimization tasks, including linear programming (LP) and quadratic programming (QP).

3. **Julia Engine**: Similar to the Python Engine, but specifically for Julia-based optimization libraries (e.g., JuMP). It leverages Julia's performance advantages for solving complex optimization problems. This engine also communicates with the Gateway using socket-based TCP connections and Apache Arrow IPC bytes as the data format, ensuring efficient data exchange between the Julia environment and the Gateway.

These three services can be run independently, allowing for flexible deployment and scaling. The Gateway acts as the central hub, coordinating requests and responses between the Python and Julia engines.