inherit "../inheritinfo.pike";
inherit "../logutil.pike";
#include <module.h>

string module_global_page( RequestID id, string conf )
{
  return sprintf("<gbutton preparse href='../../../add_module.pike?config=%s'> "
                 "&locale.add_module; </gbutton>",
                 http_encode_string( conf ) )+
         sprintf("<gbutton preparse href='../../../drop_module.pike?config=%s'> "
                 "&locale.drop_module; </gbutton>",
                 http_encode_string( conf ) );
}

#define translate( X ) _translate( (X), id )

string _translate( mixed what, object id )
{
  if( mappingp( what ) )
    if( what[ id->misc->cf_locale ] )
      return what[ id->misc->cf_locale ];
    else
      return what->standard;
  return what;
}

string describe_exts( object m, string func )
{
  return String.implode_nicely( m[func]() );
}

string describe_location( object m, RequestID id )
{
  Configuration conf = m->my_configuration();
  string url = conf->query("MyWorldLocation"),
	  mp = m->query_location();
  if(!stringp(url) || !sizeof(url))
  { // belt *and* suspenders :-)
    array(string) urls = conf->query("URLs");
    if(sizeof(urls))
      url = urls[0];
  }
  if(sizeof(url/"*") == 2)
    url = replace(url, "*", gethostname());
  return url ? sprintf("<a href=\"%s%s\">%s</a>",
		       url, mp[1..], mp)
	     : mp;
}

string make_if( string q )
{
  return "<if "+q+"=?></if>";
}

string simplified_make_container( string tagname, mapping args, string c )
{
  return make_tag(tagname, args)+make_tag("/...",args);
}

string describe_tags( object m, int q )
{
  return html_encode_string(String.implode_nicely(map(sort(indices(m->query_tag_callers())),
						      make_tag, ([])) +
						  map(sort(indices(m->query_container_callers())),
						      simplified_make_container, ([]), "")));
}

string describe_provides( object m, int q )
{
  array(string)|multiset(string)|string provides = m->query_provides();
  if (multisetp(provides))
    provides = sort((array(string))provides);
  if( arrayp(provides) )
    return String.implode_nicely(provides);
  return provides;
}

string describe_type( object m, int t, RequestID id )
{
  string res = "";

#define T(X,Y,Z)                                                        \
do                                                                      \
{                                                                       \
   if(t&X)                                                              \
     if( Y )                                                            \
       res += ("<table border=0 cellspacing=0 cellpadding=0><tr><td valign=top><b>" + #X + "</b> (</td>"     \
               "<td valign=top>"+Y(m,Z)+")</td></tr></table>");         \
     else                                                               \
       res += "<b>" + #X + "</b><br>";                                 \
} while(0)

  T(MODULE_EXTENSION,      describe_exts,       "query_extensions");
  T(MODULE_LOCATION,   describe_location,                       id);
  T(MODULE_URL,                        0,                        0);
  T(MODULE_FILE_EXTENSION, describe_exts,  "query_file_extensions");
  T(MODULE_PARSER,         describe_tags,                        0);
  T(MODULE_LAST,                       0,                        0);
  T(MODULE_FIRST,                      0,                        0);
  T(MODULE_AUTH,                       0,                        0);
  T(MODULE_TYPES,                      0,                        0);
  T(MODULE_DIRECTORIES,                0,                        0);
  T(MODULE_PROXY,                      0,                        0);
  T(MODULE_LOGGER,                     0,                        0);
  T(MODULE_FILTER,                     0,                        0);
  T(MODULE_PROVIDER,   describe_provides,                        0);
  T(MODULE_PROTOCOL,                   0,                        0);
  T(MODULE_CONFIG,                     0,                        0);
  T(MODULE_SECURITY,                   0,                        0);
  T(MODULE_EXPERIMENTAL,               0,                        0);

  return res;
}

// int creation_date = time();
// int no_reload()
// {
//   return creation_date > file_stat( __FILE__ )[ST_MTIME];
// }

