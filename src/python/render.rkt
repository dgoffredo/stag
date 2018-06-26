#lang racket

(provide render-python)

(require "types.rkt"              ; python AST structs (what we're rendering)
         "../version/version.rkt" ; version string for this code generator
         threading                ; ~> and ~>> macros
         scribble/text/wrap)      ; (wrap-line text num-chars)

(define (csv list-of-symbols indent-level indent-spaces)
  ; Return "foo, bar, baz" given '(foo bar baz). This operation is performed
  ; a few times within render-python. If list-of-symbols is not a list, then
  ; just render it alone. "csv" stands for "comma separated values."
  (if (list? list-of-symbols)
    (~>> list-of-symbols
         (map (lambda (form) (render-python form indent-level indent-spaces)))
         (string-join _ ", "))
    ; otherwise
    (render-python list-of-symbols indent-level indent-spaces)))

(define (interpose sep lst)
  ; Return a list containing the elements of the specified list, but with the
  ; specified separator between each element, e.g.
  ;     
  ;     (interpose '(1 2 3) "hello")
  ;
  ; returns
  ;
  ;     '(1 "hello" 2 "hello" 3)
  (~> lst (sequence-add-between sep) sequence->list))

(define (format-docs docs #:prefix [prefix ""] #:width [width 79])
  ; Return a string containing the specified list of paragraphs wrapped to
  ; lines each with the specified prefix, where each line (including the
  ; prefix) does not exceed the specified length, unless the line is a single
  ; word whose length exceeds the width. Additionally, between each paragraph
  ; is an "empty" line containing only the prefix, and lines are stipped of
  ; trailing white space. The length of the prefix must be less than the width.
  ; For example,
  ;
  ;     (format-docs '("oh hello there documentation" "how are you?" "good")
  ;                  #:prefix "#  "
  ;                  #:width 11)
  ;
  ; would produce a string containing:
  ;
  ;     #  oh hello
  ;     #  there
  ;     #  documentation
  ;     #
  ;     #  how are
  ;     #  you?
  ;     #
  ;     #  good
  (~>> docs
       (map (lambda (line) (wrap-line line (- width (string-length prefix)))))
       (interpose "")
       flatten
       (map (lambda (line) (string-append prefix line)))
       (map (lambda (line) (string-trim line #:left? #f)))
       (string-join _ "\n")))

(define (render-version indent-level indent-spaces)
    ; Return a string of python code that assigns this code generator's version
    ; string to a variable.
    (render-python
      (python-assignment
        '_code_generator_version ; left-hand side
        *stag-version*           ; right-hand side
        ; documentation
        (list (string-join 
                '("This is the version string identifying the version of stag "
                  "that generated this code. Search through the code "
                  "generator's git repository history for this string to find "
                  "the commit of the contemporary code generator.")
                "")))
      indent-level 
      indent-spaces))

(define TRIPQ "\"\"\"") ; triple quote

(define (triple-quoted-docs docs indent-level indent-spaces)
  (if (empty? docs)
    ""
    (let* ([margin-length (* indent-level indent-spaces)]
           [margin        (make-string margin-length #\space)]
           ; Prepend a triple quote to the first paragraph.
           [docs          (cons (~a TRIPQ (first docs)) (rest docs))])
      (~a (format-docs docs #:prefix margin) "\n" margin TRIPQ "\n"))))

(define (render-python form [indent-level 0] [indent-spaces 4])
  ; Return a string containing the python code corresponding to the specified
  ; form, which must be some composition of python-* structs, strings,
  ; symbols, etc. Prefix each line with the specified level of indentation,
  ; where each level has the specified number of space characters.
  (let* ([INDENT  (make-string (* indent-level indent-spaces) #\space)]
         ; Recurse into this procedure, preserving auxiliary arguments.
         [recur   (lambda (form [indent-level indent-level])
                    (render-python form indent-level indent-spaces))]
         ; Recurse into this procedure with indent-level incremented.
         [recur+1 (lambda (form) (recur form (+ indent-level 1)))])
    (match form
      [(python-module description docs imports statements)
       ; """This is the description.
       ;
       ; documentation...
       ; """
       ;
       ; ... imports ...
       ;
       ; ... statements ...

       (~a "\n" INDENT TRIPQ description "\n" ; description
         ; documentation
         (if (empty? docs)
           ""
           (~a "\n" 
               (format-docs docs #:prefix INDENT)))
         "\n" INDENT TRIPQ "\n"
         ; imports
         (string-join (map recur imports) "")
         "\n\n"
         ; statements (classes, functions, globals, etc.)
         (string-join (map recur statements) "\n\n")
         ; code generator version variable
         "\n\n" (render-version indent-level indent-spaces))]

      [(python-import from-module names)
       ; can be one of
       ;     import something
       ; or
       ;     from something import thing
       ; or
       ;     from something import thing1
       ;     from something import thing2
       (cond
         [(null? names)
           (~a INDENT "import " from-module "\n")]
         [(not (list? names))
           (~a INDENT "from " from-module " import " names "\n")]
         [else
           (string-join 
             (map
               (lambda (name)
                 (~a INDENT "from " from-module " import " name))
               names)
             "\n")])]

      [(python-class name bases docs statements)
       ; class Name(Base1, Base2):
       ;     """documentation blah blah
       ;     more documentation of here blah blah...
       ;     """
       ;     ...
       (~a INDENT "class " name
         (let ([bases-text (csv bases indent-level indent-spaces)])
           (if (= (string-length bases-text) 0)
             ""
             (~a "(" bases-text ")")))
         ":\n"
         ; documentation
         (triple-quoted-docs docs (+ indent-level 1) indent-spaces)
         ; statements
         (string-join (map recur+1 statements) "\n"))]

      [(python-annotation attribute type docs default)
       ; # docs...
       ; attribute : type = default
       (~a
         ; the docs
         (if (empty? docs)
           ""
           (let ([margin (~a INDENT "# ")])
             (~a (format-docs docs #:prefix margin) "\n")))
         ; the attribute name
         INDENT attribute
         ; the type name
         (if (equal? type '#:omit)
           ""
           (~a " : "
             (if (list? type)
               ; If type is a list, then it's something like
               ; typing.Optional["Foo"] or typing.Union[str, int].
               (~a (first type) "["
                 (string-join (map recur (rest type)) ", ")
                 "]")
               ; If type is not a list, then just print it.
               (recur type))))
         ; the default (assigned) value
         (if (equal? default '#:omit)
           ""
           (~a " = " (recur default))))]

      [(python-argument name type default)
       ; An argument is an annotation without documentation.
       (recur (python-annotation name type '() default))]

      [(python-assignment lhs rhs docs)
       ; An assignment is an annotation whose type is omitted.
       (recur (python-annotation lhs '#:omit docs rhs))]

      [(python-pass)
       (~a INDENT "pass\n")]

      [(python-def name args type docs body)
       ; def name(arg1, arg2):
       ;     body...
       (~a INDENT "def " name "(" (csv args indent-level indent-spaces) ")"
         (if (equal? type '#:omit) "" (~a " -> " (recur type))) ":\n"
         ; documentation
         (triple-quoted-docs docs (+ indent-level 1) indent-spaces)
         ; body
         (string-join (map recur+1 body) "")
         "\n")]

      [(python-invoke name args)
       (~a INDENT name "(" (csv args indent-level indent-spaces) ")")]

      [(python-dict items)
       ; {key1: value1, ...}
       (~a "{"
         (string-join
           ; map each (key . value) pair to "key: value"
           (map
             (match-lambda [(cons key value)
               (~a (recur key) ": " (recur value))])
             items)
           ", ")
         "}")]

      [(python-return expression)
       (~a INDENT "return " (recur expression))]

      [(python-for variables iterator body)
       (~a INDENT "for " (csv variables indent-level indent-spaces)
         " in " (recur iterator) ":\n"
         (string-join (map recur+1 body) ""))]

      [(? symbol? value)
       ; Symbols are here notable in that they're printed with ~a, not ~s.
       ; I want the spelling of the symbol to be literal in the python
       ; source code, as opposed to escaped as a symbol, e.g. [] not |[]|.
       (~a value)]

      [(? string? value)
       ; ~s so that it's printed quoted and escaped.
       (~s value)]

      [(? number? value)
       (~a value)])))