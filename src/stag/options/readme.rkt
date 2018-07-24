#lang racket

(provide display-readme)

(require "../readers.rkt") ; include/string

(define (displayln/less form [port (current-output-port)])
  ; If the specified output port is a terminal, then displayln the specified
  ; form to Unix's `less` command. If the specified output port is not a
  ; terminal, then just (displayln form).
  (if (terminal-port? port)
    ; If it's a terminal port, execute `less`, sending it the text.
    (let* ([less-path (find-executable-path "less")]
           [handles (process/ports 
                      (current-output-port) ; output -> stdout
                      #f                    ; create pipe for process input
                      (current-error-port)  ; errors -> stderr
                      less-path)])          ; command (and no args)
      (match handles
        [(list #f to-process pid #f process-do)
         (displayln form to-process)
         (flush-output to-process)
         (process-do 'wait)
         (close-output-port to-process)]))

    ; Otherwise, print the text followed by a newline.
    (displayln form port)))

(define ascii-stag
  ; This ASCII picture was signed "valkyrie" when I copied it from
  ; http://www.chris.com/ascii/index.php?art=animals/deer on July 21, 2018.
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
    (displayln/less text)))
