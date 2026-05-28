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
    'sphinx_sitemap',
]

html_baseurl = 'https://optarrow.github.io/optArrow/'

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
html_css_files = ['custom-wide.css']
html_extra_path = ['_static/robots.txt']
html_context = {
    "display_github": True,
    "github_user": "optArrow",
    "github_repo": "optArrow",
    "github_version": "gh-pages",
    "conf_py_path": "/Documentation/",
}
