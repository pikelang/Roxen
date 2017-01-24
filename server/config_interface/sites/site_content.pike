// $Id$

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
			    LOCALE("cw","and"));
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
               "<td valign='top'>"+(Y)(m,Z)+")</td></tr></table>");	\
     else                                                               \
       res += #X + "<br />";                                 \
} while(0)

  T(MODULE_EXTENSION,      describe_exts,       "query_extensions");
  T(MODULE_LOCATION,   describe_location,                       id);
  T(MODULE_URL,                 (mixed)0,                        0);
  T(MODULE_FILE_EXTENSION, describe_exts,  "query_file_extensions");
  T(MODULE_TAG,            describe_tags,                        0);
  T(MODULE_LAST,                (mixed)0,                        0);
  T(MODULE_FIRST,               (mixed)0,                        0);
  T(MODULE_AUTH,                (mixed)0,                        0);
  T(MODULE_TYPES,               (mixed)0,                        0);
  T(MODULE_DIRECTORIES,         (mixed)0,                        0);
  T(MODULE_PROXY,               (mixed)0,                        0);
  T(MODULE_LOGGER,              (mixed)0,                        0);
  T(MODULE_FILTER,              (mixed)0,                        0);
  T(MODULE_PROVIDER,   describe_provides,                        0);
  T(MODULE_PROTOCOL,            (mixed)0,                        0);
  T(MODULE_CONFIG,              (mixed)0,                        0);
  T(MODULE_SECURITY,            (mixed)0,                        0);
  T(MODULE_USERDB,              (mixed)0,                        0);
  T(MODULE_EXPERIMENTAL,        (mixed)0,                        0);

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
    if( a == LOCALE(253, "Reload") )
    {
      roxenloader.LowErrorContainer ec = roxenloader.LowErrorContainer(), nm;

      roxenloader.push_compile_error_handler( ec );

      nm = c->reload_module( replace(mn,"!","#" ) );

      roxenloader.pop_compile_error_handler();

      if( strlen( ec->get() ) )
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
				"cleared by %s (%s) from %s") + "\n",
				mod_name||mod, Roxen.get_modfullname(mod)||"",
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
      mod->error_log=([ log_msg : ({flush_time}) ]);// Flush from module log
      conf->error_log[log_msg] +=({flush_time});  // Kilroy was in the global log
      roxen->error_log[log_msg]+=({flush_time}); // and in the virtual server log
    }
    else if(mod->query_action_buttons)
    {
      mapping(string:function|array(function|string)) buttons =
	mod->query_action_buttons(id);
      foreach(indices(buttons), string title)
	if( (string)a==(string)title )
	{
	  function|array(function|string) action = buttons[title];
	  if (arrayp(action))
	    action[0](id);
	  else
	    action(id);
	  break;
	}
    }
  }

  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  string section = RXML.get_var( "section", "form" );

  string buttons = 
         "<input type=hidden name=section value='" +
         (section||"Status") + "'>";

  // Do not allow reloading of modules _in_ the configuration interface.
  // It's not really all that good an idea, I promise.
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
  if( c != id->conf )
#endif
    buttons += "<submit-gbutton>"+LOCALE(253, "Reload")+"</submit-gbutton>";
  if(!mod)
    return buttons;
  if( sizeof( mod->error_log ) )
    buttons+="<submit-gbutton>"+LOCALE(247, "Clear Log")+"</submit-gbutton>";

  // Nor is it a good idea to drop configuration interface modules.
  // It tends to make things rather unstable.
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
  if( c != id->conf )
#endif
    buttons += "<link-gbutton href='../../../../drop_module.pike?config="+
            path[0]+"&drop="+mn+"'>"+
            LOCALE(252, "Drop Module")+"</link-gbutton></a>";

  //  Add action buttons produced by the module itself
  if (mod->query_action_buttons) {
    mapping(string:function|array(function|string)) mod_buttons =
      mod->query_action_buttons(id);
    array(string) titles = indices(mod_buttons);
    if (sizeof(titles)) {
      buttons +=
	" <img src='/internal-roxen-pixel-888888' "
	"      width='1' height='15' hspace='5' align='center' />";
      foreach(sort(titles), string title) {
	function|array(function|string) action = mod_buttons[title];
	if (arrayp(action))
	  buttons += action[1];
	else
	  buttons += "<submit-gbutton>" + title + "</submit-gbutton>";
      }
    }
  }


  return buttons;
}

