#lang racket

(provide (all-defined-out))

(require xml        ; Racket's built-in XML parsing. Not namespace-aware.
         sxml       ; "standard" XML parsing in Scheme. With namespaces.
         threading) ; thrush combinator macros

(define *xsd-namespace* "http://www.w3.org/2001/XMLSchema")

(define (alias-of namespace schema-doc)
  ; Return the symbol value of the namespace alias of the specified XML
  ; namespace in the specified schema document (as parsed by the xml module).
  ; If the namespace corresponds to the document's toplevel namespace, then
  ; return the symbol '*toplevel*. If the namespace is not assigned to any
  ; attribute in the schema, then return #f.
  (let* ([attributes (~> schema-doc document-element element-attributes)]
         [matching-attr 
          (findf 
            (match-lambda [(attribute _ _ name value) 
              (equal? value namespace)])
            attributes)])
    (match matching-attr
      ; Not found? Return #f.
      [#f #f]
      ; Found: return either the alias symbol or '*toplevel*.
      [(attribute _ _ name value)
       ; The name might be, e.g. 'xmlns:foo. Then we want '("xmlns" "foo").
       (match (string-split (symbol->string name) ":")
         ; There's no alias; the attribute just sets the schema's namespace.
         [(list "xmlns")
          '*toplevel*]
         [(list "xmlns" alias)
         ; There is an alias. Return it.
         (string->symbol alias)])])))
       
(define (xsd->sxml xsd-path extensions-namespace)
  ; Parse the XSD file at the specified path, and return an SXML
  ; representation of the schema where the W3 XSD namespace is aliased as 'xs,
  ; the specified extensions namespace is aliased as 'ext, and any values for
  ; "base" or "type" attributes referring to types defined in the W3 XSD
  ; namespace have has "xs:" prepended to them as necessary. It is assumed
  ; that the schema will not refer to types defined in the extensions
  ; namespace, so that case is not handled.
  (let* ([doc (read-xml (open-input-file xsd-path))]
         [xsd-alias (alias-of *xsd-namespace* doc)]
         [schema (ssax:xml->sxml 
                   (open-input-file xsd-path)
                   `((xs . ,*xsd-namespace*)
                     (ext . ,extensions-namespace)))])
    (match xsd-alias
      [#f
       (error (~a "The schema " 
                xsd-path 
                " does not mention the required namespace "
                *xsd-namespace*))]

      ; If the W3 XSD namespace is already aliased as 'xs, then there's
      ; nothing to do.
      ['xs schema]

      ; If the W3 XSD namespace is the toplevel (global) namespace for the
      ; schema, then there will be attributes like type="string" when what we
      ; need is type="xs:string". Do that transformation.
      ['*toplevel* (replace-in-attributes schema '|| 'xs)]

      ; If the W3 XSD namespace is aliased by some name other than 'xs (say,
      ; 'foo), then there will be attributes like type="foo:int" when what we
      ; need is type="xs:int". Do that transformation.
      [(? symbol? alias) (replace-in-attributes schema alias 'xs)])))

(define (modify-attributes sxml-doc proc)
  ; Map the specified procedure over all attributes in the specified SXML
  ; document, replacing the attributes with the values returned by the
  ; procedure. Return a copy of the document having the resulting alterations.
  ; The procedure is invoked with two parameters: the name of the attribute (a
  ; symbol) and its value (a string). The procedure should return a (list name
  ; value).
  ; If you're wondering why this is so complicated, it's because sxml:modify
  ; doesn't support namespaces, so we have to do the tree traversal manually.
  (pre-post-order sxml-doc
    `((@ . 
       ,(lambda (at-tag . attributes)
           (match attributes
             ; Avoid *NAMESPACES*, which is not an attribute.
             [(list (list '*NAMESPACES* _ ...))
              (cons at-tag attributes)]
             ; For anything else, map the procedure over the attributes.
             [_ ;
              (cons at-tag 
                (map (lambda (name-value) 
                       (apply proc name-value))
                  attributes))])))
      ; Keep just the text part of *text* nodes (otherwise a side effect
      ; of pre-post-order is to inject '*text* everywhere -- annoying).
      (*text* . ,(lambda (text-tag actual-text) actual-text))
      ; Let other nodes pass through unmodified.
      (*default* . ,(lambda args args)))))

(define (replace-in-attributes
          sxml-schema
          old-ns-alias
          new-ns-alias
          [attribute-names '(type base)])
  ; Return a copy of the specified SXML schema where any of the specified
  ; attributes have had namespace aliases in their values (if applicable)
  ; remapped from the specified old alias to the specified new alias.
  ; For example,
  ;     (replace-in-attributes ... '|| 'xs '(type base))
  ; would change this
  ;     (xs:element name="foo" type="string")
  ; into this
  ;     (xs:element name="foo" type="xs:string")
  (modify-attributes sxml-schema
    (lambda (name value)
       (let ([new-value 
              (if (member name attribute-names)
                (replace-namespace-alias value old-ns-alias new-ns-alias)
                value)])
         (list name new-value)))))
        
(define (replace-namespace-alias attribute-value old-alias new-alias)
  (let ([old-alias (symbol->string old-alias)]
        [new-alias (symbol->string new-alias)])
    (match (split-name attribute-value)
      [(list ns local-name)
       (if (equal? ns old-alias)
           (make-name new-alias local-name)
           (make-name ns local-name))])))

(define (split-name attribute-value)
  (match (string-split attribute-value ":")
    [(list ns local-name) (list ns local-name)]
    [(list local-name)    (list "" local-name)]))

(define (make-name ns local-name)
  (if (equal? ns "")
    local-name
    (~a ns ":" local-name)))