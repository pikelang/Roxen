// This is a ChiliMoon module. Copyright © 2000 - 2001, Roxen IS.

inherit "chili-module:cgi": normalcgi;

constant cvs_version = "$Id: fastcgi.pike,v 2.15 2004/06/04 08:29:25 _cvs_stephen Exp $";

#include <roxen.h>
#include <module.h>
#if !defined(__NT__) && !defined(__AmigaOS__)
# define UNIX 1
#else
# define UNIX 0
#endif

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
  static
  {
    Stdio.File fd;
    array request_ids = allocate(MAX_FCGI_PREQ+1);
    array(mapping) stream = allocate(MAX_FCGI_PREQ+1);
    string buffer = "";

    function default_cb;
    function close_callback;


    void got_data( string f )
    {
      Packet p;
      buffer += f;
      while( (p = Packet( buffer ))->ready() )
      {
        mapping s;
        buffer = p->get_leftovers();
        if( stream[p->requestid] && (s = stream[ p->requestid ][ p->type ] ) )
        {
#ifdef FCGI_DEBUG
          werror( "->%s: %O\n", s->name, p->data );
#endif
          s->cb( p->data );
        }
        else
        {
#ifdef FCGI_DEBUG
          werror( "-> %O", p );
#endif
          if( request_ids[p->requestid] )
            request_ids[p->requestid]( p );
          else if( default_cb )
            default_cb( p );
#ifdef FCGI_DEBUG
          werror("\n");
#endif
        }
      }
    }

#if constant( thread_create )
    void read_thread()
    {
      string s;
      while( (s = fd->read( 1024, 1 ) ) && sizeof(s) )
        got_data( s );
      catch(fd->close());
      end_cb();
    }

    Thread.Condition cond = Thread.Condition();
    Thread.Mutex cond_mutex = Thread.Mutex();
    string wbuffer = "";
    void write_thread()
    {
      int ok=1;
      catch
      {
        while( 1 )
        {
          int written;
          while( sizeof(wbuffer) )
            if( fd )
            {
              written = fd->write( wbuffer );
              if( written <= 0 )
              {
                break;
                ok=0;
              }
              wbuffer = wbuffer[written..];
            } else
              ok=0;
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
#ifdef FCGI_DEBUG
      werror("Setting up read/write/close callbacks for FD\n");
#endif
      fd->set_id( 0 );
      fd->set_blocking();
      thread_create( read_thread );
      thread_create( write_thread );
    }

    void write( string what )
    {
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
      if( sizeof(wbuffer) )
      {
        written = fd->write( wbuffer );
        if( written < 0 )
          end_cb();
        else
          wbuffer = wbuffer[written..];
      }
    }

    void read_cb( object f, string d )
    {
      got_data( d );
    }

    void do_setup_channels()
    {
#ifdef FCGI_DEBUG
      werror("Setting up read/write/close callbacks for FD\n");
#endif
      fd->set_id( 0 );
      fd->set_read_callback( read_cb );
      fd->set_write_callback( write_cb );
      fd->set_close_callback( end_cb );
    }
#endif

    void end_cb()
    {
      if( fd )
      {
        if( close_callback )
          close_callback( this );
        catch(fd->close());
        foreach( values( stream )-({0}), mapping q )
          foreach( values( q ), mapping q )
            catch( function_object(q->cb)->close() );
        fd = 0;
      }
    }
  } /* end of static */


  void setup_channels()
  {
    do_setup_channels();
  }

  void send_packet( Packet p )
  {
#ifdef FCGI_DEBUG
    werror( "<- %O\n", p );
#endif
    write( (string)p );
  }

  void set_close_callback( function to )
  {
    close_callback = to;
  }

  void set_default_callback( function to )
  {
    default_cb = to;
  }

  void free_requestid( int i )
  {
    request_ids[i]=0;
    stream[i]=([]);
  }

  int get_requestid( function f )
  {
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
    return sizeof( values( request_ids ) - ({0}) );
  }
  void unregister_stream( int a, int b )
  {
    m_delete( stream[b], a );
  }

  void register_stream( int a, int b, function c, string n )
  {
    stream[b][a] = (["cb":c, "name":n]);
  }

  void create( Stdio.File f )
  {
    fd = f;
//  setup_channels();
  }
}

class Packet
{
  static
  {
    int readyp;
    string leftovers;
  } /* end of static */


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
//    int paddinglen = sizeof(data)&8;

    int dLen = sizeof(data);
    int eLen = (dLen + 7) & (0xFFFF - 7); // align to an 8-byte boundary
    int paddinglen = eLen - dLen;
#ifdef FCGI_DEBUG
    werror("\nPADDING: %d\n", paddinglen);
#endif

    return sprintf( "%c%c%2c%2c%c\0%s%s",1,type,requestid,sizeof(data),paddinglen
                    ,data, "X"*paddinglen);
  }

  void create( string|int s, int|void r, string|void d )
  {
    if( stringp( s ) )
    {
      int paddinglen;
      if( sizeof( s ) < 8 )
        return;
      sscanf( s, "%c%c%2c%2c%c%*c" "%s",
              version, type, requestid, contentlength, paddinglen,
              /* reserved, */leftovers );
      if( sizeof( leftovers ) < contentlength + paddinglen )
        return;

      data = leftovers[..contentlength-1];
      leftovers = leftovers[contentlength + paddinglen..];
      readyp = 1;
    } else {
      readyp = 1;
      version= 1;
      type = s;
      requestid = r;
      contentlength = sizeof( d );
      data = d;
    }
  }
}

