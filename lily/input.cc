/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 1997--2015 Han-Wen Nienhuys <hanwen@xs4all.nl>

  LilyPond is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  LilyPond is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with LilyPond.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "input.hh"

#include <cstdio>
using namespace std;

#include "international.hh"
#include "program-option.hh"
#include "source-file.hh"
#include "sources.hh"
#include "warn.hh"

Input::Input (Input const &i)
{
  source_file_ = i.source_file_;
  start_ = i.start_;
  end_ = i.end_;
}

Input::Input ()
{
  source_file_ = 0;
  start_ = 0;
  end_ = 0;
}

Input
Input::spot () const
{
  return *this;
}

void
Input::set_spot (Input const &i)
{
  *this = i;
}

void
Input::step_forward ()
{
  if (end_ == start_)
    end_++;
  start_++;
}

void
Input::set_location (Input const &i_start, Input const &i_end)
{
  source_file_ = i_start.source_file_;
  start_ = i_start.start_;
  end_ = i_end.end_;
}

/*
  Produce GNU-compliant error message.  Correcting lilypond source is
  such a breeze if you ('re edidor) know (s) the error column too

  Format:

  [file:line:column:][warning:]message
*/
string
Input::message_string (const string &msg) const
{
  if (source_file_)
    return msg + "\n" + source_file_->quote_input (start_);
  else
    return msg;
}

string
Input::message_location () const
{
  return (source_file_) ? location_string () : "";
}
void
Input::error (const string &s) const
{
  ::non_fatal_error (message_string (s), message_location ());
  // UGH, fix naming or usage (use non_fatal_error in most places, instead)
  // exit (1);
}

void
Input::programming_error (const string &s) const
{
  ::programming_error (message_string (s), message_location ());
}

void
Input::non_fatal_error (const string &s) const
{
  ::non_fatal_error (message_string (s), message_location ());
}

void
Input::warning (const string &s) const
{
  ::warning (message_string (s), message_location ());
}

void
Input::message (const string &s) const
{
  ::message (message_string (s), true, message_location ());
}

void
Input::debug_output (const string &s) const
{
  ::debug_output (message_string (s), true, message_location ());
}

string
Input::location_string () const
{
  if (source_file_)
    return source_file_->file_line_column_string (start_);
  return " (" + _ ("position unknown") + ")";
}

string
Input::line_number_string () const
{
  if (source_file_)
    return ::to_string (source_file_->get_line (start_));
  return "?";
}

string
Input::file_string () const
{
  if (source_file_)
    return source_file_->name_string ();
  return "";
}

int
Input::line_number () const
{
  if (source_file_)
    return source_file_->get_line (start_);
  return 0;
}

int
Input::column_number () const
{
  int line, chr, col, offset = 0;
  source_file_->get_counts (start_, &line, &chr, &col, &offset);

  return col;
}

int
Input::end_line_number () const
{
  if (source_file_)
    return source_file_->get_line (end_);
  return 0;
}

int
Input::end_column_number () const
{
  int line, chr, col, offset = 0;
  source_file_->get_counts (end_, &line, &chr, &col, &offset);

  return col;
}

void
Input::get_counts (int *line, int *chr, int *col, int *offset) const
{
  source_file_->get_counts (start_, line, chr, col, offset);
}

void
Input::set (Source_file *sf, char const *start, char const *end)
{
  source_file_ = sf;
  start_ = start;
  end_ = end;
}

Source_file *
Input::get_source_file () const
{
  return source_file_;
}

char const *
Input::start () const
{
  return start_;
}

char const *
Input::end () const
{
  return end_;
}
