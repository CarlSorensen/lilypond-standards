/*
  This file is part of LilyPond, the GNU music typesetter.

  Copyright (C) 2004--2015 Han-Wen Nienhuys

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

#include "context.hh"
#include "dispatcher.hh"
#include "lily-guile.hh"
#include "music.hh"
#include "music-iterator.hh"
#include "music-sequence.hh"
#include "warn.hh"

enum Outlet_type
{
  CONTEXT_ONE, CONTEXT_TWO,
  CONTEXT_SHARED, CONTEXT_SOLO,
  CONTEXT_NULL, NUM_OUTLETS
};

static const char *outlet_names_[NUM_OUTLETS]
  = {"one", "two", "shared", "solo", "null"};

class Part_combine_iterator : public Music_iterator
{
public:
  Part_combine_iterator ();

  DECLARE_SCHEME_CALLBACK (constructor, ());
protected:
  virtual void derived_substitute (Context *f, Context *t);
  virtual void derived_mark () const;

  virtual void construct_children ();
  virtual Moment pending_moment () const;
  virtual void do_quit ();
  virtual void process (Moment);

  virtual bool ok () const;

private:
  /* used by try_process */
  DECLARE_LISTENER (set_busy);
  bool busy_;
  bool notice_busy_;

  bool try_process (Music_iterator *i, Moment m);

  Music_iterator *first_iter_;
  Music_iterator *second_iter_;
  Moment start_moment_;

  SCM split_list_;

  Stream_event *unisono_event_;
  Stream_event *solo_one_event_;
  Stream_event *solo_two_event_;
  Stream_event *mmrest_event_;

  enum Status
  {
    APART,
    TOGETHER,
    SOLO,
    UNISONO,
    UNISILENCE,
  };
  Status state_;

  // For states in which it matters, this is the relevant part,
  // e.g. 1 for Solo I, 2 for Solo II.
  int chosen_part_;

  // States for generating partcombine text.
  enum PlayingState
  {
    PLAYING_OTHER,
    PLAYING_UNISONO,
    PLAYING_SOLO1,
    PLAYING_SOLO2,
  } playing_state_;

  int last_playing_;

  /*
    TODO: this is getting off hand...
  */
  Context_handle handles_[NUM_OUTLETS];

  void substitute_both (Outlet_type to1,
                        Outlet_type to2);

  /* parameter is really Outlet_type */
  void kill_mmrest (int in);
  void chords_together ();
  void solo1 ();
  void solo2 ();
  void apart (bool silent);
  void unisono (bool silent, int newpart);
};

void
Part_combine_iterator::do_quit ()
{
  if (first_iter_)
    first_iter_->quit ();
  if (second_iter_)
    second_iter_->quit ();

  // Add listeners to all contexts except Devnull.
  for (int i = 0; i < NUM_OUTLETS; i++)
    {
      Context *c = handles_[i].get_context ();
      if (c->is_alias (ly_symbol2scm ("Voice")))
        c->event_source ()->remove_listener (GET_LISTENER (set_busy), ly_symbol2scm ("music-event"));
      handles_[i].set_context (0);
    }
}

Part_combine_iterator::Part_combine_iterator ()
{
  mmrest_event_ = 0;
  unisono_event_ = 0;
  solo_two_event_ = 0;
  solo_one_event_ = 0;

  first_iter_ = 0;
  second_iter_ = 0;
  split_list_ = SCM_EOL;
  state_ = APART;
  chosen_part_ = 1;
  playing_state_ = PLAYING_OTHER;
  last_playing_ = 0;

  busy_ = false;
  notice_busy_ = false;
}

void
Part_combine_iterator::derived_mark () const
{
  if (first_iter_)
    scm_gc_mark (first_iter_->self_scm ());
  if (second_iter_)
    scm_gc_mark (second_iter_->self_scm ());
  if (unisono_event_)
    scm_gc_mark (unisono_event_->self_scm ());
  if (mmrest_event_)
    scm_gc_mark (mmrest_event_->self_scm ());
  if (solo_one_event_)
    scm_gc_mark (solo_one_event_->self_scm ());
  if (solo_two_event_)
    scm_gc_mark (solo_two_event_->self_scm ());
}

void
Part_combine_iterator::derived_substitute (Context *f,
                                           Context *t)
{
  if (first_iter_)
    first_iter_->substitute_outlet (f, t);
}

Moment
Part_combine_iterator::pending_moment () const
{
  Moment p;
  p.set_infinite (1);
  if (first_iter_->ok ())
    p = min (p, first_iter_->pending_moment ());

  if (second_iter_->ok ())
    p = min (p, second_iter_->pending_moment ());
  return p;
}

