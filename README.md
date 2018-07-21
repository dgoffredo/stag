![stag](stag.png)

stag
====
Stupid Typed Attribute Generator

Why
---
Since the advent of the personal computer, doctors and scientists have been
confounded by the persistence and virility of Overactive Type Annotation
Syndrome (OTAS). Despite decades of experience, the widespread availability
of cognitive behavioral therapy, and even a proposed vaccine, no regimen has
been shown effective for the treatment or prevention of OTAS.

Those diagnosed exhibit broad dysfunction. They agonize over irrelevant
details of code rendering, produce thousands of lines of redundant or
unnecessary code, and generally waste the time and energy of unaffected
individuals.

The leading theory of OTAS's pathology comes from Freud, who postulated that
the patient's subconscious desire to control elimination might manifest as a
preoccupation with technical rigidity and verbosity. However, no clinical
study to date supports this theory.

Alternative proposed etiologies typically involve small mind-controlling
parasites or latent food allergies. Some people display apparent immunity to
OTAS, and it is not known whether immunity is acquired or hereditary.

What
----
`stag` is a Racket program that, given an XML Schema Definition (XSD) file,
generates three python modules: one containing python classes corresponding
to the types defined in the schema, another of utilities for converting
instances of the generated classes to and from JSON-compatible compositions
of standard python objects, such as `dict` and `list`, and a final module of
private implementation details.

How
---
Invoke `stag` as a command line tool:

    $ stag foosvcmsg.xsd
    $ ls
    _foosvcmsg.py    foosvcmsg.py    foosvcmsgutil.py    foosvcmsg.xsd

To the current directory or a specified directory the script writes three
files: one containing the generated class definitions (`foosvcmsg.py`), another
containing the implementations of the `to_jsonable` and `from_jsonable`
functions and name mappings (`foosvcmsgutil.py`), and a third containing
implementation details that could be part of a library but are repeated for
convenience and portability (`_foosvcmsg.py`).

`stag` also accepts various options:

| Option                        | Description                                 |
| ------                        | -----------                                 |
| `--verbose`                   | print verbose error and debug diagnostics   |
| `--output-directory <path>`   | output directory -- defaults to `$PWD`      |
| `--types-module <name>`       | name of module containing types             |
| `--util-module <name>`        | name of module containing utilities         |
| `--private-module <name>`     | name of module containing private details   |
| `--package <name>`            | package path containing generated modules   |
| `--extensions-namespace <ns>` | XML namespace where extensions are defined  |
| `--name-overrides <list>`     | generated identifiers. See "Name Overrides."|

More
----
### Repository Initialization
Run `make init` after cloning this repository. It sets up `git` pre-commit
hook that keeps `version.rkt` up to date. See 
[.githooks/README.md](.githooks/README.md) for more information.

### Build
Stag requires Racket, and additionally the following Racket packages:
- `raco pkg install sxml`
- `raco pkg install threading-lib`

Stag can be run from source by passing it to the Racket interpreter, e.g.

    $ racket src/stag.rkt --help

To compile a self-contained distribution of stag, run `make build`. This will
create a directory `build/$(uname)` containing the `stag` binary and the
shared libraries it needs to run. The directory can then be deployed without
needing to deploy Racket, provided that the relative path between the stag
binary and its requisite libraries does not change.

### Test
Run `make test` to run all of the `test.rkt` modules recursively under `src/`.
You can run a test individually using `raco test`, e.g.

    $ raco test src/stag/xsd-util/test.rkt

### Name Overrides
The `<list>` argument to the `--name-overrides` command line parameter is a
scheme list having the following form:

    ([old-name new-name] ...)

where `old-name` is either a symbol indicating the name of a class or a list
`(class-name attribute-name)` indicating the name of a class attribute.
`new-name` is a symbol spelling the name of the class or attribute after the
replacement.

For example, suppose that the input XSD contains a few problematic names: a
type `BSaaS` and an attribute `MAXIMUM_LENGTH` in the type `Settings`. In
order to map `BSaaS` to `BSaas` and to map `MAXIMUM_LENGTH` to
`maximum_length`, the correct override list is:

    ([BSaaS Bsaas]
     [(Settings MAXIMUM_LENGTH) maximum_length])

which can be passed on the command line as:

    $ stag --name-overrides '([BSaaS Bsaas] [(Settings MAXIMUM_LENGTH) maximum_length])' schema.xsd

### Packages
The `--package` command line argument allows the generated python modules to
reside in a python package (or a sub-package, or a sub-sub-package, etc.).

If
`--package` is not specified, then modules are written to the
`--output-directory` (which defaults to the current directory).

If `--package` is specified, then its argument must be a period-separated
package name, such as "configs.balber" or "services" or "atp.dna.foostuff".
Modules will be written as leaves to a directory tree rooted at the
`--output-directory` but otherwise following the structure of `--package`. For
example,

    $ stag --output-directory /home/ksozer --package svc.namesvc namesvc.xsd

would leave the following directory tree, creating directories if necessary:

    /home/ksozer/
                 svc/
                     __init__.py
                     namesvc/
                             __init__.py
                             _namesvcmsg.py
                             namesvcmsg.py
                             namesvcmsgutil.py

The `__init__.py` files are added empty if they're not present already.

Note that if directories are created by stag, but then stag fails before
completing code generation, the created directories will remain.