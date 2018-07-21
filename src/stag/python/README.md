python
======
This module provides data structures representing Python code abstract
syntax tree (AST) elements and procedures for producing python code from
bdlat types.

Contents
--------

The [python](python.rkt) module exports various `struct`s representing nodes in
python's abstract syntax tree, and also two procedures:

The first procedure, `bdlat->python-modules`, takes a list of type
definitions from the `bdlat` module, such as `bdlat-sequence` and
`bdlat-enumeration`, and returns a list containing three `python-module`
objects. The first `python-module` object contains `class` definitions
compiled from the `bdlat` types. The second `python-module` object contains
"jsonable" encoding and decoding functions that act on instances of any of
the generated classes, and also contains some implementation details (the
mapping from names in python to names in the schema). The third `python-module`
object contains the definitions of base classes and functions used by any
generated code, but is included separately to avoid the administration problem
that could be caused by dependency on a generator-specific python library.

The other procedure exported by [python.rkt](python.rkt) is `render-python`.
`render-python` takes an instance of any of the `python-`-prefixed `struct`s
and returns a string of python code rendered from that instance.

The Idea
--------
For a real usage example, see [stag.rkt](../stag/stag.rkt).

As an example of the transformations involved in code generation, this
module can be used to transform the following list of bdlat types:

```scheme
(list 
  (sequence "BerDecoderOptions" 
    '("BER decoding options") 
    (list 
      (element "MaxDepth" (nullable (basic "int")) 
        '("maximum recursion depth") "32") 
      ...
      (element "MaxSequenceSize" (nullable (basic "int")) 
        '("maximum sequence size") "8388608"))) 
  (sequence "BerEncoderOptions" 
    '("BER encoding options") 
    (list 
      (element "TraceLevel" (nullable (basic "int")) 
        '("trace (verbosity) level") "0") 
      (element "BdeVersionConformance" (basic "int") 
      ...
  (choice "SomeChoice" 
    '() 
    (list 
      (element "foo" (basic "decimal") '() '#:omit) 
      (element "bar" (basic "string") '() '#:omit))) 
  (enumeration "Color" 
    '() 
    (list 
      (enumeration-value "RED" '() 0) 
      (enumeration-value "GREEN" '() 1) 
      (enumeration-value "BLUE" '() 2))))
```

into the following two Python ASTs:

