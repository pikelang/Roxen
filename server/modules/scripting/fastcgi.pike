// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

inherit "cgi.pike": normalcgi;

constant cvs_version = "$Id$";

#include <roxen.h>
#include <module.h>
#if !defined(__NT__) && !defined(__AmigaOS__)
# define UNIX 1
#else
# define UNIX 0
#endif

// #define FCGI_ALL_DEBUG

#ifdef FCGI_ALL_DEBUG
# define FCGI_DEBUG
# define FCGI_TRACE_FUNC
# define FCGI_IO_DEBUG
# define FCGI_THREAD_DEBUG
# define FCGI_PACKET_DEBUG
# define FCGI_PROCESS_DEBUG
#endif

#ifdef FCGI_DEBUG
# define DWERR(X) werror(debug_output("FCGI",__LINE__,X));
#else /* !FCGI_DEBUG */
# define DWERR(X)
#endif /* FCGI_DEBUG */

#ifdef FCGI_IO_DEBUG
# define IO_DEBUG(X) DWERR(X)
#else
# define IO_DEBUG(X)
#endif

#ifdef FCGI_THREAD_DEBUG
# define THREAD_DEBUG(X) DWERR(X)
# define THIS_THREAD_ID sprintf("%d: ",Thread.this_thread()->id_number())
#else
# define THREAD_DEBUG(X)
# define THIS_THREAD_ID	""
#endif

#ifdef FCGI_TRACE_FUNC
# define DTFUNC(X) werror(debug_output("FCGI_TRACE",__LINE__,sprintf("%s %O",X, this)))
# define THIS_THREAD_ID sprintf("%d: ",Thread.this_thread()->id_number())
#else
# define DTFUNC(X)
#endif

#ifdef FCGI_PACKET_DEBUG
# define PACKET_DEBUG(X) DWERR(X)
#else
# define PACKET_DEBUG(X)
#endif

#ifdef FCGI_PROCESS_DEBUG
# define PROCESS_DEBUG(X) DWERR(X)
#else
# define PROCESS_DEBUG(X)
#endif

//#define BACKTRACE_HERE(X) DWERR("######\n"+X+"\n"+describe_backtrace(backtrace())+"\n######\n")

constant module_unique = 0;
constant module_type = MODULE_LOCATION | MODULE_FILE_EXTENSION;
constant module_name = "Scripting: Fast CGI support";
constant module_doc  =
"Support for the <a href=\"http://www.fastcgi.com/\">Fast CGI 1 interface</a>";

#define FCGI_RESPONDER  1
#define FCGI_AUTHORIZER 2
#define FCGI_FILTER     3

#define FCGI_KEEP_CONN  1

#define FCGI_BEGIN_REQUEST       1
#define FCGI_ABORT_REQUEST       2
#define FCGI_END_REQUEST         3
#define FCGI_PARAMS              4
#define FCGI_STDIN               5
#define FCGI_STDOUT              6
#define FCGI_STDERR              7
#define FCGI_DATA                8
#define FCGI_GET_VALUES          9
#define FCGI_GET_VALUES_RESULT  10

#define FCGI_REQUEST_COMPLETE 0
#define FCGI_CANT_MPX_CONN    1
#define FCGI_OVERLOADED       2
#define FCGI_UNKNOWN_ROLE     3

#define MAX_FCGI_PREQ         1

