/*
 * Locale stuff.
 * <locale-token project="roxen_config"> _ </locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "small";
constant box_initial = 0;

String box_name = _(361,"Slashdot headlines");
String box_doc  = _(362,"The headlines from Slashdot: News for nerds, stuff that matters");

string parse( RequestID id )
{
  string data;
  string contents;
  if( !(data = .Box.get_http_data( "slashdot.org", 80,
			      "GET /slashdot.rdf HTTP/1.0" ) ) )
    contents = "Fetching data from slashdot...";
  else {
    contents = "";
    string title,link;
    Parser.HTML itemparser = Parser.HTML() ->
      add_containers( ([ "title": lambda(Parser.HTML p, mapping m, string c) { title = c; },
			 "link": lambda(Parser.HTML p, mapping m, string c) { link = c; } ]) );
    Parser.HTML() -> add_container("item",
				   lambda(Parser.HTML p, mapping m, string c) {
				     title = link = 0;
				     itemparser -> finish(c);
				     if(title && link)
				       contents += sprintf("<font size=-1><a href=\"%s\">%s</a></font><br />\n",
							   link, title);
					 } ) ->
      finish(data);
  }
  return ("<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>");
}
