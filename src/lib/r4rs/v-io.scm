(##include-once "./bool.scm")
(##include-once "./types.scm")
(##include-once "./pair-list.scm")
(##include-once "./vector.scm")
(##include-once "./control.scm")
(##include-once "./char.scm")
(##include-once "./error.scm")

(cond-expand
  ((host js)

   (define-primitive
     (##stdin)
     (use js/node/fs)
     "() => push(0),")

   (define-primitive
     (##stdout)
     (use js/node/fs)
     "() => push(1),")

   (define-primitive 
     (##get-fd-input-file filename)
     (use js/node/fs scm2str)
     "prim1(filename => {try{return fs.openSync(scm2str(filename), 'r')}catch{return FALSE}}),")

   (define-primitive
     (##get-fd-output-file filename)
     (use js/node/fs scm2str)
     "prim1(filename => {try{return fs.openSync(scm2str(filename), 'w')}catch{return FALSE}}),")

   (define-primitive
     (##read-char-fd fd)
     (use js/node/fs)
     "prim1(fd => {
     let buf=Buffer.alloc(1); 
     let ch=fs.readSync(fd, buf) === 0 ? NIL : buf[0]; 
     return ch;
     }),")

   (define-primitive
     (##write-char-fd ch fd)
     (use js/node/fs)
     "prim2((fd, ch) => fs.writeSync(fd, String.fromCodePoint(ch), null, 'utf8')),")

   (define-primitive
     (##close-input-port fd)
     (use js/node/fs)
     "prim1(fd => (fs.closeSync(fd),true)),")

   (define-feature 
     ##close-output-port
     (use ##close-input-port)))

  ((host c)

   (define-primitive
     (##stdin)
     (use c/stdio)
     "{
     FILE* file = fdopen(0, \"r\");
     push2((long) file | 1, PAIR_TAG);
     break;
     }")

   (define-primitive
     (##stdout)
     (use c/stdio)
     "{
     FILE* file = fdopen(1, \"w\");
     push2((long) file | 1, PAIR_TAG);
     break;
     }")

   (define-primitive 
     (##get-fd-input-file filename)
     (use c/stdio scm2str)
     "{
     PRIM1();
     char* filename = scm2str(x);
     FILE* file = fopen(filename, \"r\");
     if (file == NULL) perror(\"Couldn't open the file\\n\");
     push2((long) file | 1, PAIR_TAG);
     free((void*) filename);
     break;
     }")

   (define-primitive
     (##get-fd-output-file filename)
     (use c/stdio scm2str)
     "{
     PRIM1();
     char* filename = scm2str(x);
     FILE* file = fopen(filename, \"w\");
     push2((long) file | 1, PAIR_TAG);
     free((void *) filename);
     break;
     }")

   (define-primitive
     (##read-char-fd fd)
     (use c/stdio)
     "{
     PRIM1();
     FILE* file = (FILE*) ((long) x ^ 1);
     char buffer[1];
     int bytes_read = fread(buffer, 1, 1, file);
     if (!bytes_read) push2(NIL, PAIR_TAG);
     else push2(TAG_NUM(buffer[0]), PAIR_TAG);
     break;
     }")

   (define-primitive
     (##write-char-fd ch fd)
     (use c/stdio)
     "{
     PRIM2();
     FILE* file = (FILE*) ((long) y ^ 1);
     char buffer[1] = {(char) NUM(x)};
     int success = fwrite(buffer, 1, 1, file);
     if (success != 1) {
     perror(\"WHAT\");
     }
     fflush(file);
     push2(TRUE, PAIR_TAG);
     break;
     }")

   (define-primitive
     (##close-input-port fd)
     (use c/stdio)
     "{
     PRIM1();
     FILE* file = (FILE*) ((long) x ^ 1);
     fclose(file);
     break;
     }"))

  ((host hs)

   (define-feature hs/io-handle (hs/foreign-type "    | RibHandle !Handle"))

   (define-primitive
     (##stdin)
     (use hs/io-handle)
     " , push . RibForeign $ RibHandle stdin")

   (define-primitive
     (##stdout)
     (use hs/io-handle)
     " , push . RibForeign $ RibHandle stdout")

   (define-primitive 
     (##get-fd-input-file filename)
     (use hs/io-handle scm2str)
     " , prim1 $ \\filename -> scm2str filename >>= (\\x -> openFile x ReadMode) >>= (pure . RibForeign . RibHandle)")

   (define-primitive
     (##get-fd-output-file filename)
     (use hs/io-handle scm2str)
     " , prim1 $ \\filename -> scm2str filename >>= (\\x -> openFile x WriteMode) >>= (pure . RibForeign . RibHandle)")

   (define-primitive
     (##read-char-fd fd)
     (use hs/io-handle)
     " , prim1 $ \\(RibForeign (RibHandle handle)) -> hIsEOF handle >>= \\eof -> if eof then return ribNil else hGetChar handle >>= (pure . RibInt . ord)")

   (define-primitive
     (##write-char-fd ch fd)
     (use hs/io-handle)
     " , prim2 $ \\(RibInt ch) (RibForeign (RibHandle handle)) -> hPutChar handle (chr ch) >> pure ribTrue")

   (define-primitive
     (##close-input-port fd)
     (use hs/io-handle)
     " , prim1 $ \\(RibForeign (RibHandle handle)) -> hClose handle >> pure ribTrue")))


(define (##close-output-port port-fd) (##close-input-port port-fd))

;; ---------------------- EOF & TYPES ---------------------- ;;

(define ##eof (##rib 0 0 5))

(define (##read-char port) (let ((c (##read-char-fd (##field0 port))))
                             (if (null? c) ##eof (integer->char c))))

(define (##write-char ch port) (##write-char-fd (##field0 ch) (##field0 port)))

(define (eof-object? obj)
  (##eqv? obj ##eof))

(define stdin-port
  (##rib (##stdin) (##rib ##read-char '() #t) input-port-type)) ;; stdin

(define stdout-port
  (##rib (##stdout) (##rib ##write-char "" #t) output-port-type))  ;; stdout


;; ---------------------- INPUT ---------------------- ;;

(define (open-input-file filename)
  ;; (file_descriptor, (cursor, last_char, is_open), input_file_type)
  (##rib (##get-fd-input-file filename) (##rib ##read-char '() #t) input-port-type))

(define (close-input-port port)
  (if (##field2 (##field1 port))
    (begin 
      (##field2-set! (##field1 port) #f)
      (##close-input-port (##field0 port)))))

(define (##get-last-char port)
  (##field1 (##field1 port)))

(define (##set-last-char port ch)
  (##field1-set! (##field1 port) ch))

(define (input-port-close? port)
  (not (##field2 (##field1 port))))

(define (current-input-port)
  stdin-port)

(define (call-with-input-file filename proc)
  (let* ((port (open-input-file filename))
         (result (proc port)))
    (close-input-port port)
    result))


(define (read-char (port (current-input-port))) 
  (if (input-port-close? port) (crash))
  (let ((last-ch (##get-last-char port)))
    (if (null? last-ch)
      (let ((reader (##field0 (##field1 port))))
        (reader port))
      (begin
        (##set-last-char port '())
        last-ch))))

(define (peek-char (port (current-input-port)))
  (let ((ch (read-char port)))
    (##set-last-char port ch)
    ch))

;; ---------------------- READ ---------------------- ;;

(define special-chars '(("newline" 10) 
                        ("space" 32) 
                        ("tab" 9)
                        ("return" 13)))

(define escapes '((10 110)   ;; \n -> n
                  (13 116)   ;; \t -> t
                  (92 92)    ;; \\ -> \
                  (34 34)))  ;; \" -> "

(define (read (port (current-input-port)))
  (let ((c (peek-char-non-whitespace port)))
    (cond ((eof-object? c) c)
          ((##eqv? c 40)            ;; #\(
           (read-char port)
           (read-list port))
          ((##eqv? c 35)            ;; #\#
           (read-char port) ;; skip "#"
           (let ((c (##field0 (peek-char port))))
             (cond ((##eqv? c 102)  ;; #\f
                    (read-char port) ;; skip "f"
                    #f)
                   ((##eqv? c 116)     ;; #\t
                    (read-char port) ;; skip "t"
                    #t)
                   ((##eqv? c 92)        ;; #\\
                    (read-char port) ;; skip "\\"
                    (let ((ch (peek-char port)))
                      (if (char-whitespace? ch) 
                        (read-char port)
                        (let ((str (read-symbol port (lambda (x) x))))
                          (cond 
                            ((null? str) (read-char port))
                            ((##eqv? (length str) 1) (integer->char (##field0 str)))
                            (else (integer->char (cadr (assoc (list->string (map char-downcase (map integer->char str))) special-chars)))))))))
                   ((##eqv? c 40)  ;; #\(
                     (list->vector (read port)))
                   (else 
                     (string->symbol (##list->string (append '(35) (read-symbol port char-downcase))))))))
          ((##eqv? c 39)      ;; #\'
           (read-char port) ;; skip "'"
           (list 'quote (read port)))
          ((##eqv? c 96)      ;; #\`
           (read-char port) ;; skip "`"
           (list 'quasiquote (read port)))
          ((##eqv? c 44)      ;; #\,
           (read-char port) ;; skip ","
           (let ((c (##field0 (peek-char port))))
             (if (##eqv? c 64)  ;; #\@
               (begin
                 (read-char port) ;; skip "@"
                 (list 'unquote-splicing (read port)))
               (list 'unquote (read port)))))
          ((##eqv? c 34)      ;; #\"
           (read-char port) ;; skip """
           (##list->string (read-chars '() port)))
          (else
            ;; (read-char port) ;; skip first char
            (let ((s (##list->string (read-symbol port char-downcase))))
              (let ((n (string->number s)))
                (or n
                    (string->symbol s))))))))

(define (read-list port)
  (let ((c (peek-char-non-whitespace port)))
    (cond 
      ((##eqv? c 41) ;; #\)
       (read-char port) ;; skip ")"
       '())
      (else (let ((first (read port)))
              (if (and (symbol? first) (equal? (symbol->string first) "."))
                (let ((result (read port)))
                  (read-char port)
                  result)
                (cons first (read-list port))))))))

(define (read-symbol port case-transform)
  ;; FIXME: change char-downcase to char-upcase
  (let ((c (##field0 (case-transform (peek-char port)))))
    (if (or (##eqv? c 40)  ;; #\(
            (##eqv? c 41)  ;; #\)
            (##eqv? c 0)   ;; eof
            (##< c 33))    ;; whitespace
        '()
        (begin
          (read-char port)
          (cons c (read-symbol port case-transform))))))

(define (read-chars lst port)
  (let ((c (##field0 (read-char port))))
    (cond ((##eqv? c 0) '())   ;; eof
          ((##eqv? c 34) (reverse lst))  ;; #\"
          ((##eqv? c 92)                 ;; #\\
           (let ((c2 (##field0 (read-char port))))
             (read-chars
              (##rib (cond
                     ;#; ;; support for \n in strings
                     ((##eqv? c2 110) 10) ;; #\n
                     ;#; ;; support for \r in strings
                     ((##eqv? c2 114) 13) ;; #\r
                     ;#; ;; support for \t in strings
                     ((##eqv? c2 116) 9)  ;; #\t
                     (else          c2))
                    lst 0)
              port)))
          (else
           (read-chars (cons c lst) port)))))

(define (peek-char-non-whitespace port)
  (let ((c (peek-char port)))
    (if (eof-object? c) ;; eof?
      c
      (if (char-whitespace? c) 
        (begin
          (read-char port)
          (peek-char-non-whitespace port))
        (if (##eqv? (##field0 c) 59) ;; #\;
          (skip-comment port)
          (##field0 c))))))  ;; returns the code point of the char

(define (skip-comment port)
  (let ((c (read-char port)))
    (if (eof-object? c)
        c
        (if (##eqv? (##field0 c) 10) ;; #\newline
            (peek-char-non-whitespace port)
            (skip-comment port)))))


;; ---------------------- OUTPUT ---------------------- ;;


(define (open-output-file filename)
  ;; (file_descriptor, is_open, write_file_type)
  (##rib (##get-fd-output-file filename) (##rib ##write-char "" #t) output-port-type))

(define (close-output-port port)
  (if (##field1 port)
    (begin
      (##field2-set! (##field1 port) #f)
      (##close-output-port (##field0 port)))))

(define (output-port-close? port)
  (not (##field2 (##field1 port))))

(define (current-output-port) stdout-port)

(define (call-with-output-file filename proc)
  (let* ((port (open-output-file filename))
         (result (proc port)))
    (close-output-port port)
    result))

(define (write-char ch (port (current-output-port)))
  ((##field0 (##field1 port)) ch port))  ;; call the writer with the char and the port
  ;(##field1-set! (##field1 port) (string-append (##field1 (##field1 port)) (string ch)))) ;; updates the inner accumulator

(define (write-char-code ch-code port)
  (write-char (integer->char ch-code) port))

(define (newline (port (current-output-port)))
  (write-char-code 10 port))  ;; #\newline

(define (write o (port (current-output-port)))
  (cond ((string? o)
         (write-char-code 34 port)     ;; #\"
         (write-chars (##field0 o) escapes port)
         (write-char-code 34 port))    ;; #\"
        ((char? o)
         (write-char-code 35 port)     ;; #\#
         (write-char-code 92 port)     ;; #\\
         (let ((name (assoc (##field0 o) (map reverse special-chars)))) 
           (if (not name)
             (write-char-code (##field0 o) port)
             (display (cadr name) port))))
        ((pair? o)
         (write-char-code 40 port)  ;; #\(
         (write (##field0 o) port) ;; car
         (print-list (##field1 o) write port) ;; cdr
         (write-char-code 41 port)) ;; #\)
        ((vector? o)
         (write-char-code 35 port)  ;; #\#
         (write-char-code 40 port)  ;; #\(
         (if (##< 0 (##field1 o))
           (let ((l (##field0 o)))   ;; vector->list
             (write (##field0 l) port)
             (print-list (##field1 l) write port)))
         (write-char-code 41 port)) ;; #\)
        (else
          (display o port))))

(define (display o (port (current-output-port)))
  (cond ((not o)
         (write-char-code 35 port)     ;; #\#
         (write-char-code 102 port))   ;; #f

        ((##eqv? o #t)
         (write-char-code 35 port)     ;; #\#
         (write-char-code 116 port))   ;; #t

        ((eof-object? o)
         (write-char-code 35 port)     ;; #\#
         (write-char-code 101 port))   ;; #e

        ((null? o)
         (write-char-code 40 port)  ;; #\(
         (write-char-code 41 port)) ;; #\)

        ((integer? o)
         (display (number->string o) port))

        ((or (input-port? o) (output-port? o))
         (display (vector (##field2 (##field1 o)) (##field2 o))))

        ((char? o)
         (write-char o port))

        ((pair? o)
         (write-char-code 40 port)  ;; #\(
         (display (##field0 o) port) ;; car
         (print-list (##field1 o) display port) ;; cdr
         (write-char-code 41 port)) ;; #\)

        ((symbol? o)
         (write-chars (##field0 (##field1 o)) '() port))

        ((string? o)
         (write-chars (##field0 o) '() port)) ;; chars

        ((vector? o)
         (write-char-code 35 port)  ;; #\#
         (write-char-code 40 port)  ;; #\(
         (if (##< 0 (##field1 o))
           (let ((l (##field0 o)))   ;; vector->list
             (display (##field0 l) port)
             (print-list (##field1 l) display port)))
         (write-char-code 41 port)) ;; #\)

        ((procedure? o)
         (write-char-code 35 port)  ;; #\#
         (write-char-code 112 port)) ;; #p

        ((##rib? o)
         (display (list (##field0 o) (##field1 o) (##field2 o))))

        (else
          (crash))))

(define (print-list lst mode port)
  (cond 
    ((pair? lst)
     (write-char-code 32 port) ;; #\space
     (mode (##field0 lst) port) ;; car
     (print-list (##field1 lst) mode port))  ;; cdr

    ((null? lst) #f)

    (else
      (write-char-code 32 port) ;; #\space
      (write-char-code 46 port) ;; #\.
      (write-char-code 32 port) ;; #\space
      (mode lst port))))

(define (write-chars lst escapes port)
  (if (pair? lst)
    (let ((escape (assq (##field0 lst) escapes)))
      (if (not escape)
        (write-char-code (##field0 lst) port)
        (begin
          (write-char-code 92 port)
          (write-char-code (cadr escape) port)))
      (write-chars (##field1 lst) escapes port))))


;; ---------------------- OPTIONAL PROC OF R4RS ---------------------- ;;

(define (with-input-from-file filename thunk)
  (let ((old-input-port current-input-port)
        (new-input-port (open-input-file filename)))
    (set! current-input-port (lambda () new-input-port))
    (let ((result (thunk)))
      (set! current-input-port old-input-port)
      (close-input-port new-input-port)
      result)))

(define (with-output-to-file filename thunk)
  (let ((old-output-port current-output-port)
        (new-output-port (open-output-file filename)))
    (set! current-output-port (lambda () new-output-port))
    (let ((result (thunk)))
      (set! current-output-port old-output-port)
      (close-output-port new-output-port)
      result)))

;; ---------------------- UTILS NOT IN R4RS ---------------------- ;;

(define (capture-output-from captured-port new-port thunk)
  (let ((old-write-char ##write-char))
    (set! ##write-char 
      (lambda (ch port) 
        (old-write-char ch
                        (if (##eqv? port captured-port)
                          new-port
                          port))))
    (let ((result (thunk)))
      (set! ##write-char old-write-char)
      result)))

(define (pp arg (port (current-output-port)))
  (write arg port)
  (newline port))

(define (read-all (port (current-input-port)))
  (let ((x (read port)))
    (if (eof-object? x)
        '()
        (cons x (read-all port)))))

(define (read-chars-until predicate (port (current-input-port)))
  (let read-chars-aux ((c (read-char port)) (result '()))
    (cond 
      ((predicate c) (list->string (reverse result)))
      ((eof-object? c) #f)
      (else (read-chars-aux (read-char port) (cons c result))))))

(define (read-str-until predicate (port (current-input-port)))
  (let read-str-aux ((c (read-char port)) (result ""))
    (cond 
      ((predicate result) result)
      ((eof-object? c) #f)
      (else (read-str-aux (read-char port) (string-append result (string c)))))))

(define (read-line (port (current-input-port)) (sep #\newline))
  (read-chars-until (lambda (c) (or (eof-object? c) (eqv? c sep))) port))

(define (read-lines-until predicate (port (current-input-port)))
  (let loop ((line (read-line port)) (lines '()))
    (if (predicate line)
      (reverse (cons line lines))
      (loop (read-line port) (cons line lines)))))

(define (string-from-file filename)
  (call-with-input-file filename (lambda (port) (read-str-until eof-object? port))))

(define (open-input-string str)
  (##rib 
   (string->list str)
   (##rib
    (lambda (port) 
      (if (null? (##field0 port)) ;; no more characters
        ##eof
        (let ((c (caar port)))
          (##field0-set! port (cdar port)) 
          c)))
    '() 
    #t)
   input-port-type))

(define (open-output-string (str ""))
  (##rib 
   str 
   (##rib
    (lambda (ch port)
      (##field0-set! port (string-append (##field0 port) (string ch))))
    ""
    #t)
   output-port-type))

(define (get-output-string port)
  (##field0 port))

(define (file-exists? filename) (notnot (##get-fd-input-file filename)))
