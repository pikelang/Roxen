// -*- pike -*-
//
// Some stuff to do logging of a request through the server.
//
// $Id: request_trace.h,v 1.4 2000/08/14 18:54:20 mast Exp $

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
