Overall Setup
=============

This documentation site is built with Sphinx from the ``Documentation/`` folder.

Prerequisites
-------------

- Python 3.10+
- ``pip``

Install dependencies
--------------------

From the project root:

.. code-block:: bash

    /bin/python -m pip install -r Documentation/requirements.txt

Build the HTML docs locally
---------------------------

.. code-block:: bash

    /bin/python -m sphinx -b html Documentation Documentation/_build/html

Open the generated site at ``Documentation/_build/html/index.html``.