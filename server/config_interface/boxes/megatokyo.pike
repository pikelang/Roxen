/*
 * Locale stuff.
 * <locale-token project="roxen_config"> _ </locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 0;

String box_name = _(0,"Todays MegaTokyo comic");
String box_doc  = _(0,"Todays comic from MegaTokyo");


/* And here we go. :-) */

string parse( RequestID id )
{
  string data;
  string contents = "";

  if( !(data = .Box.get_http_data("www.megatokyo.com",80,"GET / HTTP/1.0" ) ))
    contents = "Fetching data from megatokyo...";
  else
  {
    string img;
    string rant, status;

    sscanf( data, "%*s\"strips/%s.gif\"", img );
    sscanf( data, "%*s<!--%*sstuff you%*s - start -->%s<!--", status );

    sscanf( data,
	    "%*s<!-- n e w s r a n t    c o m e n t -->"
	    "%s"
	    "<!-- comments area ends here for PIRO-->",
	    rant );

    contents  =
      "<a href='http://www.megatokyo.com/'>"
      "<img border=0 width=400 src='http://www.megatokyo.com/strips/"+
      img+".gif' /></a><br /><b>Next strip:</b><table>"+status+"</table>";
//     werror( data );
  }

  return ("<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>");
}
  
