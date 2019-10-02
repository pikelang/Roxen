#include <roxen.h>

//<locale-token project="admin_tasks">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

LocaleString name = _(46,"Change Roxen version")+"...";
LocaleString doc =  _(42,"If you have more than one Roxen version installed\n"
		     "in the same location, you can use this action to\n"
		     "change the currently running version.");

class Server(string dir,
	     string version,
	     string version_h )
{
  int cannot_change_back;
  string file( string fn )
  {
    return Stdio.read_bytes( "../"+dir+"/"+fn );
  }

  Calendar.Day get_date_from_cvsid( string data )
  {
    string q;
    if (sscanf( data, "%*s$Id: %*s,v %s\n", q ) < 3)
      return 0;
    return Calendar.dwim_day( (q/" ")[1] );
  }

  Calendar.Day reldate()
  {
    return 0;

    Calendar.Day d2, d = get_date_from_cvsid( version_h );
    if( !d )
    {
      d=get_date_from_cvsid( file( "base_server/roxen.pike" )||"" );

      foreach( ({"base_server/roxen.pike",
		 "base_server/configuration.pike",
		 "base_server/roxenloader.pike",
		 "start",
		 "base_server/module.pike" }),
	       string f )
      {
	string q = file( f )||"";
	if( f == "start" )
	  if( search( q, "100)" )==-1 )
	    cannot_change_back = 1;
	if( (d2 = get_date_from_cvsid(q )) && d2 > d )
	  d = d2;
      }
    }
    return d;
  }

  protected string _sprintf()
  {
    return sprintf("Server(%O,%O,%O)", dir,version, reldate() );
  }
}

array available_versions()
{
  array res = ({});
  foreach( glob("server*",get_dir( ".." )), string f )
  {
    if( file_stat( "../"+f+"/etc/include/version.h" ) )
    {
      catch {
	string s = Stdio.read_file( "../"+f+"/etc/include/version.h" );
	string a, b;
	sscanf( s, "%*sroxen_ver%*s\"%s\"", a );
	sscanf( s, "%*sroxen_build%*s\"%s\"", b );
	if( a && b )
	  res += ({ Server( f, a+"."+b,s ) });
      };
    }
  }
  return res;
}

string nice_relative_date( object t )
{
  if (!t)
    return "n/a";
  if( t->how_many( Calendar.Month() ) )
    if( t->how_many( Calendar.Month() ) == 1 )
      return sprintf( (string)_(43,"1 month") );
    else
      return sprintf( (string)_(44,"%d months"),
		      t->how_many( Calendar.Month() ) );
  if( t->how_many( Calendar.Day() ) == 1 )    return (string)_(139,"one day");

  if( t->how_many( Calendar.Day() ) == 0 )    return "-";
  return sprintf( (string)_(45,"%d days"),
		  t->how_many( Calendar.Day() ) );
}

string parse( RequestID id )
{
  string res =
    "<font size='+1'><b>"+_(46,"Change Roxen version")+"</b></font>\n"
    "<br />\n"
    "<p>";
  int warn;

  if( id->variables->server )
  {
    werror("Change to "+id->variables->server+"\n" );
    mv("../local/environment", "../local/environment~");
    Stdio.write_file( combine_path(roxen.configuration_dir,
				   "server_version"),
		      id->variables->server );
       roxen->shutdown(0.5);
    return (string)_(47,"Shutting down and changing Roxen version");
  }

  res += "<input type=hidden name='action' value='change_version.pike' />";
  
  res +=
    "<box-frame iwidth='100%' bodybg='&usr.content-bg;' "
    "           box-frame='yes' padding='0'>"
    "<table cellpadding=2 cellspacing=0 border=0>"
    "<tr bgcolor='&usr.obox-titlebg;'>"
    "<th></th>"
    "<th align='left'>"+_(48,"Version")+"</th>"
    "<th></th>"
    "<th><img src='/internal-roxen-unit' width=10 height=1 /></th>"
    "<th align='left'>"+_(85,"Release date")+"</th>"
    "<th><img src='/internal-roxen-unit' width=10 height=1 /></th>"
    "<th align='left'>"+_(86,"Age")+"</th>"
    "<th><img src='/internal-roxen-unit' width=10 height=1 /></th>"
    "<th align='left'>"+_(136,"Directory")+"</th>"
    "</tr>\n";
  foreach( available_versions(), Server f )
  {
    res += "<tr><td>";
    if( f->version != roxen.roxen_ver+"."+roxen.roxen_build )
      res += "<input type='radio' name='server' value='"+f->dir+"' /> ";
    else
      res += "";
    res += "</td>";

    Calendar.Day d = f->reldate();
    Calendar.Day diff = d && d->distance( Calendar.now() );

    warn += f->cannot_change_back;
    res +=
      "<td>"+f->version+"</td>"
      "<td>"+(f->cannot_change_back?"<img alt='#' src='&usr.err-2;' />":"")+
      "</td>"
      "<td></td>"
      "<td>"+(d ? d->set_language( roxen.get_locale()+"_UNICODE" )
	      ->format_ext_ymd() : "n/a")+
      "</td>"
      "<td></td>"
      "<td>"+nice_relative_date( diff )+"</td>"
      "<td></td>"
      "<td>"+f->dir+"</td></tr>\n";
  }
  res +=
    "</table>\n"
    "</box-frame>\n"
    "<br clear='all'/>\n"
    "<br />\n";
  

  if( warn )
    res += "<table><tr><td valign='top'>"
      "<img src='&usr.err-2;' alt='#' /></td>\n"
      "<td>"+
      sprintf((string)
      _(137,"If you change to one these Roxen versions, you will not be "
	"able to change back from the administration interface, you will "
	"instead have to edit the file %O manually, shutdown the server, "
	"and execute %O again"),
	      combine_path(getcwd(),
			   roxen.configuration_dir,
			   "server_version"),
	      combine_path(getcwd(),"../start") )
      +"</td></tr></table>";
	      
  res += "<table><tr><td valign='top'>"
    "<img src='&usr.err-2;' alt='#' /></td>\n"
    "<td>"+
    _(154,"Note that you will have to start the new server manually because "
      "you may have to answer a few questions for the new environment file.")+
    "</td>\n"
    "</tr></table>\n"
    "<br clear='all'/>\n"
    "<br />";
  
  res += "<submit-gbutton align='middle'>"+_(138,"Change version")+"</submit-gbutton> "
    "<cf-cancel href='./?class="+action+"'/>";
	      
  return res;
}
