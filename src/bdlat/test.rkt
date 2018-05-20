#lang racket

(require rackunit         ; test-suite, test-case, check-..., etc.
         rackunit/text-ui ; run-tests
         "private.rkt")   ; the module under test

(define *example-doc-string*
"Here is some example documentation.

It contains paragraphs of text separated by blank lines.
There might be other line breaks, and those are removed.
As is all duplicate    whitespace.

As said, blank lines are treated as paragraph delimiters.")

(define *example-doc-list* '(
"Here is some example documentation."
"It contains paragraphs of text separated by blank lines. There might be other line breaks, and those are removed. As is all duplicate whitespace."
"As said, blank lines are treated as paragraph delimiters."))

(define (check-conversion 
           input-sxml 
           expected-bdlat 
           #:converter [converter sxml->bdlat])
  ; Check that the optionally specified conversion procedure maps the
  ; specified SXML tree into the specified bdlat object, which is one of
  ; (sequence ..), (element ...), etc.
  (check-equal? (converter input-sxml) expected-bdlat))

(define (check-element-correspondence sxml-tag bdlat-type)
  ; Check that a simple xs:complexType is mapped to the expected bdlat type
  ; by sxml->bdlat. sxml-tag is the type of xs:complexType (either 'xs:sequence
  ; or 'xs:choice), while bdlat-type is the corresponding bdlat struct
  ; constructor (either sequence or choice).
  (check-conversion
    `(xs:complexType (@ (name "SomeSequence"))
       (,sxml-tag
         (xs:element (@ (type "Foo") (name "foo")))
         (xs:element (@ (type "Bar") (name "bar")))))

    (bdlat-type "SomeSequence" '()
      `(,(element "foo" "Foo" '() '#:omit)
        ,(element "bar" "Bar" '() '#:omit)))))

(define (check-type-category category-constructor occurences)
  ; Check that each `(,min-occurs ,max-occurs) in occurences, when present in
  ; an xs:element, gets mapped to a bdlat element having the specified type
  ; category (one of array or nullable).
  (for-each
    (match-lambda [(list min-occurs max-occurs)
      (check-conversion
        `(xs:element (@ (name "whatever") 
                        (type "Whatever") 
                        (minOccurs ,min-occurs) 
                        (maxOccurs ,max-occurs)))
        (element "whatever" (category-constructor "Whatever") '() '#:omit)
      #:converter sxml->element)])
    occurences))

(define (check-enumeration-order input-id-attributes expected-id-sequence)
  ; Check that an SXML enumeration type whose elements contain the specified
  ; ext:id attribute values (where #f indicates that the attribute is omitted)
  ; produces a bdlat enumeration whose values have the specified expected IDs.
  (check-conversion
    ; input SXML
    `(xs:simpleType (@ (name "Foo"))
       (xs:restriction (@ (base "xs:string"))
         ,@(for/list ([id input-id-attributes])
             `(xs:enumeration 
               (@ (value "same value!") ; arbitrary
                  ,@(if id
                      `((ext:id ,id)) ; note the necessity of the extra parens
                      '()))))))
    ; expected bdlat type
    (enumeration "Foo" '()
      (for/list ([id expected-id-sequence])
        (enumeration-value "same value!" '() id)))))

(define tests
  (test-suite
    "Tests for bdlat"

    (test-case
      "xs:sequence maps to a bdlat sequence with analogous elements"
      (check-element-correspondence 'xs:sequence sequence))

    (test-case
      "xs:choice maps to a bdlat choice with analogous elements"
      (check-element-correspondence 'xs:choice choice))

    (test-case
      "empty xs:sequence are supported (often used as a void type or tag type)"
      (check-conversion
        '(xs:complexType (@ (name "Void"))
           (xs:sequence))
  
        (sequence "Void" '() '())))

    (test-case
      "element types whose value begins with 'xs: yield \"basic\" types"
      (for-each
        (lambda (type)
          (check-conversion
            `(xs:element (@ (name "someElement") (type ,(~a "xs:" type))))
            (element "someElement" (basic type) '() '#:omit)
            #:converter sxml->element))
        '("string" "integer" "double" "dateTime" "chicken" "superman")))

    (test-case
      "element types whose value does not begin with 'xs: omit \"basic\""
      (for-each
        (lambda (type)
          (check-conversion
            `(xs:element (@ (name "someElement") (type ,type)))
            (element "someElement" type '() '#:omit)
            #:converter sxml->element))
        '("string" "integer" "double" "dateTime" "chicken" "superman")))

    (test-case
      "array-like element occurrences yield array types"
      (check-type-category
        array
        '(("0" "unbounded") ; canonical array spelling
          ("1" "unbounded") ; common, but not checked by generated code
          ("0" "140")       ; uncommon, but also supported, and not checked
          ("35" "1000")     ; silly, but supported
          ("1000" "35"))))  ; nonsense, but supported

    (test-case
      "nullable-like element occurences yield nullable types"
      (check-type-category
        nullable
        '(("0" "1")))) ; the only supported nullable spelling

    (test-case
      "ext:id overrides ordering within enumerations"
      (for ([data '(
              ; override everything
              (("0" "1" "2" "3" "4") ; attribute values
               (0 1 2 3 4))          ; expected resulting element IDs
              ; override nothing
              ((#f #f #f) ; #f means "don't use ext:id attribute"
               (0 1 2))
              ; override some things
              ((#f "7" #f #f "7") ; logically an error, but accepted here
               (0 7 2 3 7)))])
        (match data
          [(list input-id-attributes expected-id-sequence)
           (check-enumeration-order
             input-id-attributes
             expected-id-sequence)])))
    
    (test-case
      "SXML documentation annotations are parsed into lists of paragraphs"
      (for-each
        (match-lambda [(list converter input-sxml expected-bdlat)
          (check-conversion input-sxml expected-bdlat #:converter converter)])
        ; Each member of the following list is a list containing:
        ; - the conversion function to use in the check
        ; - the SXML tree to use as the input to the check
        ; - the bdlat object to expect the conversion function to produce

        (list 
          (list sxml->bdlat ; documentation above a sequence
            `(xs:complexType (@ (name "Irrelevant"))
              (xs:annotation (xs:documentation ,*example-doc-string*))
              (xs:sequence))
            (sequence "Irrelevant" *example-doc-list* '()))

          (list sxml->bdlat ; documentation above a choice
            `(xs:complexType (@ (name "Irrelevant"))
              (xs:annotation (xs:documentation ,*example-doc-string*))
              (xs:choice))
            (choice "Irrelevant" *example-doc-list* '()))

          (list sxml->element ; documentation inside of an element
            `(xs:element (@ (name "irrelevant") (type "Whatever"))
              (xs:annotation (xs:documentation ,*example-doc-string*)))
            (element "irrelevant" "Whatever" *example-doc-list* '#:omit))

          (list ; documentation inside of an enumeration value
                ; The conversion function needs to bind some index to
                ; sxml->enumeration-value. So, use zero.
            (lambda (sxml) (sxml->enumeration-value sxml 0))
            `(xs:enumeration (@ (value "whatever"))
              (xs:annotation (xs:documentation ,*example-doc-string*)))
            (enumeration-value "whatever" *example-doc-list* 0)))))

    (test-case
      "\"default\" attribute of an xs:element results in an element default"
      ; If there is a default, then it appears in the element.
      (check-conversion
        '(xs:element (@ (name "whatever") 
                        (type "Whatever") 
                        (default "default value")))
        (element "whatever" "Whatever" '() "default value")
        #:converter sxml->element)
        
      ; If there is not a default, then the "default" field is #:omit
      (check-conversion
        '(xs:element (@ (name "whatever") 
                        (type "Whatever")))
        (element "whatever" "Whatever" '() '#:omit)
        #:converter sxml->element))))

(module+ test
  (run-tests tests))