#lang racket

(provide (struct-out options) ; struct containing parsed command line options
         parse-options)       ; procedure that parses command line options

(require "readme.rkt") ; (display-readme)

(struct options (verbose              ; #t -> print verbose diagnostics
                 types-module         ; e.g. "foosvcmsg"
                 util-module          ; e.g. "foosvcmsgutil"
                 private-module       ; e.g. "_foosvcmsg"
                 package              ; e.g. "services.usersvc", or #f for none
                 extensions-namespace ; e.g. for <element>'s "id" attribute
                 name-overrides       ; e.g. ([before after] ...)
                 output-directory     ; path to directory for output files
                 schema-path)         ; path to XSD file to read
        #:transparent)

(define (name-without-extension path)
  ; e.g. "/foo/bar/chicken.txt" -> "chicken"
  (let-values ([(base name must-be-dir) ; only using 'name
                (split-path (path-replace-extension path ""))])
    (path->string name)))

(define (parse-options argv)
  ; Return an options struct parsed from the optionally specified list of
  ; command line arguments. If parsing fails, print a diagnostic to standard
  ; error and terminate the current process with a nonzero status code.
  (define verbose (make-parameter #f))
  (define types-module (make-parameter #f))
  (define util-module  (make-parameter #f))
  (define private-module  (make-parameter #f))
  (define package (make-parameter #f))
  (define extensions-namespace 
    (make-parameter "http://bloomberg.com/schemas/bdem"))
  (define name-overrides (make-parameter '()))
  (define output-directory (make-parameter (string->path "./")))

  (define schema-path-string
    (command-line
      #:argv argv
      #:once-each
      [("--readme") "Print README.md to standard output"
                    (display-readme)
                    (exit)]
      [("--verbose") "Emit verbose diagnostics" ; TODO
                      (verbose #t)]
      [("--types-module") TYPES-MODULE
                          "Set the name of the types module"
                          (types-module TYPES-MODULE)]
      [("--util-module") UTIL-MODULE
                          "Set the name of the util module"
                          (util-module UTIL-MODULE)]
      [("--private-module") PRIVATE-MODULE
                          "Set the name of the private module"
                          (private-module PRIVATE-MODULE)]
      [("--package") PACKAGE
                     "Set the name of the output package"
                     (package PACKAGE)]
      [("--extensions-namespace") EXTENSIONS-NAMESPACE
                                  "Set XSD extensions XML namespace"
                                  (extensions-namespace EXTENSIONS-NAMESPACE)]
      [("--name-overrides") NAME-OVERRIDES
                            "Override class/attribute names"
                            (name-overrides 
                              (read (open-input-string NAME-OVERRIDES)))]
      [("--output-directory") OUTPUT-DIRECTORY
                              "Directory to write module files"
                              (output-directory 
                                (string->path OUTPUT-DIRECTORY))]
      #:args (schema-path)
      schema-path))

  ; Derive types-module* from schema-path (if necessary).
  (define types-module*
    (or (types-module) 
      (string-append (name-without-extension schema-path-string) "msg")))

  ; Derive util-module from types-module* (if necessary).
  (define util-module*
    (or (util-module) (string-append types-module* "util")))

  ; Derive private-module from types-module* (if necessary).
  (define private-module*
    (or (private-module) (string-append "_" types-module*)))

  ; Return an options struct
  (options (verbose)
           types-module*
           util-module*
           private-module*
           (package)
           (extensions-namespace)
           (name-overrides)
           (output-directory)
           (string->path schema-path-string)))