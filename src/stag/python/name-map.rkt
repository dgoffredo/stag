#lang racket

(provide bdlat->name-map
         name-map->python-dict
         merge-overrides!
         capitalize-first)

(require (prefix-in bdlat: "../bdlat.rkt") ; "attribute types" from SXML
         "types.rkt"                       ; python AST structs
         threading)                        ; ~> and ~>> macros

(define (hash-value-prepend! table key value)
  ; Prepend the specified value to the list at the specified key in the
  ; specified table. If the key is not in the table, first add an empty list
  ; at the key.
  (hash-set! table key (cons value (hash-ref table key '()))))

(define (name-map-by-class name-map)
  ; Return a hash table that is the specified hash table grouped by class name.
  ; 'name-map' has the following structure:
  ;
  ;     (hash 'someType 'SomeClass
  ;           '(someType someElement) 'some_attribute
  ;           ...)
  ;
  ; while the return value of this procedure would have the following
  ; structure:
  ;
  ;     (hash 'SomeClass '(("some_attribute" someElement) ...)
  ;           ...)
  (let ([by-class (make-hash)])
    (for ([(key value) name-map])
      (match key
        ; The key maps some Type.element to a python attribute name. Add a pair
        ; (attribute_name . elementName) to the list at the class name. If
        ; there's no entry yet, start with an empty list.
        [(list type element)
         (hash-update! by-class (hash-ref name-map type)
           (lambda (pairs)
             (cons (cons (symbol->string value) element)
                   pairs))
           '())]

        ; The key maps some type name to a class name. Make sure there's an
        ; entry for this class if there isn't. Start with an empty list.
        [type
         (hash-update! by-class (hash-ref name-map type) identity '())]))

    by-class))

(define (name-map->python-dict name-map types-module-name)
  ; Return a python-dict of name mappings suitable for inclusion in the util
  ; module to be produced, e.g.
  ;
  ;     { 
  ;         foosvcmsg.Foo: gencodeutil.NameMapping({
  ;             "attribute_name": "elementName"
  ;             ...
  ;         })
  ;         ...
  ;     }
  ;
  ; types-module-name must be a single symbol.
  (python-dict
    (for/list ([(key pairs) (name-map-by-class name-map)])
      (cons
        ; the outer dict key, e.g. messages.Type
        (string->symbol (~a types-module-name "." key))
        ; the outer dict's value, e.g. gencodeutil.NameMapping({...})
        (python-invoke
          'gencodeutil.NameMapping
          (list (python-dict pairs)))))))

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
  ;
  ; Raise an exception if any of the new names would be an invalid python
  ; class name or class attribute name. Raise an exception if overrides has
  ; duplicate keys.
  (let ([previous-overrides (make-hash)]) ; Keep track to check for duplicates.
    ; Loop over each override, applying it to name-map.
    (for ([key/value overrides])
      (match key/value
        [(list key value)
         ; If we've already seen key, raise an error.
         (let ([previous-value (hash-ref previous-overrides key #f)])
           (when previous-value
             (raise-user-error 
               (~a "The key " key " was already overridden with the value "
                 previous-value ". Cannot override " key " to " value ".")))

           ; Update name-map based on whether key is for a class or attribute.
           (match key
             ; overriding a class name
             [(? symbol? klass)
              (dict-set! name-map (symbol->string klass) value)]
     
             ; overriding the name of an attribute within a class
             [(list (? symbol? klass) (? symbol? attr))
              (dict-set! name-map 
                (list (symbol->string klass) (symbol->string attr))
                value)]

             ; otherwise, raise an error
             [_ (raise-user-error "TODO: helpful error message")])
                  
           ; Mark key as already seen.
           (hash-set! previous-overrides key value))]

          ; The "key" in an override entry is invalid. Raise an error.
          [_ (raise-user-error "TODO: informative error message")])))
  ; Return the updated mapping.
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
  ; user-defined types and elements from the specified bdlat-type into python
  ; class and attribute names. Return the hash table, which is modified in
  ; place (unless there are no names to map, in which case it's returned
  ; unmodified). Raise an exception if any of the names mapped to would be an
  ; invalid python class name or class attribute name.
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
  ;
  ; Raise an exception if any of the names mapped to would be an invalid python
  ; class name or class attribute name.
  (let ([name-map (make-hash)])
    (for-each (lambda (type) (extend-name-map name-map type)) types)
    name-map))