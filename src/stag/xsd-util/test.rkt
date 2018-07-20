#lang racket

(require rackunit         ; test-suite, test-case, check-..., etc.
         rackunit/text-ui ; run-tests
         xml              ; namespace-oblivious XML parsing
         sxml/sxpath      ; search SXML trees
         "private.rkt")   ; the module under test

(define (join-lines . lines)
    (string-join lines "\n"))

(define *extensions-namespace*
  "http://www.dontmatter.com/extensions")

(define tests
  (test-suite
    "Tests for xsd-util"
    ; Strictly speaking, alias-of doesn't care what the namespace is (e.g.
    ; whether it's the XSD namespace or extensions namespace or neither).
    ; However, since those are the namespaces stag cares about, they're the
    ; ones used in these tests.
   (test-case
     "alias-of returns alias when there is one"
     (let* ([schema-string (join-lines
              "<?xml version='1.0' encoding='UTF-8'?>"
              "<xs:schema xmlns:xs='http://www.w3.org/2001/XMLSchema'"
              "           xmlns:ext='http://www.xsd.com/extensions'>"
              "</xs:schema>")]
            [doc (read-xml (open-input-string schema-string))])
      (check-equal? 
        (alias-of "http://www.w3.org/2001/XMLSchema" doc)
        'xs
        "when a namespace has an alias, alias-of should find it")
      (check-equal?
        (alias-of "http://www.xsd.com/extensions" doc)
        'ext
        "when a namespace has an alias, alias-of should find it")))

   (test-case
     "alias-of returns *toplevel* when namespace is global"
     (let* ([schema-string (join-lines
              "<?xml version='1.0' encoding='UTF-8'?>"
              "<xs:schema xmlns='http://www.w3.org/2001/XMLSchema'"
              "           xmlns:ext='http://www.xsd.com/extensions'>"
              "</xs:schema>")]
            [doc (read-xml (open-input-string schema-string))])
      (check-equal?
        (alias-of "http://www.w3.org/2001/XMLSchema" doc)
        '*toplevel*
        "when a namespace is global, alias-of should return '*toplevel")))

   (test-case
     "alias-of returns #f when namespace is not mentioned"
     (let* ([schema-string (join-lines
              "<?xml version='1.0' encoding='UTF-8'?>"
              "<xs:schema xmlns:xs='http://www.w3.org/2001/XMLSchema'"
              "           xmlns:ext='http://www.xsd.com/extensions'>"
              "</xs:schema>")]
            [doc (read-xml (open-input-string schema-string))])
      (check-equal?
        (alias-of "http://this.is.totally.not.there.com" doc)
        #f
        "when a namespace is not mentioned, alias-of should return #f")))

   (test-case
     "alias-of is not tricked by the targetNamespace attribute"
     (let* ([schema-string (join-lines
              "<?xml version='1.0' encoding='UTF-8'?>"
              "<xs:schema xmlns:xs='http://www.w3.org/2001/XMLSchema'"
              "           targetNamespace='http://www.foo.com/service'"
              "           xmlns:tns='http://www.foo.com/service'>"
              "</xs:schema>")]
            [doc (read-xml (open-input-string schema-string))])
      (check-equal? 
        (alias-of "http://www.foo.com/service" doc)
        'tns
        "even when it's the targetNamespace, alias-of should find the alias")))

   (test-case
     "alias-of does not consider targetNamespace an alias"
     (let* ([schema-string (join-lines
              "<?xml version='1.0' encoding='UTF-8'?>"
              "<xs:schema xmlns:xs='http://www.w3.org/2001/XMLSchema'"
              "           targetNamespace='http://www.foo.com/service'>"
              "</xs:schema>")]
            [doc (read-xml (open-input-string schema-string))])
      (check-equal? 
        (alias-of "http://www.foo.com/service" doc)
        #f
        "targetNamespace alone should not be considered an alias")))
    
    (test-case
      "xsd->sxml* prepends \"xs:\" when the XSD namespace is global"
      (let* ([schema-string (join-lines
              "<?xml version='1.0' encoding='UTF-8'?>"
              "<schema xmlns='http://www.w3.org/2001/XMLSchema'>"
              "  <complexType name='Example'>"
              "    <sequence>"
              "      <element name='solo' type='double' />"
              "    </sequence>"
              "  </complexType>"
              "  <simpleType name='SomeEnum'>"
              "    <restriction base='string'>"
              "      <enumeration value='SOME_VALUE' />"
              "      <enumeration value='ANOTHER_VALUE' />"
              "    </restriction>"
              "  </simpleType>"
              "</schema>")]
              [get-input-port (lambda () (open-input-string schema-string))]
              [schema (xsd->sxml* get-input-port *extensions-namespace*)]
              [tags '(schema complexType sequence element simpleType
                      restriction enumeration)]
              ; sxpath wants you to tell it aliases refer to themselves.
              [aliases '((xs . "xs") (ext . "ext"))])
        ; Verify that none of the unqualified XSD tags exist in the result,
        ; e.g. an <element ...> tag should not appear, since it would have
        ; been replaced by xs:element.
        (for-each
          (lambda (xpath-query)
            (check-equal?
              ((sxpath xpath-query aliases) schema)
              '()
              "All of the XSD tags should be qualified in SXML"))
          (map (lambda (tag-symbol) (~a "//" tag-symbol)) tags))

        ; Verify that all of the qualified XSD tags exist in the result,
        ; e.g. expect to see all of xs:element, xs:schema, etc.
        (for-each
          (lambda (xpath-query)
            (check-not-equal?
              ((sxpath xpath-query aliases) schema)
              '()
              "All of the XSD tags should be qualified in SXML"))
          (map (lambda (tag-symbol) (~a "//xs:" tag-symbol)) tags))

        ; Verify that the values of the type-referencing attributes are
        ; qualified (at least as should be the case in this example).
        (for-each
          (lambda (xpath-query)
            (match ((sxpath xpath-query aliases) schema)
              [(list (list name value))
               (check-regexp-match #px"xs:.*" value)]))
          (map (lambda (attr) (~a "//@" attr)) '(type base)))))))

(module+ test
  (run-tests tests))