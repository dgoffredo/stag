version
=======
This module provides a constant, `*stag-version*`, that is distinct for each
commit to this source repository. `*stag-version*` is included in every file
produced by `stag`, so that the corresponding source snapshot can be found.

`version.rkt` is generated by git's `pre-commit` hook. See
[.githooks/README.md](../../../.githooks/README.md) for more information.