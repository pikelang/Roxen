// This file is part of Roxen WebServer.
// Copyright © 2001 - 2009, Roxen IS.
//

//! Abstract definition of a response object
//! that a emit plugin can return in the
//! get_dataset callback. The only method that
//! needs overloading is @[really_get_row].
//! It might however be best to create a
//! completely new class, with the same interface,
//! that better utilizes the features of your
//! dataset backend, e.g. @[num_rows_left] or
//! @[skip_row].
//!
//! @example
//! class TagEmitTest {
//!   inherit RXML.Tag;
//!   inherit "emit_object";
//!   constant name = "emit";
//!   constant plugin_name = "test";
//!   mapping(string:RXML.Type) req_arg_types =
//!     ([ "table" : RXML.t_int(RXML.PEnt),
//!        "maxrows" : RXML.t_int(RXML.PEnt) ]);
//!
//!   class Response (int mult) {
//!     inherit EmitObject;
//!     int pos;
//!
//!     mapping(string:int) really_get_row() {
//!       return ([ "a":mult, "b":pos, "res":mult*pos++ ]);
//!     }
//!   }
//!
//!   Response get_dataset(mapping m, RequestID id) {
//!     // Warning. Since this table is infinite we need
//!     // to disable all functions that traverse the
//!     // entire dataset.
//!     m_delete(m, "sort");
//!     m_delete(m, "remainderinfo");
//!     if(m->maxrows<0)
//!       RXML.run_error("Maxrows must be > 0.\n");
//!
//!     return Response(m->table);
//!   }
//! }

//! Prototype for emit plugin response object.
class EmitObject {

  mapping(string:mixed) next_row;

  //! Returns a new set of variables to be used in
  //! the emit loop.
  mapping(string:mixed) get_row() {

    if(next_row) {
      mapping(string:mixed) current = next_row;
      next_row = 0;
      return current;
    }
    return really_get_row();
  }

  //! Returns the next element and increments the
  //! element counter.
  protected mapping(string:mixed) really_get_row() { }

  //! Remove the next value.
  void skip_row() {
    if(next_row) {
      next_row = 0;
      return;
    }
    really_get_row();
  }

  //! Returns the next element that get_row will
  //! return.
  mapping(string:mixed) peek() {
    if(next_row) return next_row;
    next_row = really_get_row();
    return next_row;
  }

  //! Returns the number of rows left. It does
  //! however destroy the resulting values, so
  //! the object is rendered useless after this
  //! method is called.
  int num_rows_left() {
    int num = !!next_row;
    while(really_get_row()) num++;
    return num;
  }
}