class FCGIChannel
{
  protected
  {
    Stdio.File fd;
    array request_ids = allocate(MAX_FCGI_PREQ+1);
    array(mapping) stream = allocate(MAX_FCGI_PREQ+1);
    string buffer = "";

    function default_cb;
    function close_callback;

    // For debugging. Just to log thread id into debug message.
    mixed reader_thread,writer_thread;


    void got_data( string f )
    {
      DTFUNC("FCGIChannel::got_data");
      Packet p;
      buffer += f;
      IO_DEBUG(sprintf("Channel::got_data got strlen(%d)",strlen(f)));
      while( (p = Packet( buffer ))->ready() )
      {
        PACKET_DEBUG(sprintf("Packet: FCGIChannel::got_data() got :%O",p));
        mapping s;
        buffer = p->get_leftovers();
        if( stream[p->requestid] && (s = stream[ p->requestid ][ p->type ] ) )
        {
          s->cb( p->data );
        }
        else
        {
          if( request_ids[p->requestid] ) {
            request_ids[p->requestid]( p );
	  } else if( default_cb ) {
            default_cb( p );
	  }
        }
      }
    }

#if constant( thread_create )
    void read_thread()
    {
      DTFUNC("FCGIChannel::read_thread");
      string s;

      while( (s = fd->read( 1024, 1 ) ) && strlen(s) ) {
        got_data( s );
      }
      catch(fd->close());
      end_cb();
    }

    Thread.Condition cond = Thread.Condition();
    Thread.Mutex cond_mutex = Thread.Mutex();
    string wbuffer = "";
    void write_thread()
    {
      DTFUNC("FCGIChannel::write_thread");
      int ok=1;
      catch
      {
        while( 1 )
        {
          int written;
          while( strlen(wbuffer) ) {
            if( fd )
            {
              written = fd->write( wbuffer );
              if( written <= 0 )
              {
                ok=0;
                break;
              }
              wbuffer = wbuffer[written..];
            } else {
              ok=0;
	      break;
	    }
	  }
	  if(!ok) break;
	  Thread.MutexKey lock = cond_mutex->lock();
	  if (!sizeof (wbuffer))
	    cond->wait (lock);
	  lock = 0;
        }
      };
      catch(fd->close());
      end_cb();
    }

    void do_setup_channels()
    {
      DTFUNC("FCGIChannel::do_setup_channels");
      THREAD_DEBUG(sprintf("Thread Setting up read/write/close callbacks for FD: %O",fd));
      fd->set_id( 0 );
      fd->set_blocking();
      reader_thread = thread_create( read_thread );
      THREAD_DEBUG(sprintf("created read_thread, thread id %O for ch %O",
			   reader_thread->id_number(),this));
      writer_thread = thread_create( write_thread );
      THREAD_DEBUG(sprintf("created write_thread, thread id %O for ch %O",
			   writer_thread->id_number(),this));
    }

    void write( string what )
    {
      DTFUNC("FCGIChannel::write");
      Thread.MutexKey lock = cond_mutex->lock();
      wbuffer += what;
      cond->signal();
      lock = 0;
    }
#else
    void write( string what )
    {
      wbuffer += what;
      write_cb();
    }

    void write_cb( )
    {
      if( strlen(wbuffer) )
      {
	IO_DEBUG(sprintf("nonthreaded write_cb with wbuffer: %s\n",wbuffer));
        written = fd->write( wbuffer );
	IO_DEBUG(sprintf("nonthreaded write_cb wrote: %d\n",written));
        if( written < 0 )
          end_cb();
        else
          wbuffer = wbuffer[written..];
      }
    }

    void read_cb( object f, string d )
    {
      IO_DEBUG(sprintf("Non threaded read_cb, string: %s\n   object :%O\n",d,f));
      got_data( d );
    }

    void do_setup_channels()
    {
      IO_DEBUG(sprintf("Non threaded Setting up read/write/close callbacks for FD: %O\n",fd));
      fd->set_id( 0 );
      fd->set_read_callback( read_cb );
      fd->set_write_callback( write_cb );
      fd->set_close_callback( end_cb );
    }
#endif

    void end_cb()
    {
      DTFUNC("FCGIChannel::end_cb");

      if( fd )
      {
        if( close_callback ) {
	  PROCESS_DEBUG(sprintf("FCGIChannel close callback from end_cb(): %O, calling %O",
				this_object(),close_callback));
          close_callback( this_object() );
	}
        catch(fd->close());
        foreach( values( stream )-({0}), mapping q )
          foreach( values( q ), mapping q )
            catch( function_object(q->cb)->close() );
        fd = 0;
      }
    }
  } /* end of protected */


  void setup_channels()
  {
    DTFUNC("FCGIChannel::setup_channels");
    do_setup_channels();
  }

  void send_packet( Packet p )
  {
    DTFUNC("FCGIChannel::send_packet");
    PACKET_DEBUG(sprintf("Packet: sending packet to scipt <- %O", p));
    write( (string)p );
  }

  void set_close_callback( function to )
  {
    DTFUNC("FCGIChannel::set_close_callback");
    close_callback = to;
  }

  void set_default_callback( function to )
  {
    DTFUNC("FCGIChannel::set_default_callback");
    default_cb = to;
  }

  void free_requestid( int i )
  {
    DTFUNC("FCGIChannel::free_requestid");
    request_ids[i]=0;
    stream[i]=([]);
  }

  int get_requestid( function f )
  {
    DTFUNC("FCGIChannel::get_requestid");
#if MAX_FCGI_PREQ == 1
    if( request_ids[1] )
      return -1;
    request_ids[1] = f;
    stream[1] = ([]);
    return 1;
#else
    for( int i = 1; i<sizeof( request_ids ); i++ )
      if(!request_ids[i] )
      {
        request_ids[i] = f;
        stream[i]=([]);
        return i;
      }
    return -1;
#endif
  }

