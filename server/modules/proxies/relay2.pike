// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

#include <module.h>
constant cvs_version = "$Id$";

inherit "module";
constant module_type = MODULE_FIRST|MODULE_LAST;

constant module_name =
"Proxies: HTTP Relay module";

constant module_doc =
"Smart HTTP relay module. Can relay according to "
"regular expressions.";

array(Relayer) relays = ({});

class Relay
{
  RequestID id;
  string url;
  multiset options;

  string request_data;
  string host;
  int port;
  string file;

  Stdio.File fd;

  mapping make_headers( RequestID from, int trim )
  {
    mapping res = ([
      "Proxy-Software":roxen->version(),
      // These are set by Apaches mod_proxy and are more or less
      // defacto standard.
      "X-Forwarded-For": from->remoteaddr,
      "X-Forwarded-Host": from->request_headers->host,
    ]);

    // Also try to model X-Forwarded-Server after Apaches mod_proxy.
    // The following is ripped from RequestID.url_base.
    string server_host;
    if (Protocol port = from->port_obj) {
      server_host = port->conf_data[from->conf]->hostname;
      if (server_host == "*")
	server_host = from->conf->get_host();
    }
    else
      server_host = my_configuration()->get_host();
    if (server_host)
      res["X-Forwarded-Server"] = server_host;

    if( trim ) return res;
    foreach( from->request_headers; string i; string v)
    {
      switch( i )
      {
      case "accept-encoding":
	// We need to support the stuff we pass on in the proxy
	// otherwise we might end up with things like double
	// gzipped data.
	 break;
       case "connection": /* We do not support keep-alive yet. */
	 res->Connection = "close";
         break;
       case "host":
         res->Host = host+":"+port;
	 break;
       case "x-forwarded-for":
	 res["X-Forwarded-For"] = v + "," + res["X-Forwarded-For"];
	 break;
       case "x-forwarded-host":
	 res["X-Forwarded-Host"] = v + "," + res["X-Forwarded-Host"];
	 break;
       case "x-forwarded-server":
	 if (server_host)
	   res["X-Forwarded-Server"] = v + "," + server_host;
	 else
	   res["X-Forwarded-Server"] = v;
	 break;
       default:
	 res[Roxen.canonicalize_http_header (i) || String.capitalize (i)] = v;
         break;
      }
    }
    return res;
  }

  string encode_headers( mapping q )
  {
    string res = "";
    string content_length="";
    foreach( sort( indices( q ) ), string h )
      if(lower_case(h)=="content-length")
	content_length = (string)h+": "+(string)q[h]+"\r\n";
      else
	if( arrayp( q[h] ) )
	  foreach( q[h], string w )
	    res += (string)h+": "+(string)w+"\r\n";
	else
	  res += (string)h+": "+(string)q[h]+"\r\n";
    return res+content_length;
  }

  string buffer;
  void got_some_more_data( mixed q, string d)
  {
    buffer += d;
  }

