inherit "module";
constant cvs_version="$Id: icecast.pike,v 1.3 2001/04/10 05:23:42 per Exp $";
constant thread_safe=1;

#define BSIZE 8192
#define METAINTERVAL 4192

#include <module.h>
#include <roxen.h>
#include <stat.h>
#include <request_trace.h>

//<locale-token project="mod_icecast">LOCALE</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_icecast",X,Y)

constant     module_type = MODULE_LOCATION;
LocaleString module_name = _(0,"Icecast: Server");
LocaleString  module_doc = _(0,"");
constant   module_unique = 0;

class Playlist
{
  inherit RoxenModule;
  Stdio.File next_file();
  string     pl_name();
  mapping    metadata();
  void       add_md_callback( function(mapping:void) f );
  void       remove_md_callback( function(mapping:void) f );
};

class MPEGStream( Playlist playlist )
{  
  array(function) callbacks = ({});
  int bitrate;

  int stream_position; // 1000:th of a second.
  int stream_start = time()*1000+(int)(time(time())*1000);
  Stdio.File fd;

  string status()
  {
    return ""+playlist->status()+"<br />"+
      sprintf( "Uptime: %.1fs   Bitrate: %dKbit/sec",
	       stream_position/1000.0,
	       bitrate/1000 );
  }
  
  
  void add_callback( function callback )
  {
    callbacks += ({ callback });
  }

  void remove_callback( function callback )
  {
    callbacks -= ({ callback });
  }

  void call_callbacks( mixed ... args )
  {
    
    foreach( callbacks, function f )
      if( mixed e = catch( f(@args) ) )
      {
	werror(describe_backtrace( e ) );
	callbacks -= ({f});
      }
  }

  int realtime()
  {
    return (time()*1000+(int)(time(time())*1000)) - stream_start;
  }

  void destroy()
  {
    catch(fd->set_blocking());
    catch(fd->close());
  }
  
  void feeder_thread( )
  {
    while( realtime() > stream_position )
    {
      string frame = get_frame();
      while( !frame )
      {
	fd->set_blocking();
	fd->close();
	fd = playlist->next_file();
	buffer = 0;
	bpos = 0;
	frame = get_frame();
      }
      stream_position += strlen(frame)*8000 / bitrate;
      call_callbacks( frame );
    };
    call_out( feeder_thread, 0.02 );
  }

  void start()
  {
    feeder_thread( ); // not actually a thread right now.
  }
  
  // Low level code.
  static string buffer;
  static int    bpos;

  static string|int getbytes( int n, int|void s )
  {
    if( !fd )
      fd = playlist->next_file();
    if( !buffer || !strlen(buffer) )
    {
      bpos = 0;
      buffer = fd->read( BSIZE );
    }
    if( !strlen(buffer) )
      return s?0:-1;
    if( s )
    {
      if( strlen(buffer) - bpos > n )
      {
	string d = buffer[bpos..bpos+n-1];
	buffer = buffer[bpos+n..];
	bpos=0;
	return d;
      }
      else
      {
	buffer = buffer[bpos..];
	bpos=0;
	string t = fd->read( BSIZE );
	if( !t || !strlen(t) )
	  return -1;
	buffer+=t;
	return getbytes(n,1);
      }
    }
    int res=0;
    while( n-- )
    {
      res<<=8;
      res|=buffer[ bpos++ ];
      if( bpos == strlen(buffer) )
      {
	bpos = 0;
	buffer = fd->read( BSIZE );
	if( !buffer || !strlen( buffer ) )
	  return -1;
      }
    }
    return res;
  }

  static int rate_of(int r)
  {
    switch(r)
    {
      case 0: return 44100;
      case 1: return 48000;
      case 2: return 32000;
      default:return 44100;
    }
  }

  static array(array(int)) bitrates =
  ({
    ({0,32,64,96,128,160,192,224,256,288,320,352,384,416,448}),
    ({0,32,48,56,64,80,96,112,128,160,192,224,256,320,384}),
    ({0,32,40,48,56,64,80,96,112,128,160,192,224,256,320}),
  });

