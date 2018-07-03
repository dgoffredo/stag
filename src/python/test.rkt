#lang racket

#| TODO

(require rackunit         ; test-suite, test-case, check-..., etc.
         rackunit/text-ui ; run-tests
         ; modules to test
         "check-name.rkt"
         "convert.rkt"
         "name-map.rkt"
         "render.rkt"
         "types.rkt"
         "python.rkt")

(define tests
  (test-suite
    "Tests for python"

    #;(test-case
      "TODO statement of what this does"
      TODO)))

(module+ test
  (run-tests tests))

|#