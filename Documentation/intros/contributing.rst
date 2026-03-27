Contributing to Arrow Gateway Engine
====================================

Thank you for your interest in contributing. This guide will help you get started.

Project Structure
-----------------

- ``./src``: Main source code.
- ``./tests``: Test suite for the project.
- ``./Documentation``: Documentation source files for this site.

Getting Started
---------------

1. Fork the repository and clone your fork.
2. Install dependencies as required by the project.

	- On Linux (Debian), you may use ``./scripts/envSetup.sh`` for quick environment setup.
	- ``poetry`` is used to manage Python dependencies.
	- Julia dependencies must be installed manually:

	.. code-block:: bash

		julia --project=./src/service/optimization_service/julia -e "import Pkg; Pkg.instantiate()"

3. Create a new branch for your feature or bugfix:

	.. code-block:: bash

		git checkout -b feature/your-feature-name

Making Changes
--------------

- Place all source code changes in ``./src``.
- Add or update tests in ``./tests``.
- Add or update documentation in ``./Documentation``.
- Ensure your code follows the project's style and linting rules.

Running Tests
-------------

Run the test suite to verify your changes:

.. code-block:: bash

	poetry run pytest

Add ``-s`` to see STDOUT output from tests.

Submitting Changes
------------------

1. Commit your changes with clear messages.
2. Push your branch to your fork.
3. Open a Pull Request against the main repository.

Code Review
-----------

- Address feedback from reviewers.
- Ensure all tests pass before merging.

Questions?
----------

Open an issue if you need help or clarification.

Thank you for contributing!
