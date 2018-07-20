stag
====
This directory is a Racket [package][package] containing modules used by the
code generator. Each `.rkt` file in this directory is a public module whose
implementation, unit tests, and documentation reside in a similarly named
subdirectory.

For example, the [xsd-util.rkt](xsd-util.rkt) module provides procedures for
parsing and normalizing XSD files. It uses private modules in the
[xsd-util](xsd-util/) subdirectory, where there is also a [unit test
module](xsd-util/test.rkt) and [documentation](xsd-util/README.md).

Overview
--------
Each module has dedicated documentation in its subdirectory, but here is an
overview of all of them:

- [bdlat](bdlat/) provides `struct`s describing
  [BDE-style "attribute types"][bdlat]. Attribute types are what XSDs describe:
  structures, named variants, and enumerations.
- [options](options/) provides procedures that parse command line
  options used by the code generator's command line interface.
- [python](python/) provides `struct`s describing python code AST
  nodes, and provides procedures for generating an AST from `bdlat` types, and
  then for rendering python source code from the AST.
- [stag](stag/) provides a procedure implementing the code generator's
  command line interface.
- [sxml-match](sxml-match/) is a library for matching patterns in a
  Scheme representation of XML, SXML.
- [version](version/) provides a string that's included in generated
  source code in order to mark the version of the code generator that produced
  the source code. The file itself is overwritten by a git hook on commit.
- [xsd-util](xsd-util/) provides procedures that parse an XSD into SXML
  and then transform the SXML into a "normalized" form that
  [bdlat.rkt](bdlat.rkt) can more easily process.

[package]: https://docs.racket-lang.org/pkg/Package_Concepts.html
[bdlat]: https://bloomberg.github.io/bde/group__bdlat.html