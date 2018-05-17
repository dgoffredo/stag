#lang racket

(provide
  ; function that converts an SXML s-expression into one of the types below
  sxml->bdlat

  ; function that finds all types defined in an SXML s-expression and returns
  ; a list of the resulting objects.
  sxml->types

  ; the types that compose to make a bdlat type
  (struct-out sequence)    (struct-out choice)            (struct-out element)
  (struct-out enumeration) (struct-out enumeration-value) (struct-out array)
  (struct-out nullable)    (struct-out basic))

(require sxml                           ; XML as s-expressions
         "../sxml-match/sxml-match.rkt" ; pattern matching SXML s-expressions
         threading)                     ; thrush combinator macros

; data types for composing BDE "attribute types"
; "Transparent" means fields are printed when an instance is printed.
; "docs" is always a list of strings, where each string is a paragraph.
(struct sequence          (name docs elements)     #:transparent)
(struct choice            (name docs elements)     #:transparent)
(struct element           (name type docs default) #:transparent)
(struct enumeration       (name docs values)       #:transparent)
(struct enumeration-value (name docs id)           #:transparent)
(struct array             (type)                   #:transparent)
(struct nullable          (type)                   #:transparent)
(struct basic             (type)                   #:transparent)

(define (collapse-whitespace text)
  ; Return a copy of text whose contiguous whitespaces have each been
  ; collapsed into a single space, and whose marginal whitespace has been
  ; removed.
  (string-trim (regexp-replace* #px"\\s+" text " ")))

(define (paragraphs text)
  ; Return a list of paragraphs derived from the specified text, where each
  ; paragraph has had its whitespace collapsed (see collapse-whitespace).
  (map collapse-whitespace (string-split text "\n\n")))

(define (sxml->docs node-list)
  ; Return as a list of paragraphs the documentation text of the single SXML
  ; node in node-list, or return #f. The reason this procedure takes a list of
  ; nodes rather than a single node is that the only way to match "zero or one
  ; of" in sxml-match is to match "zero or more of," and the resulting match
  ; is a list. It's then convenient to be able to pass the list directly to
  ; this function.
  (match node-list
    ; empty list: doesn't contain documentation
    ['() '()]
    ; non-empty: see whether it's documentation
    [(list body)
     (sxml-match body
       ; documentation
       [(xs:annotation (xs:documentation ,docs))
       (paragraphs docs)]
       ; not documentation
       [,otherwise '()])]))

(define (sxml->enumeration-value node index)
  (sxml-match node
    [(xs:enumeration (@ (value ,value)
                        (ext:id (,id index)))
                     ,maybe-docs ...)

     (enumeration-value 
       value 
       (sxml->docs maybe-docs) 
       ; If id comes from the XML, it's a string, whereas if it comes from
       ; index then it's a number. Make sure it's a number in both cases.
       (if (string? id) (string->number id) id))]

    [,otherwise (error 
      (format "Expected enumeration but got: ~.v" node))]))

(define (sxml->element node)
  (sxml-match node
    [(xs:element (@ (name ,name)
                    (type ,type)
                    (minOccurs [,minOccurs "1"])
                    (maxOccurs [,maxOccurs "1"])
                    (default [,default '#:omit]))
                 ,maybe-docs ...)

     (element name 
       (sxml->type type minOccurs maxOccurs)
       (sxml->docs maybe-docs) 
       default)]

    [,otherwise (error
      (format "Expected a sequence/choice element but got: ~.v" node))]))

(define (split-name xml-name)
  ; Return (list namespace local-name)
  (match (string-split xml-name ":")
    [(list namespace name) (list namespace name)]
    [(list name)           (list "" name)]))

(define (sxml->type type minOccurs maxOccurs)
  (match-let* ([(list namespace type-name)
                (split-name type)]

               [scalar-type ; whether user-defined or not (basic)
                (if (equal? namespace "xs") ; TODO "xs" is not enough.
                  (basic type-name)
                  type-name)])
      ; maxOccurs and minOccurs determine whether this is an array, nullable,
      ; or neither.
      (cond [(not (equal? maxOccurs "1"))
             (array scalar-type)]

            [(and (equal? minOccurs "0") (equal? maxOccurs "1"))
             (nullable scalar-type)]

            [(and (equal? minOccurs "1") (equal? maxOccurs "1"))
             scalar-type]

            [else (error 
              (format "Unsupported occurrence: minOccurs=~s maxOccures=~s" 
                      minOccurs maxOccurs))])))
           
(define (_:string? type-name)
 ; Return whether type-name is "string", even if qualified with an XML
 ; namespace.
 (match-let ([(list namespace local-name) (split-name type-name)])
   (equal? local-name "string")))

(define (sxml->bdlat node [type-name #f] [docs '()])
  ; Return the BDE "attribute type" representation of the type described in
  ; the specified SXML node.
  ; The XSD namespace must be aliased as "xs" and the extensions namespace, if
  ; applicable, must be aliased as "ext".
  (sxml-match node
    ; complexType (will be either a choice or a sequence)
    [(xs:complexType (@ (name ,name)) ,maybe-docs ... ,body)
     (sxml->bdlat body name (sxml->docs maybe-docs))]

    ; sequence type (recurred from complexType, above)
    [(xs:sequence ,elements ...)
     (sequence type-name docs (map sxml->element elements))]

    ; choice type (recurred from complexType, above)
    [(xs:choice ,elements ...)
     (choice type-name docs (map sxml->element elements))]

    ; enumeration
    [(xs:simpleType (@ (name ,type-name)) 
       ,maybe-docs ...
       (xs:restriction (@ (base ,base))
         ,enums ...))
 
     ; require that base="xs:string" or "string" or similar
     (guard (_:string? base))

     (enumeration type-name (sxml->docs maybe-docs)
       (map sxml->enumeration-value enums (range (length enums))))]

    [,otherwise (error 
      (format "SXML node does not match any type definition: ~.v" node))]))

(define (find-all-xs tag-name doc)
  ; e.g. (find-all-xs "complexType" doc) yields
  ; '((xs:complexType ...) (xs:complexType ...) ...) 
  (let* ([query (string-append "//xs:" tag-name)]
         [ns-aliases '((xs . "xs"))]
         [find-matching (sxml:xpath query ns-aliases)])
    (find-matching doc)))

(define (sxml->types doc)
  ; Return a list of all type definitions extractable from the specified SXML.
  ; The XSD namespace must be aliased as "xs" and the extensions namespace, if
  ; applicable, must be aliased as "ext".
  (~>> '("complexType" "simpleType")
       (append-map (lambda (name) (find-all-xs name doc)))
       (map sxml->bdlat)))