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

#include "interval.hh"

#include "interval.tcc"

template<>
Real
Interval_t<Real>::infinity ()
{
  return HUGE_VAL;
}

template<>
string
Interval_t<Real>::T_to_string (Real r)
{
  return ::to_string (r);
}

template<>
int
Interval_t<int>::infinity ()
{
  return INT_MAX;
}

template<>
string
Interval_t<int>::T_to_string (int i)
{
  return ::to_string (i);
}

template INTERVAL__INSTANTIATE (int);
template INTERVAL__INSTANTIATE (Real);