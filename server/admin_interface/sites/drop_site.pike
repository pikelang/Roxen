#include <admin_interface.h>

void get_dead( string cfg, int del )
{
};

string|mapping parse( RequestID id )
{
  if( !config_perm( "Create Site" ) )
    return "Permission denied";

  Configuration cf = core->find_configuration( id->variables->site );
  if( !cf )
    return "No such configuration: "+id->variables->site;

  if( !id->variables["really.x"] )
  {
    string res = 
      "<use file='/template' />\n"
      "<tmpl title=' Drop old site'>"
      "<topmenu base='&cf.num-dotdots;' selected='sites'/>\n"
      "<content><cv-split>"
      "<subtablist width='100%'>"
      "<st-tabs></st-tabs>"
      "<st-page><b><font size=+1>"+
      sprintf("Are you sure you want to disable the site %s?\n",
               (cf->query_name()||""))+
      "</font></b><br />";
    // 1: Find databases that will be "dead" when this site is gone.
    mapping q = DBManager.get_permission_map( );
    array dead = ({});

    foreach( sort( indices( q ) ), string db )
    {
      int ok;
      foreach( indices(q[db]), string c )
	foreach( (core->configurations-({cf}))->name, string c )
	{
	  if( q[db][c] != DBManager.NONE )
	  {
	    ok=1;
	    break;
	  }
	}
      if( !ok )
	dead += ({ db });
    }

    // Never ever drop these.
    dead -= ({ "roxen", "mysql", "local", "replicate" });

    res += "<b>This site listens to the following ports:</b><br />\n";

    res += "<ul>\n";
    foreach( cf->query( "URLs" ), string url )
    {
      url = (url/"#")[0];
#if constant(gethostname)
      res += "<li> "+replace(url,"*",gethostname())+"\n";
#else
      res += "<li> "+url+"\n";
#endif
    }      
    res += "</ul\n>";
    
    if( sizeof( dead ) )
    {
      res += "<b>Databases that will no longer be used</b><br />";

      res += "<blockquote>";
      
      if( sizeof( dead ) == 1 )
	
	res += ("If you do not want to delete this database, "
		"uncheck the checkmark in front of it");
      else
	res += ("If you do not want to delete one or more of these "
		"databases, uncheck the checkmark in front of the ones"
		" you want to keep");
      res += "<table>";
      int n;
      foreach( dead, string d )
      {
	if( n & 3 )
	  res += "</td><td>";
	else if( n )
	  res += "</td></tr><tr><td>\n";
	else
	  res += "<tr><td>";
	n++;
	res += "<input name='del_db_"+d+"' type=checkbox checked=checked />"+
	  d+"<br />";
      }
      res += "</td></tr></table>";
      res += "</blockquote>";
    }
    // 2: Tables


    res += ("<input type=hidden name=site value='"+
	    Roxen.html_encode_string(id->variables->site)+"' />");
    
    res += 
      "<table width='100%'><tr width='100%'>"
      "<td align='left'><submit-gbutton2 name='really'> "+
      "Drop old site"
      " </submit-gbutton2></td><td align='right'>"
      "<cf-cancel href='./'/></td></tr></table>";
    
    return res + 
      "</st-page></subtablist></td></tr></table>"
      "</cv-split></content></tmpl>";
  }


  report_notice("Disabling old configuration %s\n", cf->name);

  foreach( glob("del_db_*", indices(id->variables)), string d ) {
    d = d[7..];
    DBManager.drop_db( d );
  }
  string cfname = loader.query_configuration_dir() + "/" + cf->name;
  mv (cfname, cfname + "~");
  core->remove_configuration( cf->name );
  cf->stop();
  destruct( cf );
  
  return Roxen.http_redirect( "", id );
}