  int number_of_reqids()
  {
    DTFUNC("FCGIChannel::number_of_reqids");
    int nr = sizeof( values( request_ids ) - ({0}) );
    return nr;
  }

  void unregister_stream( int a, int b )
  {
    DTFUNC("FCGIChannel::unregister_stream");
    PROCESS_DEBUG(sprintf("unregister_stream %d,%d for %O, stream is %O",a,b,this_object(),stream[b]));
    m_delete( stream[b], a );
  }

  void register_stream( int a, int b, function c, string n )
  {
    DTFUNC("FCGIChannel::register_stream");
    stream[b][a] = (["cb":c, "name":n]);
  }

  void destroy() {
    DTFUNC("FCGIChannel::destroy");
  }

  void create( Stdio.File f )
  {
    DTFUNC("FCGIChannel::create");
    IO_DEBUG(sprintf("Create FCGIChannel with FD:%O\n",f));
    fd = f;
//  setup_channels();
  }
}

class Packet
{
  protected
  {
    int readyp;
    string leftovers;
  } /* end of protected */


  mixed cast( string to )
  {
    if( to == "string" )
      return encode();
  }

  string _sprintf( int c )
  {
    return sprintf("Packet(%d,%d,%d,%O)",type,
                   requestid,contentlength,data);
  }

  int version;
  int type;
  int requestid;
  int contentlength;
  string data;

  int ready()
  {
    return readyp;
  }

  string get_leftovers()
  {
    return leftovers;
  }

  string encode()
  {
//    int paddinglen = strlen(data)&8;

    int dLen = strlen(data);
    int eLen = (dLen + 7) & (0xFFFF - 7); // align to an 8-byte boundary
    int paddinglen = eLen - dLen;
    PACKET_DEBUG(sprintf("Packet: PADDING: %d", paddinglen));

    return sprintf( "%c%c%2c%2c%c\0%s%s",1,type,requestid,strlen(data),paddinglen
                    ,data, "X"*paddinglen);
  }

  void create( string|int s, int|void r, string|void d )
  {
    if( stringp( s ) )
    {
      int paddinglen;
      if( strlen( s ) < 8 )
        return;
      sscanf( s, "%c%c%2c%2c%c%*c" "%s",
              version, type, requestid, contentlength, paddinglen,
              /* reserved, */leftovers );
      if( strlen( leftovers ) < contentlength + paddinglen )
        return;

      data = leftovers[..contentlength-1];
      leftovers = leftovers[contentlength + paddinglen..];
      readyp = 1;
    } else {
      readyp = 1;
      version= 1;
      type = s;
      requestid = r;
      contentlength = strlen( d );
      data = d;
      PACKET_DEBUG(sprintf("Packet: created packet %O",this_object()));
    }
  }
}

class Stream
{
  constant id = 0;
  constant name = "UNKNOWN";

  int writer, closed;

  protected
  {
    int reqid;
    FCGIChannel fd;
    string buffer = "";
    function read_callback, close_callback, close_callback_2;
    mixed fid;

#if constant(thread_create)
    // Note: buffer is accessed both from the read_thread,
    //       and from other threads due to the implementation
    //       of set_blocking() and set_nonblocking().
    Thread.Mutex read_cb_mutex = Thread.Mutex();
#define LOCK()		read_cb_mutex->lock()
#define UNLOCK(KEY)	destruct(key)
#else
#define LOCK()	0
#define UNLOCK(KEY)
#endif
  }

  string _sprintf( )
  {
    return sprintf("FCGI.Stream(%s,%d)", name, reqid);
  }

  void destroy()
  {
    DTFUNC("Stream::destroy");
    if( fd ) {
      IO_DEBUG(sprintf("Stream destroy(%O) fd %O",this_object(),fd));
      fd->unregister_stream( id, reqid );
    }
  }

  protected void do_close(int level)
  {
    DTFUNC("Stream::do_close (level"+level+")");
    IO_DEBUG(sprintf("Stream::do_close(%O) with level %d, close_callback is %O, close_callback_2 is %O\n",
		     this_object(),level,close_callback,close_callback_2));
    if (level == 2) {
      if( close_callback_2 )
      {
        closed = 1;
	// Delay 1 second to ensure that any data is cleared first.
        call_out(close_callback_2, 1, this_object());
      }
    } else {
      closed = 1;
      if (close_callback) {
	// Delay 1 second to ensure that any data is cleared first.
	call_out(close_callback, 1, fid);
      }
    }
  }

