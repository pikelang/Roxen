// -*- pike -*-
//
// Some stuff to do logging of a request through the server.
//
// $Id: request_trace.h,v 1.6 2001/11/01 13:06:24 grubba Exp $

#ifdef REQUEST_TRACE

# define TRACE_ENTER(A,B) Roxen->trace_enter (id, (A), (B))
# define TRACE_LEAVE(A) Roxen->trace_leave (id, (A))

#else

# define TRACE_ENTER(A,B) do{ \
    function(string,mixed ...:void) _trace_enter; \
    if(id && _trace_enter = \
       [function(string,mixed ...:void)]([mapping(string:mixed)]id->misc)->trace_enter) \
      _trace_enter ((A), (B)); \
  }while(0)

# define TRACE_LEAVE(A) do{ \
    function(string:void) _trace_leave; \
    if(id && _trace_leave = \
       [function(string:void)]([mapping(string:mixed)]id->misc)->trace_leave) \
      _trace_leave (A); \
  }while(0)

#endif


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
