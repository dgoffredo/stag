#lang racket

(require rackunit         ; test-suite, test-case, check-..., etc.
         rackunit/text-ui ; run-tests
         "private.rkt")   ; the module under test

(define tests
  (test-suite
    "Tests for readers"
    (test-case
      "Including a file as a string compiles and yields the correct value"
      (check-equal? (include/string "test.txt")
                    "This file contains text\nused to test include/string"))))

(module+ test
  (run-tests tests))
