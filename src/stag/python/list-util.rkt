#lang racket

(provide list<?)

(define (not-pair? datum)
  (not (pair? datum)))

(define (list<? less-than)
  ; Return a procedure that compares two lists lexicographically using the
  ; specified comparison for list elements. Additionally, list<? treats
  ; non-pairs as lists of a single element, e.g. 4 -> '(4).
  (define lexicographic-less-than
    (match-lambda*
      [(list '() '()) #f]
      [(list '() _)   #t]
      [(list _ '())   #f]
      [(list (cons left left-rest) (cons right right-rest))
       (cond
         [(less-than left right) #t]
         [(less-than right left) #f]
         [else (lexicographic-less-than left-rest right-rest)])]
      [(list left (? not-pair? right))
       (lexicographic-less-than left (list right))]
      [(list (? not-pair? left) right)
       (lexicographic-less-than (list left) right)]))

  lexicographic-less-than)