bool
Part_combine_iterator::ok () const
{
  return first_iter_->ok () || second_iter_->ok ();
}

void
Part_combine_iterator::substitute_both (Outlet_type to1,
                                        Outlet_type to2)
{
  Outlet_type tos[] = {to1, to2};

  Music_iterator *mis[] = {first_iter_, second_iter_};

  for (int i = 0; i < 2; i++)
    {
      for (int j = 0; j < NUM_OUTLETS; j++)
        if (j != tos[i])
          mis[i]->substitute_outlet (handles_[j].get_context (), handles_[tos[i]].get_context ());
    }

  for (int j = 0; j < NUM_OUTLETS; j++)
    {
      if (j != to1 && j != to2)
        kill_mmrest (j);
    }
}

void
Part_combine_iterator::kill_mmrest (int in)
{

  if (!mmrest_event_)
    {
      mmrest_event_ = new Stream_event
        (scm_call_1 (ly_lily_module_constant ("ly:make-event-class"),
                     ly_symbol2scm ("multi-measure-rest-event")));
      mmrest_event_->set_property ("duration", SCM_EOL);
      mmrest_event_->unprotect ();
    }

  handles_[in].get_context ()->event_source ()->broadcast (mmrest_event_);
}

void
Part_combine_iterator::unisono (bool silent, int newpart)
{
  Status newstate = (silent) ? UNISILENCE : UNISONO;

  if ((newstate == state_) and (newpart == chosen_part_))
    return;
  else
    {
      Outlet_type c1 = (newpart == 2) ? CONTEXT_NULL : CONTEXT_SHARED;
      Outlet_type c2 = (newpart == 2) ? CONTEXT_SHARED : CONTEXT_NULL;
      substitute_both (c1, c2);
      kill_mmrest ((newpart == 2) ? CONTEXT_ONE : CONTEXT_TWO);
      kill_mmrest (CONTEXT_SHARED);

      if (playing_state_ != PLAYING_UNISONO
          && newstate == UNISONO)
        {
          if (!unisono_event_)
            {
              unisono_event_ = new Stream_event
                (scm_call_1 (ly_lily_module_constant ("ly:make-event-class"),
                             ly_symbol2scm ("unisono-event")));
              unisono_event_->unprotect ();
            }

          Context *out = (newpart == 2 ? second_iter_ : first_iter_)
                         ->get_outlet ();
          out->event_source ()->broadcast (unisono_event_);
          playing_state_ = PLAYING_UNISONO;
        }
      state_ = newstate;
      chosen_part_ = newpart;
    }
}

void
Part_combine_iterator::solo1 ()
{
  if ((state_ == SOLO) && (chosen_part_ == 1))
    return;
  else
    {
      state_ = SOLO;
      chosen_part_ = 1;
      substitute_both (CONTEXT_SOLO, CONTEXT_NULL);

      kill_mmrest (CONTEXT_TWO);
      kill_mmrest (CONTEXT_SHARED);

      if (playing_state_ != PLAYING_SOLO1)
        {
          if (!solo_one_event_)
            {
              solo_one_event_ = new Stream_event
                (scm_call_1 (ly_lily_module_constant ("ly:make-event-class"),
                             ly_symbol2scm ("solo-one-event")));
              solo_one_event_->unprotect ();
            }

          first_iter_->get_outlet ()->event_source ()->broadcast (solo_one_event_);
        }
      playing_state_ = PLAYING_SOLO1;
    }
}

void
Part_combine_iterator::solo2 ()
{
  if ((state_ == SOLO) and (chosen_part_ == 2))
    return;
  else
    {
      state_ = SOLO;
      chosen_part_ = 2;
      substitute_both (CONTEXT_NULL, CONTEXT_SOLO);

      if (playing_state_ != PLAYING_SOLO2)
        {
          if (!solo_two_event_)
            {
              solo_two_event_ = new Stream_event
                (scm_call_1 (ly_lily_module_constant ("ly:make-event-class"),
                             ly_symbol2scm ("solo-two-event")));
              solo_two_event_->unprotect ();
            }

          second_iter_->get_outlet ()->event_source ()->broadcast (solo_two_event_);
          playing_state_ = PLAYING_SOLO2;
        }
    }
}

void
Part_combine_iterator::chords_together ()
{
  if (state_ == TOGETHER)
    return;
  else
    {
      playing_state_ = PLAYING_OTHER;
      state_ = TOGETHER;

      substitute_both (CONTEXT_SHARED, CONTEXT_SHARED);
    }
}

