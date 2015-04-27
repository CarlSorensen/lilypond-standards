\version "2.19.12"

\header {
  lsrtags = "devel, scheme-language, tweaks-and-overrides"

  texidoc = "
When working with grob callbacks, it can be helpful to understand a
grob's @qq{ancestry}. Most grobs have @qq{parents} which influence the
positioning of the grob. X- and Y-parents influence the horizontal and
vertical positions for the grob, respectively. Additionally, each
parent may have parents of its own.


Unfortunately, there are several aspects of a grob's ancestry that can
lead to confusion:

* The types of parents a grob has may depend on context. * For some
grobs, the X- and Y-parents are the same. * A particular @qq{ancestor}
may be related to a grob in multiple ways. * The concept of
@qq{generations} is misleading.


For example, the @code{System} grob can be both parent (on the Y-side)
and grandparent (twice on the X-side) to a @code{VerticalAlignment}
grob.


This macro prints (to the console) a textual representation of a grob's
ancestry.


When called this way


@{
 \\once \\override NoteHead.before-line-breaking = #display-ancestry
 c @}


The following output is generated:


------------------------------------

NoteHead X,Y: NoteColumn
    X: PaperColumn
       X,Y: System
    Y: VerticalAxisGroup
       X: NonMusicalPaperColumn
          X,Y: System
       Y: VerticalAlignment
          X: NonMusicalPaperColumn
             X,Y: System
          Y: System



"
  doctitle = "Displaying grob ancestry"
}
%% http://lsr.di.unimi.it/LSR/Item?id=622
%% see also http://www.lilypond.org/doc/v2.18/Documentation/snippets/tweaks-and-overrides#tweaks-and-overrides-displaying-grob-ancestry

#(define (grob-name grob)
   (if (ly:grob? grob)
       (assoc-ref (ly:grob-property grob 'meta) 'name)
       #f))

#(define (get-ancestry grob)
   (if (not (null? (ly:grob-parent grob X)))
       (list (grob-name grob)
             (get-ancestry (ly:grob-parent grob X))
             (get-ancestry (ly:grob-parent grob Y)))
       (grob-name grob)))

#(define (format-ancestry lst padding)
   (string-append
    (symbol->string (car lst))
    "\n"
    (let ((X-ancestry
           (if (list? (cadr lst))
               (format-ancestry (cadr lst) (+ padding 3))
               (symbol->string (cadr lst))))
          (Y-ancestry
           (if (list? (caddr lst))
               (format-ancestry (caddr lst) (+ padding 3))
               (symbol->string (caddr lst)))))
      (if (equal? X-ancestry Y-ancestry)
          (string-append
           (format #f "~&")
           (make-string padding #\space)
           "X,Y: "
           (if (list? (cadr lst))
               (format-ancestry (cadr lst) (+ padding 5))
               (symbol->string (cadr lst))))
          (string-append
           (format #f "~&")
           (make-string padding #\space)
           "X: " X-ancestry
           "\n"
           (make-string padding #\space)
           "Y: " Y-ancestry
           (format #f "~&"))))
    (format #f "~&")))

#(define (display-ancestry grob)
   (format (current-error-port)
      "~3&~a~2%~a~&"
      (make-string 36 #\-)
      (format-ancestry (get-ancestry grob) 0)))

\relative c' {
  \once \override NoteHead.before-line-breaking = #display-ancestry
  f4
  \once \override Accidental.before-line-breaking = #display-ancestry
  \once \override Arpeggio.before-line-breaking = #display-ancestry
  <f as c>4\arpeggio
}