  void done_with_data( )
  {
    destruct(fd);
    string headers, data;
    string type, charset, status;
    int code;
    mapping h = ([]);

    if (additional_headers) {
      h = copy_value(additional_headers);
    }

    if(!id) {
      destruct();
      return;
    }

    string rewrite( string what )
    {
      // in what: URL.
      if(!strlen(what))
	return what; // local, is OK.

      if( what[0] == '/' ) // absolute, is not OK.
      {
	string base = id->not_query;
	string f2 = (file/"?")[0];
	if( strlen(f2) && search(id->not_query, f2 ) != -1)
	  base = base[..search(id->not_query, f2 )-2];
	return combine_path( base, what[1..] );
      }
      else if( search( what, url ) == 0 )
      {
	return replace( what, url, id->not_query );
      }
      return what;
    };

    string do_rewrite( string what )
    {
      Parser.HTML p = Parser.HTML();

      function rewrite_what( string elem )
      {
	return lambda( string t, mapping a ) {
		 if( a[elem] )
		   a[elem] = rewrite( a[elem] );
		 return ({Roxen.make_tag( p->tag_name(), a, 1 )});
	       };
      };
       p->add_tag( "a", rewrite_what("href") );
       p->add_tag( "img", rewrite_what("src") );
       p->add_tag( "form", rewrite_what("action") );
       return p->finish( what )->read();
    };



    if( !options->cache ) NO_PROTO_CACHE();

    if( sscanf( buffer, "%s\r\n\r\n%s", headers, data ) != 2 )
      sscanf( buffer, "%s\n\n%s", headers, data );

    if( headers )
    {
      sscanf( headers, "HTTP/%*[^ ] %d", code );

      foreach( ((headers-"\r")/"\n")[1..], string header )
      {
        if( sscanf( header, "%s:%s", string a, string b ) == 2 )
        {
          a = String.trim_all_whites( a );
          b = String.trim_all_whites( b );

          switch( lower_case( a ) )
          {
           case "connection":
           case "content-length":
           case "content-location":
             break;
           case "content-type":
             h["Content-Type"] = b;
             type = b;
             break;
           default:
	     if (h[a]) {
	       if (arrayp(h[a])) h[a] += ({ b });
	       else h[a] = ({ h[a], b });
	     }
	     else
	       h[a] = b;
          }
        } else
          status = header;
      }
      if(!type)
	type = "text/html";
      else if( sscanf( type-" ", "text/%*s;charset=%s", charset ) == 2 )
        type = String.trim_all_whites( (type/";")[0] );
    }

#ifdef RELAY_DEBUG
    werror("RELAY: url: %O, type: %O, data: %O bytes, headers: \n%s\n\n",
	   id->not_query, type, sizeof(data), headers);
#endif

    if( !headers || !data )
    {
      mapping q = Roxen.http_string_answer( buffer, "" );
      q->raw = 1;
      id->send_result( q );
      destruct( );
      return;
    }
    if( options->rxml && code >= 200 && code < 300 &&
	(lower_case(type) == "text/html" ||
	 lower_case(type) == "text/plain" ))
    {
      if( charset )
      {
        id->set_output_charset( charset );
        catch
        {
          data = Locale.Charset.decoder(charset)->feed(data)->drain();
        };
      }
      if( options->rewrite )
	do_rewrite( data );
      id->misc->defines = ([]);
      id->misc->defines[" _extra_heads"] = h;
      id->misc->defines[" _error"] = code;
#ifdef RELAY_DEBUG
      werror("RELAY: parsing rxml\n");
#endif
      id->send_result( Roxen.http_rxml_answer( query("pre-rxml")
                                               + data +
                                               query("post-rxml"), id ) );
    }
    else if( options->rewrite &&
	     (lower_case(type) == "text/html" ||
	      lower_case(type) == "text/plain" ))
    {
      id->send_result(([ "data":do_rewrite(data),
			 "type":type,
			 "extra_heads":h,
			 "error":code ]) );
    }
    else
    {
      id->send_result(([ "data":data,
			 "type":type,
			 "extra_heads":h,
			 "error":code ]) );
    }
    destruct();
    return;
  }

  string obuffer;
  void write_more( )
  {
    if( strlen( obuffer ) )
      obuffer = obuffer[ fd->write( obuffer ) .. ];
#ifdef RELAY_DEBUG
    else
      werror("RELAY: Request sent OK\n");
#endif
  }


  void connected( int how )
  {
    if( !how )
    {
#ifdef RELAY_DEBUG
      werror("RELAY: Connection failed: %s (%d)\n",
             strerror (fd->errno()), fd->errno());
#endif
      NOCACHE();
      id->send_result(
	Roxen.http_low_answer(Protocols.HTTP.HTTP_GW_TIMEOUT,
			      "504 Gateway Timeout: "
			      "Connection to remote HTTP host failed."));
      destruct();
      return;
    }

#ifdef RELAY_DEBUG
      werror("RELAY: Connection OK\n");
#endif
    // Send headers to remote server. (non-blocking)

    if( options->stream )
    {
      Stdio.sendfile( ({ request_data }), 0, 0, 0, 0, fd,
		      lambda(int q) {
#ifdef RELAY_DEBUG
			werror("RELAY: Request sent OK\n");
#endif
			Stdio.sendfile( 0, fd, 0, 0, 0, id->my_fd );
		      } );
      destruct();
    }
    else
    {
      obuffer = request_data;
      request_data = 0;
      buffer="";
      fd->set_nonblocking( got_some_more_data, write_more, done_with_data );
    }
  }

