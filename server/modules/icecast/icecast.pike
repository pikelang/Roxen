// This is a ChiliMoon module. Copyright © 2001, Roxen IS.

inherit "module";
constant cvs_version="$Id: icecast.pike,v 1.13 2002/11/19 00:56:27 _cvs_hop Exp $";
constant thread_safe=1;

#define BSIZE 16384
#define METAINTERVAL 8192

#include <module.h>
#include <roxen.h>
#include <stat.h>
#include <request_trace.h>


constant module_type = MODULE_LOCATION | MODULE_TAG;
constant module_name = "Icecast: Server";
constant  module_doc = ( "Supports the ICY and Audio-cast protocols "
			 "for streaming MPEG sound. Relies on other "
			 "modules for the actual mpeg streams." );
constant module_unique = 0;

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"emit#mp3-stream": ({ #"<desc type='plugin'><p><short>
Use this source to retrieve information about currently configured
MP3 streams.</short></p>
<p>Playlist for given stream can be reached by RXML or by http query
with '?playlist' or '?playlist?=maxlines', where maxlines is maximum
number of returned items.</p>
</desc>

<attr name='name' value='name of stream'><p>
Name of configured stream.</p>
</attr>",
([
"&_.name;":#"<desc type='name'><p>
  The name of the stream.
  </p></desc>",

"&_.current-song;":#"<desc type='current-song'><p>
  The filename of current streamed song.
  </p></desc>",

"&_.next-song;":#"<desc type='next-song'><p>
  The filename of next streamed song.
  </p></desc>",

"&_.real-dir;":#"<desc type='real-dir'><p>
  The name base directory from real filesystem.
  </p></desc>",

"&_.accessed;":#"<desc type='accessed'><p>
  The number of accessed connections.
  </p></desc>",

"&_.denied;":#"<desc type='denied'><p>
  The number of denied connections.
  </p></desc>",

"&_.connections;":#"<desc type='connections'><p>
  The number of current connections.
  </p></desc>",

"&_.avg-listen-time;":#"<desc type='avg-listen-time'><p>
  The avarage of listen time.
  </p></desc>",

"&_.max-listen-time;":#"<desc type='max-listen-time'><p>
  The maximum of listen time.
  </p></desc>",

#if 0
"&_.con;":#"<desc type='con'><p>
  Array of current connections.
  </p></desc>"

"&_.playlist;":#"<desc type='playlist'><p>
  Playlist arranged in array of songs.
  </p></desc>"
#endif
])

})

]);
#endif


