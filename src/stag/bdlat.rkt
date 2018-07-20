#lang racket

(provide
  ; procedure that converts an SXML s-expression into one of the types below
  sxml->bdlat

  ; procedure that finds all types defined in an SXML s-expression and returns
  ; a list of the resulting objects.
  sxml->types

  ; the types that compose to make a bdlat type
  (struct-out sequence)    (struct-out choice)            (struct-out element)
  (struct-out enumeration) (struct-out enumeration-value) (struct-out array)
  (struct-out nullable)    (struct-out basic))

(require "bdlat/private.rkt")