  void close()
  {
    DTFUNC("Stream::close");
    if( closed ) return;
    closed = 1;

    IO_DEBUG(sprintf("FCGI::Stream(%s):close() %O closed, fd: %O",name,this_object(),fd ));
    if( writer ) {
      PACKET_DEBUG(sprintf("Packet: Stream(%s):close() sending close packet to script",name));
      fd->send_packet( Packet( id, reqid, "" ) );
    } else {
      PACKET_DEBUG(sprintf("Packet: Stream(%s):close() sending abort packet to script",name));
      catch(fd->send_packet( packet_abort_request( reqid ) ));
    }
    catch
    {
      IO_DEBUG(sprintf("FCGI::Stream(%s)::close() calling with fid %O, close_callback %O",
		       name,fid,close_callback));
      if( close_callback )
        close_callback( fid );
    };
    catch
    {
      IO_DEBUG(sprintf("FCGI::Stream(%s)::close() calling with %O, close_callback_2 %O",
		       name,this_object(),close_callback_2));
      if( close_callback_2 )
        close_callback_2( fid );
    };
  }

  string read( int nbytes, int noblock )
  {
    DTFUNC("Stream::read");
    IO_DEBUG(sprintf("%O::read(%d,%d)",this_object(),nbytes,noblock));

    if(!nbytes)
    {
      if( noblock )
      {
#if constant( thread_create )
        while( !closed && !strlen( buffer ) ) sleep(0.1);
#endif
	mixed key = LOCK();
        string b = buffer;
        buffer="";
	UNLOCK(key);
        return b;
      }
#if constant( thread_create )
      while( !closed ) sleep( 0.1 );
#endif
      mixed key = LOCK();
      string b = buffer;
      buffer=0;
      UNLOCK(key);
      return b;
    }
    if( !closed && !noblock )
    {
#if constant( thread_create )
      while( !closed && (strlen( buffer ) < nbytes) ) /* assume MT */
        sleep( 0.1 );
#else
      if( !closed && (strlen(buffer) < nbytes) )
        error("Not enough data available, and waiting would block!\n" );
#endif
    }
#if constant( thread_create )
    while( !closed && !strlen( buffer ) ) sleep(0.1);
#endif
    mixed key = LOCK();
    string b = buffer[..nbytes-1];
    buffer = buffer[nbytes..];
    UNLOCK(key);
    return b;
  }

  int write( string data )
  {
    DTFUNC("Stream::write");
    IO_DEBUG(sprintf("%O::write will write %d len string %O\n",
		     this_object(),strlen(data),data));
    if( closed )
      error("Stream closed\n");
    if( !strlen( data ) )
      return 0;
    if( strlen( data ) < 65535 )
      fd->send_packet( Packet( id, reqid, data ) );
    else
      foreach( data / 8192.0, string d )
        fd->send_packet( Packet( id, reqid, d ) );
    return strlen(data);
  }

  void got_data( string d )
  {
    DTFUNC("Stream::got_data");
    if( closed )
    {
      IO_DEBUG(sprintf("%O::got_data ***Got data for closed stream(%s)!***",
		       this_object(),name));
      return;
    }
    DWERR(sprintf("stream::got_data called with strlen %d",strlen(d)));
    mixed key = LOCK();
    buffer += d;
    UNLOCK(key);
    IO_DEBUG(sprintf("%O::got_data arg %O, curbuffer %O. calling read_callback: %O",
		     this_object(),d,buffer,read_callback));

    if( read_callback )
    {
      do_read_callback();
      if( !strlen( d ) )
      {
        /* EOS record. */
	IO_DEBUG(sprintf("%O::got_data passed null string, so close this stream",
			 this_object()));
	do_close(1);
      }
      return;
    }
    if( !strlen( d ) ) {
      IO_DEBUG(sprintf("%O::got_data passed null string, read_callback not exist, so close2 this stream",
		       this_object()));
      do_close(2);
    }
  }

  void set_close_callback( function f )
  {
    DTFUNC(sprintf("%O::set_close_callback(%O)",this_object(),f));
    IO_DEBUG(sprintf("%O::set_close_callback: %O",this_object(),f));

    close_callback = f;
    if( f && closed )
      do_close(1);
  }

  void set_read_callback( function f )
  {
    DTFUNC(sprintf("%O::set_read_callback(%O)",this_object(),f));
    IO_DEBUG(sprintf("%O::set_read_callback(%O)",this_object(),f));

    read_callback = f;
    if( f && strlen( buffer ) )
      do_read_callback();
  }

  void set_nonblocking( function a, function n, function w )
  {
    DTFUNC(sprintf("%O::set_nonblocking",this_object()));
    IO_DEBUG(sprintf("%O::set_nonblocking:  a: %O   w: %O",
		     this_object(),a,w));

    /* It is already rather nonblocking.. */
    set_read_callback( a );
    set_close_callback( w );
  }

