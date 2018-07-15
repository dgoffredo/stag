#lang racket

(provide bdlat->python-modules)

(require (prefix-in bdlat: "../bdlat/bdlat.rkt") ; "attribute types" from SXML
         "types.rkt"                             ; python AST structs
         "name-map.rkt"                          ; schema names -> python names
         "check-name.rkt"                        ; valid python identifiers
         "readers.rkt"                           ; include/string macro
         threading                               ; ~> and ~>> macros
         srfi/1)                                 ; list procedures (e.g. any)

(define (contains-array? bdlat-type)
  ; Return whether the specified bdlat-type contains an array; i.e. whether
  ; it's either a sequence with an array-typed element or a choice with an
  ; array-typed element.
  (match-type-class bdlat-type contains-array? bdlat:array bdlat:nullable))

(define (contains-nullable? bdlat-type)
  ; Return whether the specified bdlat-type contains an nullable; i.e. whether
  ; it's either a sequence with an nullable-typed element or a choice with an
  ; nullable-typed element.
  (match-type-class bdlat-type contains-nullable? bdlat:nullable bdlat:array))

(define-syntax-rule (match-type-class argument recur matching-case other-case)
  ; Generate code that is the shared body between contains-array? and
  ; contains-nullable?. The matching-case is the type class that we're
  ; looking for (either bdlat:array or bdlat:nullable), while other-case
  ; is the one we're not looking for (e.g. bdlat:nullable or bdlat:array).
  ; recur is the name of the procedure in which this macro is being used; the
  ; idea is to define a recursive procedure. argument is the initial bdlat
  ; type on which to match.
  (match argument
    [(bdlat:sequence _ _ elements) (any recur elements)]
    [(bdlat:choice _ _ elements)   (any recur elements)]
    [(bdlat:element _ type _ _)    (recur type)]
    [(other-case type)             (recur type)]
    [(matching-case _)             #t]
    [_                             #f]))

(define (contains-basic-type? bdlat-type matching-case)
  ; Return whether the specified bdlat type contains within it the basic type
  ; specified as matching-case.
  (let recur ([outer-type bdlat-type])
    (match outer-type
        [(bdlat:sequence _ _ elements) (any recur elements)]
        [(bdlat:choice _ _ elements)   (any recur elements)]
        [(bdlat:element _ type _ _)    (recur type)]
        [(bdlat:nullable type)         (recur type)]
        [(bdlat:array type)            (recur type)]
        [(bdlat:basic type)            (equal? type matching-case)]
        [_                             #f])))

(define (bdlat->imports types private-module-name)
  ; Deduce from the specified bdlat types which python modules a module
  ; defining those types must import.
  ; e.g. if there are any "sequence" types, then gencodeutil will have to be
  ; imported for the Sequence base class. Note that bdlat->built-in also
  ; contains information about which bdlat basic types map to python types, so
  ; if either procedure is modified, the other might need to be updated as
  ; well.
  ; Additionally, import the specicified private module aliased as
  ; "gencodeutil" for use elsewhere in the python module being generated.

  (define (maybe-import predicate . import-arg-lists)
    ; If the predicate is true for any of the types, return 
    ;     (set (python-import ...) ...)
    ; Otherwise return the empty set. This is used below to construct a list
    ; of imports.
    (if (any predicate types)
      (for/set ([import-args import-arg-lists])
        (apply python-import import-args))
      (set)))

  (define imports
    (set-union
      (set 
        (python-import-alias (string->symbol private-module-name)
                             'gencodeutil))
      (maybe-import (lambda (type) (contains-basic-type? type "date"))
        '(datetime date))
      (maybe-import (lambda (type) (contains-basic-type? type "time"))
        '(datetime time))
      (maybe-import (lambda (type) (contains-basic-type? type "dateTime"))
        '(datetime datetime))
      (maybe-import (lambda (type) (contains-basic-type? type "duration"))
        '(datetime timedelta))
      (maybe-import bdlat:enumeration? '(enum ()))     ; enum.Enum
      (maybe-import bdlat:choice? '(typing ()))        ; typing.Union
      (maybe-import contains-array? '(typing ()))      ; typing.List
      (maybe-import contains-nullable? '(typing ())))) ; typing.Optional

  ; Return a list of the import statements sorted by module name. This isn't
  ; PEP8 conformant, but what a pain that would be.
  (~> imports 
      set->list 
      (sort symbol<? 
        #:key (match-lambda [(python-import from _) from]
                            [(python-import-alias from _) from]))))

(define *default-types-module-description*
  "Provide typed attribute classes.")

(define *default-types-module-docs*
  `("This module provides typed attribute classes generated from a schema."
    ,(string-join '("Instances of the types defined in this module are "
                    "immutable, and may be converted to and from "
                    "JSON-compatible objects using the similarly-named "
                    "utilities module that is dual to this module.") "")))

(define (bdlat->default default py-type bdlat-type name-map)
  (if (equal? default '#:omit)
    ; No default was specified. Apply type-modifier-specific policies.
    (match py-type
      [(list 'typing.List _)     '|[]|]    ; lists always default to empty
      [(list 'typing.Optional _) 'None]    ; optionals always default to None
      [_                         default]) ; otherwise just keep '#:omit
    ; A default was specified. Leave strings alone, since they need to remain
    ; strings in order to be quoted in render-python. Capitalize booleans since
    ; that's how they are in python. Finally there are the "enum" and "other"
    ; cases explained more below.
    (match py-type
      [(or 'str (list 'typing.Optional 'str)) default] ; keep as a string
      [(or 'bool (list 'typing.Optional 'bool))                       
       (~> default capitalize-first string->symbol)]
      ; There are two remaining cases. Either py-type is an enum, and so we
      ; need to look up the attribute name corresponding to the default value,
      ; or it's not an enum (e.g. an int), in which case we can just turn the
      ; default into a symbol. We assume that the type is an enum if the
      ; bdlat-type is a key in the name-map. Default values for other types
      ; of user-defined types don't make sense, so it's a reasonable
      ; assumption. Also, an array cannot have a user-specified default.
      [_
       (let ([mapped-type? (lambda (type) 
                             (and (string? type) 
                                  (hash-has-key? name-map type)))])
         (match bdlat-type
           [(or (bdlat:nullable (? mapped-type? enum-type))
                (? mapped-type? enum-type))
            (string->symbol
              (~a py-type "." (hash-ref name-map (list enum-type default))))]

           [_ (string->symbol default)]))])))

(define (bdlat->built-in type)
  ; Note that bdlat->imports also contains information about which bdlat basic
  ; types map to python types, so if either procedure is modified, the other
  ; might need to be updated as well.
  (case type
    [("string" "token" "normalizedString") 'str]
    [("int" "byte" "integer" "long" "negativeInteger" "nonNegativeInteger"
      "nonPositiveInteger" "positiveInteger" "short" "unsignedLong"
      "unsignedInt" "unsignedShort" "unsignedByte") 'int]
    [("decimal" "float" "double") 'float]
    [("boolean") 'bool]
    [("base64Binary" "hexBinary") 'bytes]
    [("date") 'date]
    [("time") 'time]
    [("dateTime") 'datetime]
    [("duration") 'timedelta]
    [else (error (~a "Unsupported built-in type: " type))]))

(define (bdlat->type-name type name-map)
  (match type
    ; Lookup the type name, but output a string instead of a symbol, so that
    ; when the python code is rendered, it's a "forward reference."
    [(? string? name)
     (~>> name (hash-ref name-map) symbol->string)]

    ; A nullable type maps to ('typing.Optional ...) where the "..." is
    ; determined by recursion.
    [(bdlat:nullable name)
     `(typing.Optional ,(bdlat->type-name name name-map))]

    ; An array type is handled simlarly to a nullable, but using 'typing.List
    ; instead of 'typing.Optional.
    [(bdlat:array name)
     `(typing.List ,(bdlat->type-name name name-map))]

    ; Basic types get mapped to python built-ins.
    [(bdlat:basic name) (bdlat->built-in name)]))

(define (element->annotation element parent-name name-map)
  ; parent-name is the bdlat name of the class that contains element.
  (match element
    [(bdlat:element name type docs default)
     (let ([py-type (bdlat->type-name type name-map)])
        (python-annotation
          (hash-ref name-map (list parent-name name)) ; attribute name
          py-type
          docs
          ; default value
          (bdlat->default default py-type type name-map)))]))

(define (enumeration-value->assignment value parent-name name-map)
  ; parent-name is the bdlat name of the class that contains the enum value.
  (match value
    [(bdlat:enumeration-value name docs id)
     ; - name needs to be looked up in name-map
     ; - id is an integral constant
     (python-assignment
       (hash-ref name-map (list parent-name name)) ; left hand side
       id                                          ; right hand side
       docs)]))

(define (bdlat->class type name-map)
  ; Return a python-class translated from the specified bdlat type. Use the
  ; specified hash table to map bdlat identifiers into python identifiers.
  (match type
    [(bdlat:sequence name docs elements)
     (python-class (hash-ref name-map name) ; name
       '(gencodeutil.Sequence)              ; base classes
       docs
       ; Empty classes need some statement within their body, so if there
       ; are no elements, the body is just a "pass" statement. If there are
       ; elements, then generate annotations and __init__.
       (if (empty? elements)
         (list (python-pass))
         ; otherwise, the body is:
         (let ([annotations 
                (map (lambda (element) 
                       (element->annotation element name name-map))
                  elements)])
           `(,@annotations ; attribute annotations
             ; def __init__ ...
             ,(python-def '__init__
                ; __init__ args: self, *, and the annotations (lucky reuse)
                ; except without the documentation (to spare the newlines).
                `(self * ,@(map annotation->argument annotations))
                'None ; return type
                '() ; docs
                ; __init__ body: forward all args to the base class
                (list (python-invoke 'gencodeutil.Sequence.__init__
                  (list (python-invoke '**locals '())))))))))]

    [(bdlat:choice name docs elements)
     ; While an empty choice is nonsensical, it exists in the wild. So, make
     ; a choice only if there are elements. Otherwise make an empty sequence.
     (if (empty? elements)
       (bdlat->class (bdlat:sequence name docs elements) name-map) 
       (python-class (hash-ref name-map name)  ; name
         '(gencodeutil.Choice)                 ; base classes
         docs
         ; body of the class
         (let ([annotations 
                (map (lambda (element) 
                       (element->annotation element name name-map))
                  elements)])
           `(,@annotations ; attribute annotations, e.g. foo : str = 'default'
             ; def __init__ ...
             ,(python-def '__init__
               ; __init__ args: self, **kwarg : typing.Union[...
               ;
               ; where the arguments to typing.Union are distinct (they don't
               ; have to be, since python knows that anyway, but it looks
               ; nicer if you don't have str, str, str, str, ...). Also, if
               ; there is only one type among the annotations, don't bother
               ; with a typing.Union -- just use the one type.
               (let* ([types (~>> annotations
                               (map python-annotation-type)
                               remove-duplicates)]
                      [type (if (= 1 (length types))
                              (first types)
                              (cons 'typing.Union types))])
                 (list 'self (python-argument '**kwarg type '#:omit)))
               'None ; return type
               '() ; docs
               ; __init__ body: forward all kwargs to the base class
               (list (python-invoke 'gencodeutil.Choice.__init__
                 '(self **kwarg))))))))]

    [(bdlat:enumeration name docs values)
     (python-class (hash-ref name-map name) ; name
       '(enum.Enum)                         ; base classes
       docs
       (if (empty? values)                  ; body
         (list (python-pass))
         ; foo = 0
         ; bar = 1
         ; etc.
         (map (lambda (value)
                (enumeration-value->assignment value name name-map))
           values)))]))

(define (bdlat->types-module 
          types name-map private-module-name description docs)
  (python-module
    description
    docs
    (bdlat->imports types private-module-name)
    ; The body of the module is a list of class definitions derived from types.
    (map 
      (lambda (type) (bdlat->class type name-map))
      ; sort the types: enum < non-enum (because enum values can appear as
      ; attribute defaults, so their definitions have to be first).
      (sort 
        types 
        (match-lambda* 
          [(list (struct bdlat:enumeration _)
                 (not (struct bdlat:enumeration _)))
            #t]
          [_ #f])))))

(define (util-module types-module-name private-module-name name-map)
  (python-module
    ; description
    (~a "Provide codecs for types defined in " types-module-name ".")
    ; documentation
    '() ; TODO: usage examples
    ; imports
    (list (python-import (string->symbol types-module-name) '())
          (python-import-alias 
            (string->symbol private-module-name) 'gencodeutil)
          (python-import 'typing '()))
    ; statements (body)
    (list
      ; def to_jsonable ...
      (python-def 'to_jsonable
        (list (python-argument 'obj 'typing.Any '#:omit)) ; arguments
        'typing.Any ; return type
        ; docs
        (list
          (string-join '("Return a composition of python objects (such as "
                         "'dict', 'list' and 'str') based on the specified "
                         "'obj' such that the result is suitable for "
                         "serialization to JSON by the 'json' module.")
            ""))
        ; body
        (list (python-return
          (python-invoke 'gencodeutil.to_jsonable '(obj _name_mappings)))))
      ; def from_jsonable ...
      (python-def 'from_jsonable 
        ; arguments
        (list (python-argument 'return_type 'typing.Any '#:omit)
              (python-argument 'obj         'typing.Any '#:omit))
        'typing.Any ; function return type
        ; docs
        (list
          (string-join
            '("Return an instance of the specified 'return_type' that has "
              "been constructed based on the specified 'obj', which is a "
              "composition of python objects as would result from "
              "JSON deserialization by the 'json' module.")
            ""))
        ; body
        (list (python-return
          (python-invoke
            'gencodeutil.from_jsonable
            '(return_type obj _name_mappings _class_by_name)))))
      ; _name_mappings = { ...
      (python-assignment
        '_name_mappings                                    ; lhs
        (name-map->python-dict name-map types-module-name) ; rhs
        '())                                               ; docs
      ; _class_by_name = { klass.__name__: klass for klass in _name_mappings }
      (python-assignment
        '_class_by_name            ; lhs
        (python-dict-comprehension ; rhs
          'klass.__name__  ; key
          'klass           ; value
          '(klass)         ; variables
          '_name_mappings) ; iterator
        '()))))                    ; docs

(define (private-module)
  (python-rendered-module (include/string "gencodeutil.py")))

(define (bdlat->python-modules
          types
          types-module-name
          private-module-name
          #:overrides [overrides '()]
          #:description [description *default-types-module-description*]
          #:docs [docs *default-types-module-docs*])
  (let ([name-map 
         (~> types 
           bdlat->name-map (merge-overrides! overrides) check-name-map)])
    (list
      ; the types module
      (bdlat->types-module
        types
        name-map
        private-module-name
        description
        docs)
      ; the util module
      (util-module types-module-name private-module-name name-map)
      ; the private module
      (private-module))))