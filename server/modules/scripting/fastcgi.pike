inherit "cgi.pike": normalcgi;

constant cvs_version = "$Id: fastcgi.pike,v 2.1 2000/01/25 07:23:04 per Exp $";

#include <roxen.h>
#include <module.h>
#if !defined(__NT__) && !defined(__AmigaOS__)
# define UNIX 1
#else
# define UNIX 0
#endif

constant module_type = MODULE_LOCATION | MODULE_FILE_EXTENSION | MODULE_PARSER;
constant module_name = "Fast CGI scripting support";
constant module_doc  =
"Support for the <a href=\"http://www.fastcgi.com/\">Fast CGI 1 interface</a>";


class FCGIChannel
{
  private static
  {
    Stdio.File fd;
    array request_ids = allocate(65536);
    array(mapping) stream = allocate(65536);
    string buffer;

    function default_cb;

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
          werror( "->%s: %O\n", s->name, p->data );
          s->cb( p->data );
        }
        else
        {
          werror( "%O", p );
          if( request_ids[p->requestid] )
            request_ids[p->requestid]( p );
          else if( default_cb )
            default_cb( p );
        }
      }
    }

#if constant( thread_create )
    void read_thread()
    {
      while( (string s = fd->read( 1024, 1 )) && strlen(s) )
        got_data( s );
      fd->close();
      destruct();
    }

    Threads.Condition cond = Threads.Condition();
    string wbuffer = "";
    void write_thread()
    {
      while( 1 )
      {
        int written;
        cond->wait();
        while( strlen(wbuffer) )
        {
          written = fd->write( wbuffer );
          if( written == 0 && (fd->errno() != System.EAGAIN) )
            break;
          wbuffer = wbuffer[written..];
        }
        if( !written )
          break;
      }
      fd->close();
      destruct();
    }

    void setup_channels()
    {
      thread_create( read_thread );
      thread_create( write_thread );
    }

    void write( string what )
    {
      wbuffer += what;
      cond->signal();
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

    function close_callback;

    void end_cb()
    {
      if( close_callback )
        close_callback( this_object() );
      fd->close();
      destruct();
    }

    void setup_channels()
    {
      set_read_callback( read_cb );
      set_write_callback( write_cb );
      set_close_callback( end_cb );
    }
#endif
  } /* end of private static */


  void send_packet( Packet p )
  {
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
    for( int i = 0; i<sizeof( request_ids ); i++ )
      if(!request_ids[i] )
      {
        request_ids[i] = f;
        stream[i]=([]);
        return i;
      }
    return -1;
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
    setup_channels();
  }
}

class Packet
{
  private static
  {
    int readyp;
    string leftovers;

    mixed _cast( string to )
    {
      if( to == "string" )
        return encode();
    }

    string _sprintf( int c )
    {
      switch( c )
      {
       case 'O':
         return sprintf("Packet(%d,%d,%d,%O)",type,
                        requestid,contentlength,data);
       case 's':
         return encode();
      }
    }
  } /* end of private static */


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
    return sprintf( "%c%c%2c%2c\0\0%s",1,type,requestid,strlen(data),data);
  }

  void create( string|int s, int|void r, string|void d )
  {
    if( stringp( s ) )
    {
      int paddinglen;
      if( strlen( s ) < 8 )
        return;
      sscanf( s, "%c%c%2c%2c%c%*c%s",
              version, type, requestid, contentlength, paddinglen,
              /* reserved */, leftovers );
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
    }
  }
}

class Stream
{
  constant id = 0;
  constant name = "UNKNOWN";

  int writer, closed;

  private static
  {
    int reqid;
    FCGIChannel fd;
    string buffer = "";
    function read_callback, close_callback;
    mixed fid;
  }

  void destroy()
  {
    fd->unregister_stream( id, reqid );
  }

  void close()
  {
    if( closed ) return;
    closed = 1;
    if( writer )
      write( "" );
    else
      fd->send_packet( packet_abort_request( reqid ) );
  }

  string read( int nbytes, int noblock )
  {
    if( !noblock )
    {
#if constant( thread_create )
      while( !closed && (strlen( buffer ) < nbytes) ) /* assume MT */
        sleep( 0.1 );
#else
      if( !closed && (strlen(buffer) < nbytes) )
        error("Not enough data available, and waiting would block!\n" );
#endif
    }
    string b = buffer[..nbytes-1];
    buffer = buffer[nbytes..];
    return b;
  }

  int write( string data )
  {
    if( closed )
      error("Stream closed\n");
    if( strlen( data ) < 65535 )
      fd->send_packet( Packet( id, requestid, data ) );
    else
      foreach( data / 8192, string d )
        fd->send_packet( Packet( id, requestid, d ) );
    return strlen(data);
  }

  void got_data( string d )
  {
    if( closed )
    {
      werror("Got data on closed stream ("+id+")!\n");
      return;
    }
    if( !strlen( d ) )
    {
      /* EOS record. */
      closed = 1;
      if( close_callback )
        close_callback( fid );
      return;
    }
    buffer += d;
    if( read_callback ) do_read_callback();
  }

  void set_close_callback( function f )
  {
    close_callback = f;
  }

  void set_read_callback( function f )
  {
    read_callback = f;
    if( strlen( buffer ) )
      do_read_callback();
  }

  void set_id( mixed to )
  {
    fid = to;
  }

  void do_read_callback()
  {
#if constant(thread_create)
    call_out(read_callback,0, fid,buffer);
#else
    read_callback( fid, buffer );
#endif
    buffer="";
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
  if( strlen( p ) < 127 )
    return sprintf("%c%s", strlen(p), p );
  p = sprintf( "%4c%s", strlen(p), p );
  p[0] &= 128;
}

class Params
{
  inherit Stream;
  constant id = 4;
  constant name = "Params";

