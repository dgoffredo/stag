src
===
This directory contains the Racket source code of stag. Racket doesn't have
directory-based packaging like python does, but it's still convenient to
organize modules into directories.

Each subdirectory of `src/` contains a module along with its private
implementation modules (if applicable), its unit test module, and its
documentation as a `README.md` file.

For example, the `bdlat` directory consists of:
- `bdlat/bdlat.rkt`
- `bdlat/private.rkt`
- `bdlat/README.md`
- `bdlat/test.rkt`

The public module always has the same name as the subdirectory. So, to require
the "python" module from another subdirectory, such as in `stag/stag.rkt`, the
import might look like:

```scheme
(require "../bdlat/bdlat.rkt")
```
Other subdirectories have more than one private module. Still, the `.rkt`
file with the same name as the subdirectory is the public module.