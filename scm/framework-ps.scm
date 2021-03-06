;;;; This file is part of LilyPond, the GNU music typesetter.
;;;;
;;;; Copyright (C) 2004--2015 Han-Wen Nienhuys <hanwen@xs4all.nl>
;;;;
;;;; LilyPond is free software: you can redistribute it and/or modify
;;;; it under the terms of the GNU General Public License as published by
;;;; the Free Software Foundation, either version 3 of the License, or
;;;; (at your option) any later version.
;;;;
;;;; LilyPond is distributed in the hope that it will be useful,
;;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;; GNU General Public License for more details.
;;;;
;;;; You should have received a copy of the GNU General Public License
;;;; along with LilyPond.  If not, see <http://www.gnu.org/licenses/>.

(define-module (scm framework-ps))

;;; this is still too big a mess.

(use-modules (ice-9 string-fun)
             (guile)
             (scm page)
             (scm paper-system)
             (srfi srfi-1)
             (srfi srfi-13)
             (scm clip-region)
             (lily))

(define format ergonomic-simple-format)

(define framework-ps-module (current-module))

;;(define pdebug stderr)
(define (pdebug . rest) #f)

(define-public (ps-font-command font)
  (let* ((name (ly:font-file-name font))
         (magnify (ly:font-magnification font)))
    (string-append
     "magfont"
     (ly:string-substitute
      " " "_"
      (ly:string-substitute
       "/" "_"
       (ly:string-substitute
        "%" "_" name)))
     "m" (string-encode-integer (inexact->exact (round (* 1000 magnify)))))))

(define (ps-define-pango-pf pango-pf font-name scaling)
  "")

(define (ps-define-font font font-name scaling)
  (if (ly:bigpdfs)
      (string-append
       "/" (ps-font-command font) "-N"
       " { /" font-name "-N"
       " " (ly:number->string scaling) " output-scale div selectfont }"
       " bind def\n"
       "/" (ps-font-command font) "-S"
       " { /" font-name "-S"
       " " (ly:number->string scaling) " output-scale div selectfont }"
       " bind def\n"
       "/" (ps-font-command font) "-O"
       " { /" font-name "-O"
       " " (ly:number->string scaling) " output-scale div selectfont }"
       " bind def\n"
       "/help" font-name " {\n  gsave\n  1 setgray\n  /"
       font-name "-N"
       " 0.001 selectfont 0 0 moveto <01> show\n  /"
       font-name "-S"
       " 0.001 selectfont 0 0 moveto <01> show\n  /"
       font-name "-O"
       " 0.001 selectfont 0 0 moveto <01> show\n  grestore\n} def\n")
      (string-append
       "/" (ps-font-command font)
       " { /" font-name
       " " (ly:number->string scaling) " output-scale div selectfont }"
       " bind def\n")))

;; FIXME: duplicated in other output backends
;; FIXME: silly interface name
(define (output-variables layout)
  ;; FIXME: duplicates output-layout's scope-entry->string, mostly
  (define (value->string val)
    (cond
     ((string? val) (string-append "(" val ")"))
     ((symbol? val) (symbol->string val))
     ((number? val) (number->string val))
     (else "")))

  (define (output-entry ps-key ly-key)
    (string-append
     "/" ps-key " "
     (value->string (ly:output-def-lookup layout ly-key)) " def\n"))

  (string-append
   "/lily-output-units "
   (number->string (/ (ly:bp 1))) " def %% millimeter\n"
   (output-entry "staff-line-thickness" 'line-thickness)
   (output-entry "line-width" 'line-width)
   (output-entry "paper-size" 'papersizename)
   (output-entry "staff-height" 'staff-height)  ;junkme.
   "/output-scale "
   (number->string (ly:output-def-lookup layout 'output-scale)) " def\n"
   (output-entry "page-height" 'paper-height)
   (output-entry "page-width" 'paper-width)
   (if (ly:get-option 'strokeadjust) "true setstrokeadjust\n" "")
   ))

(define (dump-page outputter page page-number page-count landscape?)
  (ly:outputter-dump-string
   outputter
   (string-append
    (format #f "%%Page: ~a ~a\n" page-number page-number)
    "%%BeginPageSetup\n"
    (if landscape?
        "page-width output-scale lily-output-units mul mul 0 translate 90 rotate\n"
        "")
    "%%EndPageSetup\n"
    "\n"
    "gsave 0 paper-height translate set-ps-scale-to-lily-scale\n"
    "/helpEmmentaler-Brace where {pop helpEmmentaler-Brace} if\n"
    "/helpEmmentaler-11 where {pop helpEmmentaler-11} if\n"
    "/helpEmmentaler-13 where {pop helpEmmentaler-13} if\n"
    "/helpEmmentaler-14 where {pop helpEmmentaler-14} if\n"
    "/helpEmmentaler-16 where {pop helpEmmentaler-16} if\n"
    "/helpEmmentaler-18 where {pop helpEmmentaler-18} if\n"
    "/helpEmmentaler-20 where {pop helpEmmentaler-20} if\n"
    "/helpEmmentaler-23 where {pop helpEmmentaler-23} if\n"
    "/helpEmmentaler-26 where {pop helpEmmentaler-26} if\n"))
  (ly:outputter-dump-stencil outputter page)
  (ly:outputter-dump-string outputter "stroke grestore\nshowpage\n"))

(define (supplies-or-needs paper load-fonts?)
  (define (extract-names font)
    (if (ly:pango-font? font)
        (map car (ly:pango-font-physical-fonts font))
        (list (ly:font-name font))))

  (let* ((fonts (ly:paper-fonts paper))
         (names (append-map extract-names fonts)))
    (string-concatenate
     (map (lambda (f)
            (format #f
                    (if load-fonts?
                        "%%DocumentSuppliedResources: font ~a\n"
                        "%%DocumentNeededResources: font ~a\n")
                    f))
          (uniq-list (sort names string<?))))))

(define (eps-header paper bbox load-fonts?)
  (string-append "%!PS-Adobe-2.0 EPSF-2.0\n"
                 "%%Creator: LilyPond " (lilypond-version) "\n"
                 "%%BoundingBox: "
                 (string-join (map ly:number->string bbox) " ") "\n"
                 "%%Orientation: "
                 (if (eq? (ly:output-def-lookup paper 'landscape) #t)
                     "Landscape\n"
                     "Portrait\n")
                 (supplies-or-needs paper load-fonts?)
                 "%%EndComments\n"))

(define (ps-document-media paper)
  (let* ((w (/ (*
                (ly:output-def-lookup paper 'output-scale)
                (ly:output-def-lookup paper 'paper-width)) (ly:bp 1)))
         (h (/ (*
                (ly:output-def-lookup paper 'paper-height)
                (ly:output-def-lookup paper 'output-scale))
               (ly:bp 1)))
         (landscape? (eq? (ly:output-def-lookup paper 'landscape) #t)))
    (ly:format "%%DocumentMedia: ~a ~2f ~2f ~a ~a ~a\n"
               (ly:output-def-lookup paper 'papersizename)
               (if landscape? h w)
               (if landscape? w h)
               80   ;; weight
               "()" ;; color
               "()" ;; type
               )))

(define (file-header paper page-count load-fonts?)
  (string-append "%!PS-Adobe-3.0\n"
                 "%%Creator: LilyPond " (lilypond-version) "\n"
                 "%%Pages: " (number->string page-count) "\n"
                 "%%PageOrder: Ascend\n"
                 "%%Orientation: "
                 (if (eq? (ly:output-def-lookup paper 'landscape) #t)
                     "Landscape\n"
                     "Portrait\n")
                 (ps-document-media paper)
                 (supplies-or-needs paper load-fonts?)
                 "%%EndComments\n"))

(define (procset file-name)
  (format #f
          "%%BeginResource: procset (~a) 1 0
~a
%%EndResource
"
          file-name (cached-file-contents file-name)))

(define (embed-document file-name)
  (format #f "%%BeginDocument: ~a
~a
%%EndDocument
"
          file-name (cached-file-contents file-name)))

(define (setup-variables paper)
  (string-append
   "\n"
   (define-fonts paper ps-define-font ps-define-pango-pf)
   (output-variables paper)))

(define (cff-font? font)
  (let* ((cff-string (ly:otf-font-table-data font "CFF ")))
    (> (string-length cff-string) 0)))

(define-public (ps-embed-cff body font-set-name version)
  (let* ((binary-data
          (string-append
           (format #f "/~a ~s StartData " font-set-name (string-length body))
           body))
         (header
          (format #f
                  "%%BeginResource: font ~a
%!PS-Adobe-3.0 Resource-FontSet
%%DocumentNeededResources: ProcSet (FontSetInit)
%%Title: (FontSet/~a)
%%Version: ~s
%%EndComments
%%IncludeResource: ProcSet (FontSetInit)
%%BeginResource: FontSet (~a)
/FontSetInit /ProcSet findresource begin
%%BeginData: ~s Binary Bytes
"
                  font-set-name font-set-name version font-set-name
                  (string-length binary-data)))
         (footer "\n%%EndData
%%EndResource
%%EndResource\n"))
    (string-append header
                   binary-data
                   footer)))

(define (write-preamble paper load-fonts? port)
  (define (internal-font? file-name)
    (or (string-startswith file-name "Emmentaler")
        (string-startswith file-name "emmentaler")
        ))

  (define (load-font-via-GS font-name-filename)
    (define (ps-load-file file-name)
      (if (string? file-name)
          (if (string-contains file-name (ly:get-option 'datadir))
              (begin
                (set! file-name (ly:string-substitute (ly:get-option 'datadir)
                                                      "" file-name))
                (format #f
                        "lilypond-datadir (~a) concatstrings (r) file .loadfont\n"
                        file-name))
              (format #f "(~a) (r) file .loadfont\n" file-name))
          (format #f "% cannot find font file: ~a\n" file-name)))

    (let* ((font (car font-name-filename))
           (name (cadr font-name-filename))
           (file-name (caddr font-name-filename))
           (bare-file-name (ly:find-file file-name)))
      (cons name
            (if (mac-font? bare-file-name)
                (handle-mac-font name bare-file-name)
                (cond
                 ((internal-font? file-name)
                  (ps-load-file (ly:find-file
                                 (format #f "~a.otf" file-name))))
                 ((string? bare-file-name)
                  (ps-load-file file-name))
                 (else
                  (ly:warning (_ "cannot embed ~S=~S") name file-name)
                  ""))))))

  (define (dir-join a b)
    (if (equal? a "")
        b
        (string-append a "/" b)))

  (define (dir-listing dir-name)
    (define (dir-helper dir lst)
      (let ((e (readdir dir)))
        (if (eof-object? e)
            lst
            (dir-helper dir (cons e lst)))))
    (reverse (dir-helper (opendir dir-name) '())))

  (define (handle-mac-font name file-name)
    (let* ((dir-name (tmpnam))
           (files '())
           (status 0)
           (embed #f)
           (cwd (getcwd)))
      (mkdir dir-name #o700)
      (chdir dir-name)
      (set! status (ly:system (list "fondu" "-force" file-name)))
      (chdir cwd)
      (set! files (dir-listing dir-name))
      (for-each
       (lambda (f)
         (let* ((full-name (dir-join dir-name f)))
           (if (and (not embed)
                    (equal? 'regular (stat:type (stat full-name)))
                    (equal? name (ly:ttf-ps-name full-name)))
               (set! embed (font-file-as-ps-string name full-name 0)))
           (if (or (equal? "." f)
                   (equal? ".." f))
               #t
               (delete-file full-name))))
       files)
      (rmdir dir-name)
      (if (not embed)
          (begin
            (set! embed "% failed\n")
            (ly:warning (_ "cannot extract file matching ~a from ~a")
                        name file-name)))
      embed))

  (define (font-file-as-ps-string name file-name font-index)
    (let* ((downcase-file-name (string-downcase file-name)))
      (cond
       ((and file-name (string-endswith downcase-file-name ".pfa"))
        (embed-document file-name))
       ((and file-name (string-endswith downcase-file-name ".pfb"))
        (ly:pfb->pfa file-name))
       ((and file-name (string-endswith downcase-file-name ".ttf"))
        (ly:ttf->pfa file-name))
       ((and file-name (string-endswith downcase-file-name ".ttc"))
        (ly:ttf->pfa file-name font-index))
       ((and file-name (string-endswith downcase-file-name ".otf"))
        (ps-embed-cff (ly:otf->cff file-name) name 0))
       (else
        (ly:warning (_ "do not know how to embed ~S=~S") name file-name)
        ""))))

  (define (mac-font? bare-file-name)
    (and (eq? PLATFORM 'darwin)
         bare-file-name
         (or (string-endswith bare-file-name ".dfont")
             (= (stat:size (stat bare-file-name)) 0))))

  (define (load-font font-psname-filename-fontindex)
    (let* ((font (list-ref font-psname-filename-fontindex 0))
           (name (list-ref font-psname-filename-fontindex 1))
           (file-name (list-ref font-psname-filename-fontindex 2))
           (font-index (list-ref font-psname-filename-fontindex 3))
           (bare-file-name (ly:find-file file-name)))
      (cons name
            (cond ((mac-font? bare-file-name)
                   (handle-mac-font name bare-file-name))
                  ((and font (cff-font? font))
                   (ps-embed-cff (ly:otf-font-table-data font "CFF ")
                                 name
                                 0))
                  (bare-file-name (font-file-as-ps-string
                                   name bare-file-name font-index))
                  (else
                   (ly:warning (_ "do not know how to embed font ~s ~s ~s")
                               name file-name font))))))

  (define (load-fonts paper)
    (let* ((fonts (ly:paper-fonts paper))

           ;; todo - doc format of list.
           (all-font-names
            (map
             (lambda (font)
               (cond ((string? (ly:font-file-name font))
                      (list (list font
                                  (ly:font-name font)
                                  (ly:font-file-name font)
                                  #f)))
                     ((ly:pango-font? font)
                      (map (lambda (psname-filename-fontindex)
                             (list #f
                                   (list-ref psname-filename-fontindex 0)
                                   (list-ref psname-filename-fontindex 1)
                                   (list-ref psname-filename-fontindex 2)))
                           (ly:pango-font-physical-fonts font)))
                     (else
                      (ly:font-sub-fonts font))))
             fonts))
           (font-names (uniq-list
                        (sort (concatenate all-font-names)
                              (lambda (x y) (string<? (cadr x) (cadr y))))))

           ;; slightly spaghetti-ish: deciding what to load where
           ;; is smeared out.
           (font-loader
            (lambda (name)
              (cond ((ly:get-option 'gs-load-fonts)
                     (load-font-via-GS name))
                    ((ly:get-option 'gs-load-lily-fonts)
                     (if (or (string-contains (caddr name)
                                              (ly:get-option 'datadir))
                             (internal-font? (caddr name)))
                         (load-font-via-GS name)
                         (load-font name)))
                    (else
                     (load-font name)))))
           (pfas (map font-loader font-names)))
      pfas))


  (display "%%BeginProlog\n" port)
  (format
   port
   "/lilypond-datadir where {pop} {userdict /lilypond-datadir (~a) put } ifelse"
   (ly:get-option 'datadir))
  (if load-fonts?
      (for-each (lambda (f)
                  (format port "\n%%BeginFont: ~a\n" (car f))
                  (display (cdr f) port)
                  (display "%%EndFont\n" port))
                (load-fonts paper)))
  (if (ly:bigpdfs)
      (display (procset "encodingdefs.ps") port))
  (display (setup-variables paper) port)

  ;; adobe note 5002: should initialize variables before loading routines.
  (display (procset "music-drawing-routines.ps") port)
  (display (procset "lilyponddefs.ps") port)
  (display "%%EndProlog\n" port)
  (display "%%BeginSetup\ninit-lilypond-parameters\n%%EndSetup\n\n" port))

(define (ps-quote str)
  (fold
   (lambda (replacement-list result)
     (string-join
      (string-split
       result
       (car replacement-list))
      (cadr replacement-list)))
   str
   '((#\\ "\\\\") (#\( "\\(") (#\) "\\)"))))

;;; Create DOCINFO pdfmark containing metadata
;;; header fields with pdf prefix override those without the prefix
(define (handle-metadata header port)
  (define (metadata-encode val)
    ;; First, call ly:encode-string-for-pdf to encode the string (latin1 or
    ;; utf-16be), then escape all parentheses and backslashes
    ;; FIXME guile-2.0: use (string->utf16 str 'big) instead

    (ps-quote (ly:encode-string-for-pdf val)))
  (define (metadata-lookup-output overridevar fallbackvar field)
    (let* ((overrideval (ly:modules-lookup (list header) overridevar))
           (fallbackval (ly:modules-lookup (list header) fallbackvar))
           (val (if overrideval overrideval fallbackval)))
      (if val
          (format port "/~a (~a)\n" field (metadata-encode (markup->string val (list header)))))))
  (display "[ " port)
  (metadata-lookup-output 'pdfcomposer 'composer "Author")
  (format port "/Creator (LilyPond ~a)\n" (lilypond-version))
  (metadata-lookup-output 'pdftitle 'title "Title")
  (metadata-lookup-output 'pdfsubject 'subject "Subject")
  (metadata-lookup-output 'pdfkeywords 'keywords "Keywords")
  (metadata-lookup-output 'pdfmodDate 'modDate "ModDate")
  (metadata-lookup-output 'pdfsubtitle 'subtitle "Subtitle")
  (metadata-lookup-output 'pdfcomposer 'composer "Composer")
  (metadata-lookup-output 'pdfarranger 'arranger "Arranger")
  (metadata-lookup-output 'pdfpoet 'poet "Poet")
  (metadata-lookup-output 'pdfcopyright 'copyright "Copyright")
  (display "/DOCINFO pdfmark\n\n" port))


(define-public (output-framework basename book scopes fields)
  (let* ((filename (format #f "~a.ps" basename))
         (outputter (ly:make-paper-outputter
                     ;; FIXME: better wrap open/open-file,
                     ;; content-mangling is always bad.
                     ;; MINGW hack: need to have "b"inary for embedding CFFs
                     (open-file filename "wb")
                     'ps))
         (paper (ly:paper-book-paper book))
         (header (ly:paper-book-header book))
         (systems (ly:paper-book-systems book))
         (page-stencils (map page-stencil (ly:paper-book-pages book)))
         (landscape? (eq? (ly:output-def-lookup paper 'landscape) #t))
         (page-number (1- (ly:output-def-lookup paper 'first-page-number)))
         (page-count (length page-stencils))
         (port (ly:outputter-port outputter)))
    (if (ly:get-option 'clip-systems)
        (clip-system-EPSes basename book))
    (if (ly:get-option 'dump-signatures)
        (write-system-signatures basename (ly:paper-book-systems book) 1))
    (output-scopes scopes fields basename)
    (display (file-header paper page-count #t) port)
    ;; don't do BeginDefaults PageMedia: A4
    ;; not necessary and wrong
    (write-preamble paper #t port)
    (if (module? header)
        (handle-metadata header port))
    (for-each
     (lambda (page)
       (set! page-number (1+ page-number))
       (dump-page outputter page page-number page-count landscape?))
     page-stencils)
    (display "%%Trailer\n%%EOF\n" port)
    (ly:outputter-close outputter)
    (postprocess-output book framework-ps-module filename
                        (ly:output-formats))))

(define-public (dump-stencil-as-EPS paper dump-me filename
                                    load-fonts)
  (let* ((xext (ly:stencil-extent dump-me X))
         (yext (ly:stencil-extent dump-me Y))
         (padding (ly:get-option 'eps-box-padding))
         (left-overshoot (if (number? padding)
                             (* -1 padding (ly:output-def-lookup paper 'mm))
                             #f))
         (bbox
          (map
           (lambda (x)
             (if (or (nan? x) (inf? x)
                     ;; FIXME: huh?
                     (equal? (format #f "~S" x) "+#.#")
                     (equal? (format #f "~S" x) "-#.#"))
                 0.0 x))

           ;; the left-overshoot is to make sure that
           ;; bar numbers stick out of margin uniformly.
           ;;
           (list
            (if (number? left-overshoot)
                (min left-overshoot (car xext))
                (car xext))
            (car yext) (cdr xext) (cdr yext)))))
    (dump-stencil-as-EPS-with-bbox paper dump-me filename load-fonts bbox)))

(define-public (dump-stencil-as-EPS-with-bbox paper dump-me filename
                                              load-fonts
                                              bbox)
  "Create an EPS file from stencil @var{dump-me} to @var{filename}.
@var{bbox} has format @code{(left-x, lower-y, right-x, upper-y)}.  If
@var{load-fonts} set, include fonts inline."
  (define (to-rounded-bp-box box)
    "Convert box to 1/72 inch with rounding to enlarge the box."
    (let* ((scale (ly:output-def-lookup paper 'output-scale))
           (strip-non-number (lambda (x)
                               (if (or (nan? x)
                                       (inf? x))
                                   0.0
                                   x)))
           (directed-round (lambda (x rounder)
                             (inexact->exact
                              (rounder (/ (* (strip-non-number x) scale)
                                          (ly:bp 1)))))))
      (list (directed-round (car box) floor)
            (directed-round (cadr box) floor)
            (directed-round (max (1+ (car box)) (caddr box)) ceiling)
            (directed-round (max (1+ (cadr box)) (cadddr box)) ceiling))))

  (let* ((outputter (ly:make-paper-outputter
                     ;; FIXME: better wrap open/open-file,
                     ;; content-mangling is always bad.
                     ;; MINGW hack: need to have "b"inary for embedding CFFs
                     (open-file (format #f "~a.eps" filename) "wb")
                     'ps))
         (port (ly:outputter-port outputter))
         (rounded-bbox (to-rounded-bp-box bbox))
         (port (ly:outputter-port outputter))
         (header (eps-header paper rounded-bbox load-fonts)))
    (display header port)
    (write-preamble paper load-fonts port)
    (display "/mark_page_link { pop pop pop pop pop } bind def\n" port)
    (display "gsave set-ps-scale-to-lily-scale\n" port)
    (display "/helpEmmentaler-Brace where {pop helpEmmentaler-Brace} if\n" port)
    (display "/helpEmmentaler-11 where {pop helpEmmentaler-11} if\n" port)
    (display "/helpEmmentaler-13 where {pop helpEmmentaler-13} if\n" port)
    (display "/helpEmmentaler-14 where {pop helpEmmentaler-14} if\n" port)
    (display "/helpEmmentaler-16 where {pop helpEmmentaler-16} if\n" port)
    (display "/helpEmmentaler-18 where {pop helpEmmentaler-18} if\n" port)
    (display "/helpEmmentaler-20 where {pop helpEmmentaler-20} if\n" port)
    (display "/helpEmmentaler-23 where {pop helpEmmentaler-23} if\n" port)
    (display "/helpEmmentaler-26 where {pop helpEmmentaler-26} if\n" port)
    (ly:outputter-dump-stencil outputter dump-me)
    (display "stroke grestore\n%%Trailer\n%%EOF\n" port)
    (ly:outputter-close outputter)))

(define (clip-systems-to-region basename paper systems region do-pdf do-png)
  (let* ((extents-system-pairs
          (filtered-map (lambda (paper-system)
                          (let* ((x-ext (system-clipped-x-extent
                                         (paper-system-system-grob paper-system)
                                         region)))
                            (if x-ext
                                (cons x-ext paper-system)
                                #f)))
                        systems))
         (count 0))
    (for-each
     (lambda (ext-system-pair)
       (let* ((xext (car ext-system-pair))
              (paper-system (cdr ext-system-pair))
              (yext (paper-system-extent paper-system Y))
              (bbox (list (car xext) (car yext)
                          (cdr xext) (cdr yext)))
              (filename (if (< 0 count)
                            (format #f "~a-~a" basename count)
                            basename)))
         (set! count (1+ count))
         (dump-stencil-as-EPS-with-bbox paper
                                        (paper-system-stencil paper-system)
                                        filename
                                        (ly:get-option 'include-eps-fonts)
                                        bbox)
         (if do-pdf
             (postscript->pdf 0 0 (format #f "~a.eps" filename)))
         (if do-png
             (postscript->png (ly:get-option 'resolution) 0 0
                              (format #f "~a.eps" filename)))))
     extents-system-pairs)))

(define-public (clip-system-EPSes basename paper-book)
  (define do-pdf
    (member "pdf" (ly:output-formats)))
  (define do-png
    (member "png" (ly:output-formats)))

  (define (clip-score-systems basename systems)
    (let* ((layout (ly:grob-layout (paper-system-system-grob (car systems))))
           (regions (ly:output-def-lookup layout 'clip-regions)))
      (for-each
       (lambda (region)
         (clip-systems-to-region
          (format #f "~a-from-~a-to-~a-clip"
                  basename
                  (rhythmic-location->file-string (car region))
                  (rhythmic-location->file-string (cdr region)))
          layout systems region
          do-pdf do-png))
       regions)))

  ;; partition in system lists sharing their layout blocks
  (let* ((systems (ly:paper-book-systems paper-book))
         (count 0)
         (score-system-list '()))
    (fold
     (lambda (system last-system)
       (if (not (and last-system
                     (equal? (paper-system-layout last-system)
                             (paper-system-layout system))))
           (set! score-system-list (cons '() score-system-list)))
       (if (paper-system-layout system)
           (set-car! score-system-list (cons system (car score-system-list))))
       ;; pass value.
       system)
     #f
     systems)
    (for-each (lambda (system-list)
                ;; filter out headers and top-level markup
                (if (pair? system-list)
                    (clip-score-systems
                     (if (> count 0)
                         (format #f "~a-~a" basename count)
                         basename)
                     system-list)))
              score-system-list)))

(define-public (output-preview-framework basename book scopes fields)
  (let* ((paper (ly:paper-book-paper book))
         (systems (relevant-book-systems book))
         (to-dump-systems (relevant-dump-systems systems)))
    (dump-stencil-as-EPS paper
                         (stack-stencils Y DOWN 0.0
                                         (map paper-system-stencil
                                              (reverse to-dump-systems)))
                         (format #f "~a.preview" basename)
                         #t)
    (postprocess-output book framework-ps-module
                        (format #f "~a.preview.eps" basename)
                        (cons "png" (ly:output-formats)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (output-width-height defs)
  (let* ((landscape (ly:output-def-lookup defs 'landscape))
         (output-scale (ly:output-def-lookup defs 'output-scale))
         (convert (lambda (x)
                    (* x output-scale (/ (ly:bp 1)))))
         (paper-width (convert (ly:output-def-lookup defs 'paper-width)))
         (paper-height (convert (ly:output-def-lookup defs 'paper-height)))
         (w (if landscape paper-height paper-width))
         (h (if landscape paper-width paper-height)))
    (cons w h)))

(define (output-resolution defs)
  (let ((defs-resolution (ly:output-def-lookup defs 'pngresolution)))
    (if (number? defs-resolution)
        defs-resolution
        (ly:get-option 'resolution))))

(define (output-filename name)
  (if (equal? (basename name ".ps") "-")
      (string-append "./" name)
      name))

(define-public (convert-to-pdf book name)
  (let* ((defs (ly:paper-book-paper book))
         (width-height (output-width-height defs))
         (width (car width-height))
         (height (cdr width-height))
         (filename (output-filename name)))
    (postscript->pdf width height filename)))

(define-public (convert-to-png book name)
  (let* ((defs (ly:paper-book-paper book))
         (resolution (output-resolution defs))
         (width-height (output-width-height defs))
         (width (car width-height))
         (height (cdr width-height))
         (filename (output-filename name)))
    (postscript->png resolution width height filename)))

(define-public (convert-to-ps book name)
  #t)

(define-public (output-classic-framework basename book scopes fields)
  (ly:error (_ "\nThe PostScript backend does not support the
system-by-system output.  For that, use the EPS backend instead,

  lilypond -dbackend=eps FILE

If have cut & pasted a lilypond fragment from a webpage, be sure
to only remove anything before

  %% ****************************************************************
  %% Start cut-&-pastable-section
  %% ****************************************************************
")))
