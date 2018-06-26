#lang racket

(provide check-name-map
         check-name
         invalid-python-identifier?)

(define (quoted char)
  ; Return a quoted string containing the specified character.
  (~s (string char)))

(define (char-diagnostic char text [name "character"])
  ; Return a string that explains that the specified character appears in the
  ; specified text, and so presumably is invalid in some context. Optionally
  ; specify a name for what the character is, e.g. to distinguish "starting
  ; character" from "character".
  (~a (~s text) " contains the invalid " name " " (quoted char)
    ", which is Unicode code point " (char->integer char) "."))

(define valid-start-char?
  ; Return whether the specified character can appear as the first character in
  ; a python identifier.
  (let ([regex #px"\\p{L}|\\p{Nl}|_"])
         ; See "Lexical analysis" in the Python docs. The regex is based on:
         ;     id_start  ::=  <Lu, Ll, Lt, Lm, Lo, Nl, the underscore>
    (lambda (char)
      (regexp-match? regex (string char)))))

(define valid-continue-char?
  ; Return whether the specified character can appear as the second character
  ; or as any later character in a python identifier.
  (let ([regex
         #px"\\p{Mn}|\\p{Mc}|\\p{Nd}|\\p{Pc}"])
         ; See "Lexical analysis" in Python docs. The regex is based on:
         ;     id_continue  ::=  <id_start, categories Mn, Mc, Nd, Pc>
    (lambda (char)
      (or (valid-start-char? char) (regexp-match? regex (string char))))))

(define (invalid-identifier-lexeme? text)
  ; Return a string stating the reason why the specified text is not a valid
  ; identifier according to python's lexical rules. This does not account for
  ; keywords and other rules that would prevent a name from being a valid
  ; identifier, only whether the lexer would accept it. If the text is valid,
  ; then return #f.
  (let ([chars (string->list text)])
   (cond
     [(not (non-empty-string? text))
      "The empty string is not a valid python identifier."]
     [(not (valid-start-char? (first chars)))
      (char-diagnostic (first chars) text "starting character")]
     [else ; check the remaining characters
      (ormap ; Return the first diagnostic produced, or #f otherwise.
        (lambda (char)
          (if (valid-continue-char? char)
            #f
            (char-diagnostic char text)))
        (rest chars))])))

(define magic-identifier?
  ; Return whether the specified string, when treated as a python identifier,
  ; looks like a "magic" identifier such as "__init__" or "__name__".
  (let ([regex #px"^__.*__$"])
    (lambda (name)
      (regexp-match? regex name))))

(define python-keyword?
  ; Return whether the specified string, when treated as a python identifier,
  ; is a reserved word such as "def" or "class".
  (let ([keywords (set 
                    "False"      "class"      "finally"    "is"        "return"
                    "None"       "continue"   "for"        "lambda"    "try"
                    "True"       "def"        "from"       "nonlocal"  "while"
                    "and"        "del"        "global"     "not"       "with"
                    "as"         "elif"       "if"         "or"        "yield"
                    "assert"     "else"       "import"     "pass"
                    "break"      "except"     "in"         "raise")])
    (lambda (name)
      (set-member? keywords name))))

(define (invalid-python-identifier? name)
  ; Return a string stating the reason why the specified name is not a valid
  ; python identifier, or return #f if it is a valid python identifier. The
  ; name can be either a string or a symbol.
  (let ([name (~a name)])
    (cond
      [(invalid-identifier-lexeme? name)
        => identity] ; invalid-identifier-lexeme? returns an explanation (or #f).
      [(python-keyword? name)
       (~a (~s name) " is a keyword in python.")]
      [(magic-identifier? name)
          (~a (~s name) " is of the reserved \"magic\" form /__*__/.")]
          [else ; it's valid 
      #f])))

(define (shell-quote text)
  ; Quote the specified text in double quotes and escape characters necessary
  ; to prevent Unix shell expansion within the resulting string.
  (~a "\"" (string-replace text "$" "\\$") "\"")) 

(define (check-name name schema-name [parent-name #f])
  ; Return the specified string (name) if it is a valid python identifier. If
  ; it is not a valid python identifier, raise a user error describing what is
  ; wrong with the name, and suggesting how the user could override the mapping
  ; from the specified schema name (from which the name was derived). If the
  ; name is an attribute within a type, then the parent name is the name of
  ; that type in the schema.
  (let ([invalid-why (invalid-python-identifier? name)])
    (if invalid-why
      (raise-user-error
        (~a "An invalid python identifier was encountered. " invalid-why
          " " (~s name) " was derived from " (~s schema-name) " in the schema."
          (if parent-name
            (~a " " (~s schema-name) " is defined in " (~s parent-name) ".")
            "")
          (~a " You can override this name in the --name-overrides command "
            "line option, e.g. --name-overrides "
            (shell-quote
                (~s `([,(if parent-name
                          `(,(string->symbol parent-name)
                            ,(string->symbol schema-name))
                          (string->symbol schema-name))
                       <new-name>]))))))
      ; Otherwise, the name is valid, so just return it.
      name)))

(define (check-name-map name-map)
  ; Return the specified name-map if its values are all valid python
  ; identifiers. If any of its values is not a valid python identifier, raise
  ; a user error describing what is wrong with the value, and suggesting how
  ; the user could override the value on the command line.
  (for ([(key name) name-map])
    (match key
      [(list klass attr) (check-name name attr klass)]
      [klass             (check-name name klass)]))

  name-map)
    