class Stream
{
  constant id = 0;
  constant name = "UNKNOWN";

  int writer, closed;

  static
  {
    int reqid;
    FCGIChannel fd;
    string buffer = "";
    function read_callback, close_callback, close_callback_2;
    mixed fid;
  }

  string _sprintf( )
  {
    return sprintf("FCGI.Stream(%s,%d)", name, reqid);
  }

  void destroy()
  {
    if( fd )
      fd->unregister_stream( id, reqid );
  }

  void close()
  {
    if( closed ) return;
    closed = 1;

#ifdef FCGI_DEBUG
    werror( name+ " closed\n" );
#endif
    if( writer )
      fd->send_packet( Packet( id, reqid, "" ) );
    else
      catch(fd->send_packet( packet_abort_request( reqid ) ));
    catch
    {
      if( close_callback )
        close_callback( fid );
    };
    catch
    {
      if( close_callback_2 )
        close_callback_2( fid );
    };
  }

  string read( int nbytes, int noblock )
  {
    if(!nbytes)
    {
      if( noblock )
      {
#if constant( thread_create )
        while( !closed && !sizeof( buffer ) ) sleep(0.1);
#endif
        string b = buffer;
        buffer="";
        return b;
      }
#if constant( thread_create )
      while( !closed ) sleep( 0.1 );
#endif
      string b = buffer;
      buffer=0;
      return b;
    }
    if( !closed && !noblock )
    {
#if constant( thread_create )
      while( !closed && (sizeof( buffer ) < nbytes) ) /* assume MT */
        sleep( 0.1 );
#else
      if( !closed && (sizeof(buffer) < nbytes) )
        error("Not enough data available, and waiting would block!\n" );
#endif
    }
#if constant( thread_create )
    while( !closed && !sizeof( buffer ) ) sleep(0.1);
#endif
    string b = buffer[..nbytes-1];
    buffer = buffer[nbytes..];
    return b;
  }

  int write( string data )
  {
    if( closed )
      error("Stream closed\n");
    if( !sizeof( data ) )
      return 0;
    if( sizeof( data ) < 65535 )
      fd->send_packet( Packet( id, reqid, data ) );
    else
      foreach( data / 8192, string d )
        fd->send_packet( Packet( id, reqid, d ) );
    return sizeof(data);
  }

  void got_data( string d )
  {
    if( closed )
    {
#ifdef FCGI_DEBUG
      werror("Got data on closed stream ("+id+")!\n");
#endif
      return;
    }
    buffer += d;

    if( read_callback )
    {
      do_read_callback();
      if( !sizeof( d ) )
      {
        /* EOS record. */
        closed = 1;
        if( close_callback )     close_callback( fid );
        return;
      }
    }
    if( !sizeof( d ) )
      if( close_callback_2 )
      {
        closed = 1;
        close_callback_2( this );
      }
  }

  void set_close_callback( function f )
  {
    close_callback = f;
    if( f && closed )
      close_callback( fid );
  }

  void set_read_callback( function f )
  {
    read_callback = f;
    if( f && sizeof( buffer ) )
      do_read_callback();
  }

  void set_nonblocking( function a, function n, function w )
  {
    /* It is already rather nonblocking.. */
    set_read_callback( a );
    set_close_callback( w );
  }

  void set_second_close_callback(function q)
  {
    close_callback_2 = q;
    if( closed )
      close_callback_2( this );
  }