  void set_second_close_callback(function q)
  {
    DTFUNC(sprintf("%O::set_second_close_callback(%O)",this_object(),q));
    IO_DEBUG(sprintf("%O::set_second_close_callback: %O",this_object(),q));

    close_callback_2 = q;
    if( closed )
      do_close(2);
  }

  void set_blocking()
  {
    DTFUNC(sprintf("%O::set_blocking",this_object()));
    set_close_callback( 0 );
    set_read_callback( 0 );
  }

  void set_id( mixed to )
  {
    DTFUNC(sprintf("%O::set_id(%O)",this_object(),to));
    fid = to;
  }

  // MUST be called from the backend thread!
  protected void really_do_read_callback()
  {
    DTFUNC(sprintf("%O::really_do_read_callback",this_object()));
    IO_DEBUG(sprintf("%O::really_do_read_callback called fid: %O, callback is %O\n  buffer: %d,",
		     this_object(),fid,read_callback,strlen(buffer)));
    mixed key = LOCK();
    string data = buffer;
    buffer = "";
    UNLOCK(key);
    if( strlen( data ) )
    {
      read_callback(fid, data);
    }
  }

  // Called from:
  //   FCGIChannel::got_data ==> got_data
  //   FCGIChannel::read_thread/read_cb ==> FCGIChannel::got_data ==> got_data
  //   set_read_callback
  //   set_nonblocking ==> set_read_callback
  //   set_blocking ==> set_read_callback
  // which may execute concurrently, which causes a race on buffer.
  //
  // We attempt to solve this by sequencing through the main backend.
  void do_read_callback()
  {
    DTFUNC("Stream::do_read_callback");
    if( strlen( buffer ) )
    {
      call_out(really_do_read_callback, 0);
    }
  }

  void create( FCGIChannel _fd, int requestid, int _writer )
  {
    DTFUNC("Stream::create");
    fd = _fd;
    writer = _writer;
    reqid = requestid;
    fd->register_stream( id, requestid, got_data, name );
  }
}

string encode_param( string p )
{
  if( strlen( p ) < 127 )
    return sprintf("%c%s", strlen(p), p );
  p = sprintf( "%4c%s", strlen(p), p );
  p[0] |= 128;
}

string encode_param_length(string p)
{
  if( strlen( p ) < 128 )	
    return sprintf("%c", strlen(p));
  else
  {
    p = sprintf( "%4c", strlen( p ) );
    p[0] |= 128;
    return p;
  }
}

class Params
{
  inherit Stream;
  constant id = FCGI_PARAMS;
  constant name = "Params";

  void write_mapping( mapping m )
  {   
    string data = "";
    foreach( indices( m ), string i )
      data += encode_param_length((string)i) + 
              encode_param_length(m[i]) + i + m[i];
    write( data );
  }
}

class Stdin
{
  inherit Stream;
  constant id = FCGI_STDIN;
  constant name = "Stdin";
}

class Stdout
{
  inherit Stream;
  constant id = FCGI_STDOUT;
  constant name = "Stdout";
}

class Stderr
{
  inherit Stream;
  constant id = FCGI_STDERR;
  constant name = "Stderr";
}

/* server -> client */
Packet packet_begin_request( int requestid, int role, int flags )
{
  return Packet( FCGI_BEGIN_REQUEST, requestid,
                 sprintf("%2c%c\0\0\0\0\0", role, flags ) );
}

Packet packet_get_values( string ... values )
{
  string data = "";
  foreach( values, string q )
    data += encode_param( q ) + encode_param( "" );
  return Packet( FCGI_GET_VALUES, 0, data );
}

Packet packet_abort_request( int requestid )
{
  PACKET_DEBUG(sprintf("Abort request for %d",requestid));
  return Packet( FCGI_ABORT_REQUEST, requestid, "" );
}

class FCGIRun
{
  int rid;
  int is_done;
  RequestID id;
  FCGIChannel parent;

  CGIScript me;
  Stream stdin, stdout, stderr;

  function done_callback;

  class FakePID
  {
    int status()
    {
      DTFUNC("FCGIRun::FakePID::status");
      PROCESS_DEBUG(sprintf("FCGIRun: Status check status is %d, parent %O and pid %d",
			    is_done,parent,parent->attached_pid));
      return is_done;
    }

    void kill( int with )
    {
      DTFUNC("FCGIRun:FakePID:kill");
      catch(stdout->close());
      catch(stderr->close());
      catch(stdin->close());
      is_done = 1;
    }
  }

  FakePID fake_pid()
  {
    return FakePID();
  }

