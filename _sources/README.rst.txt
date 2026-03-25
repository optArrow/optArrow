Documentation workflow
======================

This branch contains generated site files for GitHub Pages and a source docs project in ``Documentation/``.

Local build
-----------

.. code-block:: bash

   cd Documentation
   python -m pip install -r requirements.txt
   make html

GitHub Actions deployment
-------------------------

The workflow in ``.github/workflows/sphinx-docs.yml`` builds docs from ``Documentation/`` and publishes HTML to the ``gh-pages`` branch.
