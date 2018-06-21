#lang racket

(require rackunit         ; test-suite, test-case, check-..., etc.
         rackunit/text-ui ; run-tests
         "private.rkt")   ; the module under test

(define tests
  (test-suite
    "Tests for python"

    #;(test-case
      "TODO statement of what this does"
      TODO)))

(module+ test
  (run-tests tests))