  void done()
  {
    DTFUNC("FCGIRun::done");
    PROCESS_DEBUG(sprintf("FCGIRun: done for rid %d, parent:%O, calling %O",
			  rid,parent,done_callback));
    parent->free_requestid( rid );
    if( done_callback )
      done_callback( this_object() );
    is_done = 1;
  }

  void handle_packet( Packet p )
  {
    DTFUNC("FCGIRun::handle_packet");
    /* stdout / stderr routed to the above streams.. */
    if( p->type == FCGI_END_REQUEST )
    {
      done();
    }
    else {
      werror(" Unexpected FCGI packet: %O\n", p );
    }
  }

  void set_done_callback( function to )
  {
    DTFUNC("FCGIRun::set_done_callback");
    done_callback = to;
  }

  void destroy () {
    DTFUNC("FCGIRun::destroy");
    PROCESS_DEBUG(sprintf("FCGIRun::destroy called, I'm %O",me));
  }

  void create( RequestID i, FCGIChannel p, CGIScript c )
  {
    DTFUNC("FCGIRun::create");
    Params params;
    me = c;
    rid = p->get_requestid( handle_packet );
    parent = p;
    /* Now _this_ is rather ugly... */
    if( rid == -1 )
    {
      werror("Warning: FCGI out of request IDs for script\n");
      call_out( create, 1, i, p );
      return;
    }


    stdin  =  Stdin( p, rid, 1);
    stdout = Stdout( p, rid, 0);
    stderr = Stderr( p, rid, 0);
    params = Params( p, rid, 1);

    stdout->set_second_close_callback( done );

    parent->send_packet( packet_begin_request( rid,
                                               FCGI_RESPONDER,
                                               FCGI_KEEP_CONN ) );
    params->write_mapping( c->environment );
    params->close();    
  }
}