string get_eventlog(RoxenModule o, RequestID id, int|void no_links )
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
      sprintf(LOCALE(472,"%d entries skipped. Present in log on disk."),
	      sizeof( report )-999 );

  return "<h3>"+LOCALE(216, "Events")+"</h3>" + (report[..1000]*"");
}

string get_module_snmp(RoxenModule o, ModuleInfo moduleinfo, RequestID id)
{
  if (!o->query_snmp_mib) return "";

  Configuration conf = o->my_configuration();

  // NOTE: Duplicates code in configuration.pike:call_low_start_callbacks()!
  array(int) segment = conf->generate_module_oid_segment(o);
  array(int) oid_prefix =
    conf->query_oid() + ({ 8, 2 }) + segment[..sizeof(segment)-2];

  foreach(conf->registered_urls, string url) {
    mapping(string:string|Configuration|Protocol|array(Protocol)) port_info =
      roxen.urls[url];

    Protocol prot;
    foreach((port_info && port_info->ports) || ({}), Protocol any_prot) {
      if ((any_prot->prot_name != "snmp") || (!any_prot->mib)) continue;
      prot = any_prot;
      break;
    }
    if (!prot) continue;

    // Normalize the path.
    string path = port_info->path || "";
    if (has_prefix(path, "/")) path = path[1..];
    if (has_suffix(path, "/")) path = path[..sizeof(path)-2];

    array(int) oid_suffix = ({ sizeof(path), @((array(int))path),
			       segment[-1] });

    ADT.Trie mib = ADT.Trie();
    mib->merge(o->query_snmp_mib(oid_prefix, oid_suffix));
    mib->merge(conf->generate_module_mib(conf->query_oid() + ({ 8, 1 }),
					 oid_suffix[..0],
					 o, moduleinfo, UNDEFINED));
    return "<h3>SNMP</h3>\n" + get_snmp_values(mib, mib->first());
  }

  return "";
}

string get_site_snmp(Configuration conf)
{
  foreach(conf->registered_urls, string url) {
    mapping(string:string|Configuration|Protocol|array(Protocol)) port_info =
      roxen.urls[url];

    Protocol prot;
    foreach((port_info && port_info->ports) || ({}), Protocol any_prot) {
      if ((any_prot->prot_name != "snmp") || (!any_prot->mib)) continue;
      prot = any_prot;
      break;
    }
    if (!prot) continue;

    foreach((port_info && port_info->ports) || ({}), Protocol prot) {
      if ((prot->prot_name != "snmp") || (!prot->mib)) continue;

      return "<h3>SNMP</h3>\n" +
	get_snmp_values(prot->mib, conf->query_oid(), conf->query_oid()+({8}));
    }
  }

  return "";
}

