// $Id: site_content.pike,v 1.146 2004/06/04 08:29:15 _cvs_stephen Exp $

inherit "../inheritinfo.pike";
inherit "../logutil.pike";
inherit "../statusinfo.pike";
#include <module.h>
#include <module_constants.h>
#include <admin_interface.h>
#include <config.h>
#include <roxen.h>

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
  string mp = m->query_location && m->query_location();
  return mp ? sprintf("<a target='server_view' href=\"%s%s\">%s</a>",
		      m->my_configuration()->get_url(), mp[1..], mp) : "";
}

string describe_tags( RoxenModule m, int q )
{
  multiset tags=(<>), conts=(<>);
  RXML.TagSet new=m && m->query_tag_set && m->query_tag_set();
  if(!new) return "";

  foreach(indices(new->get_tag_names()), string name) {
    if(tags[name] || conts[name])
      continue;
    if(new->get_tag(name)->flags & RXML.FLAG_EMPTY_ELEMENT)
      tags+=(< replace(Roxen.html_encode_string(name),"#","&nbsp;") >);
    else
      conts+=(< replace(Roxen.html_encode_string(name),"#","&nbsp;") >);
  }

  array pi=map(indices(new->get_proc_instr_names()), Roxen.html_encode_string);

  return 
      String.implode_nicely(map(sort(indices(tags)-({"\x266a"})),
				lambda(string tag) {
				  return "<nobr>&lt;"+tag+(tag[0]=='/'?"":"/")+"&gt;</nobr>";
				} ) +
			    map(sort(indices(conts)),
				lambda(string tag) {
				  return "<nobr>&lt;"+tag+"/&gt;&lt;/&gt;</nobr>";
				} ) +
			    map(sort(pi),
				lambda(string tag) {
				  return "<nobr>&lt;?"+tag+" ?&gt;</nobr>";
				} ),
			    "and");
}

string describe_provides( RoxenModule m, int q )
{
  array(string)|multiset(string)|string provides = m &&
						   m->query_provides &&
						   m->query_provides();
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
               "<td valign='top'><nobr>" + #X + " (</nobr></td>"     \
               "<td valign='top'>"+Y(m,Z)+")</td></tr></table>");         \
     else                                                               \
       res += #X + "<br />";                                 \
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
  T(MODULE_USERDB,                     0,                        0);
  T(MODULE_EXPERIMENTAL,               0,                        0);

  return res;
}

string buttons( Configuration c, string mn, RequestID id )
{
  RoxenModule mod = c->find_module( replace( mn,"!","#" ) );
  if( !mod )
    return "";
  if( sizeof( glob( "*.x", indices( id->variables ) ) ) )
  {
    string a = glob( "*.x", indices( id->variables ) )[0]-".x";
    if( a == "Reload" )
    {
      loader.LowErrorContainer ec = loader.LowErrorContainer(), nm;

      loader.push_compile_error_handler( ec );

      nm = c->reload_module( replace(mn,"!","#" ) );

      loader.pop_compile_error_handler();

      if( sizeof( ec->get() ) )
      {
	.State->current_compile_errors[ c->name+"!"+mn ] = ec->get();
	report_debug( ec->get() ); // Do not add to module log.
      }
      else if( nm != mod )
      {
	m_delete( .State->current_compile_errors, c->name+"!"+mn );
      }
      mod = c->find_module( replace( mn,"!","#" ) );
    }
    else if( a == "Clear Log" )
    {
      array(int) times, left;
      Configuration conf = mod->my_configuration();
      int flush_time = time();
      string realname = id->misc->config_user->real_name,
		 name = id->misc->config_user->name,
		 host = id->misc->config_settings->host,
	     mod_name = Roxen.get_modname(mod),
	      log_msg = sprintf("2,%s," +
				("Module event log for '%s' "
				 "cleared by %s (%s) from %s\n"),
				mod_name||mod, Roxen.get_modfullname(mod)||"",
				realname, name, host);
      foreach(indices(mod->error_log), string error)
      {
	times = mod->error_log[error];

	// Flush from global log:
	if(left = core->error_log[error])
	  if(sizeof(left -= times))
	    core->error_log[error] = left;
	  else
	    m_delete(core->error_log, error);

	// Flush from virtual server log:
	if(left = conf->error_log[error])
	  if(sizeof(left -= times))
	    conf->error_log[error] = left;
	  else
	    m_delete(conf->error_log, error);
      }
      mod->error_log=([ log_msg : ({flush_time}) ]);// Flush from module log
      conf->error_log[log_msg] +=({flush_time});  // Kilroy was in the global log
      core->error_log[log_msg]+=({flush_time}); // and in the virtual server log
    }
    else if(mod->query_action_buttons)
    {
      mapping buttons=mod->query_action_buttons("standard");
      foreach(indices(buttons), string title)
	if( (string)a==(string)title )
	{
	  buttons[title](id);
	  break;
	}
    }
  }

  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  string section = RXML.get_var( "section", "form" );

  string buttons = 
         "<input type=hidden name=section value='" +
         (section||"Status") + "'>";

  // Do not allow reloading of modules _in_ the administration interface.
  // It's not really all that good an idea, I promise.
#ifndef DEVELOPER
  if( c != id->conf )
#endif
    buttons += "<submit-gbutton>Reload</submit-gbutton>";
  if(!mod)
    return buttons;
  if( sizeof( mod->error_log ) )
    buttons+="<submit-gbutton>Clear Log</submit-gbutton>";

  if(mod->query_action_buttons)
    foreach( indices(mod->query_action_buttons("standard")), string title )
      buttons += "<submit-gbutton>"+title+"</submit-gbutton>";

  // Nor is it a good idea to drop administration interface modules.
  // It tends to make things rather unstable.
#ifndef DEVELOPER
  if( c != id->conf )
#endif
    buttons += "<link-gbutton href='../../../../drop_module.pike?config="+
            path[0]+"&drop="+mn+"'>Drop Module</link-gbutton></a>";
  return buttons;
}

