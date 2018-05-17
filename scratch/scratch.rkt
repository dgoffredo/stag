#lang racket

(require 
  ; XML s-expressions
  sxml 
  ; pattern matching on SXML nodes
  "../src/sxml-match/sxml-match.rkt"
  ; thrush combinator macros
  threading                          
  ; "attribute types" from SXML 
  (prefix-in bdlat: "../src/bdlat/bdlat.rkt")
  ; python AST and code generation from bdlat
  "../src/python/python.rkt")

(define doc
  (ssax:xml->sxml 
    (open-input-file "scratch/balber.xsd") 
    '((xs . "http://www.w3.org/2001/XMLSchema") 
      (ext . "http://bloomberg.com/schemas/bdem"))))

(define types (bdlat:sxml->types doc))

(define modules (bdlat->python-modules types "mysvcmsg"))

(for-each
  (lambda (py-module file-path)
    (with-output-to-file file-path
      (lambda () 
        (display (render-python py-module)))
      #:exists 'truncate))
  modules
  '("scratch/testoutput.py" "scratch/testoutpututil.py"))

; Apply overrides to names-map. The structure of overrides is a little
; different from that of names-map, so convert each key, value pair.
; (for-each
;   (match-lambda [(list key value)
;     (match (key)
;       [(? symbol? klass)
;        (dict-set! names-map (~a klass) value)]
;       [(list (? symbol? klass) (? symbol? attr))
;        (dict-set! names-map (cons (~a klass) (~a attr)) value)])])
;   overrides)