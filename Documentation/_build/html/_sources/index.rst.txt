Introduction
============

.. figure:: ../_static/logo.png
   :align: center
   :width: 20%
   :class: intro-logo

   **OptArrow**

   *Solve optimization problems anywhere, in any language, with any solver.*

OptArrow is an optimization integration engine designed to seamlessly connect the Python and Julia ecosystems.
It addresses the technical and structural challenges of building scalable, high-performance optimization
pipelines across languages.

Motivation
----------

Modern optimization workflows often involve multiple components:

- **Python** is widely used for data preparation, orchestration, and web service development.
- **Julia**, on the other hand, offers state-of-the-art numerical solvers with exceptional performance for mathematical programming.

However, bridging these two environments remains challenging. Users frequently encounter issues with data format inconsistencies,
communication overhead, and the lack of a unified interface for optimization models.

OptArrow was developed to close this gap.

What Problem Does OptArrow Solve?
---------------------------------

- **Cross-language communication bottlenecks**: Passing large-scale optimization models between Python and Julia often involves serialization overhead, format mismatches, and maintenance burdens.
- **Inconsistent model representations**: Different solvers have their own modeling APIs (for example, Pyomo and JuMP), making solver switching difficult and error-prone.
- **Scalability and memory inefficiency**: Traditional formats such as JSON or ``.mat`` files struggle with large sparse matrices and high-dimensional data.

OptArrow's Solution
-------------------

OptArrow introduces a streamlined, interoperable architecture with the following features:

- **Unified in-memory model representation**: Based on the Apache Arrow columnar format, OptArrow enables zero-copy data exchange between Python and Julia.
- **Protocol-based model definitions**: Optimization problems (for example, Linear Programming and Quadratic Programming) are described using well-defined schemas, independent of solver-specific syntax.
- **Multi-backend support**: Users can run the same model through solvers like HiGHS, Gurobi, Mosek, or GLPK by switching backend configuration.
- **Efficient communication channels**: OptArrow supports HTTP and Arrow Flight RPC, providing flexibility for both local and distributed deployments.

Learn More
----------

- :doc:`How to Define an LP Problem <tutorials/lp_problem>`
- :doc:`How to Use OptArrow to solve an LP Problem <tutorials/lp_example1>`

.. toctree::
   :maxdepth: 1
   :caption: Introduction

   intros/architecture

.. toctree::
   :maxdepth: 1
   :caption: Setup and Installation

   intros/quickstart
   intros/installation
   intros/julia_setup
   intros/python_engine_setup
   intros/benchmarking

.. toctree::
   :maxdepth: 1
   :caption: Tutorials

   tutorials/lp_problem
   tutorials/lp_example1
   tutorials/lp_example2
   tutorials/qp_problem
   tutorials/qp_example
   tutorials/conversion_dictionary_arrow_table
   tutorials/matlab_interface

.. toctree::
   :maxdepth: 1
   :caption: Maintenance and Contribution

   intros/contributing