```scheme
(list
 (python-module
  "Provide typed attribute classes."
  '("This module provides typed attribute classes generated from a schema."
    "Instances of the types defined in this module are immutable, and may be converted to and from JSON-compatible objects using the similarly-named utilities module that is dual to this module.")
  (list
   (python-import 'enum 'Enum)
   (python-import 'namedunion 'NamedUnion)
   (python-import 'typing 'NamedTuple)
   (python-import 'typing 'Optional))
  (list
   (python-class
    'BerDecoderOptions
    '(NamedTuple)
    '("BER decoding options")
    (list
     (python-annotation
      'MaxDepth
      '(Optional int)
      '("maximum recursion depth")
      '|32|)
     ...
     (python-annotation
      'MaxSequenceSize
      '(Optional int)
      '("maximum sequence size")
      '|8388608|)))
   (python-class
    'BerEncoderOptions
    '(NamedTuple)
    '("BER encoding options")
    (list
     (python-annotation
      'TraceLevel
      '(Optional int)
      '("trace (verbosity) level")
      '|0|)
     ...
     (python-annotation 'color "Color" '() '#:omit)
     (python-annotation 'thing "SomeChoice" '() '#:omit)))
   (python-class
    'SomeChoice
    '(NamedUnion)
    '()
    (list
     (python-annotation 'foo 'float '() '#:omit)
     (python-annotation 'bar 'str '() '#:omit)))
   (python-class
    'Color
    '(Enum)
    '()
    (list
     (python-assignment 'RED 0 '())
     (python-assignment 'GREEN 1 '())
     (python-assignment 'BLUE 2 '())))))
 (python-module
  "Provide codecs for types defined in mysvcmsg."
  '()
  (list (python-import 'mysvcmsg '()) (python-import 'gencodeutil '()))
  (list
   (python-def
    'to_jsonable
    '(obj)
    (list
     (python-return
      (python-invoke 'gencodeutil.to_jsonable '(obj _name_mappings)))))
   (python-def
    'from_jsonable
    '(return_type obj)
    (list
     (python-return
      (python-invoke
       'gencodeutil.from_jsonable
       '(return_type obj _name_mappings)))))
   (python-assignment
    '_name_mappings
    (python-dict
     (list
      (cons
       'mysvcmsg.BerEncoderOptions
       (python-invoke
        'gencodeutil.NameMapping
        (list
         (python-dict
          '(("BdeVersionConformance" . "BdeVersionConformance")
            ("TraceLevel" . "TraceLevel")
            ("DatetimeFractionalSecondPrecision"
             .
             "DatetimeFractionalSecondPrecision")
            ("EncodeEmptyArrays" . "EncodeEmptyArrays")
            ("thing" . "thing")
            ("color" . "color")
            ("EncodeDateAndTimeTypesAsBinary"
             .
             "EncodeDateAndTimeTypesAsBinary"))))))
      (cons
       'mysvcmsg.Color
       (python-invoke
        'gencodeutil.NameMapping
        (list
         (python-dict
          '(("BLUE" . "BLUE") ("GREEN" . "GREEN") ("RED" . "RED"))))))
      (cons
       'mysvcmsg.BerDecoderOptions
       (python-invoke
        'gencodeutil.NameMapping
        (list
         (python-dict
          '(("MaxDepth" . "MaxDepth")
            ("TraceLevel" . "TraceLevel")
            ("SkipUnknownElements" . "SkipUnknownElements")
            ("MaxSequenceSize" . "MaxSequenceSize"))))))
      (cons
       'mysvcmsg.SomeChoice
       (python-invoke
        'gencodeutil.NameMapping
        (list (python-dict '(("bar" . "bar") ("foo" . "foo"))))))))
    '()))))
```

and then into the following two Python modules (plus a third being the
"private" module, whose content is independent of the two ASTs):

```python
"""Provide typed attribute classes.

This module provides typed attribute classes generated from a schema.

Instances of the types defined in this module are immutable, and may be
converted to and from JSON-compatible objects using the similarly-named
utilities module that is dual to this module.
"""


from enum import Enum
from namedunion import NamedUnion
from typing import NamedTuple
from typing import Optional


class BerDecoderOptions(NamedTuple):
    """BER decoding options
    """
    # maximum recursion depth
    MaxDepth : Optional[int] = 32
    # Option to skip unknown elements
    SkipUnknownElements : Optional[bool] = True
    # trace (verbosity) level
    TraceLevel : Optional[int] = 0
    # maximum sequence size
    MaxSequenceSize : Optional[int] = 8388608


class BerEncoderOptions(NamedTuple):
    """BER encoding options
    """
    # trace (verbosity) level
    TraceLevel : Optional[int] = 0
    # The largest BDE version that can be assumed of the corresponding decoder
    # for the encoded message, expressed as 10000*majorVersion +
    # 100*minorVersion + patchVersion (e.g. 1.5.0 is expressed as 10500).
    # 
    # Ideally, the BER encoder should be permitted to generate any BER that
    # conforms to X.690 (Basic Encoding Rules) and X.694 (mapping of XSD to
    # ASN.1). In practice, however, certain unimplemented features and
    ...
    # standards conformant. The default should be increased only when old
    # copies of the decoder are completely out of circulation.
    BdeVersionConformance : int = 10500
    # This option allows users to control if empty arrays are encoded. By
    # default empty arrays are encoded as not encoding empty arrays is
    # non-compliant with the BER encoding specification.
    EncodeEmptyArrays : bool = True
    # This option allows users to control if date and time types are encoded
    # as binary integers. By default these types are encoded as strings in the
    # ISO 8601 format.
    EncodeDateAndTimeTypesAsBinary : bool = False
    # This option controls the number of decimal places used for seconds when
    # encoding 'Datetime' and 'DatetimeTz'.
    DatetimeFractionalSecondPrecision : Optional[int] = 3
    color : Color
    thing : SomeChoice


class SomeChoice(NamedUnion):
    foo : float
    bar : str


class Color(Enum):
    RED = 0
    GREEN = 1
    BLUE = 2
```

