#include <module.h>
inherit "module";
inherit "roxenlib";
constant module_type = MODULE_FIRST;

constant module_name =
"HTTP Relay module, take 2";

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

  Stdio.File fd;

  mapping make_headers( object from, int trim )
  {
    mapping res = ([ "Proxy-Software":roxen->version(), ]);
    if( trim ) return res;
    foreach( indices(from->request_headers), string i )
    {
      switch( lower_case(i) )
      {
       case "connection": /* We do not support keep-alive yet. */
         break;
       case "host":
         res[String.capitalize( i )] = host+":"+port;
         break;
       default:
         res[String.capitalize( i )] = from->request_headers[i];
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
    id->send_result( http_rxml_answer( buffer, id ) );
    destruct();
    return;
  }

  void done_with_send( int ok )
  {
    id->end();
    destruct( fd );
    destruct( );
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

    Stdio.sendfile( ({ request_data }), 0, 0, 0, 0, fd );

    if( !options->rxml )
    {
      Stdio.sendfile( ({}), fd, 0, -1, ({}), id->my_fd, done_with_send );
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
      string file;

      if( sscanf(url,"%*[^:/]://%[^:/]:%d/%s",host,port,file) != 4 )
      {
        port=80;
        sscanf(url,"%*[^:/]://%[^:/]/%s",host,file);
      }

      headers = make_headers( id, options->trimheaders );

      request_data = (id->method+" /"+http_encode_string(file)+" HTTP/1.0\r\n"+
                      encode_headers( headers ) +
                      "\r\n" + id->data );

    }

    if( options->utf8 )
      request_data = string_to_utf8( request_data );
    fd = Stdio.File( );
    fd->async_connect( host, port, connected );
  }
}


class Relayer
{
  object r;
  string pattern;
  string url;
  multiset options;

  string do_replace( string f )
  {
    array to = (array(string))r->split( f );
    array from = map( indices( to ), lambda(int q ){
                                       return "\\"+(q+1);
                                     } );
    if( sizeof( to ) )
      return predef::replace( url, from, to );
    return url;
  }

  Relay relay( object id )
  {
    string file = id->not_query;

    if( id->query )
      file = file+"?"+id->query;

    if( r->match( file ) )
      return Relay( id, do_replace( file ), options );
  }

  void create( string p, string u, multiset o )
  {
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
            "Syntax: \n"
            "<pre>\n"
            "EXTENSION extension CALL url-prefix [rxml] [trimheaders] [raw] [utf8]\n"
            "LOCATION location CALL url-prefix [rxml] [trimheaders] [raw] [utf8]\n"
            "MATCH regexp CALL url [rxml] [trimheaders] [raw] [utf8]\n"
            "</pre> \1 to \9 will be replaced with submatches from the regexp.<p>"
            "rxml, trimheaders etc. are flags. If rxml is specified, the "
            "result of the relay will be RXML-parsed, Trimheaders and raw are "
            " mutually exclusive, if"
            "trimheaders is present, only the most essential headers are sent "
            "(actually, no headers at all right now), "
            "if raw is specified, the request is sent to the remote server"
            " exactly as it arrived to roxen, not even the Host: header "
            "is changed.  If utf8 is specified the request is utf-8 encoded "
            "before it is sent to the remote server.<p>"
            " For EXTENSION and LOCATION, the matching local filename is "
            "appended to the url-prefix specified, no replacing is done." );
  }
}

void start( int i, Configuration c )
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
           tokens[1] += "\\1";
           break;

         case "extension":
           tokens = tokens[1..];
           tokens[1] += "\\1."+tokens[0]+"\\2";
           tokens[0] = "(.*)\\."+
                     replace(tokens[0],
                             ({"*", ".", "?" }),
                             ({ "\\*", "\\.", "\\?" }) )
                     +"(.*)";
           break;

         default:
           report_warning( "Unknown rule: "+tokens[0]+"\n");
           break;
        }

        if(mixed e  = catch ( relays += ({ Relayer( tokens[0], tokens[1],
                                                    (multiset)map(tokens[2..],
                                                                  lower_case))
        }) ) )
          report_warning( "Syntax error in regular expression: "+
                          tokens[0]+": %s\n", ((array)e)[0] );
      }
    }
  }

}

mapping first_try( RequestID id )
{
  foreach( relays, Relayer q )
    if( q->relay( id ) )
      return http_pipe_in_progress( );
}
