#lang racket

(provide bdlat->name-map
         name-map->python-dict
         merge-overrides!
         capitalize-first)

(require (prefix-in bdlat: "../bdlat/bdlat.rkt") ; "attribute types" from SXML
         "types.rkt"                             ; python AST structs
         threading)                              ; ~> and ~>> macros

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
          ; Use the keys that refer to an attribute within a type.
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

(define (merge-overrides! name-map overrides)
  ; Apply overrides to name-map and return name-map modified in place. The
  ; structure of overrides is a little different from that of name-map, so
  ; convert each key/value pair. name-map looks like:
  ;
  ;     #hash(("MyClass" . MyClass)
  ;           (("MyClass" "someField") . 'some_field)
  ;           ...)
  ;
  ; while overrides looks like:
  ;
  ;     '((MyClass NewName)
  ;       ((MyClass sOmEField) some_field))
  (for-each
    (match-lambda [(list key value)
      (match key
        ; Note how ~a is used as a short alternative to symbol->string.
        [(? symbol? klass)
         (dict-set! name-map (~a klass) value)]
        [(list (? symbol? klass) (? symbol? attr))
         (dict-set! name-map (list (~a klass) (~a attr)) value)])])
    overrides)

  name-map)

(define split-name
  (let* ([clauses '("\\s+"                                       ; whitespace
                    "\\p{P}+"                                    ; punctuation
                    "(?<=[[:upper:]])(?=[[:upper:]][[:lower:]])" ; THISCase
                    "(?<=[[:lower:]])(?=[[:upper:]])")]          ; thisCase
         [pattern-string (string-join clauses "|")]
         [separator-regexp (pregexp pattern-string)])
    (lambda (name)
    ; Divide the specified string into a list of parts, where each part was
    ; separated from its adjacent parts by any of:
    ; - white space
    ; - punctuation
    ; - an upper case to lower case transition
    ; - a lower case to upper case transition
    ;
    ; For example:
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
    (string-join _ "")))

(define (bdlat-name->attribute-name bdlat-name)
  ; Python class attributes use underscore_separated_lower_casing.
  (~>> bdlat-name
    split-name
    (map string-downcase)
    (string-join _ "_")))

(define (bdlat-name->enumeration-value-name bdlat-name)
  ; Python enumeration values use UNDERSCORE_SEPARATED_UPPER_CASING.
  (~>> bdlat-name
    split-name
    (map string-upcase)
    (string-join _ "_")))

(define (extend-name-map name-map bdlat-type)
  ; Fill the specified hash table with mappings between the names of
  ; user-defined types and elements from the specified bdlat-type into
  ; python class and attribute names. Return the hash table, which is modified
  ; in place (unless there are no names to map, in which case it's returned
  ; unmodified).
  (let recur ([name-map name-map] ; the hash table we're populating
              [parent-name #f]    ; when we recur on a type's elements
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
         (hash-set! name-map (list parent-name name)
           (~> name bdlat-name->attribute-name string->symbol))]

        [(bdlat:enumeration-value name _ _)
         ; Enumeration value names are mapping from a key that is a
         ; (list class value).
         (hash-set! name-map (list parent-name name)
           (~> name bdlat-name->enumeration-value-name string->symbol))])

    ; Return the hash map, which has been (maybe) modified in place.
    name-map))

(define (bdlat->name-map types)
  ; Return a hash table mapping bdlat type, element, and enumeration value
  ; names to the corresponding python class name symbols and attribute name
  ; symbols. Each key is either a string indicating a type name or a pair of
  ; string indicating a type.attribute name, where the first in the pair is
  ; the type name and the second in the pair is the attribute name. The
  ; mapped value is always a single symbol, e.g.
  ;
  ;  "FOOThing" -> 'FooThing
  ;  ("FOOThing" . "highWaterMark") -> 'high_water_mark
  (let ([name-map (make-hash)])
    (for-each (lambda (type) (extend-name-map name-map type)) types)
    name-map))