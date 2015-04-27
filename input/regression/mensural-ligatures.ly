\version "2.17.6"

\header {
  texidoc = "Mensural ligatures show different shapes, depending on the
  rhythmical pattern and direction of the melody line."
}


\layout {
  ragged-right = ##t
  indent = 0.0
  \context {
    \Voice
    \remove "Ligature_bracket_engraver"
    \consists "Mensural_ligature_engraver"
  }
  \context {
    \Score
    \override SpacingSpanner.packed-spacing = ##t
    \override PaperColumn.keep-inside-line = ##f
  }
}

\context Voice {
  \clef "petrucci-c4"
  \set Staff.printKeyCancellation = ##f
  \cadenzaOn % turn off bar lines
  \accidentalStyle forget
  \textLengthOn

% ligaturae binaria

  \[
    b\breve^\markup { \column { { \bold "ligaturae binaria" } "BL" } }
    g\longa
    \]

  \[
    g\breve^\markup { "BL" }
    b\longa
    \]

  \[
    b\longa^\markup { "LL" }
    g
    \]

  \[
    g\longa^\markup { "LL" }
    b
    \]

  \[
    b\breve^\markup { "BB" }
    g
    \]

  \[
    g\breve^\markup { "BB" }
    b
    \]

  \[
    b\longa^\markup { "LB" }
    g\breve
    \]

  \[
    g\longa^\markup { "LB" }
    b\breve
    \]

  \[
    b1^\markup { "SS" }
    g
    \]

  \[
    g1^\markup { "SS" }
    b
    \]

  \bar "|" \break

% ligaturae ternariae, quaternariae, etc. (sicut in Apel[1])

  \[
    b\breve^\markup {
      \column { { \bold "ligaturae ternariae, quaternariae, etc." } "BBL" } }
    a
    g\longa
    \]

  \[
    a\breve^\markup { "BBBB" }
    g
    a
    b
    \]

  \[
    b1^\markup { "SSBBBLB" }
    a
    g\breve
    a
    b
    a\longa
    b\breve
    \]

  \[
    a\longa^\markup { "LBMxBL" }
    g\breve
    a\maxima
    b\breve
    a\longa
    \]

  \[
    d'\breve^\markup { "BBBBLL" }
    c'
    f
    d'
    b\longa
    g
    \]

  \[
    c'1^\markup { "SSBLLBB" }
    b
    g\breve
    d'\longa
    a
    c'\breve
    b
    \]

  \bar "|" \break

% examples from "dtv-Atlas zur Musik" [2]

  \[
    d'\breve^\markup { \column { { \bold "dtv-Atlas" } "BBL" } }
    c'
    b\longa
    \]

  \[
    a\breve^\markup { "BBBL" }
    b
    c'
    d'\longa
    \]

  \[
    b\longa.^\markup { "L.B.BBLBBB" }
    g\breve.
    a\breve
    b
    c'\longa
    a\breve
    b
    a
    \]

  \[
    c'1^\markup { "SSBB" }
    b
    g\breve
    a
    \]

  \[
    b\longa^\markup { "LBL" }
    a\breve
    c'\longa
    \]

  \[
    a1^\markup { "SSBL" }
    b
    d'\breve
    c'\longa
    \]

  \bar "|" \break

% some ligatures from Ockeghem: Missa De plus en plus

  \[
    c'\maxima^\markup {
      \column { { \bold "Ockeghem: Missa De plus en plus" } "MxMx" } }
    g
    \]

  \[
    d\longa^\markup { "LBBBB" }
    c\breve
    f
    e
    d
    \]

  \[
    c'\maxima^\markup { "MxL" }
    d'\longa
    \]

  \[
    e'\breve^\markup { "BBB" }
    d'
    c'
    \]

  \[
    \override NoteHead.style = #'blackpetrucci
    b\longa^\markup { "LBBBBB." }
    c'\breve
    d'
    g
    \once \override NoteHead.ligature-flexa = ##t
    f
    \revert NoteHead.style
    g\breve.
    \]

  \[
    g\breve^\markup { "BBBBL" }
    b
    c'
    e'
    d'\longa
    \]

  \[
    \override NoteHead.style = #'blackpetrucci
    e'1^\markup { "SSB" }
    a
    g\breve
    \revert NoteHead.style
    \]

  \[
    g\longa^\markup { "LLLL" }
    b
    c'
    e'
    \]

  \[
    \override NoteHead.style = #'blackpetrucci
    e'\longa^\markup { "LBB" }
    f'\breve
    \revert NoteHead.style
    e'
    \]

  \[
    \override NoteHead.style = #'blackpetrucci
    b\breve^\markup { "BBBBBBL" }
    g
    \override NoteHead.ligature-flexa = ##t
    \override NoteHead.flexa-width = #3
    f
    f'
    \override NoteHead.flexa-width = #5
    b
    c'
    \revert NoteHead.style
    % though ligature-flexa is still ##t, this pair must be drawn as recta
    b\longa
    \revert NoteHead.flexa-width
    \revert NoteHead.ligature-flexa
    \]

  \bar "|" \break

% some from the Requiem

  \[
    a1^\markup { \column { { \bold "Ockeghem: Requiem" } "SSBBBBBBBL" } }
    d
    e\breve
    f
    d
    f
    e
    f
    g
    e\longa
    \]

  \[
    c'\breve^\markup { "BBBBL" }
    c
    d
    c
    c'\longa
    \]

  \bar "|" \break
}

\context Staff \with
{
  \override StaffSymbol.line-count = #4
}
{
  \clef "petrucci-c5"
  \set Staff.printKeyCancellation = ##f
  \cadenzaOn % turn off bar lines
  \accidentalStyle forget
  \textLengthOn

  \[
    c\breve^\markup { \column { { \bold "crazy ligatures" } "BBBBB" } }
    e
    f
    g
    bes
    \]

  \[
    bes\breve^\markup { "BB" }
    a
    \] % TODO: accidentals must be collected and printed before ligature

  \[
    a\breve.^\markup { "B.B.B.B.B.B.B.B.B." }
    g
    b
    a
    e
    g
    f
    a
    g
    \]

  \[
    b^\markup { "B.B." }
    a
    \] % TODO the first dot is too high to avoid a non-existent (ledger) line

  \bar "|" \break

% invalid ligatures (those commented out are rejected with explanation)

%  \[
%    a1^\markup { \column { { \bold "invalid ligatures" } "SS" } }
%    as
%  \]

  \[
    a\breve^\markup { "BBB" }
    g
    as
    \]

%  \[
%    f\longa^\markup { "LLB" }
%    g
%    f\breve
%  \]

%  \[
%    f\breve^\markup { "BSLB" }
%    a1
%    g\longa
%    a\breve
%  \]
}


% Litterae:
%
% [1] Willi Apel: The Notation of Polyphonic Music. 900-1600.
% [2] Ulrich Michels: dtv-Atlas zur Musik, 1977.
%
