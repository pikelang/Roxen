inherit "module";
constant module_type = MODULE_FIRST;

constant module_name =
"HTTP Relay module, take 2";

constant module_doc =
"Smart HTTP relay module. Can relay according to "
"regular expressions.";

array(Relayer) relays;


class Relay
{
  RequestID id;
  string url;
  multiset options;

  string request_data;
  string host;
  int port;

  Stdio.File fd;

  mapping make_headers( object from, int trim )
  {
    mapping res = ([ "proxy-software":version(), ]);
    if( trim ) return res;
    foreach( indices(from->request_headers), string i )
    {
      switch( lower_case(i) )
      {
       case "connection": /* We do not support keep-alive yet. */
         break;
       case "host":
         res[i] = host+":"+port;
         break;
       default:
         res[i] = from->request_headers[i];
         break;
      }
    }
    return res;
  }

  string encode_headers( mapping q )
  {
    string res = "";
    foreach( sort( indices( q ) ), string h )
      res += (string)h+": "+(string)q[h]+"\r\n";
    return res;
  }

  string buffer;
  void got_some_more_data( mixed q, string d)
  {
    buffer += d;
  }

  void done_with_data( )
  {
    destruct(fd);
    id->send_result( http_rxml_reply( buffer, id ) );
    destruct();
    return;
  }

  void connected( int how )
  {
    if( !how )
    {
      id->send_result( ([
        "type":"text/plain",
        "data":"Connection to remote HTTP host failed."
      ]) );
      destruct();
      return;
    }

    sendfile( ({ request_data }), 0, 0, 0, 0, fd, 0, 0 );

    if( !options->rxml )
    {
      id->send_result( ([
        "raw":1,
        "file":fd
      ]) );
      destruct();
      return;
    }

    buffer="";
    fd->set_read_callback( got_some_more_data );
    fd->set_close_callback( done_with_data );
  }

  void create( RequestID _id,
               string _url,
               multiset _options )
  {
    id = _id;
    url = _url;
    options = _options;

    if( options->raw )
      request_data = _id->raw;
    else
    {
      mapping headers = ([]);

      if( sscanf(url,"%*[^:/]://%[^:/]:%d/%s",host,port,file) != 4 )
      {
        port=80;
        sscanf(url,"%*[^:/]://%[^:/]/%s",host,file);
      }

      headers = make_headers( id, options->trimheaders );

      request_data = (id->method+" "+file+" HTTP/1.0\r\n"+
                      encode_headers( headers ) +
                      "\r\n" + id->data );
    }

    if( options->utf8 )
      request_data = string_to_utf8( request );

    fd = Stdio.File( );

    fd->async_connect( host, port, connected );
  }
}


class Relayer
{
  inherit Regexp;
  string pattern;
  string url;
  multiset options;

  void do_replace( string f )
  {
    array to = split( f );
    array from = map( indices( to ), lambda(int q ){
                                       return "\\"+(q+1);
                                     } );
    return replace( url, from, to );
  }

  Relay relay( object id )
  {
    string file = id->not_query;

    if( id->query )
      file = file+"?"+id->query;

    if( match( file ) )
      return Relay( id, do_replace( file ), options );
  }

  void create( string pattern, string u, multiset o )
  {
    options = o;
    url = u;
    ::create( pattern );
  }
}


/****** module callbacks **/

void create( Configuration c )
{
  if( c )
  {
    defvar( "patterns", "", "Relay patterns", TYPE_TEXT,
            "Syntax: \n"
            "<pre>\n"
            "EXTENSION extension CALL url-prefix [rxml] [trimheaders] [raw] [utf8]\n"
            "LOCATION location CALL url-prefix [rxml] [trimheaders] [raw] [utf8]\n"
            "MATCH regexp CALL url [rxml] [trimheaders] [raw] [utf8]\n"
            "<pre> \1 to \9 will be replaced with submatches from the regexp."
            "rxml, trimheaders etc. are flags. If rxml is specified, the "
            "result of the relay will be RXML-parsed, Trimheaders and raw are "
            " mutually exclusive, if"
            "trimheaders is present, only the most essential headers are sent "
            "(actually, no headers at all right now), "
            "if raw is specified, the request is sent to the remote server"
            " exactly as it arrived to roxen, not even the Host: header "
            "is changed.  If utf8 is specified the request is utf-8 encoded "
            "before it is sent to the remote server." );
  }
}

void start( Configuration c )
{
  if( c )
  {
    relays = ({});
    foreach( query( "patterns" ) / "\n" - ({ "" }), string line )
    {
      if( strlen(line) && line[0] == '#' )
        continue;
      sscanf( line, "%s#", line );
      array tokens = replace( trim( line ), "\t", " ")/" " - ({ "" });
      if( sizeof( tokens ) > 2 )
      {
        tokens -= ({ "CALL", "call", "OPTIONS", "options" });
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
           tokens[1] += "\1";
           break;
         case "extension":
           tokens = tokens[1..];
           tokens[1] += "\1."+tokens[0]+"\2";
           tokens[0] = "(.*)\\."+
                     replace(tokens[0],
                             ({"*", ".", "?" }),
                             ({ "\\*", "\\.", "\\?" }) )
                     +"(.*)";
         default:
           report_warning( "Unknown rule: "+tokens[0]+"\n");
           break;
        }
        if(catch ( relays += ({ Relayer( tokens[0], tokens[1],
                                         (multiset)map(tokens[2..],lower_case))
        }) ) )
          report_warning( "Syntax error in regular expression: "+
                          token[0]+"\n" );
    }
  }
}

mapping first_try( RequestID id )
{
  foreach( relays, Relayer q )
    if( q->relay( id ) )
      return http_pipe_in_progress( );
}
