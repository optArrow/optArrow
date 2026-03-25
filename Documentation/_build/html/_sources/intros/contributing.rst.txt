Contributing
============

Thank you for helping improve OptArrow documentation.

Documentation workflow
----------------------

1. Edit files under ``Documentation/``.
2. Build locally to validate changes.
3. Open a pull request.

Local validation
----------------

.. code-block:: bash

	/bin/python -m pip install -r Documentation/requirements.txt
	/bin/python -m sphinx -b html Documentation Documentation/_build/html

When ``Documentation/`` changes are pushed to ``gh-pages``, GitHub Actions rebuilds and updates the generated site files on the same branch.