  static string get_frame()
  {
    string data;
    /* Find header */
    int trate = 0;
    int patt = 0;
    int by, p=0, sw=0;
    while( (by = getbytes( 1  )) > 0  )
    {
      patt <<= 8;
      patt |= by;
      p++;
      if( (patt & 0xfff0) == 0xfff0 )
      {
	int srate, channels, layer, ID, pad, blen;
	int header = ((patt&0xffff)<<16);
	if( (by = getbytes( 2 )) < 0 )
	  break;
	header |= by;

	string data = sprintf("%4c",header);
	patt=0;
	header <<= 12;

	int getbits( int n )
	{
	  int res = 0;
	  while( n-- )
	  {
	    res <<= 1;
	    if( header&(1<<31) )  res |= 1;
	    header<<=1;
	  }
	  return res;
	};
	ID = getbits(1); // version
	if(!ID) /* not MPEG1 */
	  continue;
	layer = (4-getbits(2));

	header<<=1; /* getbits(1); // error protection */

	bitrate = getbits(4); 
	srate = getbits(2);
      
	if((layer>3) || (layer<2) ||  (bitrate>14) || (srate>2))
	  continue;
      
	pad = getbits(1);
	bitrate = bitrates[ layer-1 ][ bitrate ] * 1000;
	srate = rate_of( srate );

	switch( layer )
	{
	  case 1:
	    blen = (int)(12 * bitrate / (float)srate + (pad?4:0))-4;
	    break;
	  case 2:
	  case 3:
	    blen = (int)(144 * bitrate / (float)srate + pad )-4;
	    break;
	}

	string q = getbytes( blen,1 );
	if(!q)
	  return 0;
	return data + q;
      }
    }
    return 0;
  }
} 

class Location( string location,
		string initial,
		MPEGStream stream,
		int max_connections )
		
{
  int accessed, denied;
  int connections;

  int total_time, max_time, successful;
  
  array(Connection) conn = ({});
  
  mapping handle( RequestID id )
  {
    NOCACHE();
    accessed++;
    if( connections == max_connections )
    {
      denied++;
      return Roxen.http_string_answer( "Too many listeners\n" );
    }


    mapping meta = stream->playlist->metadata();
    if( !meta )
    {
      denied++;
      return Roxen.http_string_answer( "Too early\n" );
    }

    connections++;
    int use_metadata;
    string i, metahd="";
    string protocol = "ICY";

    werror("%O\n", id->request_headers );
    if( id->request_headers[ "icy-metadata" ] )
    {
//       use_metadata = (int)id->request_headers[ "icy-metadata" ];
//       if( use_metadata )
// 	metahd = "icy-metaint:"+METAINTERVAL+"\r\n";
    }
    
    if( id->request_headers[ "x-audiocast-udpport" ] )
    {
      protocol = "AudioCast";
      i = ("HTTP/1.0 200 OK\r\n"
	   "Server: "+roxen.version()+"\r\n"
	   "Content-type: audio/mpeg\r\n"
	   "x-audiocast-name:"+(meta->name||meta->path)+"\r\n"
	   "x-audiocast-gengre:"+(meta->gengre||"unknown")+"\r\n"
	   "x-audiocast-url:"+("http://"+id->misc->host+
			       query_location()+location)+"\r\n"+
	   "x-audiocast-streamid:1\r\n"+metahd+
	   "x-audiocast-public:1\r\n"
	   "x-audiocast-bitrate:"+(stream->bitrate/1000)+"\r\n"
	   "x-audiocast-description:Served by Roxen\r\n"
	   "\r\n" );
    }
    else
    {
      i = ("ICY 200 OK\r\n"
	   "Server: "+roxen.version()+"\r\n"
	   "Content-type: audio/mpeg\r\n"
	   "icy-notice1:This stream requires a shoutcast compatible player.\r\n"
	   "icy-notice2:Roxen mod_mp3\r\n"+metahd+
	   "icy-name:"+(meta->name||meta->path)+"\r\n"
	   "icy-gengre:"+(meta->gengre||"unknown")+"\r\n"
	   "icy-url:"+("http://"+id->misc->host+
		       query_location()+location)+"\r\n"+
	   "icy-pub:1\r\n"
	   "icy-br:"+(stream->bitrate/1000)+"\r\n"
	   "\r\n" );
    }
    if( initial )
      i += initial;
    
    conn += ({ Connection( id->my_fd, i,protocol,use_metadata,
			   stream,
			   lambda( Connection c ){
			     int pt = time()-c->connected;
			     conn-=({c});
			     total_time += pt;
			     if( pt > max_time )
			       max_time = pt;
			     successful++;
			     connections--;
			   } ) });
    return Roxen.http_pipe_in_progress( );
  }

  string format_time( int t )
  {
    if( t > 60*60 )
      return sprintf( "%d:%02d:%02d", t/3600, (t/60)%60, t%60 );
    return sprintf( "%2d:%02d", (t/60)%60, t%60 );
  }

  string avg_listen_time()
  {
    int tt = total_time;
    int n  = successful;
    foreach( conn, Connection c )
    {
      n++;
      tt += time()-c->connected;
    }
    int t = tt / (n||1);
    return format_time( t );
  }

  string longest_listen_time()
  {
    foreach( conn, Connection c )
      if( time()-c->connected > max_time )
	max_time = time()-c->connected;
    return format_time( max_time );
  }
  
  string status()
  {
    string res = "<table>";
    res += "<tr> <td colspan=2>"+
      ""+stream->status()+"</td></tr>"
      "<tr><td>Connections:</td><td>"+connections+"/"+max_connections+" ("+
      accessed+" since server start, "+denied+" denied)</td></tr><tr>"
      "<tr><td>Average listen time:</td><td>"+avg_listen_time()+"</td></tr>"
      "<tr><td>Longest listen time:</td><td>"+longest_listen_time()+"</td></tr>"
      "<tr><td>Current connections:</td><td>";
    foreach( conn, Connection c )
      res += "  "+c->status()+"\n";
    return res+"</td></tr></table>";
  }
  
}

