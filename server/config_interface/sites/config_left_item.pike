#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string noendslash( string what )
{
  while( strlen( what ) && what[ -1 ] == '/' )
    what = what[..strlen(what)-2];
  return what;
}

mapping group( array(string) w )
{
  mapping groups = ([]);
  foreach( w, string n )
  {
    string g, s;
    ModuleInfo i = roxen.find_module( n );
    if( sscanf( (string)i->get_name(), "%s:%s", g, s ) == 2 )
      groups[ g ] += ({ n });
    else
      groups[ "_misc" ] += ({ n });
  }
  return groups;
}

string selected_item( string q, Configuration c, RequestID id,
		      string module_group,string module )
{
  while ( id->misc->orig )
    id = id->misc->orig;

  string pre = 
         ("<gbutton frame-image='&usr.left-buttonframe;' href='/sites/' "
          "width='&usr.left-buttonwidth;' bgcolor='&usr.left-buttonbg;' icon_src='&usr.selected-indicator;' "
          "align_icon='left'>"+LOCALE(213, "Sites")+"</gbutton><br />"
          "<gbutton frame-image='&usr.left-buttonframe;' width='&usr.left-buttonwidth;' "+
          (module == "" ?
           "bgcolor='&usr.left-selbuttonbg;'" : "bgcolor='&usr.left-buttonbg;'") +
          " href='"+id->not_query+"/"+replace(c->name, " ", "%20" )+"/' "
          " icon_src='&usr.selected-indicator;' align_icon='left'>"+
          c->query_name()+"</gbutton><br /><br />");

  string url = id->not_query + id->misc->path_info;
  string pre_site_url="";
  string quoted_url = Roxen.http_encode_string( url );
  if( has_value( quoted_url, "!" )  )
    quoted_url += "../"*(sizeof(quoted_url/"!")-1);

  sscanf(id->not_query, "%ssite.html", pre_site_url);

  if( !config_perm( "Site:"+c->name ) )
    return "Permission denied";

  mapping gr = group(indices(c->modules));
  array module_groups = ({});

  foreach( indices( gr ), string gn  )
  {
    array gg = ({});
    foreach( gr[gn], string q )
    {
      ModuleInfo mi = roxen->find_module( q );
      foreach( sort(indices(c->modules[ q ]->copies)), int i )
      {
	string name, doc;
	mixed err;
	if(err=catch(name=mi->get_name()+(i?" # "+i:""))) {
	  name = q + (i?" # "+i:"") + " (Generated an error)";
	  report_error("Error reading module name from %s#%d\n%s\n",
		       q, i, describe_backtrace(err));
	}
	if( c->modules[q]->copies[i]->query_name )
	  if( err=catch(name=c->modules[q]->copies[i]->query_name( )))
	    report_error("Cannot get module name for %s#%d\n%s\n",
			 q, i, describe_backtrace(err));

	if( sscanf( name, "%*s:%s", name ) == 2 )
	  name = String.trim_whites( name );
	gg +=
	  ({
	    ([
	      "sname":q+"!"+i,
	      "name":name,
	    ]),
	  });
      }
    }
    sort( map(gg->name,lower_case), gg );
    module_groups += ({ ({gn, gg}) });
  }

  sort( module_groups );
  pre += "<table cellspacing='0' cellpadding='0'>\n";

  foreach( module_groups, array gd )
  {
    int onlysel,fin;
    string group_name = gd[0];
    if( (group_name != "_misc")  )
    {
      fin = 1;
      if( group_name != module_group )
      {
	if(sizeof( gd[1] ) > 1)
	  onlysel = 1;
	pre += ("\n<tr><td valign='top'><img src=\"&usr.item-indicator;\" width='12' height='12' alt='' /></td>"
		"<td><a href=\""+quoted_url+
		Roxen.http_encode_string(group_name)+
		"!0/"+module+"/\">"+Roxen.html_encode_string(group_name)+
		": ...</a><br />\n");
	pre += "<table cellspacing='0' cellpadding='0'>\n";
      }
      else
      {
	pre += ("\n<tr><td valign='top'>"
		"<img src=\"&usr.selected-indicator;\" width='12'"
		" height='12' alt='' /></td>"
		"<td>"+Roxen.html_encode_string(group_name)+":<br />\n");
	pre += "<table cellspacing='0' cellpadding='0'>\n";
      }
    }
    foreach( gd[1], mapping data )
    {
      if( onlysel && data->sname != module )
	continue;
      if( data->sname != module )
	pre += ("\n<tr><td valign='top'>"
		"<img src=\"&usr.item-indicator;\" width='12' "
		"height='12' alt='' /></td>"
		"<td><a href=\""+quoted_url+
		Roxen.http_encode_string(group_name)+"!0/"+data->sname+
		"/\">"+Roxen.html_encode_string(data->name)+
		"</a></td></tr>\n");
      else
	pre += ("\n<tr><td valign='top'>"
		"<img src=\"&usr.selected-indicator;\" width='12' "
		"height='12' alt='' /></td>"
		"<td><b>" + Roxen.html_encode_string(data->name) +
		"</b></td></tr>\n");
    }
    if( fin )
      pre += "</table></td></tr>";
  }
  pre += "</table>\n";


  // Do not allow easy addition and removal of modules to and
  // from the configuration interface server. Most of the time
  // it's a really bad idea.  Basically, protect the user. :-)
  if(
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
    (c != id->conf) &&
#endif
    config_perm( "Add Module" ) )
  {
    pre+=sprintf("<br />\n<gbutton frame-image='&usr.left-buttonframe;' "
		 "width='&usr.left-buttonwidth;' bgcolor='&usr.left-buttonbg;' "
		 "href='"+pre_site_url+
		 "add_module.pike?config=%s'> "
		 +LOCALE(258, "Add module")+" </gbutton>",
		 Roxen.http_encode_string( c->name ) )+
      sprintf("<br />\n<gbutton frame-image='&usr.left"
	      "-buttonframe;' width='&usr.left-buttonwidth;' bgcolor='&usr."
	      "left-buttonbg;' href='"+pre_site_url+
	      "drop_module.pike?config=%s'> "
	      +LOCALE(259, "Drop module")+
	      " </gbutton><br />\n",
	      Roxen.http_encode_string( c->name ));
  }
  return pre;
}

string parse( RequestID id )
{
  string site;
  if( !id->misc->path_info ) id->misc->path_info = "";
  sscanf( id->misc->path_info, "/%[^/]/", site );
  array(string) path = ((id->misc->path_info||"")/"/")-({""});
  return selected_item( site, roxen.find_configuration( site ), id,
 			(((sizeof(path)>=2)?path[1]:"")/"!")[0],
			((sizeof(path)>=3)?path[2]:""));
}
