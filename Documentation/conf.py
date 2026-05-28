import os
import sys
from datetime import datetime

project = 'OptArrow'
author = 'OptArrow Contributors'
copyright = f"{datetime.now().year}, {author}"

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.napoleon',
    'sphinx.ext.mathjax',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
html_css_files = ['custom-wide.css']
html_context = {
    "display_github": True,
    "github_user": "optArrow",
    "github_repo": "optArrow",
    "github_version": "main",
    "conf_py_path": "/Documentation/",
}
