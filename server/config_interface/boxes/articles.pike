// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "small";
constant box_initial = 0;

LocaleString box_name = _(195,"Community articles");
LocaleString box_doc  = _(231,"Most recently published community articles");

string parse( RequestID id )
{
  string data;
  string contents;
  if( !(data = .Box.get_http_data( "community.roxen.com", 80,
			      "GET /boxes/articles.html HTTP/1.0" ) ) )
    contents = "Fetching data from community...";
  else
    contents = replace( data, ({ "/articles/",
				 "cellspacing=\"0\"",
				 "cellpadding=\"0\"",
			      }),
			({"http://community.roxen.com/articles/","",""}));
  return ("<cbox type='"+box+"' title='"+box_name+"'>"+contents+"</cbox>");
}
