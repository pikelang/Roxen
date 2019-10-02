// -*- pike -*-
//
// Some stuff to do logging of a request through the server.
//
// $Id$

#ifndef REQUEST_TRACE_H
#define REQUEST_TRACE_H

#include <roxen.h>
#include <module.h>

// Note that TRACE_ENTER (and TRACE_LEAVE) takes message strings
// in plain text. Messages are preferably a single line, and they
// should not end with period and/or newline.
//
//
// Roxen 5.0 compatibility notice:
//
//   Pre-5.0 TRACE_ENTER and TRACE_LEAVE allowed html markup to pass
//   through unquoted into the Resolve Path wizard page, but since the
//   ultimate destination may not be a web page at all this capability
//   has been removed. The Resolve Path wizard will now quote all
//   strings instead.

#if constant (gethrvtime)
#define HRTIME() gethrvtime()
#elif constant (gethrtime)
#define HRTIME() gethrtime()
#else
#define HRTIME() 0
#endif

#ifdef REQUEST_TRACE

# define ID_TRACE_ENTER(ID, MSG, OBJ) do{				\
    int _ts_ = HRTIME();						\
    if (object _id_ = (ID)) {						\
      Roxen->trace_enter ((ID), (MSG), (OBJ), _ts_);			\
      _id_->misc->trace_overhead += HRTIME() - _ts_;			\
    }									\
  }while(0)

# define ID_TRACE_LEAVE(ID, MSG) do{					\
    int _ts_ = HRTIME();						\
    if (object _id_ = (ID)) {						\
      Roxen->trace_leave ((ID), (MSG), _ts_);				\
      _id_->misc->trace_overhead += HRTIME() - _ts_;			\
    }									\
  }while(0)

#else

# define ID_TRACE_ENTER(ID, MSG, OBJ) do{				\
    if (object _id_ = (ID)) {						\
      mapping _id_misc_ = _id_->misc;					\
      if (function(string,mixed,int:void) _trace_enter =		\
	  ([function(string,mixed,int:void)] _id_misc_->trace_enter)) {	\
	int _ts_ = HRTIME();						\
	_trace_enter ((MSG), (OBJ), _ts_);				\
	_id_->misc->trace_overhead += HRTIME() - _ts_;			\
      }									\
    }									\
  }while(0)

# define ID_TRACE_LEAVE(ID, MSG) do{					\
    if (object _id_ = (ID)) {						\
      mapping _id_misc_ = _id_->misc;					\
      if (function(string,int:void) _trace_leave =			\
	  ([function(string,int:void)] _id_misc_->trace_leave)) {	\
	int _ts_ = HRTIME();						\
	_trace_leave ((MSG), _ts_);					\
	_id_->misc->trace_overhead += HRTIME() - _ts_;			\
      }									\
    }									\
  }while(0)

#endif

#define TRACE_ENTER(MSG,OBJ) ID_TRACE_ENTER (id, (MSG), (OBJ))
#define TRACE_LEAVE(MSG) ID_TRACE_LEAVE (id, (MSG))

// SIMPLE_TRACE_ENTER and SIMPLE_TRACE_LEAVE are simpler variants of
// the above macros since they handle sprintf style format lists. Note
// the reversed argument order in SIMPLE_TRACE_ENTER compared to
// TRACE_ENTER.

#define SIMPLE_ID_TRACE_ENTER(ID, OBJ, MSG...) do {			\
    array _msg_arr_;							\
    ID_TRACE_ENTER ((ID),						\
		    (_msg_arr_ = ({MSG}),				\
		    sizeof (_msg_arr_) > 1 ? sprintf (@_msg_arr_) :	\
		    (sizeof (_msg_arr_) ? _msg_arr_[0] : "")),		\
		 (OBJ));						\
  } while (0)

#define SIMPLE_ID_TRACE_LEAVE(ID, MSG...) do {				\
    array _msg_arr_;							\
    ID_TRACE_LEAVE ((ID),						\
		    (_msg_arr_ = ({MSG}),				\
		    sizeof (_msg_arr_) > 1 ? sprintf (@_msg_arr_) :	\
		    (sizeof (_msg_arr_) ? _msg_arr_[0] : "")));		\
  } while (0)

#define SIMPLE_TRACE_ENTER(OBJ, MSG...) SIMPLE_ID_TRACE_ENTER (id, OBJ, MSG)
#define SIMPLE_TRACE_LEAVE(MSG...) SIMPLE_ID_TRACE_LEAVE (id, MSG)

// The following variant should be used inside RXML.Frame callbacks
// such as do_enter. In addition to the request trace, it does rxml
// debug logging which is activated with the DEBUG define in
// combination with the magic _debug_ tag argument or the RXML_VERBOSE
// or RXML_REQUEST_VERBOSE defines.

#define TAG_TRACE_ENTER(MSG...) do {					\
    array _msg_arr_;							\
    string _msg_;							\
    TRACE_ENTER ("tag <" + (tag && tag->name) + "> " +			\
		   (_msg_arr_ = ({MSG}),				\
		    _msg_ = sizeof (_msg_arr_) > 1 ? sprintf (@_msg_arr_) : \
		    (sizeof (_msg_arr_) ? _msg_arr_[0] : "")),		\
		 tag);							\
    DO_IF_DEBUG (							\
      if (TAG_DEBUG_TEST (flags & RXML.FLAG_DEBUG))			\
	tag_debug ("%O:   %s\n", this_object(),				\
		   _msg_ ||						\
		   (_msg_arr_ = ({MSG}),				\
		    sizeof (_msg_arr_) > 1 ? sprintf (@_msg_arr_) :	\
		    (sizeof (_msg_arr_) ? _msg_arr_[0] : "")));		\
    );									\
  } while (0)

#define TAG_TRACE_LEAVE(MSG...) do {					\
    array _msg_arr_;							\
    string _msg_;							\
    TRACE_LEAVE ((_msg_arr_ = ({MSG}),					\
		  _msg_ = sizeof (_msg_arr_) > 1 ? sprintf (@_msg_arr_) : \
		  (sizeof (_msg_arr_) ? _msg_arr_[0] : "")));		\
    DO_IF_DEBUG (							\
      if (TAG_DEBUG_TEST (flags & RXML.FLAG_DEBUG)) {			\
	if (!_msg_) {							\
	  _msg_arr_ = ({MSG});						\
	  _msg_ =							\
	    sizeof (_msg_arr_) > 1 ? sprintf (@_msg_arr_) :		\
	    (sizeof (_msg_arr_) ? _msg_arr_[0] : "");			\
	}								\
	if (sizeof (_msg_)) tag_debug ("%O:   %s\n", this_object(), _msg_); \
      }									\
    );									\
  } while (0)

#ifdef AVERAGE_PROFILING
#define PROF_ENTER(X,Y) id->conf->avg_prof_enter( X, Y, id )
#define PROF_LEAVE(X,Y) id->conf->avg_prof_leave( X, Y, id )
#define COND_PROF_ENTER(X,Y,Z) if(X)PROF_ENTER(Y,Z)
#define COND_PROF_LEAVE(X,Y,Z) if(X)PROF_LEAVE(Y,Z)
#else
#define PROF_ENTER(X,Y)
#define PROF_LEAVE(X,Y)
#define COND_PROF_ENTER(X,Y,Z)
#define COND_PROF_LEAVE(X,Y,Z)
#endif

#endif	// !REQUEST_TRACE_H
