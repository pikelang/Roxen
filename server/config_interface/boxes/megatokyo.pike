// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 0;

LocaleString box_name = _(398,"Todays MegaTokyo comic");
LocaleString box_doc  = _(399,"Todays comic from MegaTokyo");


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
    string status;

    sscanf( data, "%*sstrips/%s.gif", img );
    sscanf( data, "%*s<!--%*sstuff you%*s - start -->%s<!--", status );

    if( !img )
      return ("<box type='"+box+"' title='"+box_name+"'>"+data+"</box>");
    if( !status )
      status = "";
    array st = status/"<br>";
    string tmp;
    status = "<font size=-1>";
    if( sizeof( st ) > 4 )
    {
      sscanf( st[0], "%*s>\n%s", tmp );
      status += tmp +"<br />due "+ st[1]+ " (";
      sscanf( st[2], "%*s%[0-9]%% done", tmp );
      status += tmp+"% done)<br />\n";
      status += "<i>"+st[3]+"</i><br />";
      for( int i = 4; i<sizeof(st); i++ )
	status += (st[i]/"</font")[0]+"<br />";

      status = "<cimg format=png src='/internal-roxen-pixel-orange' "
	"     scale='"+(int)(2.8*(int)tmp)+",12'/>"
	"<cimg format=png src='/internal-roxen-pixel-black' "
	"     scale='"+(int)(280-(2.5*(int)tmp))+",12' />"
	"<br />"+status;
    }
    status += "</font>";

    contents  =
      "<a href='http://www.megatokyo.com/'>"
      "<center><cimg format=png border=0 max-width=390 "
      "src='http://www.megatokyo.com/strips/"+img+".gif' /></center>"
      "</a><br /><b>Next strip:</b>"+status;
//     werror( data );
  }

  return ("<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>");
}
  
