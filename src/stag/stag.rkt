#lang racket

(require "../options/options.rkt")

(define options (parse-options))

(display options)
(newline)

; TODO: 
; - Parse XSD into SXML with proper namespaces.
; - Extract types using bdlat.rkt.
; - Create python modules using python.rkt.
; - Print module files to output directory using python.rkt.