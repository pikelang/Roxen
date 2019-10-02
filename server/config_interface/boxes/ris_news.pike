// Locale stuff.
// <locale-token project="roxen_config">_</locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "small";
constant box_initial = 1;

LocaleString box_name = _(263,"News from www.roxen.com");
LocaleString box_doc  = _(281,"The news headlines from www.roxen.com");

string isodate( string date )
{
  return (Calendar.dwim_day( date )->format_iso_ymd()/" ")[0];
}

string extract_nonfluff( string from )
{
  string res = "";
  string last_a, last_date="";
  int list_style = sizeof(RXML.user_get_var("list-style-boxes", "usr"));
  string parse_div( Parser.HTML p, mapping m, string c )
  {
    if( m->class == "smalltext" )
      last_date = String.trim_all_whites( c );
    return c;
  };

  void parse_a( Parser.HTML p, mapping m, string c )
  {
    last_a = m->href;
    if( !strlen( last_a ) || last_a == "/" )
      return;
    if(search( last_a, "index.xml" ) == -1 )
      return;
    last_a = "http://www.roxen.com"+last_a;
    if (list_style)
      res += "<li style='margin-left: -0.9em; margin-right: 0.9em;'>"
	"<a href='"+last_a+"'><font size=-1>"+c+"</font></a></li>\n";
    else
      res += "<tr><td valign=top><a href='"+last_a+"'><font size=-1>"+c+
	"</font></a></td></tr>\n";

  };
  Parser.HTML( )->add_containers((["a":parse_a,"div":parse_div]))
    ->finish( from )->read();

  if (list_style)
    return "<ul>"+res+"</ul>";
  else
    return "<table>"+res+"</table>";
}

string parse( RequestID id )
{
  string contents;
  if( !(contents = .Box.get_http_data( "www.roxen.com", 80,
			      "GET /press-ir/news/index.xml?__xsl=printerfriendly.xsl HTTP/1.0") ) )
    contents = "Fetching data from www.roxen.com...";
  else
    contents = extract_nonfluff( contents );
  return
    "<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>";
}

