
constant task = "maintenance";
constant name = "Change ChiliMoon version...";
constant doc  = ("If you have more than one version of ChiliMoon installed\n"
		 "in the same location, you can use this task to\n"
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
    if( !sscanf( data, "%*s$Id: %*s,v %s\n", q ) )
      return 0;
    return Calendar.dwim_day( (q/" ")[1] );
  }

  Calendar.Day reldate()
  {
    Calendar.Day d2, d = get_date_from_cvsid( version_h );
    if( !d )
    {
      d=get_date_from_cvsid( file( "base_server/core.pike" )||"" );

      foreach( ({"base_server/core.pike",
		 "base_server/configuration.pike",
		 "base_server/loader.pike",
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

  static string _sprintf()
  {
    return sprintf("Server(%O,%O,%O)", dir,version, reldate() );
  }
}

array available_versions()
{
  array res = ({});
  foreach( glob("server*",get_dir( ".." )), string f )
  {
    if( file_stat( "../"+f+"/data/include/version.h" ) )
    {
      catch {
	string s = Stdio.read_file( "../"+f+"/data/include/version.h" );
	string a, b;
	sscanf( s, "%*s__roxen_vers%*s\"%s\"", a );
	sscanf( s, "%*s__roxen_build%*s\"%s\"", b );
	if( a && b )
	  res += ({ Server( f, a+"."+b,s ) });
      };
    }
  }
  return res;
}

string nice_relative_date( object t )
{
  if( t->how_many( Calendar.Month() ) )
    if( t->how_many( Calendar.Month() ) == 1 )
      return "1 month";
    else
      return sprintf( "%d months",
		      t->how_many( Calendar.Month() ) );
  if( t->how_many( Calendar.Day() ) == 1 )    return "one day";

  if( t->how_many( Calendar.Day() ) == 0 )    return "-";
  return sprintf( "%d days", t->how_many( Calendar.Day() ) );
}

string parse( RequestID id )
{
  string res = "<gtext fgcolor='&usr.fgcolor;'>Change ChiliMoon version</gtext>";
  int warn;

  if( id->variables->server )
  {
    werror("Change to "+id->variables->server+"\n" );
    mv("../local/environment", "../local/environment~");
    Stdio.write_file( combine_path(roxen.configuration_dir,
				   "server_version"),
		      id->variables->server );
    roxen->shutdown(0.5);
    return "Shutting down and changing server version";
  }

  res += "<input type='hidden' name='task' value='change_version.pike' />";
  
  res += "<table><tr><td><b>Version</b></td><td></td>"
    "<td><b>Release date</b></td>"
    "<td><b>Age</b></td>"
    "<td><b>Directory</b></td></tr>\n";
  foreach( available_versions(), Server f )
  {
    res += "<tr><td>";
    if( f->version != roxen.__roxen_version__+"."+roxen.__roxen_build__ )
      res += "<input type='radio' name='server' value='"+f->dir+"' /> ";
    else
      res += "";

    Calendar.Day d = f->reldate();
    Calendar.Day diff = d->distance( Calendar.now() );

    warn += f->cannot_change_back;
    res += f->version+"</td><td>"+
      (f->cannot_change_back?"<img alt='#' src='&usr.err-2;' />":"")+
      "</td><td>"+d->set_language( roxen.get_locale()+"_UNICODE" )
      ->format_ext_ymd() + "</td>"
      "<td>"+nice_relative_date( diff )+"</td>"
      "<td>"+f->dir+"</td></tr>\n";
  }
  res += "</table>";
  

  if( warn )
    res += "<table><tr><td valign='top'>"
      "<img src='&usr.err-2;' alt='#' /></td>\n"
      "<td>"+
      sprintf("If you change to one these roxen versions, you will not be "
	      "able to change back from the administration interface, you will "
	      "instead have to edit the file %O manually, shutdown the server, "
	      "and execute %O again",
	      combine_path(getcwd(),
			   roxen.configuration_dir,
			   "server_version"),
	      combine_path(getcwd(),"../start") )
      +"</td></tr></table>";
	      
  res += "<table><tr><td valign='top'>"
    "<img src='&usr.err-2;' alt='#' /></td>\n"
    "<td>Note that you will have to start the new server manually because you "
    "may have to answer a few questions for the new environment file.</td>\n"
    "</tr></table>\n";
  
  res += "<submit-gbutton>Change version</submit-gbutton>";
	      
  return res;
}
