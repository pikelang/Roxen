/*
 * Locale stuff.
 * <locale-token project="roxen_config">_</locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "small";
String box_name = _(0,"News from www.roxen.com");
String box_doc  = _(0,"The news headlines from www.roxen.com");



class Fetcher
{
  Protocols.HTTP.Query query;

  void done( Protocols.HTTP.Query q )
  {
    data = query->data();
    
    cache_set( "risnews_data", "data", data );
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
    query->async_request( "www.roxen.com", 80,
			  "GET /index.xml?__xsl=print.xsl HTTP/1.0",
			  ([ "Host":"www.roxen.com:80" ]) );
  }
}

string extract_nonfluff( string from )
{
  string res = "";
  string last_a, last_alt;
  void parse_a( Parser.HTML p, mapping m )  {  last_a = m->href;   };
  void parse_img( Parser.HTML p, mapping m ){  last_alt = m->alt;  };
  void parse_font( Parser.HTML p, mapping m )
  {
    if( last_alt == "roxen.com" )
      return;
    if( !strlen( last_a ) || last_a == "/" )
      return;
    if(search( last_a, "roxen.com" ) == -1 )
    {
      if( last_a[0] == '/' ) last_a = last_a[1..];
      last_a = "http://www.roxen.com/"+last_a;
    }
    if( last_a && last_alt )
      res += "<a href='"+last_a+"'>"+last_alt+"</a><br />";
  };
  Parser.HTML( )->add_tags((["a":parse_a,"img":parse_img,"font":parse_font]))
    ->finish( data )->read();
  return res;
}

Fetcher fetcher;
string data;
string parse( RequestID id )
{
  string contents;
  if( !data )
  {
    if( !(data = cache_lookup( "risnews_data", "data" )) )
    {
      if( !fetcher )
	fetcher = Fetcher();
      contents = "Fetching data from www.roxen.com...";
    } else {
      call_out( Fetcher, 3600 );
      contents = extract_nonfluff( data );
    }
  } else
    contents = extract_nonfluff( data );
  return
    "<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>";
}