mapping current_compile_errors = ([]);
string devel_buttons( object c, string mn, object id )
{
  object mod = c->find_module( replace( mn,"!","#" ) );
  if( sizeof( glob( "*.x", indices( id->variables ) ) ) )
  {
    string a = glob( "*.x", indices( id->variables ) )[0]-".x";
    if( a == parse_rxml( "&locale.reload;",id ) )
    {
      object ec = roxenloader.LowErrorContainer();
      roxenloader.push_compile_error_handler( ec );
      c->reload_module( replace(mn,"!","#" ) );
      roxenloader.pop_compile_error_handler();
      if( strlen( ec->get() ) )
        current_compile_errors[ mn ] = html_encode_string(ec->get());
      else
        m_delete(current_compile_errors, mn );
      mod = c->find_module( replace( mn,"!","#" ) );
      if( !mod )
        return "<h1>FAILED TO RELOAD MODULE! FATAL! AJEN!</h1>";
    }
    else if( a == parse_rxml( "&locale.clear_log;",id ) )
    {
      array(int) times, left;
      Configuration conf = mod->my_configuration();
      int flush_time = time();
      string realname = id->misc->config_user->real_name,
		 name = id->misc->config_user->name,
		 host = id->misc->config_settings->host,
	     mod_name = get_modname(mod),
	      log_msg = sprintf("2,%s,Module event log for '%s' "
				"cleared by %s (%s) from %s",
				mod_name, get_modfullname(mod),
				realname, name, host);
      foreach(indices(mod->error_log), string error)
      {
	times = mod->error_log[error];

	// Flush from global log:
	if(left = roxen->error_log[error])
	  if(sizeof(left -= times))
	    roxen->error_log[error] = left;
	  else
	    m_delete(roxen->error_log, error);

	// Flush from virtual server log:
	if(left = conf->error_log[error])
	  if(sizeof(left -= times))
	    conf->error_log[error] = left;
	  else
	    m_delete(conf->error_log, error);
      }
      mod->error_log=([ log_msg : ({ flush_time }) ]);// Flush from module log
      conf->error_log[log_msg]  = ({ flush_time });  // Kilroy was in the global log
      roxen->error_log[log_msg] = ({ flush_time }); // and in the virtual server log
    }
  }
  return (current_compile_errors[ mn ] ?
          "<font color=red><pre>"+current_compile_errors[ mn ]+
          "</pre></font>" : "" )
         + "<input type=hidden name=section value='" +
	 (id->variables->section||"Information") + "'>"
         "<submit-gbutton preparse>&locale.reload;</submit-gbutton>"+
         (sizeof( mod->error_log ) ?
         "<submit-gbutton preparse>&locale.clear_log;</submit-gbutton>":
          "");
}

string get_eventlog( roxen.ModuleInfo o, RequestID id, int|void no_links )
{
  mapping log = o->error_log;
  if(!sizeof(log)) return "";

  array report = indices(log), r2;

  last_time=0;
  r2 = map(values(log),lambda(array a){
     return id->variables->reversed?-a[-1]:a[0];
  });
  sort(r2,report);
  for(int i=0;i<sizeof(report);i++)
     report[i] = describe_error(report[i], log[report[i]],
				id->misc->cf_locale, no_links);
  return "<h2>&locale.eventlog;</h2>" + (report*"");
}

string find_module_doc( string cn, string mn, object id )
{
  object c = roxen.find_configuration( cn );

  if(!c)
    return "";

  string dbuttons;
  if( id->misc->config_settings->query( "devel_mode" ) )
    dbuttons = "<h2>&locale.actions;</h2>"+devel_buttons( c, mn, id );

  object m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  roxen.ModuleInfo mi = roxen.find_module( (mn/"!")[0] );

  string eventlog = get_eventlog( m, id );

  string homepage = m->module_url;
  if(stringp(homepage) && sscanf(homepage, "%*[A-Za-z0-9+.-]:%*s")==2)
    homepage = sprintf("<br><b>Module homepage:</b> <a href=\"%s\">%s</a>",
		       homepage, homepage);
  else homepage = "";

  string|array(string) creators = m->module_creator;
  if(stringp(creators))
    creators = ({ creators });
  if(arrayp(creators))
  {
    creators = map(creators,
		  lambda(string mail)
		  {
		    if(sscanf(mail, "%s <%s>", string name, string adr)==2 &&
		       search(adr, "@") != -1)
		      mail = sprintf("<a href=\"mailto:%s\">%s</a>", adr, name);
		    return mail;
		  });
    creators = sprintf("<br><b>Module creator%s:</b> %s",
		      (sizeof(creators)==1 ? "" : "s"),
		      String.implode_nicely(creators));
  } else creators = "";

  return replace( "<br><b><font size=+2>"
                  + translate(m->register_module()[1]) +
                  "</font></b><br>"
                  + translate(m->info()) + "<p>"
                  + translate(m->status()||"") + "<p>"
                  + eventlog +
                  ( id->misc->config_settings->query( "devel_mode" ) ?
		    dbuttons + "<br clear=all>"
		    "<h2>Developer information</h2>" +
                    "<b>Identifier:</b> " + mi->sname + "<br>"
		    "<b>Thread safe:</b> " + (m->thread_safe ? "Yes" : "No") +
                    "<br><br><table border=0 cellspacing=0 cellpadding=0>"
		    "<tr><td valign=top><b>Type:</b> </td><td "
                    "valign=top>" + describe_type( m, mi->type, id ) +
                    "</td></tr></table><br>" +
                    translate(m->file_name_and_stuff()) +
		    homepage + creators + "<dl>" +
                    rec_print_tree( Program.inherit_tree( object_program(m) ) )
                    + "</dl>" : homepage + creators),
                  ({ "/image/", }), ({ "/internal-roxen-" }));
}

