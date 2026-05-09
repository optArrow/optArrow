# Apache Arrow MATLAB Linux x86_64 Bundle

This experimental bundle was copied from a local Apache Arrow MATLAB install:

- Source install path: `/home/farid/arrow_matlab/arrow_matlab`
- Bundled path: `src/matlab/vendor/apache-arrow/linux-x86_64/arrow_matlab`
- Platform: Linux x86_64 / MATLAB `glnxa64`
- Size: about 28 MB

Native files included under `arrow_matlab/+libmexclass/+proxy`:

- `gateway.mexa64`
- `libarrowproxy.so`
- `libmexclass.so`
- `libarrow.so.2500.0.0`
- `libarrow.so.2500` -> `libarrow.so.2500.0.0`
- `libarrow.so` -> `libarrow.so.2500`

Known result from the first local verification:

- MATLAB R2026a loads its own `libstdc++.so.6`.
- This bundled build requires `GLIBCXX_3.4.32`.
- The MATLAB R2026a runtime observed locally exposes symbols only through
  `GLIBCXX_3.4.30`, so this bundle fails verification on that runtime.

This bundle is useful for testing the packaging flow, but it should be rebuilt
on an older Linux/libstdc++ baseline before being treated as a portable release
artifact.
