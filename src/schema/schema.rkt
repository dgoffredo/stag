#lang racket

; TODO: This will have utilities that prepare an XML tree for processing by
;       bdlat.rkt. Need to munge around with namespaces a bit since SXML
;       doesn't know to interpret namespaces within "base" and "type" 
;       attribute values.

(require xml   ; Racket's built-in XML parsing. Not namespace-aware.
         sxml) ; "Standard" XML parsing in Scheme. Understands namespaces.

; TODO: This might come in handy...
; ((sxml:modify
;    (list 
;      "//@type" 
;      (lambda (node context root) 
;        (print node) 
;        (newline) 
;        node))) 
;  doc)