# OptArrow Docs (gh-pages)

This branch contains generated site files for GitHub Pages and the Sphinx source project in `Documentation/`.

## Local build

```bash
cd Documentation
python -m pip install -r requirements.txt
make html
```

## GitHub Actions deployment

The workflow in `.github/workflows/sphinx-docs.yml` builds docs from `Documentation/` and publishes HTML to the `gh-pages` branch.

## Notes

- The default development branch is `main`.
- This `gh-pages` branch is for published documentation artifacts.
