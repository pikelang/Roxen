/*
 * Locale stuff.
 * <locale-token project="roxen_config">_</locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "small";
String box_name = _(263,"News from www.roxen.com");
String box_doc  = _(281,"The news headlines from www.roxen.com");

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
    ->finish( from )->read();
  return res;
}

string parse( RequestID id )
{
  string contents;
  if( !(contents = .Box.get_http_data( "www.roxen.com", 80,
			      "GET /index.xml?__xsl=print.xsl HTTP/1.0") ) )
    contents = "Fetching data from www.roxen.com...";
  else
    contents = extract_nonfluff( contents );
  return
    "<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>";
}