  void write_mapping( mapping m )
  {
    string data = "";
    foreach( indices( m ), string i )
      data += encode_param( (string)i ) + encode_param( m[i] );
    write( data );
  }
}

class Stdin
{
  inherit Stream;
  constant id = 5;
  constant name = "Stdin";
}

class Stdout
{
  inherit Stream;
  constant id = 6;
  constant name = "Stdout";
}

class Stderr
{
  inherit Stream;
  constant id = 7;
  constant name = "Stdout";
}

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

#if 0
/* client -> server */
Packet packet_end_request( int requestid, int appstatus, int protstats )
{
  return Packet( FCGI_END_REQUEST, requestid,
                 sprintf("%4c%c\0\0\0", appstatus, protstatus ) );
}
#endif

class FCGIRun
{
  int rid;

  RequestID id;
  FCGIChannel parent;

  CGIScript me;
  Stream stdin, stdout, stderr;

  function done_callback;

  void handle_packet( Packet p )
  {
    /* stdout / stderr routed to the above streams.. */
    if( p->type == FCGI_END_REQUEST )
    {
      parent->free_requestid( rid );
      if( done_callback )
        done_callback( this_object() );
      destruct();
    }
    else
    {
      werror(" Unexpected packet: %O\n", p );
    }
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
    /* Now _this_ is rather ugly... */
    if( mri == -1 )
    {
      werror("Warning: FCGI out of request IDs for script\n");
      call_out( create, 1, i, p );
      return;
    }

    stdin  =  Stdin( p, rid, 1);
    stdout = Stdout( p, rid, 0);
    stderr = Stderr( p, rid, 0);
    params = Params( p, rid, 1);

    parent->send_packet( packet_begin_request( rid,
                                               FCGI_RESPONDER,
                                               FCGI_KEEP_CONN ) );


    params->write_mapping( c->environment );

    params->close();
  }
}





class FCGI
{
  private static
  {
    Stdio.Port socket;
    array all_pids = ({});
    mapping options = ([]);
    mapping options = ([ ]);
    array argv;
    FCGIChannel channels = ({});
    int current_conns;

    FCGIChannel new_channel( )
    {
      while( current_conns > (options->MAX_CONNS*sizeof(all_pids)) )
        start_new_script();
      current_conns++;
      Stdio.File fd = Stdio.File();
      ch = FCGIChannel( fd );
      if( !fd->connect( "localhost", (int)(socket->query_address()/" ")[1] ) )
        return 0;
      channels += ({ ch });
      ch->set_close_callback( lambda(object c) {
                                channels -= ({ c });
                                current_conns--;
                              });
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
      all_pids += ({ create_process( argv, options ) });
    }

    string values_cache = "";
    void parse_values( )
    {
      while( strlen( values_cache ) )
      {
        string index, value;
        sscanf( values_cache, "%2c%s", len, values_cache );
        index = values_cache[..len-1];
        values_cache = values_cache[len..];
        sscanf( values_cache, "%2c%s", len, values_cache );
        value = values_cache[..len-1];
        values_cache = values_cache[len..];

        options[ index-"FCG_" ] = (int)value;
        options[ index ] = value;
        werror( "%O == %O\n", index, value );
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
                "env":s->environment,
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
          options->uid = 0xffff & uid;

          if (options->uid <= 10)
          {
            // Paranoia
            options->uid = 65534;
          }
        }
        if (gid >= 0)
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
        if( !s->uid && QUERY(warn_root_cgi) )
          report_warning( "FCGI: Running "+command+" as root (as per request)" );
      }
      if(QUERY(nice))
      {
        m_delete(options, "priority");
        options->nice = QUERY(nice);
      }
      if( s->limits )
        options->rlimit = s->limits;
#endif

      all_pids = ({create_proces( argv, options )});

      options->MPXS_CONNS = 0;
      options->MAX_REQS = 1;
      options->MAX_CONNS = 1; /* sensible (for a stupid script) defaults */

      FCGIChannel c = stream();
      c->set_default_callback( maintenance_packet );
      c->send_packet( packet_get_values("FCGI_MAX_CONNS","FCGI_MAX_REQS","FCGI_MPXS_CONNS") );
    }
  } /* end of private static */


  FCGIChannel stream()
  {
    foreach( channels,  FCGIChannel ch )
    {
      if( options->MPXS_CONNS )
      {
        if( ch->number_of_reqids()  < options->MAX_REQS )
          return ch;
      }
      else if( !ch->number_of_reqids() )
        return ch;
    }
    return new_channel();
  }
}

mapping(string:FCGI) fcgis = ([]);
FCGIRun do_fcgiscript( CGIScript f )
{
  if( fcgis[ f->command ] )
    return FCGIRun( f->mid, fcgis[ f->command ]->stream(), f );
  return fcgis[ f->command ] = FCGI( f );
}


class CGIScript
{
  inherit normalcgi:CGIScript;

  int ready;
  FCGIRun run;
  Stdio.File stdin;
  Stdio.File stdout;

  void perhaps_set_ready( )
  {
    if( !run->stdin )
    {
      call_out( perhaps_set_ready, 1 );
      return;
    }
    ready = 1;
    stdin = run->stdin;
    stdout= run->stdout;
    pid = run->parent->pid;
  }

  CGIScript run()
  {
    run = do_fcgiscript( this_object() );
    run->set_done_callback( done );
    perhaps_set_ready( );
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

  defvar("cgi_tag", 1, "Provide the &lt;fcgi&gt; and &lt;runfcgi&gt; tags",
	 TYPE_FLAG,
	 "If set, the &lt;fcgi&gt; and &lt;runfcgi&gt; tags will be available.");
}
