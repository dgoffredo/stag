python
======
This module provides data structures representing Python code abstract syntax tree (AST) elements and procedures for producing python code from bdlat types.

For example, this module can be used to transform the following list of bdlat types:

```scheme
(list 
  (sequence "BerDecoderOptions" 
    '("BER decoding options") 
    (list 
      (element "MaxDepth" (nullable (basic "int")) 
        '("maximum recursion depth") "32") 
      (element "SkipUnknownElements" (nullable (basic "boolean"))
        '("Option to skip unknown elements") "true") 
      (element "TraceLevel" (nullable (basic "int")) 
        '("trace (verbosity) level") "0") 
      (element "MaxSequenceSize" (nullable (basic "int")) 
        '("maximum sequence size") "8388608"))) 
  (sequence "BerEncoderOptions" 
    '("BER encoding options") 
    (list 
      (element "TraceLevel" (nullable (basic "int")) 
        '("trace (verbosity) level") "0") 
      (element "BdeVersionConformance" (basic "int") 
        '("The largest BDE version that can..."
          "Documentation blah blah...") "10500") 
      (element "EncodeEmptyArrays" (basic "boolean") 
        '("This option allows users to control....") "true")
      (element "EncodeDateAndTimeTypesAsBinary" (basic "boolean") 
        '("This option allows users to...") "false") 
      (element "DatetimeFractionalSecondPrecision" (nullable (basic "int")) 
        '("This option controls....") "3")
      (element "color" "Color" '() '#:omit)
      (element "thing" "SomeChoice" '() '#:omit)))
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
     (python-annotation
      'SkipUnknownElements
      '(Optional bool)
      '("Option to skip unknown elements")
      'True)
     (python-annotation
      'TraceLevel
      '(Optional int)
      '("trace (verbosity) level")
      '|0|)
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
     (python-annotation
      'BdeVersionConformance
      'int
      '("The largest BDE version..."
        "Ideally, the BER encoder....")
      '|10500|)
     (python-annotation
      'EncodeEmptyArrays
      'bool
      '("This option allows users to control...")
      'True)
     (python-annotation
      'EncodeDateAndTimeTypesAsBinary
      'bool
      '("This option allows users to control...")
      'False)
     (python-annotation
      'DatetimeFractionalSecondPrecision
      '(Optional int)
      '("This option controls...")
      '|3|)
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
    'to_json
    '(obj)
    (list
     (python-return
      (python-invoke 'gencodeutil.to_json '(obj _name_mappings)))))
   (python-def
    'from_json
    '(return_type obj)
    (list
     (python-return
      (python-invoke
       'gencodeutil.from_json
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

and then into the following two Python modules:

```python
"""Provide typed attribute classes.

This module provides typed attribute classes generated from a schema.

Instances of the types defined in this module are immutable, and may be converted to and from JSON-compatible objects using the similarly-named utilities module that is dual to this module.
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
    # The largest BDE version that can be assumed of the corresponding decoder for the encoded message, expressed as 10000*majorVersion + 100*minorVersion + patchVersion (e.g. 1.5.0 is expressed as 10500).
    # 
    # Ideally, the BER encoder should be permitted to generate any BER that conforms to X.690 (Basic Encoding Rules) and X.694 (mapping of XSD to ASN.1). In practice, however, certain unimplemented features and missunderstandings of these standards have resulted in a decoder that cannot accept the full range of legal inputs. Even when the encoder and decoder are both upgraded to a richer subset of BER, the program receiving the encoded values may not have been recompiled with the latest version and, thus restricting the encoder to emit BER that can be understood by the decoder at the other end of the wire. If it is that the receiver has a more modern decoder, set this variable to a larger value to allow the encoder to produce BER that is richer and more standards conformant. The default should be increased only when old copies of the decoder are completely out of circulation.
    BdeVersionConformance : int = 10500
    # This option allows users to control if empty arrays are encoded. By default empty arrays are encoded as not encoding empty arrays is non-compliant with the BER encoding specification.
    EncodeEmptyArrays : bool = True
    # This option allows users to control if date and time types are encoded as binary integers. By default these types are encoded as strings in the ISO 8601 format.
    EncodeDateAndTimeTypesAsBinary : bool = False
    # This option controls the number of decimal places used for seconds when encoding 'Datetime' and 'DatetimeTz'.
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


def to_json(obj):
    return gencodeutil.to_json(obj, _name_mappings)


def from_json(return_type, obj):
    return gencodeutil.from_json(return_type, obj, _name_mappings)


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
