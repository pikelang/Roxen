#ifdef REQUEST_DEBUG
# define TRACE_ENTER(A,B) do{ \
    if(([mapping(string:mixed)]id->misc)->trace_enter) \
      ([function(string,mixed ...:void)]([mapping(string:mixed)]id->misc)->trace_enter)((A),(B)); \
  }while(0)

# define TRACE_LEAVE(A) do{ \
    if(([mapping(string:mixed)]id->misc)->trace_leave) \
      ([function(string:void)]([mapping(string:mixed)]id->misc)->trace_leave)((A)); \
  }while(0)
#else
# define TRACE_ENTER(A,B)
# define TRACE_LEAVE(A)
#endif
