#lang racket

(provide main)

(require 
  "../options.rkt"                      ; command line parsing
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
      (let* ([schema (xsd->sxml schema-path extensions-namespace)]
             [types (sxml->types schema)]
             [modules (bdlat->python-modules 
                        types
                        types-module
                        private-module
                        #:overrides name-overrides)])
        (for ([py-module modules]
              [module-name (list types-module util-module private-module)])
          (let* ([file-name (~a module-name ".py")]
                 [output-path (build-path output-directory file-name)]
                 [output-port (open-output-file 
                                output-path 
                                #:exists 'truncate)])
            (display (render-python py-module) output-port))))]))
  