class FCGI
{
  protected
  {
    Stdio.Port socket;
    array all_pids = ({});
    mapping options = ([]);
    array argv;
    array(FCGIChannel) channels = ({});
    int current_conns;

    void do_connect( object fd, mixed|void q )
    {
      DTFUNC("FCGI::do_connect");

#if constant(thread_create)
      THREAD_DEBUG(sprintf("FCGI::do_connect with fd: %O, q: %O\n",fd,q));

      IO_DEBUG(" Connecting...\n" );
      while( !fd->connect( "localhost",(int)(socket->query_address()/" ")[1]) )
      {
	IO_DEBUG(" Connection failed...\n" );
        sleep( 0.1 );
      }
      q();
#else
      IO_DEBUG(sprintf("no thread_create: Connecting to %d...\n",(int)(socket->query_address()/" ")[1]));
      fd->connect( "localhost",(int)(socket->query_address()/" ")[1]);
#endif
      THREAD_DEBUG("FCGI::do_connect done");
    }

    FCGIChannel new_channel( )
    {
      DTFUNC("FCGI::new_channel");
      PROCESS_DEBUG(sprintf("FCGI::new_channel all_process is :%O\n      options: %O\n",all_pids,options));

      while( current_conns >= (options->MAX_CONNS*sizeof(all_pids)) )
        start_new_script();
      current_conns++;
      Stdio.File fd = Stdio.File();
      fd->open_socket();
      FCGIChannel ch = FCGIChannel( fd );
#if constant(thread_create)
      fd->set_blocking();
      mixed th;
      th = thread_create( do_connect,  fd, ch->setup_channels );
      THREAD_DEBUG(sprintf("%O::new_channel created thread id %O for do_connect()",
			   this,th->id_number()));
#else
      fd->set_nonblocking( 0,
                           ch->setup_channels,
                           do_connect );
      fd->set_id( fd );
      do_connect( fd );
#endif
      channels += ({ ch });
      ch->set_close_callback( lambda(object c)
                              {
                                DTFUNC("Channel close callback lambda");
                                PROCESS_DEBUG(sprintf("Close callback for %O called",c));
                                channels -= ({ c });
                                current_conns--;
                              });
      return ch;
    }

    void destroy()
    {
      DTFUNC("FCGI::destroy");
    }

    void reaperman()
    {
      // Suppress logging when no process managed.
      if (sizeof(all_pids)) {
	DTFUNC("FCGI::reaperman");
      }
      if (! this_object()) {
	PROCESS_DEBUG("*** reaperman, object is destructed already ***");
      }
      PROCESS_DEBUG(sprintf("*** reaperman, current status is %O ***",all_pids));

      call_out( reaperman, 1 );
      foreach( all_pids, object p )
        if( !p || p->status() ) // done
          all_pids -= ({ p });
    }

    void start_new_script( )
    {
      DTFUNC("FCGI::start_new_script");
      PROCESS_DEBUG(sprintf("FCGI::start_new_script, argv: %O\n  options: %O\n",argv,options));

      all_pids += ({ Process.create_process( /*({ "/bin/truss"}) +*/ argv,
                                             options ) });
    }

    string values_cache = "";
    void parse_values( )
    {
      while( strlen( values_cache ) )
      {
        string index, value;
        int len;
        sscanf( values_cache, "%2c%s", len, values_cache );
        index = values_cache[..len-1];
        values_cache = values_cache[len..];
        sscanf( values_cache, "%2c%s", len, values_cache );
        value = values_cache[..len-1];
        values_cache = values_cache[len..];

        options[ index-"FCG_" ] = (int)value;
        options[ index ] = value;
        PACKET_DEBUG(sprintf("Packet: parse_value() %O == %O", index, value ));
      }
    }

    void maintenance_packet( Packet p )
    {
      switch( p->type )
      {
       case FCGI_GET_VALUES_RESULT:
         if( strlen( p->data ) )
           values_cache += p->data;
         else
         {
           parse_values();
           values_cache = "";
         }
         break;
       default:
         werror("FCGI: Unknown maintenance style package: %O\n", p );
      }
    }

    void create( CGIScript s )
    {
      DTFUNC("FCGI::create");
      PROCESS_DEBUG(sprintf("FCGI::create with %O, fcgirun: %O",s,s->fcgi));
      socket = Stdio.Port( 0, 0, "localhost" );
#ifdef __NT__
      if( s->nt_opencommand )
        argv = s->nt_opencommand( s->command, s->arguments );
      else
#endif
        argv = ({ s->command }) + s->arguments;
      options =
              ([
                "stdin":socket,
                "cwd":dirname( s->command ),
                "noinitgroups":1,
              ]);

#if UNIX
      if(!getuid())
      {
        if (s->uid >= 0)
          options->uid = s->uid;
        else
        {
          // Some OS's (HPUX) have negative uids in /etc/passwd,
          // but don't like them in setuid() et al.
          // Remap them to the old 16bit uids.
          options->uid = 0xffff & s->uid;

          if (options->uid <= 10)
          {
            // Paranoia
            options->uid = 65534;
          }
        }
        if (s->gid >= 0)
        {
          options->gid = s->gid;
        } else {
          // Some OS's (HPUX) have negative gids in /etc/passwd,
          // but don't like them in setgid() et al.
          // Remap them to the old 16bit gids.
          options->gid = 0xffff & s->gid;

          if (options->gid <= 10)
          {
            // Paranoia
            options->gid = 65534;
          }
        }
        options->setgroups = s->extra_gids;
        if( !s->uid && query("warn_root_cgi") )
          report_warning( "FCGI: Running "+s->command+" as root (as per request)" );
      }
      if(query("nice"))
      {
        m_delete(options, "priority");
        options->nice = query("nice");
      }
      if( s->limits )
        options->rlimit = s->limits;
#endif

      start_new_script();

      options->MPXS_CONNS = 0;
      options->MAX_REQS = 1;
      options->MAX_CONNS = 1; /* sensible (for a stupid script) defaults */

#if MAX_FCGI_PREQ  > 1
//   This breaks the fastcgi library... *$#W(#$)#"$!
//       FCGIChannel c = stream();
//       if(!c)
//         error( "Impossible!\n");
//       c->set_default_callback( maintenance_packet );
//       c->send_packet( packet_get_values("FCGI_MAX_CONNS",
//                                         "FCGI_MAX_REQS",
//                                         "FCGI_MPXS_CONNS") );
#endif

      call_out(reaperman, 1);
    }

  } /* end of  protected */


  FCGIChannel stream()
  {
    DTFUNC("FCGI::stream");

    channels -= ({ 0 });
    //    Not really needed right now, since libfcgi with
    //    friends does _not_ support multiplexing anyway.
    //
    //    Also, see the comment above, we don't even try to get the
    //    parameters.
    //
    //    But the code is here, it might start working in libfcgi.
    //    I rather doubt that, though. libfcgi must be the worst code
    //    I have seen in quite some time...
    //
#if MAX_FCGI_PREQ == 1
    foreach( channels, FCGIChannel ch )
      if( !ch->number_of_reqids() )
        return ch;
#else
    DWERR("*** Check for free channel ***");
    channels -= ({ 0 });
    foreach( channels,  FCGIChannel ch )
    {
      if( catch {
        if( ch && options->MPXS_CONNS )
        {
          if( ch->number_of_reqids()  < options->MAX_REQS )
            return ch;
        }
        else if( !ch->number_of_reqids() )
          return ch;
      }  )
        channels -= ({ ch });
    }
#endif
    PROCESS_DEBUG("*** No free channel found, create new channel***");
    return new_channel();
  }