  void create( RequestID _id,
               string _url,
               multiset _options )
  {
    id = _id;
    url = _url;
    options = _options;

    //  Support IPv6 addresses
    Standards.URI uri = Standards.URI(url);
    host = uri->host;
    port = uri->port || 80;
    file = uri->get_path_query();
    if (has_prefix(file, "/"))
      file = file[1..];

    if( options->raw )
      request_data = _id->raw;
    else
    {
      mapping headers = ([]);
      headers = make_headers( id, options->trimheaders );

      request_data = (id->method+" /"+file+" HTTP/1.0\r\n"+
                      encode_headers( headers ) +
                      "\r\n" + id->data );

    }

    if( options->utf8 )
      request_data = string_to_utf8( request_data );
    fd = Stdio.File( );

#ifdef RELAY_DEBUG
    werror("RELAY: Connecting to "+host+":"+port+"\n");
#endif

    // Kludge for bug 3127.
    if (linux) {
      if( fd->connect( host, port ) )
	connected( 1 );
      else
	connected( 0 );
      return;
    }

    fd->async_connect( host, port, connected );
  }
}

mapping stats = ([ ]);

class Relayer
{
  object r;
  string pattern;
  string url;
  multiset options;
  int last;

  string do_replace( array(string) to )
  {
    array from = map( indices( to ), lambda(int q ){
                                       return "\\"+(q+1);
                                     } );
    if( sizeof( to ) )
      return predef::replace( url, from, (array(string)) to );
    return url;
  }

  int(0..1) relay( object id )
  {
    string file = id->not_query;

    if( id->query )
      file = file+"?"+id->query;

    // Workaround widestring deficiency in the regexp module.
    int use_utf8 = String.width (file) > 8;
    if (use_utf8) file = string_to_utf8 (file);

    if (array(string) split = r->split( file ) )
    {
      if (use_utf8)
	for (int i = sizeof (split); i--;)
	  if (stringp (split[i]))
	    // Catch errors in case the split broke apart a utf8 sequence.
	    catch (split[i] = utf8_to_string (split[i]));

      stats[ pattern ]++;
      Relay( id, do_replace( split ), options );
      return 1;
    }
  }

  void create( string p, string u, int _last, multiset o )
  {
    last = _last;
    pattern = p;
    options = o;
    url = u;
    r = Regexp( pattern );
  }
}


/****** module callbacks **/

void create( Configuration c )
{
  if( c )
  {
    defvar( "patterns", "", "Relay patterns", TYPE_TEXT,
            "<p>Syntax:\n"
            "<pre>\n"
            "[LAST ]EXTENSION extension CALL url-prefix [rxml] [trimheaders] [raw] [utf8] [cache] [stream] [rewrite]\n"
            "[LAST ]LOCATION location CALL url-prefix [rxml] [trimheaders] [raw] [utf8] [cache] [stream] [rewrite]\n"
            "[LAST ]MATCH regexp CALL url [rxml] [trimheaders] [raw] [utf8] [cache] [stream] [rewrite]\n"
            "</pre> \\1 to \\9 will be replaced with submatches from the "
	    "regexp.</p><p>"

	    "Rxml, trimheaders etc. are flags. If <b>rxml</b> is specified, "
	    "the result of the relay will be RXML-parsed. Trimheaders and raw "
	    "are mutually exclusive. If <b>trimheaders</b> is present, only "
	    "the most essential headers are sent to the remote server "
	    "(actually, no headers at all right now), if <b>raw</b> is "
	    "specified, the request is sent to the remote server exactly as it "
	    "arrived to Roxen, not even the Host: header is changed.  If "
	    "<b>utf8</b> is specified the request is utf-8 encoded before it "
	    "is sent to the remote server.</p><p>"

	    "Cache and stream alter the sending of data to the client. If "
	    "<b>cache</b> is specified, the data can end up in the roxen "
	    "data cache, if <b>stream</b> is specified, the data is streamed "
	    "directly from the server to the client. This disables logging, "
	    "headers will be exactly those sent by the remote server, and this "
	    "only works for http clients. Less memory is used, however.</p><p>"

	    "For <b>EXTENSION</b> and <b>LOCATION</b>, the URL path+query "
	    "components (<b>location</b> part trimmed off) is appended to the "
	    "<b>url-prefix</b> specified; no replacing is done.</p><p>"

	    "Note that /login.xml is a submatch in itself, it will match all paths containing /login.xml, "
	    "since /login.xml will be translated to /login.xml(.*) and therefore "
	    "will match /login.xml, /foo/login.xml, /bar/foo/login.xml and /login.xml?x=3"
	    "Changing the pattern to ^/login.xml will make it only match /login.xml and anything "
	    "after /login.xml - e.g. /login.xml?x=2&amp;y=34.</p><p>"

            "If <b>LAST</b> is specified, the match is only tried if Roxen "
            "fails to find a file (a 404 error). If <b>rewrite</b> is "
	    "specified, redirects and file contents are rewritten if possible, "
	    "so that links and images point to the correct place.</p><p>"

	    "Example:\n"
	    "<pre>\n"
	    "LOCATION /&lt;path&gt;/ CALL http://&lt;domain&gt;/&lt;path&gt;/\n"
 	    "</pre></p>");
    defvar("pre-rxml", "",
           "Header-RXML", TYPE_TEXT,
           "Included before the page contents for redirectpatterns with "
           "the 'rxml' attribute set if the content-type is text/*" );
    defvar("post-rxml", "",
           "Footer-RXML", TYPE_TEXT,
           "Included after the page contents for redirectpatterns with "
           "the 'rxml' attribute set if the content-type is text/*" );
    defvar("additional-headers", "",
           "Additional response headers", TYPE_TEXT,
           "Additional headers to add to the response. Write in the format:<br/>"
           "<tt>Header-Name: header-value</tt><br/>One header per line.");
  }
}

