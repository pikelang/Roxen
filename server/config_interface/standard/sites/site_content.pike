inherit "../inheritinfo.pike";
inherit "../logutil.pike";
inherit "../statusinfo.pike";
#include <module.h>
#include <module_constants.h>
#include <config_interface.h>
#include <config.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)
#define TRANSLATE( X ) _translate( (X), id )

string _translate( mixed what, RequestID id )
{
  if( mappingp( what ) )
    if( what[ id->misc->cf_locale ] )
      return what[ id->misc->cf_locale ];
    else
      return what->standard;
  return what;
}

string describe_exts( RoxenModule m, string func )
{
  return String.implode_nicely( m[func]() );
}

string describe_location( RoxenModule m, RequestID id )
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
  return url && mp ? sprintf("<a target='server_view' href=\"%s%s\">%s</a>",
			     url, mp[1..], mp)
		   : mp || "";
}

string describe_tags( RoxenModule m, int q )
{
  multiset tags=(<>), conts=(<>);
  RXML.TagSet new=m->query_tag_set();
  if(!new) return "";

  foreach(indices(new->get_tag_names()), string name) {
    if(tags[name] || conts[name])
      continue;
    if(new->get_tag(name)->flags & RXML.FLAG_EMPTY_ELEMENT)
      tags+=(< replace(name,"#"," ") >);
    else
      conts+=(< replace(name,"#"," ") >);
  }

  array pi=indices(new->get_proc_instr_names());

  return 
    Roxen.html_encode_string(String.implode_nicely(map(sort(indices(tags)-
							    ({"\x266a"})),
						       lambda(string tag) {
							 return "<"+tag+(tag[0]=='/'?"":"/")+">";
						       } ) +
						   map(sort(indices(conts)),
						       lambda(string tag) {
							 return "<"+tag+"></>";
						       } ) +
						   map(sort(pi),
						       lambda(string tag) {
							 return "<?"+tag+" ?>";
						       } )));
}

string describe_provides( RoxenModule m, int q )
{
  array(string)|multiset(string)|string provides = m->query_provides();
  if (multisetp(provides))
    provides = sort((array(string))provides);
  if( arrayp(provides) )
    return String.implode_nicely(provides);
  return provides;
}