mapping(string:Location) locations = ([]);

int __id=1;

class Connection
{
  Stdio.File fd;
  MPEGStream stream;
  int do_meta, last_meta;
  string protocol;
  int sent, skipped; // frames.
  int sent_bytes;
  int id = __id++;
  array buffer = ({});
  string current_block;
  function _ccb;
  mapping current_md;
  
  int connected = time();
  
  string status()
  {
    return sprintf( "%d. %s Time: %ds  Remote: %s  "
		    "%d sent, %d skipped<br />",id,protocol,
		    time()-connected,
		    (fd->query_address()/" ")[0],
		    sent-skipped, skipped );
  }

  string gen_metadata( )
  {
    if(!current_md )
      current_md = stream->playlist->metadata();
    string s = sprintf( " StreamTitle='%s';StreamUrl='%s';",
			current_md->name || current_md->path,
			"")+"\0";
    while( strlen(s) & 15 ) s+= "\0";
    s[0]=strlen(s);
    return s;
  }
  
  static void callback( string frame )
  {
    buffer += ({ frame });
    if( sizeof( buffer ) > 10 )
    {
      skipped++;
      buffer = buffer[1..];
    }
    if( !sizeof( buffer ) )
      send_more();
  }

  int headers_done;
  
  static void send_more()
  {
    if( !strlen(current_block) )
    {
      headers_done = 1;
      if( !sizeof(buffer) )
      {
	return;
      }
      current_block = buffer[0];

      if( do_meta )
      {
	if( (strlen( current_block ) + sent_bytes) - last_meta >= METAINTERVAL )
	{
	  last_meta = (strlen( current_block ) + sent_bytes);
	  current_block += gen_metadata();
	}
      }
      
      buffer = buffer[1..];
      sent++;
    }
    int n = fd->write( current_block );
    if( !n || n < 0 )
      closed();
    if( headers_done )
      sent_bytes += n;
    current_block = current_block[n..];
  }

  static void md_callback( mapping metadata )
  {
    current_md = metadata;
  }
  
  static void closed( )
  {
    fd = 0;
    stream->remove_callback( callback );
    stream->playlist->remove_md_callback( md_callback );
    _ccb( this_object() );
    destruct( this_object() );
  }
  