string get_snmp_values(ADT.Trie mib,
		       array(int) oid_start,
		       void|array(int) oid_ignore)
{
  array(string) res = ({
    "<th align='left'>Name</th>"
    "<th align='left'>Value</th>"
  });

  for (array(int) oid = oid_start; oid; oid = mib->next(oid)) {
    if (!has_prefix((string)oid, (string)oid_start)) {
      // Reached end of the oid subtree.
      break;
    }
    if (oid_ignore && has_prefix((string)oid, (string)oid_ignore)) continue;
    string oid_string = ((array(string)) oid) * ".";
    string name = "";
    string doc = "";
    mixed val = "";
    mixed err = catch {
	val = mib->lookup(oid);
	if (zero_type(val)) continue;
	if (objectp(val)) {
	  if (val->update_value) {
	    val->update_value();
	  }
	  name = val->name || "";
	  doc = val->doc || "";
	  val = sprintf("%s", val);
	}
	val = (string)val;
      };
    if (err) {
      name = "Error";
      val = "";
      doc = "<tt>" +
	replace(Roxen.html_encode_string(describe_backtrace(err)),
		"\n", "<br />\n") +
	"</tt>";
    }
    res += ({
	sprintf("<td><b><a href=\"urn:oid:%s\">%s:</a></b></td>"
		"<td>%s</td>",
		oid_string,
		Roxen.html_encode_string(name),
		Roxen.html_encode_string(val)),
    });
    if (sizeof(doc)) {
      res += ({
	sprintf("<td></td><td><font size='-1'>%s</font></td>", doc),
      });
    }
  }

  return "<table><tr>" +
    res * "</tr>\n<tr>" +
    "</tr></table>\n";
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

  string dbuttons="";
  if( config_perm( "Add Module" ) )
    dbuttons += "<h3>"+LOCALE(196, "Tasks")+"</h3>"+buttons( c, mn, id );
  RoxenModule m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  ModuleInfo mi = roxen.find_module( (mn/"!")[0] );

  string snmp = get_module_snmp(m, mi, id);

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

  if( .State->current_compile_errors[ cn+"!"+mn ] )
    dbuttons += "<font color='&usr.warncolor;'><pre>"+
      .State->current_compile_errors[ cn+"!"+mn ]+
      "</pre></font>";
  string fnas = EC(TRANSLATE(m->file_name_and_stuff()));
  fnas = replace(fnas, "<br>", "</td></tr>\n<tr><td>");
  fnas = "<tr><td nowrap=''>"+
    ((fnas/":</b>")*":</b></td><td><img src='/internal-roxen-unit' width=10 height=1 /></td><td>") +
    "</td></tr>\n";
  return
    replace( "<b><h2>" +
	     Roxen.html_encode_string(EC(TRANSLATE(m->register_module()[1])))
	     + "</h2></b>"
                  + EC(TRANSLATE(m->info(id)||"")) + "</p><p>"
                  + EC(TRANSLATE(m->status()||"")) + "</p><p>"
                  + dbuttons + snmp + eventlog +
                  ( config_setting( "devel_mode" ) ?
		    "<br clear='all' />\n"
		    "<h3>Developer information</h3>"
		    "<table border=0 cellpadding=0 cellspacing=0>"
                    "<tr nowrap=''><td><b>Identifier:</b></td>"
		    "<td><img src='/internal-roxen-unit' width=10 height=1 /></td>"
		    "<td>" + mi->sname + "</td></tr>\n"
		    "<td nowrap=''><b>Thread safe:</b></td>"
		    "<td><img src='/internal-roxen-unit' width=10 height=1 /></td>"
		    "<td>" + (m->thread_safe ? 
		     LOCALE("yes", "Yes") : LOCALE("no", "No")) +
#ifdef THREADS
		    " <small>(<a href='../../../../../actions/?action"
		    "=locks.pike&class=status'>more info</a>)</small></td></tr>\n"
		    "<tr><td nowrap=''><b>Number of accesses:</b></td>"
		    "<td><img src='/internal-roxen-unit' width=10 height=1 /></td>"
		    "<td>" + my_accesses +
#endif
                    "</td></tr>\n"
		    "<tr><td valign='top' nowrap=''><b>Type:</b></td>"
		    "<td><img src='/internal-roxen-unit' width=10 height=1 /></td>"
		    "<td valign='top'>" + describe_type( m, mi->type, id ) +
                    "</td></tr>\n"
                    + fnas +
		    "</table>\n" +		    
		    homepage + creators  
		    + "<h3>"+LOCALE(261,"Inherit tree")+"</h3>"+
                    program_info( m ) +
                    "<dl>" + 
                    (m->faked?"(Not on disk, faked module)":inherit_tree( m ))
		    + 
                    "</dl>" 
                    : homepage + creators),
                  ({ "/image/", }), ({ "/internal-roxen-" }));
}