string describe_type( RoxenModule m, int t, RequestID id )
{
  string res = "";

#define T(X,Y,Z)                                                        \
do                                                                      \
{                                                                       \
   if(t&X)                                                              \
     if( Y )                                                            \
       res += ("<table border='0' cellspacing='0' cellpadding='0'><tr>" \
               "<td valign='top'><b>" + #X + "</b> (</td>"     \
               "<td valign='top'>"+Y(m,Z)+")</td></tr></table>");         \
     else                                                               \
       res += "<b>" + #X + "</b><br />";                                 \
} while(0)

  T(MODULE_EXTENSION,      describe_exts,       "query_extensions");
  T(MODULE_LOCATION,   describe_location,                       id);
  T(MODULE_URL,                        0,                        0);
  T(MODULE_FILE_EXTENSION, describe_exts,  "query_file_extensions");
  T(MODULE_TAG,            describe_tags,                        0);
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

mapping current_compile_errors = ([]);
string buttons( Configuration c, string mn, RequestID id )
{
  RoxenModule mod = c->find_module( replace( mn,"!","#" ) );
  if( !mod )
    return "";
  if( sizeof( glob( "*.x", indices( id->variables ) ) ) )
  {
    string a = glob( "*.x", indices( id->variables ) )[0]-".x";
    if( a == LOCALE(253, "Reload") )
    {
      object ec = roxenloader.LowErrorContainer(), nm;

      roxenloader.push_compile_error_handler( ec );

      nm = c->reload_module( replace(mn,"!","#" ) );

      roxenloader.pop_compile_error_handler();

      if( strlen( ec->get() ) )
      {
        current_compile_errors[ mn ] = Roxen.html_encode_string(ec->get());
        report_error("While reloading:\n"+ec->get()+"\n");
      }
      else if( mod != nm )
      {
        mod = nm;
        m_delete(current_compile_errors, mn );
      }
    }
    else if( a == LOCALE(247, "Clear Log") )
    {
      array(int) times, left;
      Configuration conf = mod->my_configuration();
      int flush_time = time();
      string realname = id->misc->config_user->real_name,
		 name = id->misc->config_user->name,
		 host = id->misc->config_settings->host,
	     mod_name = Roxen.get_modname(mod),
	      log_msg = sprintf("2,%s," +
				LOCALE(290,"Module event log for '%s' "
				"cleared by %s (%s) from %s"),
				mod_name, Roxen.get_modfullname(mod),
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
    else if(mod->query_action_buttons) {
      mapping buttons=mod->query_action_buttons("standard");
      foreach(indices(buttons), string title)
	if( a==title ) {
	  buttons[a](id);
	  break;
	}
    }
  }

  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  string buttons = 
         "<input type=hidden name=section value='" +
         (id->variables->section||LOCALE(299,"Information")) + "'>";
  if( current_compile_errors[ mn ] )
    buttons += 
            "<font color='&usr.warncolor;'><pre>"+
            current_compile_errors[ mn ]+
            "</pre></font>";

  // Do not allow reloading of modules _in_ the configuration interface.
  // It's not really all that good an idea, I promise.
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
  if( c != id->conf )
#endif
    buttons += "<submit-gbutton>"+LOCALE(253, "Reload")+"</submit-gbutton>";

  if( sizeof( mod->error_log ) )
    buttons+="<submit-gbutton>"+LOCALE(247, "Clear Log")+"</submit-gbutton>";

  if(mod->query_action_buttons)
    foreach( indices(mod->query_action_buttons("standard")), string title )
      buttons += "<submit-gbutton>"+title+"</submit-gbutton>";

  // Nor is it a good idea to drop configuration interface modules.
  // It tends to make things rather unstable.
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
  if( c != id->conf )
#endif
    buttons += "<a href='../../../drop_module.pike?config="+
            path[0]+"&drop="+mn+"'><gbutton>"+
            LOCALE(252, "Drop Module")+"</gbutton></a>";
  return buttons;
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
  return "<h2>"+LOCALE(216, "Events")+"</h2>" + (report*"");
}

#define EC(X) niceerror( lambda(){ return (X); } , #X)

string niceerror( function tocall, string y )
{
  string res;
  mixed bt=catch( res = tocall( ) );

  if( bt )
  {
    bt = (array)bt;
    for( int i = 0; i<sizeof( bt[1] ); i++ )
      if( bt[1][i][2] == niceerror )
      {
        bt[1] = bt[1][i+2..];
        break;
      }
    return sprintf("Error while calling "+ y+":<br /><pre><font size='-1'>"+
                   Roxen.html_encode_string( describe_backtrace( bt ) )+
                   "</font></pre>" );
  }
  return res;
}

string find_module_doc( string cn, string mn, RequestID id )
{
  Configuration c = roxen.find_configuration( cn );

  if(!c)
    return "";

  string dbuttons;
  if( config_perm( "Add Module" ) )
    dbuttons = "<h2>"+LOCALE(196, "Tasks")+"</h2>"+buttons( c, mn, id );
  else
    dbuttons = "";
  Roxen.RoxenModule m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  roxen.ModuleInfo mi = roxen.find_module( (mn/"!")[0] );

  string eventlog = get_eventlog( m, id );

  string homepage = m->module_url;
  if(stringp(homepage) && sscanf(homepage, "%*[A-Za-z0-9+.-]:%*s")==2)
    homepage = sprintf("<br /><b>" + LOCALE(254,"Module homepage") +
		       ":</b> <a href=\"%s\">%s</a>",
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
    creators = sprintf("<br /><b>Module creator%s:</b> %s",
		       (sizeof(creators)==1 ? "" : "s"),
		       String.implode_nicely(creators));
  } else 
    creators = "";

#ifdef THREADS
  mapping accesses = c[m->thread_safe ? "thread_safe" : "locked"];
  int my_accesses = accesses[m];
#endif

  return replace( "<br /><b><font size='+2'>"
                  + EC(TRANSLATE(m->register_module()[1])) +
                  "</font></b><br />"
                  + EC(TRANSLATE(m->info())) + "</p><p>"
                  + EC(TRANSLATE(m->status()||"")) + "</p><p>"
                  + eventlog + dbuttons +
                  ( config_setting( "devel_mode" ) ?
		    "<br clear='all' />\n"
		    "<h2>Developer information</h2>" +
                    "<b>Identifier:</b> " + mi->sname + "<br />\n"
		    "<b>Thread safe:</b> " + 
		    (m->thread_safe ? 
		     LOCALE("yes", "Yes") : LOCALE("no", "No")) +
#ifdef THREADS
		    " <small>(<a href='../../../../actions/?action"
		    "=locks.pike&class=status'>more info</a>)</small><br />\n"
		    "<b>Number of accesses:</b> " + my_accesses +
#endif
                    "<br /><br />\n<table border='0' cellspacing='0' cellpadding='0'>"
		    "<tr><td valign='top'><b>Type:</b> </td><td "
                    "valign='top'>" + describe_type( m, mi->type, id ) +
                    "</td></tr></table><br />\n" +
                    EC(TRANSLATE(m->file_name_and_stuff())) +
		    homepage + creators  
		    + "<h2>"+LOCALE(261,"Inherit tree")+"</h2>"+
                    program_info( m ) +
                    "<dl>" + 
                    inherit_tree( m ) + 
                    "</dl>" 
                    : homepage + creators),
                  ({ "/image/", }), ({ "/internal-roxen-" }));
}

string module_page( RequestID id, string conf, string module )
{
  while( id->misc->orig )
    id = id->misc->orig;

  if( id->variables->section )
    id->variables->section = (id->variables->section/"\0")[0];

  if((id->variables->section == "Information")
     ||!(id->variables->section)
     ||id->variables->info_section_is_it)
    return "<blockquote>"+find_module_doc( conf, module, id )+"</blockquote>";

  return #"
 <input type=\"hidden\" name=\"section\" value=\"&form.section;\" />
 <cf-save what='Module'/><br clear=\"all\" />
<nooutput>
  This is necessary to update all the variables before showing them.
  <emit source='module-variables' configuration=\""+conf+#"\" 
        section=\"&form.section;\" module=\""+module+#"\"/>
</nooutput>
<table>
  <emit source='module-variables' configuration=\""+conf+#"\" 
        section=\"&form.section;\" module=\""+module+#"\">
    <tr><td width='20%'><b>&_.name;</b></td><td>&_.form:none;</td></tr>
    <tr><td colspan='2'>&_.doc:none;<p>&_.type_hint;</td></tr>
   </emit>
  </table>
 <cf-save what='Module'/>";
}

string port_for( string url )
{
  if(!roxen->urls[url] ) return "";
  object p = roxen->urls[url]->port;
  if(!p)
    return "";
  return "<font size='-1'>(" + LOCALE(291,"handled by") +
    " <a href='../../../ports/?port="+p->get_key()+"'>"+
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

  Configuration conf = roxen->find_configuration( path[0] );

  if( !conf->inited )
    conf->enable_all_modules();

  id->misc->current_configuration = conf;

  if( sizeof( path ) == 1 )
  {
    /* Global information for the configuration */
    switch( id->variables->config_page )
    {
     default: /* Status info */
       string res = "<br />\n<blockquote><h1>" +
 	 LOCALE(38,"URLs") + "</h1>";
       foreach( conf->query( "URLs" ), string url )
       {
         int open = roxen->urls[ url ] && roxen->urls[ url ]->port->bound;
         if( !open )
           res += url + " "+port_for(url)+(" <font color='&usr.warncolor;'>"+
                                           LOCALE(301, "Not open")+
                                           "</font>")+"<br />\n";
         else if(search(url, "*")==-1)
           res += ("<a target='server_view' href='"+url+"'>"+
                   url+"</a> "+port_for(url)+"<br />\n");
	 else if( sizeof( url/"*" ) == 2 )
	   res += ("<a target='server_view' href='"+
                   replace(url, "*", gethostname() )+"'>"+
                   url+"</a> "+port_for(url)+"<br />\n");
         else
	   res += url + " "+port_for(url)+"<br />\n";
       }

       res += "<br /><br /><table><tr><td valign=top>";
       res +="<h2>"+LOCALE(260, "Request status")+"</h2>";
       res += status(conf);
       res += "</td><td valign=top>";
       res += "<h2>"+LOCALE(292, "Cache status")+"</h2><table cellpading='0' cellspacing='0' width='50'%>\n";

       int total = conf->datacache->hits+conf->datacache->misses;

       if( !total )
         total = 1;

       res += 
           sprintf("<tr><td><b>" + LOCALE(293, "Hits") + ": </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d%%</td></tr>\n",
                   conf->datacache->hits,
                   conf->datacache->hits*100 / total );
       res += 
           sprintf("<tr><td><b>" + LOCALE(294, "Misses") + ": </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d%%</td></tr>\n",
                   conf->datacache->misses,
                   conf->datacache->misses*100 / total );

       res += 
           sprintf("<tr><td><b>" + LOCALE(295, "Entries") + ": </b></td>"
		   "<td align='right'>%d</td><td align='right'>%dKb</td></tr>\n",
                   sizeof( conf->datacache->cache ),
                   (conf->datacache->current_size / 1024 ) );
       
       res += "</table>\n";
                   
       res += "</td></tr></table><br />";



       res+="<h1>"+LOCALE(216, "Events")+"</h1><insert file='log.pike' nocache='' />";


//     if( id->misc->config_settings->query( "devel_mode" ) )
//     {
//       res += "<h1>"+LOCALE(261, "Inherit tree")+"</h1>";
//       res += program_info( conf ) + "<dl>" + inherit_tree( conf ) + "</dl>";
//     }
       return res+"<br />\n";
    }
  } else {
    switch( path[ 1 ] )
    {
     case "settings":
       return
	 "<emit source='config-variables' configuration=\""+path[ 0 ]+"\""
         " section=\"&form.section;\"></emit>\n"
         ""
	 "<input type=\"hidden\" name=\"section\" value=\"&form.section;\"/>\n"
	 "<table>\n"
	 "  <emit source='config-variables' configuration=\""+path[ 0 ]+"\"\n"
         "        section=\"&form.section;\">\n"
         ""
	 "    <tr><td width='20%'><b>&_.name;</b></td><td>&_.form:none;</td></tr>\n"
	 "    <tr><td colspan='2'>&_.doc:none;<p>&_.type_hint;</p></td></tr>\n"
	 "   </emit>\n"
	 "  </table>\n"
	 "   <cf-save what='Site'/>";
       break;

     default:
       return module_page( id, path[0], path[1] );
    }
  }
  return "";
}
