// -*- pike -*-
//
// Some stuff to do logging of a request through the server.
//
// $Id: request_trace.h,v 1.5 2001/05/07 02:48:36 per Exp $

#ifdef REQUEST_TRACE

# define TRACE_ENTER(A,B) Roxen->trace_enter (id, (A), (B))
# define TRACE_LEAVE(A) Roxen->trace_leave (id, (A))

#else

# define TRACE_ENTER(A,B) do{ \
    if(function(string,mixed ...:void) _trace_enter = \
       [function(string,mixed ...:void)]([mapping(string:mixed)]id->misc)->trace_enter) \
      _trace_enter ((A), (B)); \
  }while(0)

# define TRACE_LEAVE(A) do{ \
    if(function(string:void) _trace_leave = \
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
