#lang racket

; This module provides a procedure used to interpret the code generator's
; --package command line argument.

(provide prepare-package)

(define (prepare-package package output-directory . module-names)
    ; Create a python package (possibly with subpackages) directory tree
    ; within the specified output-directory. Interpret the specified package
    ; string as a period-separated nested package name. Return a pair
    ; containing the path to the prepared package, and the specified
    ; module-names each prefixed by package. If package is #f, create no
    ; directories and return (cons output-directory module-names).
    (if (not package)
      ; If no package was specified, leave the output directory and module
      ; names alone.
      (cons output-directory module-names)
      ; If a package was specified, create the corresponding directory tree
      ; beginning at output-directory, and return the resulting directory
      ; along with modules-names each prefixed with the package, e.g.
      ; "messages" -> "some.package.name.messages".
      (cons
        (for/fold ([parent output-directory])           ; accumulators
                  ([part   (string-split package ".")]) ; iterators
          (let* ([dir (build-path parent part)]         ; e.g. a/b/ (for a.b)
                 [init (build-path dir "__init__.py")]) ; e.g. a/b/__init__.py
            ; Make sure that the directory is there.
            (unless (directory-exists? dir)
              (make-directory dir))
            ; Make sure that __init__.py is in the directory.
            (unless (file-exists? init)
              (open-output-file init))
            ; Continue to the next subdirectory, if applicable.
            dir))
  
        (for/list ([module-name module-names])
          (string-append package "." module-name)))))
