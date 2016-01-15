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
      groups[ "zz_misc" ] += ({ n });
  }
  return groups;
}

string selected_item( string q, Configuration c, RequestID id,
		      string module_group,string module )
{
  while ( id->misc->orig )
    id = id->misc->orig;

  string pre = "";
  int do_js = config_setting( "modulelistmode" ) == "js";
  int unfolded = config_setting( "modulelistmode" ) == "uf";

  if( do_js )
  {
    RXML.set_var( "js-code", 
		  "<js-include file='CrossPlatform.js'/>\n"
		  "<js-include file='Popup.js'/>\n"
		  "<style><js-insert name='style'/></style>"
		  "<js-insert name='div'/>",
		  "var" );
  }
  pre +=
    "<script language='javascript' "
    "        charset='iso-8859-1' type='text/javascript' >\n"
    "  function p_on(item)  { item.className = 'module-list-item-hover'; }\n"
    "  function p_off(item) { item.className = 'module-list-item'; }\n"
    "  function p_on_sub(item)  { item.className = 'module-sub-list-item-hover'; }\n"
    "  function p_off_sub(item) { item.className = 'module-sub-list-item'; }\n"
    "  function p_popup_on(item)"
    "    { item.className = 'module-popup-list-item-hover'; }\n"
    "  function p_popup_off(item)"
    "    { item.className = 'module-popup-list-item'; }\n"
    "</script>\n";

  pre += 
    ("<gbutton frame-image='&usr.left-buttonframe;' href='/sites/' "
     "width='&usr.left-buttonwidth;' bgcolor='&usr.left-buttonbg;' "
     "icon_src='&usr.selected-indicator;' "
     "align_icon='left'>"+LOCALE(213, "Sites")+"</gbutton><br />"
     "<img src='/internal-roxen-unit' width='1' height='5'/><br />"
     "<gbutton frame-image='&usr.left-buttonframe;' "
     "width='&usr.left-buttonwidth;' "+
     (module == "" ?
      "bgcolor='&usr.left-selbuttonbg;'" : "bgcolor='&usr.left-buttonbg;'") +
     " href='"+id->not_query+"/"+replace(c->name, " ", "%20" )+"/' "
     " icon_src='&usr.selected-indicator;' align_icon='left'>"+
     c->query_name()+"</gbutton><br />"
     "<img src='/internal-roxen-unit' width='1' height='2'/><br />");

  string url = id->not_query + id->misc->path_info;
  string pre_site_url="";
  string quoted_url = Roxen.http_encode_invalids( url );
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
	      "locked":mi->config_locked[c]
	    ]),
	  });
      }
    }
    sort( map(gg->name,lower_case), gg );
    module_groups += ({ ({gn, gg}) });
  }

  module_groups = Array.sort_array( module_groups,
				    lambda(array a, array b) {
				      return a[0]>b[0]; });

  int list = (RXML.get_var("module-list-style", "usr") == "list");

  pre += "<box-frame width='100%' iwidth='100%' ::='&usr.module-list-frame;'>"+
    (list ?
     "<ul class='module-list'>" :
     "<table width='100%' cellspacing='0' cellpadding='0' class='module-list'>")+
    "\n";

  if (!sizeof(module_groups))
    pre += LOCALE(513,"No modules");
  
  foreach( module_groups, array gd )
  {
    int onlysel,fin;
    string real_group_name = gd[0];
    string r_module_group = module_group;
    string group_name = (real_group_name == "zz_misc" ? LOCALE(525,"Other") :
			 real_group_name);
    // Step 1: Is the selected module in this group?
    //         If so, force-select this group.

    foreach( gd[1], mapping data )
      if( data->sname == module )
	r_module_group = real_group_name;


    int fold;
    fold = !!RXML.get_var("unfolded", "usr");
    string sel;
    if (fold) sel = "unfolded";
    else sel = "selected-indicator";
    string css_class = "selected-indicator";
    if( real_group_name != r_module_group )
    {
      if (fold) sel = "folded";
      else sel = "item-indicator";
      css_class = "item-indicator";
      if (!unfolded)
        onlysel = 1;
    }
    if( onlysel )
    {
      if (do_js)
      {
	// Popup content
	string popup_bg;
	if (RXML.get_var("module-list-frame", "usr"))
	  popup_bg = "&usr.obox-bodybg;";
	else
	  popup_bg = "&usr.bgcolor;";
	pre +=
	  "<js-popup ox=" + (list ? "130" : "130") + " oy=-2 event='onClick' "
	  "args-variable='popup-args' "
	  ">\n"
	  "<table border=0 bgcolor='&usr.obox-border;' cellspacing='0' "
	  " cellpadding='1'>\n"
	  "<tr><td>"
	  "<table border=0 bgcolor='"+popup_bg+"' cellspacing='0' "
	  "cellpadding='1'>\n"
	  "<tr><td>\n"
	  "<table border='0' cellspacing='0' sellpadding='0' "
	  "       class='module-popup-list'>\n"
	  ;
	
	foreach( gd[1], mapping data ) {
	  pre +=
	    "<tr class='module-popup-list-item' "
	    "    onMouseOver='p_popup_on(this);' "
	    "    onMouseOut='p_popup_off(this);' "
	    "    onClick=\"window.location='" +
	    // Should it be http_encode_url below? I've no idea what
	    // real_group_name contains. /mast
	    (quoted_url + Roxen.http_encode_invalids(real_group_name) + "!0/" +
	     data->sname + "/") + "'\">"
	    "<td>" +
	    replace(Roxen.html_encode_string(data->name), " ", "&nbsp;") +
	    (data->locked ? " <imgs src='&usr.padlock;'/>" : "") +
	    "</td>\n</tr>\n";
	}
	pre +=
	  "</table>\n</td></tr></table>\n</td>\n</tr>\n</table>\n"
	  "\n</js-popup>\n";
      }

      // Folded group
      if (list) {
        if (!do_js)
          pre +=
	    "<li class='module-list-item' "
            "    onMouseOver='p_on(this);' "
	    "    onMouseOut='p_off(this);' "
            "    onClick=\"window.location='" +
	    // Should it be http_encode_url below? I've no idea what
	    // real_group_name contains. /mast
	    (quoted_url + Roxen.http_encode_invalids(real_group_name) + "!0/" +
             ((module&&strlen(module)) ? module + "/" : "")) + "';\">";
      }
      else
        pre +=
          "<tr>"
          "<td valign='top' width='0%'>"
          "<imgs src='&usr." + sel + ";' vspace='1' hspace='4' "
          "alt='' /></td>"
          "<td width='100%' "
	  "    class='module-list-item' "
          "    onMouseOver='p_on(this);' "
	  "    onMouseOut='p_off(this);' "
          +(do_js ? "::='&form.popup-args;'" :
            "onClick=\"window.location='" +
	    // Should it be http_encode_url below? I've no idea what
	    // real_group_name contains. /mast
	    (quoted_url + Roxen.http_encode_invalids(real_group_name) + "!0/" +
             ((module&&strlen(module)) ? module + "/" : "")) + "';\"") +
	  ">";
      if( !do_js )
        pre +=
          "<a href='" +
	  // Should it be http_encode_url below? I've no idea what
	  // real_group_name contains. /mast
	  (quoted_url + Roxen.http_encode_invalids(real_group_name) + "!0/" +
           ((module&&strlen(module)) ? module + "/" : "")) + "'>" +
          Roxen.html_encode_string(group_name) + "&nbsp;"
          "("+sizeof(gd[1])+")</a>";
      if (list) {
        if (!do_js)
          pre += "</li>\n";
      }
      else
        // </tr> ?
        ;
    }
    else
    {
      // Unfolded group
      if (list)
        pre +=
          "<li class='"+css_class+"'>" +
          Roxen.html_encode_string(group_name) +
          "</li>"
          "<ul class='module-sub-list'>\n";
      else
        pre +=
          "<tr><td>"
	  "<img src='/internal-roxen-unit' width=1 height=3 /></td></tr>\n"
          "<tr><td valign='top' width='0%'>"
          "<imgs src='&usr." + (unfolded&&fold ? "unfolded" : sel) + ";' "
	  "      vspace='1' hspace='4' alt='' /></td>"
          "<td width='100%'>" +
	  Roxen.html_encode_string(group_name) + "\n"
          "<table cellspacing='0' cellpadding='0' "
          "       width='100%' class='module-sub-list'>\n";
      fin = 1;
    }

    // If the group should be unfolded draw the module entries.
    if( !onlysel )
    {
      foreach( gd[1], mapping data )
      {
	if( data->sname != module )
	{
	  if (list)
	    pre +=
	      "<li class='module-list-item' "
	      "    onMouseOver='p_on(this);' onMouseOut='p_off(this);' "
	      "    onClick=\"window.location='" +
	      // Should it be http_encode_url below? I've no idea what
	      // real_group_name contains. /mast
	      (quoted_url + Roxen.http_encode_invalids(real_group_name) + "!0/" +
	       data->sname + "/") + "'; return false;\">"
	      "<a href='" +
	      (quoted_url + Roxen.http_encode_invalids(real_group_name) + "!0/" +
	       data->sname + "/") + "'>" +
	      Roxen.html_encode_string(data->name) +
	      "</a>" +
	      (data->locked ? " <imgs src='&usr.padlock;'/>" : "") +
	      "</li>\n";
	  else
	    pre +=
	      "<tr>"
	      "<td valign='top' width='0%'>"
	      "<imgs src='&usr.item-indicator;' vspace='1' hspace='4' alt=''/>"
	      "</td>"
	      "<td width='100%' class='module-sub-list-item' "
	      "onMouseOver='p_on_sub(this);' onMouseOut='p_off_sub(this);' "
	      "onClick=\"window.location='" +
	      // Should it be http_encode_url below? I've no idea what
	      // real_group_name contains. /mast
	      (quoted_url + Roxen.http_encode_invalids(real_group_name) + "!0/" +
	       data->sname+"/") + "'; return false;\">"
	      "<a href='" +
	      (quoted_url +
	       Roxen.http_encode_invalids(group_name) + "!0/"+data->sname +
	      "/'") + ">" +
	      Roxen.html_encode_string(data->name) +
	      "</a>" +
	      (data->locked ? " <imgs src='&usr.padlock;'/>" : "") +
	      "</td></tr>\n";
	}
	else
	{
	  if (list)
	    pre +=
	      "<li class='selected-indicator'>"
	      "" + Roxen.html_encode_string(data->name) + "" +
	      (data->locked ? " <imgs src='&usr.padlock;'/>" : "") +
	      "</li>\n";
	  else
	    pre +=
	      "<tr>"
	      "<td valign='top' width='0%'>"
	      "<imgs src='&usr.selected-indicator;' vspace='1' hspace='4' "
	      "      alt='' />"
	      "</td>"
	      "<td width='100%' class='selected-indicator'>"
	      "" + Roxen.html_encode_string(data->name) + "" +
	      (data->locked ? " <imgs src='&usr.padlock;'/>" : "") +
	      "</td></tr>\n";
	}
      }
    }
    else
    {
      // Folded group, cont.
      if( do_js )
      {
	if (list)
	  pre +=
	    "<li class='module-list-item' "
	    "    onMouseOver='p_on(this);' onMouseOut='p_off(this);' "
	    "    ::='&form.popup-args;'"
	    ">";
	pre +=
	  "<a>" + Roxen.html_encode_string(group_name) +
	  "&nbsp;(" + sizeof(gd[1]) + ")</a>";
	if (list)
	  pre += "</li>";
      }
      if (!list)
	pre += "</td></tr>\n";
    }
    if( fin )
      if (list)
	pre += "</ul>\n";
      else
	pre += "</table></td></tr>";
  }
  if (list)
    pre += "</ul>";
  else
    pre += "</table>";
  pre += "</box-frame>"
    "<br clear='all'/>"
    "<img src='/internal-roxen-unit' width='1' height='2'/><br />";

  // Do not allow easy addition and removal of modules to and
  // from the configuration interface server. Most of the time
  // it's a really bad idea.  Basically, protect the user. :-)
  if(
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
    (c != id->conf) &&
#endif
    config_perm( "Add Module" ) )
  {
    pre+=sprintf("<gbutton frame-image='&usr.left-buttonframe;' "
		 "width='&usr.left-buttonwidth;' bgcolor='&usr.left-buttonbg;' "
		 "href='%sadd_module.pike?config=%s&amp;&usr.set-wiz-id;'> %s </gbutton>",
		 pre_site_url,
		 Roxen.http_encode_url( c->name ),
		 LOCALE(251, "Add Module"))+
      sprintf("<br />\n"
	      "<img src='/internal-roxen-unit' width=1 height=1/><br />"
	      "<gbutton frame-image='&usr.left-buttonframe;' "
	      "width='&usr.left-buttonwidth;' "
	      "bgcolor='&usr.left-buttonbg;' "
	      "href='%sdrop_module.pike?config=%s&amp;&usr.set-wiz-id;'> %s </gbutton><br />\n",
	      pre_site_url,
	      Roxen.http_encode_url( c->name ),
	      LOCALE(252, "Drop Module"));
  }
  return pre;
}

mapping|string parse( RequestID id )
{
  string site;
  if( !id->misc->path_info ) id->misc->path_info = "";
  sscanf( id->misc->path_info, "/%[^/]/", site );
  array(string) path = ((id->misc->path_info||"")/"/")-({""});
  return Roxen.http_string_answer(
    selected_item( site, roxen.find_configuration( site ), id,
		   (((sizeof(path)>=2)?path[1]:"")/"!")[0],
		   ((sizeof(path)>=3)?path[2]:"")));
}
