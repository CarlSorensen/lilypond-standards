%% DO NOT EDIT this file manually; it is automatically
%% generated from LSR http://lsr.di.unimi.it
%% Make any changes in LSR itself, or in Documentation/snippets/new/ ,
%% and then run scripts/auxiliar/makelsr.py
%%
%% This file is in the public domain.
\version "2.18.0"

\header {
  lsrtags = "ancient-notation, specific-notation, symbols-and-glyphs, tweaks-and-overrides"

  texidoc = "
Custodes may be engraved in various styles.

"
  doctitle = "Custodes"
} % begin verbatim

\layout { ragged-right = ##t }

\new Staff \with { \consists "Custos_engraver" } \relative c' {
  \override Staff.Custos.neutral-position = #4

  \override Staff.Custos.style = #'hufnagel
  c1^"hufnagel" \break
  <d a' f'>1

  \override Staff.Custos.style = #'medicaea
  c1^"medicaea" \break
  <d a' f'>1

  \override Staff.Custos.style = #'vaticana
  c1^"vaticana" \break
  <d a' f'>1

  \override Staff.Custos.style = #'mensural
  c1^"mensural" \break
  <d a' f'>1
}