string get_eventlog( roxen.ModuleInfo o, RequestID id, int|void no_links )
{
  mapping log = o->error_log;
  if(!sizeof(log)) return "";

  array report = indices(log), r2;

  last_time=0;
  sort(map(values(log),lambda(array a){
			 return id->variables->reversed?-a[-1]:a[0];
		       }),report);
  for(int i=0;i<min(sizeof(report),1000);i++)
     report[i] = describe_error(report[i], log[report[i]],
				id->misc->cf_locale, no_links);

  if( sizeof( report ) >= 1000 )
    report[1000] =
      sprintf("%d entries skipped. Present in log on disk.",
	      sizeof( report )-999 );

  return "<h2>Events</h2>" + (report[..1000]*"");
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
  Configuration c = core.find_configuration( cn );

  if(!c)
    return "";

  string dbuttons="";
  if( config_perm( "Add Module" ) )
    dbuttons += "<h2>Tasks</h2>"+buttons( c, mn, id );
  RoxenModule m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  ModuleInfo mi = core.find_module( (mn/"!")[0] );

  string eventlog = get_eventlog( m, id );

  string homepage = m->module_url;
  if(stringp(homepage) && sscanf(homepage, "%*[A-Za-z0-9+.-]:%*s")==2)
    homepage = sprintf("<br /><b>Module homepage:</b> <a href=\"%s\">%s</a>",
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

  if( .State->current_compile_errors[ cn+"!"+mn ] )
    dbuttons += "<font color='&usr.warncolor;'><pre>"+
      .State->current_compile_errors[ cn+"!"+mn ]+
      "</pre></font>";

  string fnas = EC(TRANSLATE(m->file_name_and_stuff()));
  fnas = replace(fnas, "<br>", "</td></tr>\n<tr><td>");
  fnas = "<tr><td nowrap=''>"+
    ((fnas/":</b>")*":</b></td><td><img src='/*/unit' width=10 height=1 /></td><td>") +
    "</td></tr>\n";
  return     "<b><h2>" +
	     Roxen.html_encode_string(EC(TRANSLATE(m->register_module()[1])))
	     + "</h2></b>"
                  + EC(TRANSLATE(m->info(id)||"")) + "</p><p>"
                  + EC(TRANSLATE(m->status()||"")) + "</p><p>"
                  + dbuttons + eventlog +
                  ( config_setting( "devel_mode" ) ?
		    "<br clear='all' />\n"
		    "<h3>Developer information</h3>"
		    "<table border=0 cellpadding=0 cellspacing=0>"
                    "<tr nowrap=''><td><b>Identifier:</b></td>"
		    "<td><img src='/*/unit' width=10 height=1 /></td>"
		    "<td>" + mi->sname + "</td></tr>\n"
		    "<td nowrap=''><b>Thread safe:</b></td>"
		    "<td><img src='/*/unit' width=10 height=1 /></td>"
		    "<td>" + (m->thread_safe ? 
		     "Yes" : "No") +
#ifdef THREADS
		    " <small>(<a href='../../../../../tasks/?task"
		    "=locks.pike&class=status'>more info</a>)</small></td></tr>\n"
		    "<tr><td nowrap=''><b>Number of accesses:</b></td>"
		    "<td><img src='/*/unit' width=10 height=1 /></td>"
		    "<td>" + my_accesses +
#endif
                    "</td></tr>\n"
		    "<tr><td valign='top' nowrap=''><b>Type:</b></td>"
		    "<td><img src='/*/unit' width=10 height=1 /></td>"
		    "<td valign='top'>" + describe_type( m, mi->type, id ) +
                    "</td></tr>\n"
                    + fnas +
		    "</table>\n" +		    
		    homepage + creators  
		    + "<h3>Inherit tree</h3>"+
                    program_info( m ) +
                    "<dl>" + 
                    (m->faked?"(Not on disk, faked module)":inherit_tree( m ))
		    + 
                    "</dl>" 
                    : homepage + creators);
}

string find_module_documentation( string conf, string mn, RequestID id )
{
  Configuration c = core.find_configuration( conf );

  if(!c) return "";
  RoxenModule m = c->find_module( replace(mn,"!","#") );
  ModuleInfo mi = core.find_module( (mn/"!")[0] );

  if(!m) return "";
  if(!m->register_module) return "";

  LocaleString full_doc    = m->module_full_doc;
  if( !full_doc ) full_doc = m->module_doc;
  if( !full_doc ) full_doc = m->register_module()[2];
  if( !full_doc ) full_doc = m->register_module()[1];
    
  if( mi->type & MODULE_TAG )
  {
    RXML.TagSet tags=m->query_tag_set();
    if(!tags) return "";
    id = id->clone_me();
    id->conf = c;
    foreach(sort(indices(tags->get_tag_names())), string name)
    {
      string tag_doc = c->find_tag_doc( name, id, 1 );
      if (tag_doc && sizeof(tag_doc))
	full_doc += "<p>"+tag_doc+"</p>";
    }
  }

  return "<br />"+full_doc;
}

string module_page( RequestID id, string conf, string module )
{
  while( id->misc->orig )
    id = id->misc->orig;

  string section = RXML.get_var( "section", "form" );

  if( section == "Status" || RXML.get_var( "info_section_is_it", "form" ) )
    return find_module_doc( conf, module, id );

  if( section == "Docs" )
    return find_module_documentation( conf, module, id );
  
  return "<cfg-variables source='module-variables' configuration='"+conf+"' "
          "section='&form.section;' module='"+module+"'/>";
}

string port_for( string url, int settings )
{
  string ourl = (url/"#")[0];
  url = core->normalize_url(url);
  if(!core->urls[url]) {
    //  report_debug(sprintf("site_content.pike:port_for(): URL %O not found!\n",
    //  	       ourl));
    //  report_debug(sprintf("Known URLS are:\n"
    //  	       "%{  %O\n%}\n",
    //  	       indices(core->urls)));
    return "";
  }
  Protocol p = core->urls[url]->port;
  if(!p) return "<font color='&usr.warncolor;'>Not open</font>";
  string res =
#"
  <set variable='var.port' value='"+Roxen.http_encode_string(p->get_key())+
"'/><set variable='var.url' value='"+Roxen.http_encode_string(url)+#"'/>
  <emit source='ports' scope='port'>
    <if variable='var.port is &_.port;'>"+
    (settings?
#"
 <table border=0 cellspacing=0 cellpadding=4 width='100%'>
   <tr bgcolor='&usr.content-titlebg;'>
      <td colspan=2>
        <font color='&usr.content-titlefg;' size=+1>
          <b>&_.name;</b>
	</font>
      </td>
    </tr>
    <tr>
      <td colspan=2>":"")+#"
        <if variable='_.warning = ?*'>
           <font color='&usr.warncolor;'><b>&_.warning;</b></font>
           <br clear='all' />
        </if>
        <unset variable='var.end'/>
        <emit source='port-urls' port='&_.port;'>
          <if not variable='_.url is &var.url;'>
            <if not='' variable='var.end'>
              <set variable='var.end' value='.'/>
              Shared with
            </if>
            <else>
              and
            </else>
            <a href='../&_.conf;/'>&_.confname;</a>
          </if>
        </emit>
        &var.end;
      </td>
    </tr>
    <tr>
      <td><img src='/*/unit' width=20 height=1/></td>
      <td>
"
      +(settings?
#"<cfg-variables nosave='' source='port-variables' port='&port.port;'/>
  </td></tr>
  ":"")+#"
    </if>
  </emit>";
  return res+(settings?"</table>":"");
}


string parse( RequestID id )
{
  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  // roxen_perror("site_content:parse(): path: %{%O,%}\n", path);

  string section;
  array(string) _sec = id->real_variables->section;

  if( _sec )
  {
    if( sizeof( _sec ) > 0 )
      RXML.set_var( "section",  _sec[0], "form" );
    section = _sec[0];
  }

  if( !sizeof( path )  )
    return "Hm?";

  Configuration conf = core->find_configuration( path[0] );

  if( !conf->inited )
    conf->enable_all_modules();
  
  if( !config_perm( "Site:"+conf->name ) )
    return "Permission denied";

  id->misc->current_configuration = conf;

  if( sizeof( path ) < 3 )
  {
    /* Global information for the configuration */
    switch( section )
    {
     default: /* Not status info */
       do  id->misc->do_not_goto = 1; while( id = id->misc->orig );
       return "<cfg-variables source='config-variables' "
	      "configuration='"+path[0]+"' section='&form.section;'/>";

     case "Ports":
       string res = 
	 "<input type=hidden name='section' value='Ports' />"
	 "<cfg-variables source='config-variables' "
	 " configuration='"+path[0]+"' section='Ports'/><br clear='all'/>";
       
       foreach( conf->query( "URLs" ), string url )
       {
	 res += port_for( url, 1 );
       }
       return res+"<br /><cf-save/>\n";
       break;

     case 0:
     case "":
     case "Status":
       res = "\n<h1>" +
 	 "URLs</h1>";
       res += "<table>";
       foreach( conf->query( "URLs" ), string url )
       {
	 url = (url/"#")[0];

	 //  If no port number is present we add the default port for
	 //  the given protocol. This is needed to get a match in the
	 //  core->urls mapping.
	 string match_url = url;
	 if (sizeof(url / ":") < 3) {
	   sscanf(url, "%s://%s/%s", string proto, string host, string path);
	   int portnum =
	     core->protocols[proto] &&
	     core->protocols[proto]->default_port;
	   match_url = proto + "://" + host + ":" + portnum + "/" + path;
	 }
	 
         int open = (core->urls[ match_url ] 
                     && core->urls[ match_url ]->port 
                     && core->urls[ match_url ]->port->bound);
	 
         if( !open )
           res += "<tr><td>" + url + "</td><td>"+port_for(url,0) + "</td></tr>\n";
         else if(search(url, "*")==-1)
           res += ("<tr><td>" + "<a target='server_view' href='"+url+"'>"+
                   url+"</a></td><td>"+port_for(url,0)+"</td></tr>\n");
	 else if( sizeof( url/"*" ) == 2 )
	   res += ("<tr><td><a target='server_view' href='"+
                   replace(url, "*", gethostname() )+"'>"+
                   url+"</a></td><td>"+port_for(url,0)+"</td></tr>\n");
         else
	   res += "<tr><td>" +url + "</td><td>"+port_for(url,0)+"</td></tr>\n";
       }
       res += "</table>\n";

       res += "<p>"+Roxen.html_encode_string(conf->variables->comment->query())+"</p>";

       res += "<br /><table><tr><td valign=\"top\">"
	 "<h2>Request status</h2>";
       res += status(conf);
       res += "</td>"
	 "<td><img src='/*/unit' width='10' height='1' /></td>"
	 "<td valign=top>"
	 "<h2>Cache status</h2><table cellpading='0' cellspacing='0' width='100%'>\n";

       int total = conf->datacache->hits+conf->datacache->misses;

       if( !total )
         total = 1;

       res += 
           sprintf("<tr><td><b>Hits: </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d</td>"
		   "<td align='left'>%%</td></tr>\n",
                   conf->datacache->hits,
                   conf->datacache->hits*100 / total );
       res += 
           sprintf("<tr><td><b>Misses: </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d</td>"
		   "<td align='left'>%%</td></tr>\n",
                   conf->datacache->misses,
                   conf->datacache->misses*100 / total );

       res += 
           sprintf("<tr><td><b>Entries: </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d</td>"
		   "<td align='left'>Kb</td></tr>\n",
                   sizeof( conf->datacache->cache ),
                   (conf->datacache->current_size / 1024 ) );
       
       res += "</table>\n";
                   
       res += "</td></tr></table><br />";


       if( id->variables[ "Clear Log.x" ] )
       {
	 foreach( values(conf->modules), ModuleCopies m )
	   foreach( values( m ), RoxenModule md )
	     md->error_log = ([]);
	 foreach( indices( conf->error_log ), string error )
	 {
	   array times = conf->error_log[error];

	   // Flush from global log:
	   if(array left = core->error_log[error])
	     if(sizeof(left -= times))
	       core->error_log[error] = left;
	     else
	       m_delete(core->error_log, error);
	 }
	 conf->error_log = ([]);
	 core->nwrite( 
	   sprintf("Site event log for '%s' "
		   "cleared by %s (%s) from %s\n",
		   conf->query_name(),
		   id->misc->config_user->real_name,
		   id->misc->config_user->name,
		   id->misc->config_settings->host),
	   0, 2, 0, conf);
       }
       res+="<h1>Events</h1><insert file='log.pike' nocache='1' />";
       if( sizeof( conf->error_log ) )
	 res+="<submit-gbutton>Clear Log</submit-gbutton>";
       return res+"<br />\n";
    }
  } else
    return module_page( id, path[0], path[2] );
  return "";
}
