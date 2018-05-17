#lang racket

(provide 
  ; Return a (list types-module util-module) of python-module objects.
  bdlat->python-modules 

  ; Write a python source code entity to a string.
  render-python

  ; values describing parts of python code
  (struct-out python-module)      (struct-out python-import)
  (struct-out python-class)       (struct-out python-annotation)
  (struct-out python-assignment)  (struct-out python-def)
  (struct-out python-invoke)      (struct-out python-dict))

(require (prefix-in bdlat: "../bdlat/bdlat.rkt") ; "attribute types" from SXML
         threading                               ; ~> and ~>> macros
         srfi/1                                  ; list procedures (e.g. any)
         scribble/text/wrap)                     ; (wrap-line text num-chars)

; TODO: For use when developing only.
(define (TODO)
  (error "You've encountered something that is not yet implemented."))

(struct python-module
  (description ; string
   docs        ; list of paragraphs (strings)
   imports     ; list of python-import
   statements) ; list of any of python-class, python-assignment, etc.
  #:transparent) 

(struct python-import
  (from-module ; symbol
   symbols)    ; a list of symbols or a single symbol
  #:transparent) 

(struct python-class
  (name        ; symbol
   bases       ; list of symbols
   docs        ; list of paragraphs (strings)
   statements) ; list of annotations, assignments, and/or pass
  #:transparent) 

(struct python-annotation
  (attribute ; symbol
   type      ; string or list of symbol/string
   docs      ; list of paragraphs
   default)  ; default value ('#:omit to ignore)
  #:transparent) 

(struct python-assignment
  (lhs   ; symbol
   rhs   ; value
   docs) ; list of paragraphs
  #:transparent) 

(struct python-pass
  () ; no fields
  #:transparent)

(struct python-def
  (name  ; symbol
   args  ; list of either symbol or pair (symbol, value)
   body) ; list of statements
  #:transparent) 

(struct python-invoke
  (name  ; symbol or list of symbol
   args) ; list of either value or pair (symbol, value)
  #:transparent) 

(struct python-dict
  (items) ; list of pair (key, value)
  #:transparent) 

(struct python-return
  (expression) ; some value or invocation
  #:transparent)

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
  ; specified as matching-base.
  (let recur ([outer-type bdlat-type])
    (match outer-type
        [(bdlat:sequence _ _ elements) (any recur elements)]
        [(bdlat:choice _ _ elements)   (any recur elements)]
        [(bdlat:element _ type _ _)    (recur type)]
        [(bdlat:nullable type)         (recur type)]
        [(bdlat:array type)            (recur type)]
        [(bdlat:basic type)            (equal? type matching-case)]
        [_                             #f])))

(define (bdlat->imports types)
  ; Deduce from the specified bdlat types which python modules a module
  ; defining those types must import.
  ; e.g. if there are any "sequence" types, then NamedTuple will have to be
  ; imported from the typing module. Note that bdlat->built-in also contains
  ; information about which bdlat basic types map to python types, so if
  ; either procedure is modified, the other might need to be updated as well.

  (define (maybe-import predicate import-args)
    ; If the predicate is true for any of the types, return
    ; (python-import ...). Otherwise return the empty list. This is used
    ; below to construct a list of imports.
    (if (any predicate types)
      (list (apply python-import import-args))
      '()))

  (append
    (maybe-import (lambda (type) (contains-basic-type? type "date")) 
      '(datetime date))
    (maybe-import (lambda (type) (contains-basic-type? type "time")) 
      '(datetime time))
    (maybe-import (lambda (type) (contains-basic-type? type "dateTime")) 
      '(datetime datetime))
    (maybe-import (lambda (type) (contains-basic-type? type "duration")) 
      '(datetime timedelta))
    (maybe-import bdlat:enumeration? '(enum Enum))
    (maybe-import bdlat:choice? '(namedunion NamedUnion))
    (maybe-import contains-array? '(typing List))
    (maybe-import bdlat:sequence? '(typing NamedTuple))
    (maybe-import contains-nullable? '(typing Optional))))

(define (join strings [separator ""])
  ; string-join, but with "" as the default separator instead of " ".
  (string-join strings separator))

(define split-name
  (let* ([clauses '("\\s+"                                       ; whitespace
                    "\\p{P}+"                                    ; punctuation
                    "(?<=[[:upper:]])(?=[[:upper:]][[:lower:]])" ; THISCase
                    "(?<=[[:lower:]])(?=[[:upper:]])")]          ; thisCase
         [pattern-string (join clauses "|")]
         [separator-regexp (pregexp pattern-string)])
    (lambda (name)
    ; Divide the specified string into a list of parts, where each part was
    ; separated from its adjacent parts by any of:
    ; - white space
    ; - punctuation
    ; - an upper case to lower case transition
    ; - a lower case to upper case transition
    ;
    ; So, for example:
    ; "IANATimeZone" -> ("IANA" "Time" "Zone")
    ; "wakka/wakka.txt" -> ("wakka" "wakka" "txt")
    ; "this_-oneIS   contrived-true" -> ("this" "one" "IS" "contrived" "true")
    ; "THISIsAHARDOne" -> ("THIS" "Is" "AHARD" "One")
    ; "BSaaS" -> ("B" "Saa" "S") 
      (regexp-split separator-regexp name))))

(define (capitalize-first text)
  ; "hello" -> "Hello"
  ; "hello there" -> "Hello there"
  ; "12345" -> "12345"
  (match (string->list text)
    [(cons first-char others)
     (list->string (cons (char-upcase first-char) others))]
    [_ text]))

(define (bdlat-name->class-name bdlat-name)
  ; Python classes use CapitalizedCamelCasing.
  (~>> bdlat-name
    split-name 
    (map string-downcase) 
    (map capitalize-first) 
    join))

(define (bdlat-name->attribute-name bdlat-name)
  ; Python class attributes use underscore_separated_lower_casing.
  (~>> bdlat-name
    split-name
    (map string-downcase) 
    (join _ "_")))

(define (bdlat-name->enumeration-value-name bdlat-name)
  ; Python enumeration values use UNDERSCORE_SEPARATED_UPPER_CASING.
  (~>> bdlat-name
    split-name 
    (map string-upcase) 
    (join _ "_")))

(define (extend-name-map name-map bdlat-type)
  ; Fill the specified hash table with mappings between the names of
  ; user-defined types and elements from the specified bdlat-type into
  ; python class and attribute names. Return the hash table, which is modified
  ; in place (unless there are no names to map, in which case it's returned
  ; unmodified).
  (let recur ([name-map name-map] ; the hash table we're populating
              [class-name #f]     ; when we recur on a type's elements
              [item bdlat-type])  ; the bdlat struct we're inspecting
    (match item
        [(bdlat:sequence name _ elements)
         ; Map the sequence name as a class name and then recur on each of its
         ; elements to map their names.
         (hash-set! name-map name 
           (~> name bdlat-name->class-name string->symbol))
         (for-each (lambda (elem) (recur name-map name elem)) elements)]

        [(bdlat:choice name _ elements)   
         ; Map the choice name as a class name and then recur on each of its
         ; elements to map their names.
         (hash-set! name-map name 
           (~> name bdlat-name->class-name string->symbol))
         (for-each (lambda (elem) (recur name-map name elem)) elements)]

        [(bdlat:enumeration name _ values)
         ; Map the enumeration name as a class name and then recur on each of
         ; its values to map their names.
         (hash-set! name-map name 
           (~> name bdlat-name->class-name string->symbol))
         (for-each (lambda (value) (recur name-map name value)) values)]

        [(bdlat:element name type _ _)
         ; Element names are mapped from a key that is a (list class element).
         (hash-set! name-map (list class-name name)
           (~> name bdlat-name->attribute-name string->symbol))]

        [(bdlat:enumeration-value name _ _)
         ; Enumeration value names are mapping from a key that is a
         ; (list class value).
         (hash-set! name-map (list class-name name)
           (~> name bdlat-name->enumeration-value-name string->symbol))])
         
    ; Return the hash map, which has been (maybe) modified in place.
    name-map))

(define (bdlat->name-map types)
  ; Return a hash table mapping bdlat type, element, and enumeration value
  ; names to the corresponding python class name symbols and attribute name
  ; symbols. Each key is either a string indicating a type name or a pair of
  ; string indicating a type.attribute name, where the first in the pair is
  ; the class name and the second in the pair is the attribute name. The
  ; mapped value is always a single symbol, e.g.
  ;
  ;  "FooThing" -> 'FooThing
  ;  ("FooThing" . "highWaterMark") -> 'high_water_mark
  (let ([name-map (make-hash)])
    (for-each (lambda (type) (extend-name-map name-map type)) types)
    name-map))

(define *default-types-module-description*
  "Provide typed attribute classes.")

(define *default-types-module-docs*
  `("This module provides typed attribute classes generated from a schema."
    ,(join '("Instances of the types defined in this module are "
                    "immutable, and may be converted to and from "
                    "JSON-compatible objects using the similarly-named "
                    "utilities module that is dual to this module."))))

(define (capitalize str)
  (match (string->list str)
    [(cons first-letter the-rest) 
     (list->string (cons (char-upcase first-letter) the-rest))]
    [_
     str]))

(define (bdlat->default default py-type)
  (if (equal? default '#:omit)
    ; No default was specified. Apply type-specific policies.
    (match py-type
      [(list 'List _)     '|[]|]  ; lists always default to empty
      [(list 'Optional _) 'None]  ; optionals always default to None
      [_                  default])
    ; A default was specified. Unless it's actually a string type, convert
    ; it into a symbol. Also, handle booleans properly (python capitalizes
    ; its boolean literals).
    (match py-type
      ['str                   default] ; keep as a string
      [(list 'Optional 'str)  default] ; keep as a string
      ['bool                  (~> default capitalize string->symbol)]
      [(list 'Optional 'bool) (~> default capitalize string->symbol)]
      [_                      (string->symbol default)])))

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
    [("duration") 'timedelta]))

(define (bdlat->type-name type name-map)
  (match type
    ; Lookup the type name, but output a string instead of a symbol, so that
    ; when the python code is rendered, it's a "forward reference."
    [(? string? name) 
     (~>> name (hash-ref name-map) symbol->string)]

    ; A nullable type maps to ('Optional ...) where the "..." is determined by
    ; recursion.
    [(bdlat:nullable name)
     `(Optional ,(bdlat->type-name name name-map))]

    ; An array type is handled simlarly to a nullable, but using 'List instead
    ; of 'Optional.
    [(bdlat:array name)
     `(List ,(bdlat->type-name name name-map))]

    ; Basic types get mapped to python built-ins.
    [(bdlat:basic name) (bdlat->built-in name)]))

(define (element->annotation element parent-name name-map)
  ; parent-name is the bdlat name of the class that contains element.
  (match element
    [(bdlat:element name type docs default)
     (let ([py-type (bdlat->type-name type name-map)])
        (python-annotation
          (hash-ref name-map (list parent-name name)) ; attribute (name)
          py-type
          docs
          (bdlat->default default py-type)))]))       ; default value

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

(define (python-class-by-category 
           base-class         ; e.g. 'NamedTuple
           bdlat-name         ; e.g. "MyType"
           name-map           ; populated earlier
           type-docs          ; list of paragraphs
           member-transformer ; procedure that maps a member to a statement
           members)           ; list of bdlat:element or list
                              ; of bdlat:enumeration-value
  ; Return a python-class modeling a bdlat sequence, a bdlat choice, or a
  ; bdlat enumeration, depending on the specified base-class and the specified
  ; statement-transformer.
  (python-class 
    (hash-ref name-map bdlat-name) ; class name
    (list base-class)              ; base classes (there's only one)
    type-docs
    ; If the class has no members, then it must contain at least one
    ; statement, so let it be a "pass" statement. If it has members,
    ; then transform them into statements using member-transformer.
    (if (empty? members)
      (list (python-pass))
      (map (lambda (elem) (member-transformer elem bdlat-name name-map))
          members))))

(define (bdlat->class type name-map)
  ; Return a python-class translated from the specified bdlat type. Use the
  ; specified hash table to map bdlat identifiers into python identifiers.
  (match type
    [(bdlat:sequence name docs elements)
     (python-class-by-category
       'NamedTuple name name-map docs element->annotation elements)]

    [(bdlat:choice name docs elements)
     ; Choice types derive from NamedUnion _except_ when they're empty,
     ; in which case they have to derive from NamedTuple, because an
     ; empty NamedUnion doesn't make any sense.
     (let ([base-class (if (empty? elements)
                         'NamedTuple
                         'NamedUnion)])
       (python-class-by-category
         'NamedUnion name name-map docs element->annotation elements))]

    [(bdlat:enumeration name docs values)
     (python-class-by-category
       'Enum name name-map docs enumeration-value->assignment values)]))

(define (bdlat->types-module types name-map description docs)
  (python-module
    description
    docs
    (bdlat->imports types)
    (map (lambda (type) (bdlat->class type name-map)) types)))

(define (hash-value-prepend! table key value)
  ; Prepend the specified value to the list at the specified key in the
  ; specified table. If the key is not in the table, first add an empty list
  ; at the key.
  (hash-set! table key (cons value (hash-ref table key '()))))

(define (name-map->python-dict name-map types-module-name)
  ; Return a python-dict of name mappings suitable for inclusion in the util
  ; module to be produced.
  (let ([by-type (make-hash)])
    ; Build up by-type :: {'type: '(("py_attr" . "bdlatAttr") ...)}.
    (hash-for-each name-map
      (lambda (key value)
        (match key
          [(list type bdlat-attribute)
           (hash-value-prepend! 
             by-type 
             (hash-ref name-map type) 
             (cons (symbol->string value) bdlat-attribute))]
          ; Ignore the keys that are just class names.
          [_ (void)])))

    ; Build up the dict using by-type.
    (python-dict
      (hash-map 
        by-type
        (lambda (key pairs)
          (cons
            ; the outer dict key, e.g. messages.Type
            (string->symbol (~a types-module-name "." key))
            ; the outer dict's value, e.g. gencodeutil.NameMapping({...})
            (python-invoke 
              'gencodeutil.NameMapping 
              (list (python-dict pairs)))))))))

(define (util-module types-module-name name-map)
  (python-module
    ; description
    (~a "Provide codecs for types defined in " types-module-name ".")
    ; documentation
    '() ; TODO
    ; imports
    (list (python-import (string->symbol types-module-name) '())
          (python-import 'gencodeutil '()))
    ; statements (body)
    (list
      ; def to_json ...
      (python-def 'to_json '(obj)
        (list (python-return
          (python-invoke 'gencodeutil.to_json '(obj _name_mappings)))))
      ; def from_json ...
      (python-def 'from_json '(return_type obj)
        (list (python-return
          (python-invoke 
            'gencodeutil.from_json 
            '(return_type obj _name_mappings)))))
      ; _name_mappings = { ...
      (python-assignment
        '_name_mappings                                    ; lhs
        (name-map->python-dict name-map types-module-name) ; rhs
        '()))))                                            ; docs


(define (bdlat->python-modules types 
                               types-module-name
                               [description *default-types-module-description*]
                               [docs *default-types-module-docs*])
  (let ([name-map (bdlat->name-map types)])
    (list
      ; the types module
      (bdlat->types-module
        types
        name-map
        description
        docs)
      ; the util module
      (util-module types-module-name name-map))))

(define (csv list-of-symbols indent-level indent-spaces)
  ; Return "foo, bar, baz" given '(foo bar baz). This operation is performed
  ; a few times within render-python.
  (~> list-of-symbols
      (map (lambda (form) (render-python form indent-level indent-spaces)) _)
      (join _ ", ")))

(define (render-python form [indent-level 0] [indent-spaces 4])
  (let* ([INDENT   (make-string (* indent-level indent-spaces) #\space)]
         [TRIPQ "\"\"\""] ; triple quote
         ; Recurse into this procedure, preserving auxiliary arguments.
         [recur (lambda (form [indent-level indent-level]) 
                  (render-python form indent-level indent-spaces))]
         ; Recurse into this procedure with indent-level incremented.
         [recur+1 (lambda (form) (recur form (+ indent-level 1)))])
    (match form
      [(python-module description docs imports statements)
       ; """This is the description.
       ;
       ; documentation...
       ; """
       ;
       ; ... imports ...
       ;
       ; ... statements ...
       (~a "\n" INDENT TRIPQ description "\n"
         (if (empty? docs)
           ""
           (~a "\n" (join docs (~a "\n\n" INDENT)) "\n"))
         INDENT TRIPQ "\n\n\n"
         ; imports
         (join (map recur imports))
         "\n\n"
         ; statements (classes, functions, globals, etc.)
         (join (map recur statements) "\n\n"))]

      [(python-import from-module names)
       ; can be one of
       ;     import something
       ; or
       ;     from something import thing
       ; or
       ;     from something import thing1, thing2, thing3
       (cond 
         [(null? names)
           (~a INDENT "import " from-module "\n")]
         [(not (list? names))
           (~a INDENT "from " from-module " import " names "\n")]
         [else
           (join (map (lambda (name) 
                                (~a INDENT "from " from-module " import " name)) 
                            names) 
             "\n")])]
      
      [(python-class name bases docs statements)
       ; class Name(Base1, Base2):
       ;     """documentation blah blah
       ;     """
       ;     ...
       (~a INDENT "class " name
         (let ([bases-text (csv bases indent-level indent-spaces)])
           (if (= (string-length bases-text) 0) 
             ""
             (~a "(" bases-text ")")))
         ":\n"
         ; documentation
         (if (empty? docs) 
           ""
           (let ([tab (make-string indent-spaces #\space)])
             (~a INDENT tab TRIPQ (join docs (~a "\n\n" INDENT tab)) 
               "\n" INDENT tab TRIPQ "\n")))
         ; statements
         (join (map recur+1 statements)))]

      [(python-annotation attribute type docs default)
       ; # docs...
       ; attribute : type = default
       (~a 
         ; the docs
         (if (empty? docs)
           ""
           (let ([margin (~a INDENT "# ")])
             (~a (join 
                   (map (lambda (doc) (~a margin doc)) docs)
                   "\n")
                "\n")))
         ; the attribute name
         INDENT attribute
         ; the type name
         (if (equal? type '#:omit)
           ""
           (~a " : " 
             (if (list? type)
               ; If type is a list, then it's something like Optional["Foo"]
               ; or Union[str, int] (though the latter won't happen).
               (~a (first type) "["
                 (join (map recur (rest type)) ", ") 
                 "]")
               ; If type is not a list, then just print it.
               (recur type))))
         ; the default (assigned) value
         (if (equal? default '#:omit)
           ""
           (~a " = " (recur default)))
         "\n")]

      [(python-assignment lhs rhs docs)
       ; An assignment is an annotation whose type is omitted.
       (recur (python-annotation lhs '#:omit docs rhs))]

      [(python-pass)
       (~a INDENT "pass\n")]

      [(python-def name args body)
       ; def name(arg1, arg2):
       ;     body...
       (~a INDENT "def " name "(" (csv args indent-level indent-spaces) "):\n"
         (join (map recur+1 body))
         "\n")]

      [(python-invoke name args)
       (~a name "(" (csv args indent-level indent-spaces) ")")]

      [(python-dict items)
       ; {key1: value1, ...}
       (~a "{"
         (join
           ; map each (key . value) pair to "key: value"
           (map
             (match-lambda [(cons key value)
               (~a (recur key) ": " (recur value))])
             items)
           ", ")
         "}")]

      [(python-return expression)
       (~a INDENT "return " (recur expression))]

      [(? symbol? value)
       ; Symbols are here notable in that they're printed with ~a, not ~s.
       ; I want the spelling of the symbol to be literal in the python
       ; source code, as opposed to escaped as a symbol, e.g. [] not |[]|.
       (~a value)]

      [(? string? value)
       ; ~s so that it's printed quoted and escaped.
       (~s value)]

      [(? number? value)
       (~a value)])))