#lang racket

(provide main)

(require 
  "../options.rkt"                      ; command line parsing
  "package.rkt"                         ; prepare-package
  (only-in "../xsd-util.rkt" xsd->sxml) ; schema from XSD file
  (only-in "../bdlat.rkt" sxml->types)  ; bdlat types from schema
  (only-in "../python.rkt"              ; python from bdlat types
    bdlat->python-modules render-python))

(define (main argv)
  (match (parse-options argv)
    [(options 
        verbose 
        types-module 
        util-module 
        private-module
        package
        extensions-namespace 
        name-overrides 
        output-directory 
        schema-path)
      (match (prepare-package package output-directory 
               types-module util-module private-module)
        ; Get module names prefixed by the package name, and rebind the
        ; output-directory to refer to within the package. Note that
        ; util-module* is not used (none of the generated code imports the
        ; utilities module).
        [(list output-directory types-module* util-module* private-module*)

         (let* ([schema (xsd->sxml schema-path extensions-namespace)]
                [types (sxml->types schema)]
                [modules (bdlat->python-modules 
                           types
                           types-module*
                           private-module*
                           #:overrides name-overrides)])
           (for ([py-module modules]
                 [module-name (list types-module util-module private-module)])
             (let* ([file-name (string-append module-name ".py")]
                    [output-path (build-path output-directory file-name)]
                    [output-port (open-output-file 
                                   output-path 
                                   #:exists 'truncate)])
               (display (render-python py-module) output-port))))])]))
 