  static void create( Stdio.File _fd, string buffer, 
		      string prot, int _meta,  MPEGStream _stream,
		      function _closed )
  {
    protocol = prot;
    fd = _fd;
    do_meta = _meta;
    stream = _stream;
    _ccb = _closed;
    current_block = buffer;
    fd->set_nonblocking( lambda(){}, send_more, closed );
    if( stream ) 
      stream->add_callback( callback );
    if( stream->playlist )
      stream->playlist->add_md_callback( md_callback );
  }
}


class VarStreams
{
  inherit Variable.List;
  constant type="StreamList";

  // location
  // playlist
  // jingle
  // maxconn

  string render_row( string prefix, mixed val, int width )
  {
    string res = "<input type=hidden name='"+prefix+"' value='"+prefix+"' />";
    array split = val/"\0";
    res += (query_location()+"<input name='"+prefix+"loc' value='"+
	    Roxen.http_encode_string(split[0])+"' size=20/>");
    res += "<select name='"+prefix+"playlist'>";
    mapping pl;
    foreach( sort(indices(pl=playlists(0))), string p )
      if( pl[ p ]->sname() == split[1] )
	res += "<option value='"+pl[p]->sname()+"' selected='t'>"+p+"</option>";
      else
	res += "<option value='"+pl[p]->sname()+"'>"+p+"</option>";
    res += "</select><br />";
    res += ("conn: <input name='"+prefix+"conn' value='"+
	    ((int)split[3]||10)+"' size=5/>");
    res += ("jingle: <input name='"+prefix+"jingle' value='"+
	    Roxen.http_encode_string(split[2])+"' size=40/>");
    return res;
  }

  string transform_from_form( string v, mapping va )
  {
    if( v == "" ) return "\0\0\0\0";
    v = v[strlen(path())..];
    return va[v+"loc"]+"\0"+va[v+"playlist"]+"\0"+va[v+"jingle"]
           +"\0"+va[v+"conn"];
  }
  
  array(mapping) get_streams()
  {
    array res = ({});
    foreach( query(), string s )
    {
      mapping m = ([]);
      array a = s/"\0";
      m->location = a[0];
      m->playlist = a[1];
      m->jingle =   a[2];
      m->maxconn =  (int)a[3];
      if( !strlen( m->jingle ) )
	m_delete( m, "jingle" );
      res += ({ m });
    }
    return res;
  }
}

void create()
{
  defvar( "streams", VarStreams( ({}), 0, _(0,"Streams"),
				 _(0,"All the streams") ) );
  defvar("location", "/strm/",
	 _(0,"Mount point"), TYPE_LOCATION|VAR_INITIAL,
	 _(0,"Where the module will be mounted in the site's virtual "
   	     "file system."));
}

mapping playlists(int s)
{
  mapping res = ([ ]);
  foreach( my_configuration()->get_providers( "icecast:playlist" ),
	   Playlist m )
  {
    if( s )
      res[ m->sname() ] = m;
    else
      res[ m->pl_name() ] = m;
  }
  return res;
}

mapping streams = ([ ]);

void st2()
{
  mapping pl = playlists( 1 );
  foreach( getvar( "streams" )->get_streams(), mapping strm )
  {
    MPEGStream mps;

    if( strm->playlist && pl[ strm->playlist ] )
      if( !(mps = streams[ pl[strm->playlist] ]) )
      {
	mps = streams[pl[strm->playlist]] = MPEGStream( pl[strm->playlist] );
        mps->start();
      }
    if( !mps )
      continue;
    if( !locations[ strm->location ] )
      locations[ strm->location ] =
	Location( strm->location,
		  (strm->jingle?
		   Stdio.read_file( strm->jingle ) :
		   0 ),
		  mps,
		  (int)strm->maxconn );
  }
}

void start()
{
  call_out( st2, 0.5 );
}

mapping find_file( string f, RequestID id )
{
  if( locations[f] )
    return locations[f]->handle( id );
  return 0;
}


string status()
{
  string res = "<table>";
  foreach( indices( locations ), string loc )
  {
    res += "<tr><td valign=top>"+loc+"</td><td valign=top>"+
      locations[loc]->status()+"</td></tr>";
  }
  return res+"</table>";
}
