/*
 * Locale stuff.
 * <locale-token project="roxen_config"> _ </locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "small";
String box_name = _(195,"Community articles");
String box_doc  = _(231,"Most recently published community articles");



class Fetcher
{
  Protocols.HTTP.Query query;

  void done( Protocols.HTTP.Query q )
  {
    data = replace( query->data(), ({ "/articles/",
				      "cellspacing=\"0\"",
				      "cellpadding=\"0\"",
				      "size=2",
				   }),
		    ({"http://community.roxen.com/articles/","","",""}));
    cache_set( "articles_data", "data", data );
    destruct();
  }
  
  void fail( Protocols.HTTP.Query q )
  {
    data = "Failed to connect to server";
    call_out( Fetcher, 30 );
  }

  void create()
  {
    call_out( Fetcher, 3600 );
    query = Protocols.HTTP.Query( )->set_callbacks( done, fail );
    query->async_request( "community.roxen.com", 80,
			  "GET /boxes/articles.html HTTP/1.0",
			  ([ "Host":"community.roxen.com:80" ]) );
  }
}


Fetcher fetcher;
string data;
string parse( RequestID id )
{
  string contents;
  if( !data )
  {
    if( !(data = cache_lookup( "articles_data", "data" )) )
    {
      if( !fetcher )
	fetcher = Fetcher();
      contents = "Fetching data from community...";
    } else {
      call_out( Fetcher, 3600 );
      contents = data;
    }
  } else
    contents = data;
  return
    "<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>";
}