string find_module_documentation( string conf, string mn, RequestID id )
{
  Configuration c = roxen.find_configuration( conf );

  if(!c) return "";
  RoxenModule m = c->find_module( replace(mn,"!","#") );
  ModuleInfo mi = roxen.find_module( (mn/"!")[0] );

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

    if (has_prefix (mn, "rxmltags!"))
      // Ugly kludge: The rxmltags tagdoc has rxml examples that require a
      // late compat level to render correctly, so we switch to the admin
      // UI config since it always uses the latest compat level.
      id->conf = roxen.get_admin_configuration();
    else
      id->conf = c;

    mapping(string:int) documented_tags = ([]);
    foreach(sort(indices(tags->get_tag_names())), string name)
    {
      string tag_doc = id->conf->find_tag_doc( name, id, 1, 0, documented_tags);
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

array(Protocol|array(string)) get_port_for(string url)
{
  mapping(string:Configuration|Protocol|string) url_data =
    roxen->urls[roxen->normalize_url (url, 1)];
  if(!url_data) {
    return ({ 0, ({ url }) });
  }
  return ({ url_data->port, ({ roxen->normalize_url (url) }) });
}

string port_for( string url, int settings )
{
  return low_port_for(get_port_for(url), settings);
}

string low_port_for(array(Protocol|array(string)) port_info, int settings)
{
  [ Protocol p, array(string) urls ] = port_info;
  if(!urls) {
    return "";
  }
  if(!p) return "<font color='&usr.warncolor;'>Not open</font>";

  string url =			// FIXME: Report the others too.
    roxen->normalize_url (urls[0], 1);
  string res =
#"
  <set variable='var.port' value='"+
    Roxen.html_encode_string(p->get_key())+ #"'/>
  <set variable='var.urlconf' value='"+
    Roxen.html_encode_string (replace (p->urls[url]->conf->name, " ", "-"))+#"'/>
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
	<emit source='port-urls' port='&_.port;' rowinfo='var.rowinfo'
	      distinct='conf'>"
    // No whitespace in this emit
	  "<if not variable='_.conf is &var.urlconf;'>"
            "<if not='' variable='var.end'>"
              "<set variable='var.end' value='.'/>"
              +LOCALE(323,"Shared with ")+
            "</if>"
            "<elseif variable='var.rowinfo = &_.counter;'>"
              " "+LOCALE("cw","and")+" "
            "</elseif>"
            "<else>"
              ", "
            "</else>"
            "<a href='../&_.conf;/'>&_.confname;</a>"
          "</if>"
        "</emit>"
        "&var.end;"+#"
      </td>
    </tr>
    <tr>
      <td><img src='/internal-roxen-unit' width=20 height=1/></td>
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

  // roxen_perror(sprintf("site_content:parse(): path: %{%O,%}\n", path));

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

  Configuration conf = roxen->find_configuration( path[0] );

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

    case "ModulePriorities":
      return module_priorities_page(id, conf);
       

     case "Ports":
       string res = 
	 "<input type=hidden name='section' value='Ports' />"
	 "<cfg-variables source='config-variables' "
	 " configuration='"+path[0]+"' section='Ports'/><br clear='all'/>";

       array(string) urls = conf->query("URLs");
       array(array(Protocol|array(string))) ports =
	 map(conf->query("URLs"), get_port_for);
       mapping(Protocol:array(Protocol|array(string))) prot_info = ([]);
       foreach(ports, array(Protocol|array(string)) port) {
	 array(Protocol|array(string)) prev;
	 if (prev = prot_info[port[0]]) {
	   if (prev[1]) {
	     prev[1] += port[1];
	   } else {
	     prev[1] = port[1];
	   }
	   port[0] = 0;
	   port[1] = 0;
	 } else {
	   prot_info[port[0]] = port;
	 }
       }
       res += map(ports, low_port_for, 1)*"";
       return res+"<br /><cf-save/>\n";
       break;

     case 0:
     case "":
     case "Status":
       res = "\n<h1>" +
 	 LOCALE(299,"URLs") + "</h1>";
       res += "<table>";
       foreach( conf->query( "URLs" ), string url )
       {
	 url = (url/"#")[0];
	 string match_url = roxen.normalize_url (url, 1);
	 
         int open = (roxen->urls[ match_url ] 
                     && roxen->urls[ match_url ]->port 
                     && roxen->urls[ match_url ]->port->bound);
	 
         if( !open )
           res += "<tr><td valign='top'>" + url + "</td><td>"+port_for(url,0) + "</td></tr>\n";
         else if(search(url, "*")==-1)
           res += ("<tr><td valign='top'>" + "<a target='server_view' href='"+url+"'>"+
                   url+"</a></td><td>"+port_for(url,0)+"</td></tr>\n");
	 else if( sizeof( url/"*" ) == 2 )
	   res += ("<tr><td valign='top'><a target='server_view' href='"+
                   replace(url, "*", gethostname() )+"'>"+
                   url+"</a></td><td>"+port_for(url,0)+"</td></tr>\n");
         else
	   res += "<tr><td valign='top'>" +url + "</td><td>"+port_for(url,0)+"</td></tr>\n";
       }
       res += "</table>\n";

       res += "<p>"+Roxen.html_encode_string(conf->variables->comment->query())+"</p>";

       res += "<br /><table><tr><td valign=\"top\">"
	 "<h2>"+LOCALE(260, "Request status")+"</h2>";
       res += status(conf);
       res += "</td>"
	 "<td><img src='/internal-roxen-unit' width='10' height='1' /></td>"
	 "<td valign=top>"
	 "<h2>"+LOCALE(292, "Cache status")+"</h2><table cellpading='0' cellspacing='0' width='100%'>\n";

       int total = conf->datacache->hits+conf->datacache->misses;

       if( !total )
         total = 1;

       res += 
           sprintf("<tr><td><b>" + LOCALE(293, "Hits") + ": </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d</td>"
		   "<td align='left'>%%</td></tr>\n",
                   conf->datacache->hits,
                   conf->datacache->hits*100 / total );
       res += 
           sprintf("<tr><td><b>" + LOCALE(294, "Misses") + ": </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d</td>"
		   "<td align='left'>%%</td></tr>\n",
                   conf->datacache->misses,
                   conf->datacache->misses*100 / total );

       res += 
           sprintf("<tr><td><b>" + LOCALE(295, "Entries") + ": </b></td>"
		   "<td align='right'>%d</td><td align='right'>%d</td>"
		   "<td align='left'>Kb</td></tr>\n",
                   sizeof( conf->datacache->cache ),
                   (conf->datacache->current_size / 1024 ) );
       
       res += "</table>\n";
                   
       res += "</td></tr></table><br />";


       if( id->variables[ LOCALE(247, "Clear Log")+".x" ] )
       {
	 foreach( values(conf->modules), ModuleCopies m )
	   foreach( values( m ), RoxenModule md )
	     md->error_log = ([]);
	 foreach( indices( conf->error_log ), string error )
	 {
	   array times = conf->error_log[error];

	   // Flush from global log:
	   if(array left = roxen->error_log[error])
	     if(sizeof(left -= times))
	       roxen->error_log[error] = left;
	     else
	       m_delete(roxen->error_log, error);
	 }
	 conf->error_log = ([]);
	 roxen->nwrite( 
	   sprintf(LOCALE(311,"Site event log for '%s' "
			  "cleared by %s (%s) from %s") + "\n",
		   conf->query_name(),
		   id->misc->config_user->real_name,
		   id->misc->config_user->name,
		   id->misc->config_settings->host),
	   0, 2, 0, conf);
       }
       res+="<h1>"+LOCALE(216, "Events")+"</h1><insert file='log.pike' nocache='1' />";
       if( sizeof( conf->error_log ) )
	 res+="<submit-gbutton>"+LOCALE(247, "Clear Log")+"</submit-gbutton>";
       res += "<br />\n";
       res += get_site_snmp(conf);
       return res;
    }
  } else
    return module_page( id, path[0], path[2] );
  return "";
}



