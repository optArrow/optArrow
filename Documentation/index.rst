Introduction
============

.. figure:: ../_static/logo.png
   :align: center
   :width: 20%
   :class: intro-logo

   **OptArrow**

   *Solve optimization problems anywhere, in any language, with any solver.*

OptArrow is an optimization integration engine designed to connect optimization
clients and solver backends through a stable, high-performance transport layer.
Its current runtime centers on Python and Julia backends, and it can also be
called from environments such as MATLAB through a lightweight client
interface.

.. raw:: html

   <div style="text-align: center; margin: 1.5em 0 2em;">
     <a href="https://github.com/optArrow/optArrow" target="_blank" rel="noopener noreferrer"
        style="display: inline-flex; align-items: center; gap: 0.55em; padding: 0.55em 1.3em;
               background: #24292e; color: #fff; border-radius: 6px; text-decoration: none;
               font-weight: 600; font-size: 0.95em; letter-spacing: 0.01em;
               box-shadow: 0 1px 4px rgba(0,0,0,0.18);">
       <svg height="18" width="18" viewBox="0 0 16 16" fill="white" xmlns="http://www.w3.org/2000/svg" style="flex-shrink:0;">
         <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38
                  0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01
                  1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15
                  -.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82
                  2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0
                  1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
       </svg>
       View on GitHub
     </a>
   </div>

Motivation
----------

Modern optimization workflows often involve multiple components:

- **Python** is widely used for data preparation, orchestration, and web service development.
- **Julia**, on the other hand, offers state-of-the-art numerical solvers with exceptional performance for mathematical programming.
- **MATLAB** is still widely used in scientific and engineering workflows and benefits from a clean client path to the same backend services.

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
- **Reusable client integrations**: client-specific adapters can remain thin while OptArrow stays solver- and domain-generic.

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
   tutorials/qp_problem
   tutorials/qp_example
   tutorials/conversion_dictionary_arrow_table
   tutorials/matlab_interface

.. toctree::
   :maxdepth: 1
   :caption: Maintenance and Contribution

   intros/contributing

Learn More
----------

- :doc:`How to Define an LP Problem <tutorials/lp_problem>`
- :doc:`How to Use OptArrow to solve an LP Problem <tutorials/lp_example1>`
