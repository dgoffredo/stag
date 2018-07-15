#lang racket

; This module provides the 'include/string' macro, which takes a path to a file
; and expands to a string containing the contents of that file. This is used
; to include python code verbatim in the output of the code generator
; (currently for the "private" python module).
(provide include/string)

(begin-for-syntax
  (require racket/generator)
  (require racket/port)

  (define (verbatim-reader)
    ; Return a generator suitable for use as a syntax reader procedure in
    ; include/reader. The generator will consume the entire contents of the
    ; input port provided and yield the contents as a string in a syntax
    ; object.
    (generator (src in)
      (yield 
        (with-syntax ([str (port->string in)])
         (syntax str)))
      eof)))

(define-syntax-rule (include/string path)
  ; include/string is a macro that, given the path to a file, will expand to
  ; a string containing the contents of the file. Being a macro, this operation
  ; happens during macro expansion, which is typically during compilation.
  (include/reader path (verbatim-reader)))