  void set_blocking()
  {
    set_close_callback( 0 );
    set_read_callback( 0 );
  }

  void set_id( mixed to )
  {
    fid = to;
  }

  void do_read_callback()
  {
    if( sizeof( buffer ) )
    {
      read_callback( fid, buffer );
      buffer="";
    }
  }

  void create( FCGIChannel _fd, int requestid, int _writer )
  {
    fd = _fd;
    writer = _writer;
    reqid = requestid;
    fd->register_stream( id, requestid, got_data, name );
  }
}

string encode_param( string p )
{
  if( sizeof( p ) < 127 )
    return sprintf("%c%s", sizeof(p), p );
  p = sprintf( "%4c%s", sizeof(p), p );
  p[0] |= 128;
}

string encode_param_length(string p)
{
  if( sizeof( p ) < 128 )	
    return sprintf("%c", sizeof(p));
  else
  {
    p = sprintf( "%4c", sizeof( p ) );
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
  constant name = "Stdout";
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
      return is_done;
    }

    void kill( int with )
    {
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
    parent->free_requestid( rid );
    if( done_callback )
      done_callback( this );
    is_done = 1;
  }

  void handle_packet( Packet p )
  {
    /* stdout / stderr routed to the above streams.. */
    if( p->type == FCGI_END_REQUEST )
    {
#ifdef FCGI_DEBUG
      werror(" Got EOR from stream\n");
#endif
      done();
    }
    else
      werror(" Unexpected FCGI packet: %O\n", p );
  }

  void set_done_callback( function to )
  {
    done_callback = to;
  }

  void create( RequestID i, FCGIChannel p, CGIScript c )
  {
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
  static
  {
    Stdio.Port socket;
    array all_pids = ({});
    mapping options = ([]);
    array argv;
    array(FCGIChannel) channels = ({});
    int current_conns;

    void do_connect( object fd, mixed|void q )
    {
#if constant(thread_create)
#ifdef FCGI_DEBUG
      werror(" Connecting...\n" );
#endif
      while( fd->connect( "localhost",(int)(socket->query_address()/" ")[1]) )
      {
#ifdef FCGI_DEBUG
        werror(" Connection failed...\n" );
#endif
        sleep( 0.1 );
      }
      q();
#else
#ifdef FCGI_DEBUG
      werror(" Connecting...\n" );
#endif
      fd->connect( "localhost",(int)(socket->query_address()/" ")[1]);
#endif
    }

    FCGIChannel new_channel( )
    {
      while( current_conns >= (options->MAX_CONNS*sizeof(all_pids)) )
        start_new_script();
      current_conns++;
      Stdio.File fd = Stdio.File();
      fd->open_socket();
      FCGIChannel ch = FCGIChannel( fd );
#if constant(thread_create)
      fd->set_blocking();
      thread_create( do_connect,  fd, ch->setup_channels );
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
                                channels -= ({ c });
                                current_conns--;
                              });
      return ch;
    }

    void reaperman()
    {
      call_out( reaperman, 1 );
      foreach( all_pids, object p )
        if( !p || p->status() ) // done
          all_pids -= ({ p });
    }

    void start_new_script( )
    {
      all_pids += ({ Process.create_process( /*({ "/bin/truss"}) +*/ argv,
                                             options ) });
    }

    string values_cache = "";
    void parse_values( )
    {
      while( sizeof( values_cache ) )
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
#ifdef FCGI_DEBUG
        werror( "%O == %O\n", index, value );
#endif
      }
    }

    void maintenance_packet( Packet p )
    {
      switch( p->type )
      {
       case FCGI_GET_VALUES_RESULT:
         if( sizeof( p->data ) )
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
    }
  } /* end of  static */


  FCGIChannel stream()
  {
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
    return new_channel();
#else
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
    return new_channel();
#endif
  }
}

mapping(string:FCGI) fcgis = ([]);
FCGIRun do_fcgiscript( CGIScript f )
{
  if( fcgis[ f->command ] )
    return FCGIRun( f->mid, fcgis[ f->command ]->stream(), f );
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

  Stdio.Stream get_fd()
  {
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
  }

  CGIScript run()
  {
    fcgi = do_fcgiscript( this );
    fcgi->set_done_callback( done );
    ready = 1;
    stdin = fcgi->stdin;
    stdout= fcgi->stdout;
    pid   = fcgi->fake_pid();
    return this;
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
