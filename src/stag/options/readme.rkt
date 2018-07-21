#lang racket

(provide display-readme)

(require "../readers.rkt") ; include/string

(define ascii-stag
#<<END
     /|       |\
  `__\\       //__'
     ||      ||
   \__`\     |'__/
     `_\\   //_'
     _.,:---;,._
     \_:     :_/
       |@. .@|
       |     |
       ,\.-./ \
       ;;`-'   `---__________-----.-.
       ;;;                         \_\
       ';;;                         |
        ;    |                      ;
         \   \     \        |      /
          \_, \    /        \     |\
            |';|  |,,,,,,,,/ \    \ \_
            |  |  |           \   /   |
            \  \  |           |  / \  |
             | || |           | |   | |
             | || |           | |   | |
             | || |           | |   | |
             |_||_|           |_|   |_|
            /_//_/           /_/   /_/
END
)

(define (display-readme)
  (let* ([readme (include/string "../../../README.md")]
         ; The first line of the readme is an image. Replace it with ASCII.
         [escaped-ascii (regexp-replace-quote ascii-stag)]
         [text (regexp-replace #px"^[^\\\n]*" readme escaped-ascii)])
    (displayln text)))
