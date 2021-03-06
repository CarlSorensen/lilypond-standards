\header {
  texidoc = "Different styles may be used for
string number indications.  Predefined options
are arabic (used by default) and roman numerals."
}

\version "2.19.16"
\paper {
  ragged-right = ##t
}

\relative c'' {
  c2\2
  \romanStringNumbers
  a\3
  \override StringNumber.number-type = #'roman-lower
  a\3
  \arabicStringNumbers
  g\4
}
