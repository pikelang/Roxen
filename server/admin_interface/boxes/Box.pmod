mapping cache =  ([]);

class RDF
{
  constant url = "";

  string parse( RequestID id )
  {
    string data;
    string contents;

    string host, file;
    int port;

    Standards.URI uri = Standards.URI( url );
    host = uri->host;
    port = uri->port;
    file = uri->path+(uri->query?"?"+uri->query:"");
    
    if( !(data = get_http_data( host, port, "GET "+file+" HTTP/1.0" ) ) )
      contents = sprintf("Fetching data from %s...", host);
    else
    {
      contents = "";
      string title,link,description;
      Parser.HTML itemparser = Parser.HTML() ->
	add_containers( ([ "title": lambda(Parser.HTML p, mapping m, string c)
				      { title = c; },
			   "description":lambda(Parser.HTML p, mapping m,
						string c)
				      { description = c; },
			   "link": lambda(Parser.HTML p, mapping m, string c)
				     { link = c; } ]) );
      Parser.HTML() -> add_container("item",
				     lambda(Parser.HTML p, mapping m, string c)
				     {
				       title = link = 0;
				       description="";
				       itemparser->finish(c);
				       if(title && link)
					 contents +=
					   sprintf("<font size=-1>"
						   "<a href=\"%s\">%s</a>"
						   "<br />%s<br />"
						   "</font>\n",
						   link, title, description);
				     } )->
	finish(data);
    }
    return ("<box type='"+this_object()->box+"' title='"+
	    this_object()->box_name+"'>"+contents+"</box>");
  }
}

class Fetcher
{
  Protocols.HTTP.Query query;
  function cb;
  string h, q;
  int p;

  void done( Protocols.HTTP.Query qu )
  {
    cache[h+p+q] = ({query->data()});
    if( cb )
      cb( query->data() );
  }
  
  void fail( Protocols.HTTP.Query qu )
  {
    cache[h+p+q] = ({"Failed to connect to server"});
    if( cb )
      cb(  "Failed to connect to server" );
    call_out( start, 30 );
  }

  void start( )
  {
    remove_call_out( start );
    call_out( start, 3600 );
    query = Protocols.HTTP.Query( )->set_callbacks( done, fail );
    query->async_request( h, p, q, ([ "Host":h+":"+p ]) );
  }
  
  void create( function _cb, string _h, int _p, string _q,
	       RequestID id )
  {
    cb = _cb;
    h = _h; p = _p; q = _q;

    RoxenModule px;
    if( px = id->conf->find_module("update#0") )
    {
      if( strlen( px->query( "proxyserver" ) ) )
      {
	sscanf( q, "GET %s", q );
	q = "GET http://"+h+":"+p+q;
	h = px->query( "proxyserver" );
	p = px->query( "proxyport" );
      }
    }
    start();
  }
}

string get_http_data( string host, int port, string query,
		      function|void cb )
{
  mixed data;
#ifdef OFFLINE
  return "The server is offline.";
#else
  if( data = cache[host+port+query] )
  {
    return data[0];
  }
  else
  {
    cache[host+port+query] = ({0});
    RXML.get_context()->id->variables->_box_fetching = 1;
    Fetcher( cb, host, port, query, RXML.get_context()->id );
  }
#endif
}