void
Part_combine_iterator::apart (bool silent)
{
  if (!silent)
    playing_state_ = PLAYING_OTHER;

  if (state_ == APART)
    return;
  else
    {
      state_ = APART;
      substitute_both (CONTEXT_ONE, CONTEXT_TWO);
    }
}

void
Part_combine_iterator::construct_children ()
{
  start_moment_ = get_outlet ()->now_mom ();
  split_list_ = get_music ()->get_property ("split-list");

  Context *c = get_outlet ();

  for (int i = 0; i < NUM_OUTLETS; i++)
    {
      SCM type = (i == CONTEXT_NULL) ? ly_symbol2scm ("Devnull") : ly_symbol2scm ("Voice");
      /* find context below c: otherwise we may create new staff for each voice */
      c = c->find_create_context (type, outlet_names_[i], SCM_EOL);
      handles_[i].set_context (c);
      if (c->is_alias (ly_symbol2scm ("Voice")))
        c->event_source ()->add_listener (GET_LISTENER (set_busy), ly_symbol2scm ("music-event"));
    }

  SCM lst = get_music ()->get_property ("elements");
  Context *one = handles_[CONTEXT_ONE].get_context ();
  set_context (one);
  first_iter_ = Music_iterator::unsmob (get_iterator (Music::unsmob (scm_car (lst))));
  Context *two = handles_[CONTEXT_TWO].get_context ();
  set_context (two);
  second_iter_ = Music_iterator::unsmob (get_iterator (Music::unsmob (scm_cadr (lst))));
  Context *shared = handles_[CONTEXT_SHARED].get_context ();
  set_context (shared);
}

IMPLEMENT_LISTENER (Part_combine_iterator, set_busy);
void
Part_combine_iterator::set_busy (SCM se)
{
  if (!notice_busy_)
    return;

  Stream_event *e = Stream_event::unsmob (se);

  if (e->in_event_class ("note-event") || e->in_event_class ("cluster-note-event"))
    busy_ = true;
}

/*
  Processes a moment in an iterator, and returns whether any new music
  was reported.
*/
bool
Part_combine_iterator::try_process (Music_iterator *i, Moment m)
{
  busy_ = false;
  notice_busy_ = true;

  i->process (m);

  notice_busy_ = false;
  return busy_;
}

void
Part_combine_iterator::process (Moment m)
{
  Moment now = get_outlet ()->now_mom ();
  Moment *splitm = 0;

  /* This is needed if construct_children was called before iteration
     started */
  if (start_moment_.main_part_.is_infinity () && start_moment_ < 0)
    start_moment_ = now;

  for (; scm_is_pair (split_list_); split_list_ = scm_cdr (split_list_))
    {
      splitm = Moment::unsmob (scm_caar (split_list_));
      if (splitm && *splitm + start_moment_ > now)
        break;

      SCM tag = scm_cdar (split_list_);

      if (scm_is_eq (tag, ly_symbol2scm ("chords")))
        chords_together ();
      else if (scm_is_eq (tag, ly_symbol2scm ("apart"))
               || scm_is_eq (tag, ly_symbol2scm ("apart-silence"))
               || scm_is_eq (tag, ly_symbol2scm ("apart-spanner")))
        apart (scm_is_eq (tag, ly_symbol2scm ("apart-silence")));
      else if (scm_is_eq (tag, ly_symbol2scm ("unisono")))
        {
          // Continue to use the most recently used part because we might have
          // killed mmrests in the other part.
          unisono (false, (last_playing_ == 2) ? 2 : 1);
        }
      else if (scm_is_eq (tag, ly_symbol2scm ("unisilence")))
        {
          // as for unisono
          unisono (true, (last_playing_ == 2) ? 2 : 1);
        }
      else if (scm_is_eq (tag, ly_symbol2scm ("silence1")))
        unisono (true, 1);
      else if (scm_is_eq (tag, ly_symbol2scm ("silence2")))
        unisono (true, 2);
      else if (scm_is_eq (tag, ly_symbol2scm ("solo1")))
        solo1 ();
      else if (scm_is_eq (tag, ly_symbol2scm ("solo2")))
        solo2 ();
      else if (scm_is_symbol (tag))
        {
          string s = "Unknown split directive: "
                     + (scm_is_symbol (tag) ? ly_symbol2string (tag) : string ("not a symbol"));
          programming_error (s);
        }
    }

  if (first_iter_->ok ())
    {
      if (try_process (first_iter_, m))
        last_playing_ = 1;
    }

  if (second_iter_->ok ())
    {
      if (try_process (second_iter_, m))
        last_playing_ = 2;
    }
}

IMPLEMENT_CTOR_CALLBACK (Part_combine_iterator);