string module_page( RequestID id, string conf, string module )
{
  while( id->misc->orig )
    id = id->misc->orig;
  if((id->variables->section == "Information")
     ||!(id->variables->section)
     ||id->variables->info_section_is_it)
    return "<blockquote>"+find_module_doc( conf, module, id )+"</blockquote>";

  return #"<cf-save what=Module>
 <input type=hidden name=section value=\"&form.section;\">
<table>
  <configif-output source=module-variables configuration=\""+
   conf+"\" section=\"&form.section;\" module=\""+module+#"\">
    <tr><td width=20%><b>#name#</b></td><td>#form:quote=none#</td></tr>
    <tr><td colspan=2>#doc:quote=none#<p>#type_hint#</td></tr>
   </configif-output>
  </table>
    <cf-save what=Module>";
}

string port_for( string url )
{
  if(!roxen->urls[url] ) return "";
  object p = roxen->urls[url]->port;
  if(!p)
    return "";
  return "<font size=-1>(handled by <a href='../../../ports/?port="+p->get_key()+"'>"+
         p->name+"://"+(p->ip||"*")+":"+p->port+"/" + "</a>)</font>";
}


string parse( RequestID id )
{
  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  // roxen_perror(sprintf("site_content:parse(): path: %{%O,%}\n", path));

  if( id->variables->section )
    sscanf( id->variables->section, "%s\0", id->variables->section );

  if( !sizeof( path )  )
    return "Hm?";

  object(Configuration) conf = roxen->find_configuration( path[0] );
  id->misc->current_configuration = conf;

  if( sizeof( path ) == 1 )
  {
    /* Global information for the configuration */
    switch( id->variables->config_page )
    {
     default: /* Status info */
       string res="<br><blockquote><h1>Urls</h1>";
       foreach( conf->query( "URLs" ), string url )
       {
	 if(search(url, "*")==-1)
           res += "<a href='"+url+"'>"+url+"</a> "+port_for(url)+"<br>";
	 else if( sizeof( url/"*" ) == 2 )
	   res += "<a href='"+replace(url, "*", gethostname() )+"'>"+
               url+"</a> "+port_for(url)+"<br>";
         else
	   res += url + " "+port_for(url)+"<br>";
       }
       res+="<h1>&locale.eventlog;</h1><insert file=log.pike nocache>";

       res +="<h1>Request status</h1>";
       res += conf->status();

       if( id->misc->config_settings->query( "devel_mode" ) )
       {
         res += "<h1>Inherit tree</h1><dl>";
         res += rec_print_tree( Program.inherit_tree( object_program(conf) ) );
         res += "</dl>";
       }
       return res+"<br>";
    }
  } else {
    switch( path[ 1 ] )
    {
     case "settings":
       return
#"<configif-output source=config-variables configuration=\""+
path[ 0 ]+#"\" section=\"&form.section;\"></configif-output>"+#"
<input type=hidden name=section value=\"&form.section;\">
<table>
   <cf-save what=Site>
  <configif-output source=config-variables configuration=\""+
path[ 0 ]+#"\" section=\"&form.section;\">
    <tr><td width=20%><b>#name#</b></td><td>#form:quote=none#</td></tr>
    <tr><td colspan=2>#doc:quote=none#<p>#type_hint#</td></tr>
   </configif-output>
  </table>
   <cf-save what=Site>";
       break;

     case "modules":
       if( sizeof( path ) == 2 )
         return module_global_page( id, path[0] );
       else
         return module_page( id, path[0], path[2] );
    }
  }
  return "";
}
