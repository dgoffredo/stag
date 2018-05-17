src
===
This directory contains the Racket source code of stag. Racket doesn't have
directory-based packaging like python does, but it's still convenient to
organize modules into directories.

Each subdirectory of `src/` contains a module along with its private
implementation module (if applicable), its unit test module, and its
documentation as a `README.md` file.

For example, the `python` directory consists of:
- `python/python.rkt`
- `python/private.rkt`
- `python/README.md`
- `python/test.rkt`

The public module always has the same name as the subdirectory. So, to require
the "python" module from another subdirectory, such as in `stag/stag.rkt`, the
import might look like:
```scheme
(require "../python/python.rkt")
```