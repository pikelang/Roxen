mapping cache =  ([]);
/*
 * Locale stuff.
 * <locale-token project="roxen_config">_</locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

class RDF
{
  constant host = "";
  constant port = 80;
  constant file = "";

  string parse( RequestID id )
  {
    string data;
    string contents;
    if( !(data = get_http_data( host, port,"GET "+file+" HTTP/1.0" ) ) )
      contents = sprintf((string)_(0,"Fetching data from %s..."), host);
    else
    {
      contents = "";
      string title,link;
      Parser.HTML itemparser = Parser.HTML() ->
	add_containers( ([ "title": lambda(Parser.HTML p, mapping m, string c)
				      { title = c; },
			   "link": lambda(Parser.HTML p, mapping m, string c)
				     { link = c; } ]) );
      Parser.HTML() -> add_container("item",
				     lambda(Parser.HTML p, mapping m, string c)
				     {
				       title = link = 0;
				       itemparser->finish(c);
				       if(title && link)
					 contents +=
					   sprintf("<font size=-1>"
						   "<a href=\"%s\">%s</a>"
						   "</font><br />\n",
						   link, title);
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
  
  void create( function _cb, string _h, int _p, string _q  )
  {
    cb = _cb;
    h = _h; p = _p; q = _q;
    start();
  }
}

string get_http_data( string host, int port, string query,
		      function|void cb )
{
  mixed data;
  if( data = cache[host+port+query] )
  {
    return data[0];
  }
  else
  {
    cache[host+port+query] = ({0});
    Fetcher( cb, host, port, query );
  }
}
