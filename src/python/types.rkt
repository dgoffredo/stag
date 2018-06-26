#lang racket

(provide (all-defined-out))

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
   type      ; symbol/string or list of symbol/string
   docs      ; list of paragraphs
   default)  ; default value ('#:omit to ignore)
  #:transparent)

(struct python-argument
  (name     ; symbol
   type     ; symbol/string or list of symbol/string
   default) ; default value ('#:omit ro ignore)
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
   args  ; list of either symbol or python-annotation
   type  ; return type, or '#:omit to ignore
   docs  ; list of paragraphs (strings)
   body) ; list of statements
  #:transparent)

(struct python-invoke
  (name  ; symbol or list of symbol
   args) ; list of expressions
  #:transparent)

(struct python-dict
  (items) ; list of pair (key, value)
  #:transparent)

(struct python-return
  (expression) ; some value or invocation
  #:transparent)

(struct python-for
  (variables ; list of symbols
   iterator  ; expression (anything)
   body)     ; list of statements
  #:transparent)

(define (annotation->argument annotation)
  ; A python-argument is just a python-annotation without the "docs" field, so
  ; it can be convenient to convert an annotation into an argument, such as
  ; might be used in the argument list of the "__init__" function of a class
  ; having annotated attributes.
  (match annotation
    [(python-annotation attribute type docs default)
     (python-argument   attribute type      default)]))