class Playlist
{
  inherit RoxenModule;
  Stdio.File next_file();
  string     pl_name();
  mapping    metadata();
  void       add_md_callback( function(mapping:void) f );
  void       remove_md_callback( function(mapping:void) f );

#if 0
  mixed `->(string index) {
#endif

};

class MPEGStream
{  
  array(function) callbacks = ({});
  int bitrate; // bits/second
  int stream_start=realtime(), stream_position; // µSeconds
  Stdio.File fd;
#if constant(Parser.MP3)
  Parser.MP3.File parser;
#else
  Audio.Format.MP3 parser;
#endif
  Playlist playlist;
  string cmd;

  mixed get_playlist() {
    if(!playlist || zero_type(playlist["current_file"])) {
      // playlist object is lost
      werror("DEB: playlist %O is lost!\n", "???");
      return 0;
    }
    return playlist;
  }

  void create(Playlist plist) {
    playlist = plist;
    fd = playlist->next_file();

  }

  string status()
  {
    return ""+get_playlist()->status()+"<br />"+
      sprintf( "Stream position: %.1fs   Bitrate: %dKbit/sec",
	       stream_position/1000000.0,
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
	remove_callback( f );
      }
  }
  
  static int last_hrtime, base_time;

  int realtime()
  {
    if(!last_hrtime)
    {
      last_hrtime = gethrtime();
      base_time = 0;
    }
    else
    {
      int nt = gethrtime();
      base_time += nt-last_hrtime;
      last_hrtime = nt;
    }
    return base_time;
  }

  void destroy()
  {
    catch(fd->set_blocking());
    catch(fd->close());
  }
  
  void feeder_thread( )
  {
    if(cmd) {
      switch(cmd) {
        case "forward":
	  if(fd = get_playlist()->cmd_next_file()) {
	    stream_position = 0;
	    parser = 0;
	  }
	  break;
        case "back":
	  if(fd = get_playlist()->cmd_prev_file()) {
	    stream_position = 0;
	    parser = 0;
	  }
	  break;
      }
      cmd = 0;
    }
    while( sizeof(callbacks) &&
	   ((realtime()-stream_start) > stream_position) )
    {
      mapping frame;
      if(!parser)
#if constant(Parser.MP3)
        parser = Parser.MP3.File(fd);
#else
        parser = Audio.Format.MP3();
	parser->buffer = Audio.Format.vbuffer(fd);
#endif
      frame = parser->get_frame();
      while( !frame )
      {
	fd->set_blocking();
	fd->close();
	fd = get_playlist()->next_file();
#if constant(Parser.MP3)
	parser = Parser.MP3.File(fd);
#else
	parser = Audio.Format.MP3();
	parser->buffer = Audio.Format.vbuffer(fd);
#endif
	frame = parser->get_frame();
      }
      // Actually, this is supposed to be quite constant, but not all
      // frames are the same size.
      stream_position += strlen(frame->data)*8000000 / frame->bitrate;
      call_callbacks( frame->data );
    }
    if(!sizeof(callbacks))
    {
      stream_position = 0;
      stream_start = realtime();
    }
    call_out( feeder_thread, 0.02 );
  }

  void start()
  {
    feeder_thread( ); // not actually a thread right now.
  }
  
} 

class Location( string location,
		string initial,
		MPEGStream stream,
		int max_connections,
		string url,
		string name )
		
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

    if( !stream->fd )
      stream->fd = stream->get_playlist()->next_file();
    
    mapping meta = stream->get_playlist()->metadata();
    if( !meta )
    {
      denied++;
      return Roxen.http_string_answer( "Too early\n" );
    }

    connections++;
    int use_metadata;
    string i, metahd="";
    string protocol = "ICY";
    int client_udp;

    werror("Client: %O\n", id->request_headers );
    if(id->request_headers[ "icy-metadata" ] )
    {
      use_metadata = (int)id->request_headers[ "icy-metadata" ];
      if( use_metadata )
	metahd = "icy-metaint:"+METAINTERVAL+"\r\n";
    }

    if( id->request_headers[ "x-audiocast-udpport" ] )
    {
      protocol = "AudioCast";
      if(id->request_headers[ "icy-metadata" ] &&
         query("udpmeta") ) {
        metahd = "x-audiocast-udpport: " + query("udpmeta") + "\r\n";
        client_udp = (int)id->request_headers[ "x-audiocast-udpport" ] ;
	use_metadata = 0;
      }

      i = ("HTTP/1.0 200 OK\r\n"
	   "Server: "+roxen.version()+"\r\n"
	   "Content-type: audio/mpeg\r\n"
	   "x-audiocast-gengre:"+(meta->gengre||"unknown")+"\r\n"
	   +((meta->url||url)?"x-audiocast-url:"+(meta->url||url)+"\r\n":"")+
	   "x-audiocast-name:"+name+"\r\n"
	   "x-audiocast-streamid:1\r\n"+metahd+
	   "x-audiocast-public:1\r\n"
	   "x-audiocast-bitrate:"+(stream->bitrate/1000)+"\r\n"
	   "x-audiocast-description:Served by ChiliMoon\r\n"
	   "\r\n" );
    }
    else
    {
      if( id->request_headers[ "icy-metadata" ] )
        i = ("ICY 200 OK\r\n"
	   "Server: "+roxen.version()+"\r\n"
	   "Content-type: audio/mpeg\r\n"
	   "icy-notice1:This stream requires a shoutcast compatible player.\r\n"
	   "icy-notice2:ChiliMoon mod_mp3\r\n"+metahd+
	   "icy-name:"+name+"\r\n"
	   "icy-gengre:"+(meta->gengre||"unknown")+"\r\n"
	   +((meta->url||url)?"icy-url:"+(meta->url||url)+"\r\n":"")+
	   "icy-pub:1\r\n"
	   "icy-br:"+(stream->bitrate/1000)+"\r\n"
	   "\r\n" );
      else {
    werror("MS Player?\n");
        protocol = "AudioCast";
        i = ("HTTP/1.0 200 OK\r\n"
	   "Server: "+roxen.version()+"\r\n"
	   "Content-type: audio/mpeg\r\n"
	   "Content-Length: 9999999999\r\n" );
      }
    }
    if( initial )
      i += initial;
    
    conn += ({ Connection( id->my_fd, i,protocol,use_metadata,
			   stream, this_object(),
			   lambda( Connection c ){
			     int pt = time()-c->connected;
			     conn -= ({ c });
			     total_time += pt;
			     if( pt > max_time )
			       max_time = pt;
			     successful++;
			     connections--;
			   }, client_udp ) });
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
      catch {
	res += "  "+c->status()+"\n";
      };
    return res+"</td></tr></table>";
  }
  
}

mapping(string:Location) locations = ([]);

int __id=1;

Stdio.UDP udpstream;
int q_playlist;

class Connection
{
  Stdio.File fd;
  MPEGStream stream;
  Location location;
  int do_meta, meta_cnt;
  string protocol;
  int sent, skipped; // frames.
  int sent_bytes, sent_meta;
  int id = __id++;
  array buffer = ({});
  string current_block;
  function _ccb;
  mapping current_md;
  int cudp;
  string claddr;
  
  int connected = time();
  
  string status()
  {
    if(!fd)
      return "Closed stream\n";
    return sprintf( "%d. %s Time: %ds  Remote: %s  "
		    "%d sent, %d skipped, meta: %s<br />",id,protocol,
		    time()-connected,
		    claddr,
		    sent, skipped,
		    cudp ? "UDP" : (do_meta ? "inline" : ""));
  }

  string old_mdkey;
  string gen_metadata( )
  {
    string s = "";
    if( !current_md )
      current_md = stream->get_playlist()->metadata();
    if( (current_md->name||current_md->path)+current_md->url != old_mdkey )
    {
      old_mdkey = (current_md->name||current_md->path)+current_md->url;
      s = sprintf( "StreamTitle='%s';StreamUrl='%s';",
		   get_streamtitle(),
		   location->url || current_md->url );
    }
    while( strlen(s) & 15 )
      s+= "\0";
    s = " " + s;
    s[ 0 ]=(strlen(s)-1)/16;
    //if(s[0])
    //  werror("MD: %O\n", s );
    return s;
  }

  void send_udptitle() {
    if(!current_md) {
      werror("No metadata found.\n");
      return;
    }
    //udp->send("192.168.1.3", 10003, "x-audiocast-udpseqnr: 1\r\nx-audiocast-streamtitle: hop - xxx\r\nx-audiocast-streamurl: http://mepege.unibase.cz/strm/en\r\nx-audiocast-streamleght: 3222111");
    udpstream->send(claddr, cudp,
		  "x-audiocast-streamtitle: "+get_streamtitle()+"\r\n");
  }
  
  static void callback( string frame )
  {
    buffer += ({ frame });
    if( sizeof( buffer ) > 100 )
    {
      skipped++;
      buffer = buffer[1..];
    }
    if( sizeof( buffer ) == 1 )
    {
      remove_call_out( send_more );
      call_out( send_more, 0.01 );
    }
  }

  int headers_done;

/*

http://www.xiph.org/archives/icecast-dev/0060.html

There are updates every interval. Please notice the 'justnull' 
variable. Apparently you haven't fully understood the format of the 
metadata: the first byte of metadata is a length byte. Multiply it by 
16 to determine how much text to extract from the stream as 
metadata. If the first byte is null, then you extract 0 bytes and 
continue to use the metadata you already have. Every 4096 bytes you 
either get new metadata if the udpseqnr doesn't match between source 
and client, or you get a 'null' length byte. You can't just omit the 
data without causing skipping problems - valid mp3 data would be 
interpreted as a length byte and that amount of data would be removed 
from the stream.

*/

/*

http://www.radiotoolbox.com/forums/viewtopic.php?t=76

I tried hosting PLS files with my web host and it didn't work, the files just got displayed as text files, why did this happen? 
Simply because your web servers MIME types were not setup properly to handle PLS files, in this case you must add them to your MIME types file. The proper entry is: 

Code: 
audio/x-scpls           pls  


or if 
you are using M3U files 

Code: 
audio/x-mpegurl       m3u  


If your web host does not allow you to access your mime types, you can request that it be added or, if your web host supports it, you can use the .htaccess file to add the mime type to the server.

*/
  
  static void send_more()
  {
    if( !strlen(current_block) )
    {
      headers_done = 1;
      if( !sizeof(buffer) )
	return;
      current_block = buffer[0];

      if( do_meta )
      {
	meta_cnt += strlen( current_block );
	if( meta_cnt >= METAINTERVAL )
	{
	  string meta = gen_metadata();
	  meta_cnt -= METAINTERVAL;
	  int rest = strlen(current_block)-meta_cnt-1;
	  sent_meta += strlen(meta);
	  current_block = current_block[..rest]+meta+current_block[rest+1..];
	}
      }
      buffer = buffer[1..];
      sent++;
    }
    int n = -1;
    catch( n = fd->write( current_block ));
    if( n > 0 )
    {
      if( headers_done )
	sent_bytes += n;
      current_block = current_block[n..];
    }
    else if( n < 0 )
      closed();
  }

  string get_streamtitle() {
    string title = query("mdtitle");
    title = replace(title, "%title%", current_md->title||"");
    title = replace(title, "%artist%", current_md->artist||"");
    title = replace(title, "%album%", current_md->album||"");
    title = replace(title, "%track%", current_md->track||"");
    title = replace(title, "%year%", (""+current_md->year) == "0" ? "" :
					current_md->year );
    return title;
  }

  static void md_callback( mapping metadata )
  {
    current_md = metadata;
    if(cudp && udpstream)
      send_udptitle();
  }
  
  static void closed( )
  {
    catch(fd->set_blocking( )); //hop@: zachyceno. BTW: nejspis je zbytecne?
    fd = 0;
    stream->remove_callback( callback );
    stream->get_playlist()->remove_md_callback( md_callback );
    _ccb( this_object() );
    werror("Closed from client side\n");
//     destruct( this_object() );
  }
  
  static void create( Stdio.File _fd, string buffer, 
		      string prot, int _meta,  MPEGStream _stream,
		      Location _loc,   function _closed, int _cudp )
  {
    location = _loc;
    protocol = prot;
    fd = _fd;
    do_meta = _meta;
    stream = _stream;
    _ccb = _closed;
    cudp = _cudp;
    claddr = (fd->query_address()/" ")[0];
    current_block = buffer;
    fd->set_nonblocking( lambda(){}, send_more, closed );
    if( stream ) 
      stream->add_callback( callback );
    if( stream->get_playlist() ) {
      md_callback(stream->get_playlist()->metadata());
      stream->get_playlist()->add_md_callback( md_callback );
    }
  }
}


class VarStreams
{
  inherit Variable.List;
  constant type="StreamList";

  // loc
  // playlist
  // jingle
  // maxconn
  // URL
  // name
  string render_row( string prefix, mixed val, int width )
  {
    string res = "<input type=hidden name='"+prefix+"' value='"+prefix+"' />";

    mapping m = decode_stream( val );
    
    res += "<table>";
    

    res += "<tr><td>Location "+query_location()+"</td><td>";
    res += ("<input name='"+prefix+"loc' value='"+
	    Roxen.html_encode_string(m->location||"")+"' size=20/>");
    res += "</td><td>Source</td><td>";
    res += "<select name='"+prefix+"playlist'>";
    mapping pl;
    foreach( sort(indices(pl=playlists(0))), string p )
      if( pl[ p ]->sname() == m->playlist )
	res +="<option value='"+pl[p]->sname()+"' selected='t'>"+p+"</option>";
      else
	res +="<option value='"+pl[p]->sname()+"'>"+p+"</option>";
    res += "</select></td></tr><tr>";

    res += ("<td>Max. conn</td><td><input name='"+prefix+"conn' value='"+
	    (m->maxconn||10)+"' size=5/></td> ");

    res += ("<td>Name</td><td> <input name='"+prefix+"name' value='"+
	    Roxen.html_encode_string(m->name || "")+"' size=20/></td></tr>");

    res += ("<tr><td>Jingle</td><td colspan=3>"
	    "<input name='"+prefix+"jingle' value='"+
	    Roxen.html_encode_string(m->jingle || "")+"' size=50/></td></tr>");

    res += ("<td>URL</td><td colspan=3> <input name='"+prefix+"url' value='"+
	    Roxen.html_encode_string(m->url || "")+"' size=50/></td>");

    return res+"</tr></table>";
  }

  string transform_from_form( string v, mapping va )
  {
    if( v == "" ) return "\0\0\0\0";
    v = v[strlen(path())..];
    return va[v+"loc"]+"\0"+va[v+"playlist"]+"\0"+va[v+"jingle"]
           +"\0"+va[v+"conn"]+"\0"+va[v+"url"]+"\0"+va[v+"name"];
  }

  mapping decode_stream( string s )
  {
    mapping m = ([]);
    array a = s/"\0";
    m->location = a[0];
    if( sizeof( a ) > 1 ) m->playlist = a[1];
    if( sizeof( a ) > 2 ) m->jingle =   a[2];
    if( sizeof( a ) > 3 ) m->maxconn =  (int)a[3];
    if( sizeof( a ) > 4 ) m->url = a[4];
    if( sizeof( a ) > 5 ) m->name = a[5];
    if( !m->jingle || !strlen( m->jingle ) ) m_delete( m, "jingle" );
    if( !m->url || !strlen( m->url ) )    m_delete( m, "url" );
    if( !m->name || !strlen( m->name ) )   m_delete( m, "name" );
    return m;
  }  
  array(mapping) get_streams()
  {
    return map( query(), decode_stream );
  }
}

void create()
{
  defvar( "streams", VarStreams( ({}), 0, "Streams", "All the streams" ) );

  defvar("location", "/strm/",
	 "Mount point", TYPE_LOCATION|VAR_INITIAL,
	 "Where the module will be mounted in the site's virtual file system.");

  defvar("udpmeta", 0,
	 "UDP port", TYPE_INT|VAR_MORE,
	 ("Port number for out of band metadata exchange. Note: Works only "
	  "for Audiocast clients (like FreeAmp). "
	  "<br /><b>Zero disables support</b>."));

  defvar("mdtitle", "%artist%: %album% [%year%]: %title%",
	 "Stream title", TYPE_STRING|VAR_MORE,
	 ("The template for title of stream<br />"
	  "Usable macros are:"
	  "<ul>"
	  "<li>%artist%<br />"
	  "Performer(s)/Soloist(s) <i>(TPE1 in v2.3+)</i><br /></li>"
	  "<li>%album%<br />"
	  "Album/Movie/Show title <i>(TALB in v2.3+)</i><br /></li>"
	  "<li>%title%<br />"
	  "Title/songname/content description "
	  "<i>(TIT2 in v2.3+)</i><br /></li>"
	  "<li>%track%<br />"
	  "Album/Movie/Show title <i>(TRCK in v2.3+)</i><br /></li>"
	  "<li>%year%<br />"
	  "A year of the recording<i>(TYER in v2.3+)</i><br /></li>"
	  "</ul>"
	  "."));

  defvar("pllen", 0,
	 "Playlist lenght", TYPE_INT|VAR_MORE,
	 ("Max. lenght of returned playlist. Useful for long playlists."
	  "<br /><b>Zero means full lenght</b>."));
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

werror("DEB: strm: %O\n", strm);
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
		  (int)strm->maxconn,
		  strm->url,
		  strm->name );
  }
}

void start(int occasion, Configuration conf)
{
  call_out( st2, 1 );
  
  // udpstreaming
  if(udpstream)
    udpstream = 0;
  if(query("udpmeta")) {
      udpstream = Stdio.UDP();
      mixed err = catch( udpstream->bind(query("udpmeta"),
      			Standards.URI(conf->query("MyWorldLocation"))->host) );
      if(err) {
        udpstream = 0;
        werror("UDP title streaming is disabled. Reason: "+err[0]+"\n");
      } else
        werror("UDP title streaming port [%s] is opened.\n", (udpstream->query_address()/" ")*":");
  }

}

mapping find_file( string f, RequestID id )
{

  if(id->query && stringp(id->query) && sizeof(id->query)) {
    array qs = id->query / "?"; // note: only first will be used
    switch((qs[0]/"=")[0]) {
      case "playlist": // playlist request
        string pls;
	int len;
	if(sizeof(qs[0]/"=") > 1)
	  len = (int)((qs[0]/"=")[1]);
	else
	  len = query("pllen");
	if(len)
	  pls = locations[f]->stream->get_playlist()->list[..len-1] * "\r\n";
	else
	  pls = locations[f]->stream->get_playlist()->list * "\r\n";
	q_playlist++;
#if 1
        return Roxen.http_string_answer(pls, "text/plain");
#else
        return Roxen.http_string_answer(pls, "audio/x-mpegurl");
#endif
	break;
      case "cmd-next": // forward request
	locations[f]->stream->cmd = "forward";
	break;
      case "cmd-prev": // back request
	locations[f]->stream->cmd = "back";
	break;
    }
    return 0;
  }
  
  if( locations[f] )
    return locations[f]->handle( id );
  return 0;
}


string status()
{
  string res = udpstream ? "<p>UDP title streaming port: " +
  		  query("udpmeta") + "</p>\n" : "";
  res += "<p>Playlist queries: " + q_playlist + "</p>\n";
  res += "<h3>Streams</h3><table>";
  foreach( indices( locations ), string loc )
  {
    res += "<tr><td valign=top>"+loc+"</td><td valign=top>"+
      locations[loc]->status()+"</td></tr>";
  }
  return res+"</table>";
}

// -hop@

class TagEmitKnownMP3streams
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "mp3-stream";
  array get_dataset(mapping m, RequestID id)
  {
    if(m->name)
      if(locations[m->name])
        return ({ loc_description(m->name, (int)m->listmax, m->delimiter) });
      else
        return 0;
    return map(indices(locations), loc_description);
  }

  private mapping loc_description(string loc, int maxlist, string delim) {
    return (["name": loc,
	"accessed": locations[loc]->accessed,
	"denied": locations[loc]->denied,
	"connections": locations[loc]->connections,
	"avg-listen-time": locations[loc]->avg_listen_time(),
	"longest-listen-time": locations[loc]->longest_listen_time(),
	"real-dir": locations[loc]->stream->get_playlist()->real_dir(),
	"current-song":
	  locations[loc]->stream->get_playlist()->current_filename() || "",
	"next-song":
	  locations[loc]->stream->get_playlist()->peek_next() || "",
#if 0
	"conn":
	  map(locations[loc]->fd->query_address()/" ")[0]
#endif
	"playlist": 
	  maxlist ?
	  locations[loc]->stream->get_playlist()->list[..maxlist-1] * (delim || "\0")
	  : locations[loc]->stream->get_playlist()->list * (delim || "\0")
	]);
  }
}
