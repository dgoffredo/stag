#lang info

(define name "stag")

(define deps '("racket" "threading-lib" "sxml"))

(define raco-commands '(("stag"                 ; command
                         stag                   ; module path
                         "generate python code" ; description
                         #f)))                  ; prominence (#f -> hide)