```python
"""Provide codecs for types defined in mysvcmsg.
"""


import mysvcmsg
import gencodeutil


def to_jsonable(obj):
    return gencodeutil.to_jsonable(obj, _name_mappings)


def from_jsonable(return_type, obj):
    return gencodeutil.from_jsonable(return_type, obj, _name_mappings)


_name_mappings = {
    mysvcmsg.BerEncoderOptions: gencodeutil.NameMapping({
        "BdeVersionConformance": "BdeVersionConformance", 
        "TraceLevel": "TraceLevel", 
        "DatetimeFractionalSecondPrecision": "DatetimeFractionalSecondPrecision", "EncodeEmptyArrays": "EncodeEmptyArrays", 
        "thing": "thing", 
        "color": "color", 
        "EncodeDateAndTimeTypesAsBinary": "EncodeDateAndTimeTypesAsBinary"
    }), 
    mysvcmsg.Color: gencodeutil.NameMapping({
        "BLUE": "BLUE", 
        "GREEN": "GREEN", 
        "RED": "RED"
    }), 
    mysvcmsg.BerDecoderOptions: gencodeutil.NameMapping({
        "MaxDepth": "MaxDepth", 
        "TraceLevel": "TraceLevel", 
        "SkipUnknownElements": "SkipUnknownElements", 
        "MaxSequenceSize": "MaxSequenceSize"
    }), 
    mysvcmsg.SomeChoice: gencodeutil.NameMapping({
        "bar": "bar", 
        "foo": "foo"
    })
}
```

Implementation Modules
----------------------
The implementation of the procedures exported by [python.rkt](python.rkt)
spans multiple modules. Each is summarized below.

### types
[types.rkt](types.rkt) contains `struct` definitions representing nodes in
python code's abstract syntax tree. For example:
```scheme
(struct python-class
  (name        ; symbol
   bases       ; list of symbols
   docs        ; list of paragraphs (strings)
   statements) ; list of annotations, assignments, and/or pass
```
defines `python-class` as a `struct` representing a class definition in
python. A class has a name, a list of base classes, optional documentation,
and a list of statements that form the body of the class.

### name-map
[name-map.rkt](name-map.rkt) contains procedures used to convert between the
type and element names used in bdlat (in the schema) and those used in
python. Python code has certain naming conventions. For example, python
classes use `CapitalCamelCase`, while object attribute names use
`lower_case_with_underscores`, and enumeration values use
`UPPER_CASE_WITH_UNDERSCORES`. [name-map.rkt](name-map.rkt) enforces these
conventions and allows for its naming decisions to be overridden by the user.

### check-name
[check-name.rkt](check-name.rkt) contains procedures that check whether a
name (string or symbol) would be a valid identifier if it appeared in python
code as a name, such as a class or variable name. These procedures check not
only the lexical conventions of python but also its keywords and other
naming rules. This module also forms user-visible diagnostics when an
invalid name is encountered.

### convert
[convert.rkt](convert.rkt) contains procedures that convert `bdlat` type
definitions (such as `sequence` and `choice`) into python AST objects (such
as `python-class`). This module determines which python code constructs are
produced by the generator.

### list-util
[list-util.rkt](list-util.rkt) contains procedures that are shamefully missing
from the standard library. Admittedly, SRFI 67 defines lexicographic
comparisons, but they're a pain to use.

### render
[render.rkt](render.rkt) contains the procedure `render-python`, which takes
a python AST object (such as `python-module`) and produces a string
containing python source code suitable for use in a `python3.6` interpreter.

### gencodeutil
[gencodeutil.py](gencodeutil.py) and its unit test
[test_gencodeutil.py](test_gencodeutil.py) are a python module that is included
verbatim in the output of the code generator as the "private" module. The
contents of this module could instead be a library shared by all generated
code, but it's more convenient to include it separately with each generator
invocation.