string module_priorities_page( RequestID id, Configuration c)
{

  array modids = map( indices( c->otomod )-({0}),
		      lambda(mixed q){ return c->otomod[q]; });

  array mod_types = ({ 
    ([ "title" : "First Try Modules", "type" : MODULE_FIRST  ]), 
    ([ "title" : "Filter Modules",    "type" : MODULE_FILTER ]), 
    ([ "title" : "Last Try Modules",  "type" : MODULE_LAST   ]), 
    
  });
  
  array mods = map( modids,
		   lambda(string q) {
		     object mod = roxen.find_module( (q/"#")[0] );
		     object modi = c->find_module(q);
		     int c = (int)((q/"#")[-1]);
		     return ([
		       "id":q,
		       "name":mod->get_name(),
		       "name2":mod->get_name()+(c?" #"+(c+1):""),
		       "modi":modi,
		       "instance":c,
		       "pri":modi->query("_priority"),
		       "type":modi->module_type,
		     ]);
		   } );

 
  string res = "<input type=hidden name='section' value='ModulePriorities' />";

  res += "<cf-save/>";

  res += "<h1>Module priorities for site "+Roxen.roxen_encode(c->name,"html")+"</h1>";
  res += "9 is highest and 0 is lowest.<br /><br />";

  res += "<table border='0' cellpadding='0' cellspacing='2'>";

  mapping modules_seen = ([ ]);

  foreach(mod_types, mapping mt) {
    res += "<tr><td colspan='3'><h2>"+mt->title+"</h2></td></tr>\n";

    array _mods = Array.filter(mods, lambda(mapping m) { return m->type & mt->type; });

    foreach( _mods, mapping m ) {
      int modpri = m->pri;
      string varname = "prichange_"+replace(m->id,"#","!");
      if(id->variables[varname]) {
	modpri = (int)(id->variables[varname]);
	if(modpri < 0)
	  modpri = 0;
	if(modpri > 9)
	  modpri = 9;

	if(m->pri != modpri) {
	  m->oldpri = m->pri;
	  m->pri = modpri;
	  m->modi->getvar("_priority")->set(m->pri);
	  if( m->modi->save_me )
	    m->modi->save_me();
	  else
	    m->modi->save();
	}
      }
    }

    _mods = Array.sort_array(_mods, lambda(mapping m1, mapping m2) { 
				      if(m2->pri==m1->pri) 
					return m2->name2 > m1->name2;
				      return m2->pri > m1->pri;
				    }
			     );

    mapping seen_pri = ([ ]);
    int pri_warn = 0;

    foreach( _mods, mapping m ) {
      
      res += "<tr><td>" + m->name2 + "</td>";
      res+= "<td><img src='/internal-roxen-unit' width='20' height='1'/></td>";

      res += "<td> Priority: ";

      if(seen_pri[m->pri])
	pri_warn = 1;
      else
	seen_pri[m->pri] = 1;

      if(!modules_seen[m->name2]) {
	res += "<select name='prichange_"+replace(m->id,"#","!")+"'>";
	foreach( ({ 0,1,2,3,4,5,6,7,8,9 }), int pri) {
	  if(m->pri == pri)
	    res+="<option selected='selected' value='"+pri+"'>"+pri+"</option>";
	  else
	    res+="<option value='"+pri+"'>"+pri+"</option>";
	}
	res+="</select>";
	modules_seen[m->name2] = 1;
      } else {
	res += (string)m->pri + " (change above)";
      }


      res+="</td></tr>\n";
      
      res += "<tr><td colspan='3'>";

      if(m->oldpri)
	res += "<imgs src='&usr.err-1;'/> Priority changed from " + m->oldpri + " to " + m->pri +".";

      res += "</td></tr>";
    }
    
    if(pri_warn) {
      res += "<tr><td colspan='3'>";
      res+= "<br /><imgs src='&usr.err-2;'/> Some modules have the same priority and will be called in random order.";
      res += "</td></tr>";
    }

    res += "<tr><td colspan='3'>";
    res+= "<img src='/internal-roxen-unit' width='1' height='20'/>";
    res += "</td></tr>";

  }
  
  res += "</table>";

  res += "<cf-save/>";

  return res;
}