  // Just for debugging
  array show_all_pids() {
    return all_pids;
  }
  array show_channels() {
    return channels;
  }
}

mapping(string:FCGI) fcgis = ([]);
FCGIRun do_fcgiscript( CGIScript f )
{
  DTFUNC("fastcgi.pike:do_fcgiscript");
  if( fcgis[ f->command ] )
    return FCGIRun( f->mid, fcgis[ f->command ]->stream(), f );

  DWERR("do_fcgiscript: access to new script");
  fcgis[ f->command ] = FCGI( f );
  return do_fcgiscript( f );
}


class CGIScript
{
  inherit normalcgi::CGIScript;

  int ready;
  FCGIRun fcgi;
  Stdio.File stdin;
  Stdio.File stdout;
  Stdio.File stderr;

  Stdio.Stream get_fd()
  {
    DTFUNC("CGIScript::get_fd");
    //
    // Send input (if any) to the script.
    //
    if( tosend )
      stdin->write( tosend );
    stdin->close();
    stdin=0;

    //
    // And then read the output.
    //
    PROCESS_DEBUG(sprintf("fastcgi::CGIScript::get_fd and then read the output from %O, blocking status is %O",
			  fcgi->show_request_origin(),blocking));
    if(!blocking)
    {
#ifdef FCGI_DEBUG
      werror( "***** Non-Blocking ******\n");
#endif
      Stdio.Stream fd = stdout;
      fd = CGIWrapper( fd, mid, kill_script )->get_fd();
      if( query("rxml") )
        fd = RXMLWrapper( fd, mid, kill_script )->get_fd();
      stdout = 0;
      call_out( check_pid, 0.1 );
      return fd;
    }
    remove_call_out( kill_script );
    return stdout;
  }

  void done()
  {
    DTFUNC("CGIScript::done");
    PROCESS_DEBUG(sprintf("fastcgi.pike::CGIScript::done close stderr %O for %O\n  stdin: %O\n  stdout: %O\n",
			  stderr,fcgi,stdin,stdout));
    stderr->close();
  }

  CGIScript run()
  {
    DTFUNC("CGIScript::run");
    fcgi = do_fcgiscript( this_object() );
    fcgi->set_done_callback( done );
    ready = 1;
    stdin = fcgi->stdin;
    stdout= fcgi->stdout;
    stderr= fcgi->stderr;
    pid   = fcgi->fake_pid();
    return this_object( );
  }
}


// override some variables...
void create(Configuration conf)
{
  ::create( conf );

  set("location", "/fcgi-bin/" );

  defvar("ex", 1, "Handle *.fcgi", TYPE_FLAG,
	 "Also handle all '.fcgi' files as FCGI-scripts, as well "
	 " as files in the fcgi-bin directory.");

  defvar("ext",
	 ({"fcgi",}), "FCGI-script extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, will be parsed as "+
	 "FCGI-scripts.");

  killvar("cgi_tag");
}

string status()
{
  string statmessage = "<h3>FastCGI object status</h3>\n";
  foreach (fcgis; string cmd; FCGI f) {
    int count = 0;
    statmessage += 
      "<h4>" + Roxen.html_encode_string(cmd) + "</h4>\n"
      "<pre>Object: " + Roxen.html_encode_string(sprintf("%O", f)) + "</pre>\n"
      "<h5>pids</h5>\n"
      "<ul>\n";
    foreach (f->show_all_pids(),mixed p)
      statmessage += sprintf("<li>%d Pid: %d, status: %d</li>",
			     ++count, p->pid(), p->status());
    statmessage +=
      "</ul>\n"
      "<h5>Channels</h5>\n"
      "<ul>\n";
    count = 0;
    foreach (f->show_channels(),FCGIChannel ch)
      statmessage +=
	sprintf("<li>%d %O<br /><pre>%O</pre></li>",
		++count, ch, ch->request_ids);
    statmessage += "</ul>\n";
  }
  return statmessage;
}

string debug_output (string heading, int line, string body) {
  array(string) r = body / "\n";
  array bt = backtrace();
  heading = sprintf(THIS_THREAD_ID+"%s(line:%4d):"+" "*sizeof(bt),heading,line);
  string sep = " ";
  string m = map(r,lambda(string t,string h) {
		     string tmp = h + sep + t;
		     sep = "    ";
		     return tmp;
		   },
		 heading) * "\n" + "\n";
  return m;
}