string status()
{
  string res = "Relays per regexp:<p>\n"
         "<table cellpadding=0 border=0>";
  foreach( sort(indices(stats)), string s )
    res += sprintf("<tr><td>%s</td><td align=right>%d</td></tr>\n",
                   s, stats[s]);
  return res + "</table>\n";
}

int linux;

mapping additional_headers = ([]);

void start( int i, Configuration c )
{
  if (uname()->sysname == "Linux")
    linux = 1;
  if( c )
  {
    relays = ({});
    foreach( (query( "patterns" )-"\r") / "\n" - ({ "" }), string line )
    {
      if( strlen(line) && line[0] == '#' )
        continue;
      sscanf( line, "%s#", line );
      array tokens = replace( String.trim_whites( line ), "\t", " ")/" " - ({ "" });
      int last;
      if( sizeof( tokens ) > 2 )
      {
        tokens -= ({ "CALL", "call", "OPTIONS", "options" });
        if( lower_case( tokens[0] ) == "last" )
        {
          last = 1;
          tokens = tokens[1..];
        }

        switch( lower_case(tokens[ 0 ]) )
        {
         case "match":
           tokens = tokens[1..];
           break;

         case "location":
           tokens = tokens[1..];
           tokens[0] = replace(tokens[0],
                               ({"*", ".", "?" }),
                               ({ "\\*", "\\.", "\\?" }) )+"(.*)";
           tokens[1] += "\\1";
           break;

         case "extension":
           tokens = tokens[1..];
           tokens[1] += "\\1."+tokens[0]+"\\2";
           tokens[0] = "^([^?]*)\\."+
                     replace(tokens[0],
                             ({"*", ".", "?" }),
                             ({ "\\*", "\\.", "\\?" }) )
                     +"(.*)";
           break;

         default:
           report_warning( "Unknown rule: "+tokens[0]+"\n");
           break;
        }

        if(mixed e  = catch ( relays += ({ Relayer( tokens[0], tokens[1],last,
                                                    (multiset)map(tokens[2..],
                                                                  lower_case))
        }) ) )
          report_warning( "Syntax error in regular expression: "+
                          tokens[0]+": %s\n", ((array)e)[0] );
      }
    }

    additional_headers = ([]);

    foreach ((query("additional-headers")-"\r")/"\n", string line) {
      line = String.trim_all_whites(line);

      if (!sizeof(line) || line[0] == '#') {
        continue;
      }

      if (sscanf(line, "%s:%s", string name, string val) == 2) {
        string n = Roxen.canonicalize_http_header(name) ||
                   String.capitalize(name);
        additional_headers[n] = String.trim_all_whites(val);
      }
    }

#ifdef RELAY_DEBUG
    werror("Additional headers: %O\n", additional_headers);
#endif
  }
}

mapping first_try( RequestID id )
{
  foreach( relays, Relayer q )
    if( !q->last && q->relay( id ) )
      return Roxen.http_pipe_in_progress( );
}

mapping last_resort( RequestID id )
{
  foreach( relays, Relayer q )
    if( q->last && q->relay( id ) )
      return Roxen.http_pipe_in_progress( );
}
