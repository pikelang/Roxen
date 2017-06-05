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
#define LOCALE(X,Y)     _STR_LOCALE("roxen_config",X,Y)
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

  // TRACE("tags: %O\n", conts);

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
       res += ("<table class='auto'><tr>" \
               "<td valign='top'><nobr>" + #X + " (</nobr></td>"        \
               "<td valign='top'>"+(Y)(m,Z)+")</td></tr></table>");     \
     else                                                               \
       res += "<div class='module-type'>" + #X + "</div>";              \
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
    buttons += "<submit-gbutton type='reload'>"+LOCALE(253, "Reload")+"</submit-gbutton>";
  if(!mod)
    return buttons;
  if( sizeof( mod->error_log ) )
    buttons+="<submit-gbutton type='clear'>"+LOCALE(247, "Clear Log")+"</submit-gbutton>";

  // Nor is it a good idea to drop configuration interface modules.
  // It tends to make things rather unstable.
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
  if( c != id->conf )
#endif
    buttons += "<link-gbutton type='remove' href='../../../../drop_module.pike?config="+
            path[0]+"&amp;drop="+mn+"&amp;&usr.set-wiz-id;'>"+
            LOCALE(252, "Drop Module")+"</link-gbutton></a>";

  //  Add action buttons produced by the module itself
  if (mod->query_action_buttons) {
    mapping(string:function|array(function|string)) mod_buttons =
      mod->query_action_buttons(id);
    array(string) titles = indices(mod_buttons);
    if (sizeof(titles)) {
      buttons +=
        "<div class='action-btn-spacer'></div>";
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

  if( sizeof( report ) > 1000 )
    report[1000] =
      sprintf(LOCALE(472,"%d entries skipped. Present in log on disk."),
              sizeof( report )-1000 );

  return "<h3 class='section'>"+LOCALE(216, "Events")+"</h3>" + (report[..1000]*"");
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

      return "<h2 class='section'>SNMP</h2>\n" +
        get_snmp_values(prot->mib, conf->query_oid(), conf->query_oid()+({8}));
    }
  }

  return "";
}

string get_snmp_values(ADT.Trie mib,
                       array(int) oid_start,
                       void|array(int) oid_ignore)
{
  array(string) res = ({});

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
                "<td>%s%s</td>",
                oid_string,
                Roxen.html_encode_string(name),
                Roxen.html_encode_string(val),
                sizeof(doc)
                  ? "<br><small>" + doc + "</small>"
                  : "")
    });
  }

  return
    "<table class='nice'>"
    "<thead><tr>"
      "<th align='left'>Name</th>"
      "<th align='left'>Value</th>"
    "</tr></thead>"
    "<tbody>"
    "<tr>" +
    res * "</tr>\n<tr>" +
    "</tr></tbody></table>\n";
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
    return sprintf("Error while calling "+ y+":<div class='notify error'><pre>"+
                   Roxen.html_encode_string( describe_backtrace( bt ) )+
                   "</pre></div>" );
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
    dbuttons += "<h3 class='section'>"+LOCALE(196, "Tasks")+"</h3>"+buttons( c, mn, id );
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

  if( .State->current_compile_errors[ cn+"!"+mn ] ) {
    dbuttons += "<div class='notify error'><pre>"+
      .State->current_compile_errors[ cn+"!"+mn ]+
      "</pre></div>";
  }

  string fnas = EC(TRANSLATE(m->file_name_and_stuff()));
  fnas = replace(fnas, "<br>", "</td></tr>\n<tr><td>");
  fnas = "<tr><td nowrap=''>"+
    ((fnas/":</b>")*":</b></td><td>") +
    "</td></tr>\n";

  string prefix = "", suffix = "";

  if (mi->deprecated) {
    prefix = "<div class='site-module module-deprecated'>";
    suffix = "</div>";
  }

  return
    prefix +
    replace( "<h2>" +
             Roxen.html_encode_string(EC(TRANSLATE(m->register_module()[1])))
             + "</h2>"
                  + EC(TRANSLATE(m->info(id)||"")) + "</p><p>"
                  + EC(TRANSLATE(m->status()||"")) + "</p><p>"
                  + dbuttons + snmp + eventlog +
                  ( config_setting( "devel_mode" ) ?
                    "<h3 class='section'>Developer information</h3>"
                    "<table class='devinfo auto'>"
                    "<tr nowrap=''><td><b>Identifier:</b></td>"
                    "<td>" + mi->sname + "</td></tr>\n"
                    "<td nowrap=''><b>Thread safe:</b></td>"
                    "<td>" + (m->thread_safe ?
                     LOCALE("yes", "Yes") : LOCALE("no", "No")) +
#ifdef THREADS
                    " <small>(<a href='../../../../../actions/?action"
                    "=locks.pike&amp;class=status&amp;&usr.set-wiz-id;'>"
                    "more info</a>)</small></td></tr>\n"
                    "<tr><td nowrap=''><b>Number of accesses:</b></td>"
                    "<td>" + my_accesses +
#endif
                    "</td></tr>\n"
                    "<tr><td valign='top' nowrap=''><b>Type:</b></td>"
                    "<td valign='top'>" + describe_type( m, mi->type, id ) +
                    "</td></tr>\n"
                    + fnas +
                    "</table>\n" +
                    homepage + creators
                    + "<h3 class='section'>"+LOCALE(261,"Inherit tree")+"</h3>"+
                    program_info( m ) +
                    "<dl>" +
                    (m->faked?"(Not on disk, faked module)":inherit_tree( m ))
                    +
                    "</dl>"
                    : homepage + creators),
                  ({ "/image/", }), ({ "/internal-roxen-" })) + suffix;
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

  return "<div class='tagdoc'>" + full_doc + "</div>";
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

string port_for(string url, int settings)
{
  // TRACE("port for: %s\n", url);
  return low_port_for(get_port_for(url), settings);
}

string low_port_for(array(Protocol|array(string)) port_info, int settings)
{
  [ Protocol p, array(string) urls ] = port_info;

  if (!urls) {
    return "";
  }

  if (!p) {
    // TRACE("port_info: %O\n", port_info);
    return
      sprintf("<div class='notify warn%s'>Not open</div>",
              settings ? "" : " inline");
  }

  string tmpl = #"
    <set variable='var.port' value='{{ port }}'/>
    <set variable='var.urlconf' value='{{ urlconf }}'/>
    <emit source='ports' scope='port'>
      <if variable='var.port is &_.port;'>
        {{ #settings }}
          <section class='port'>
            <h2>&_.name;</h2>
        {{ /settings }}

        <if variable='_.warning = ?*'>
          <div class='notify warn'><b>&_.warning;</b></div>
        </if>

        <unset variable='var.end'/>
        <set variable='var.port_cont' value='' type='text/*' />

        <emit source='port-urls' port='&_.port;' rowinfo='var.rowinfo'
              distinct='conf'>
          <if not variable='_.conf is &var.urlconf;'>
            <if not='' variable='var.end'>
              <set variable='var.end' value='.'/>
              <append variable='var.port_cont' value='{{ shared_with }}' />
            </if>
            <elseif variable='var.rowinfo = &_.counter;'>
              <append variable='var.port_cont' value=' {{ cw_and }} ' />
            </elseif>
            <else>
              <append variable='var.port_cont' value=', ' />
            </else>
            <append variable='var.port_cont' type='text/*'
              ><a href='../&_.conf;/'>&_.confname;</a></append>
          </if>
        </emit>

        <if variable='var.port_cont != '>
          <div class='ports'>&var.port_cont;&var.end;</div>
        </if>

        {{ #settings }}
            <cfg-variables nosave='' source='port-variables' port='&port.port;'/>
          </section>
        {{ /settings }}
      </if>
    </emit>";

  // FIXME: Report the others too.
  string url = roxen->normalize_url(urls[0], 1);

  mapping mctx = ([
    "port"        : p->get_key(),
    "urlconf"     : replace(p->urls[url]->conf->name, " ", "-"),
    "settings"    : settings,
    "shared_with" : LOCALE(323,"Shared with "),
    "cw_and"      : LOCALE("cw","and")
  ]);

  Mustache stache = Mustache();
  string x = stache->render(tmpl, mctx);
  destruct(stache);

  // TRACE("My res: %s\n", x);

  return x;
}

private typedef array(Protocol|array(string)) port_t;

private string render_ports(Configuration conf, string path, RequestID id)
{
  array(string) urls = conf->query("URLs");
  array(port_t) ports = map(conf->query("URLs"), get_port_for);
  mapping(Protocol:port_t) prot_info = ([]);

  foreach (ports, port_t port) {
    port_t prev;

    if (prev = prot_info[port[0]]) {
     if (prev[1]) {
       prev[1] += port[1];
     }
     else {
       prev[1] = port[1];
     }

     port[0] = 0;
     port[1] = 0;
    }
    else {
     prot_info[port[0]] = port;
    }
  }

  string ret = #"
    <input type=hidden name='section' value='Ports' />
    <div class='port-cfg-vars'>
      <cfg-variables source='config-variables'
      configuration='" + path + #"' section='Ports'/>
    </div>";

  ret += (map(ports, low_port_for, 1)*"");

  // TRACE("ports: %s\n", ret);

  return ret + "<cf-save/>";
}


string|mapping parse( RequestID id )
{
  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  // roxen_perror(sprintf("site_content:parse(): path: %{%O,%}\n", path));

  string section;
  string res = "";
  array(string) _sec = id->real_variables->section;

  if (_sec) {
    if (sizeof(_sec) > 0) {
      RXML.set_var("section",  _sec[0], "form");
    }

    section = _sec[0];
  }

  if (!sizeof(path) || equal(path, ({ "" }))) {
    return Roxen.http_redirect("/sites/", id);
  }

  Configuration conf = roxen->find_configuration(path[0]);

  if (!conf->inited) {
    conf->enable_all_modules();
  }

  if (!config_perm("Site:"+conf->name)) {
    return "Permission denied";
  }

  id->misc->current_configuration = conf;

  if (sizeof(path) < 3) {
    /* Global information for the configuration */
    switch (section){
    default: /* Not status info */
      do {
        id->misc->do_not_goto = 1;
      } while (id = id->misc->orig);

      return "<cfg-variables source='config-variables' "
             "configuration='"+path[0]+"' section='&form.section;'/>";

    case "ModulePriorities":
      if (conf == id->conf) {
        // Configuration interface.
        return 0;
      }
      return module_priorities_page(id, conf);


     case "Ports":
      return render_ports(conf, path[0], id);

     case 0:
     case "":
     case "Status":
       res = "<h1>" + LOCALE(299,"URLs") + "</h1>";
       res += "<table class='auto'>";
       foreach( conf->query( "URLs" ), string url ) {
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

      string vcomment = conf->variables->comment->query();

      if (sizeof(vcomment)) {
        res += "<p>"+Roxen.html_encode_string(vcomment)+"</p>";
      }

      res += "<hr class='section'>"
        "<div class='flex-row'>"
        "<div class='flex col-6'>"
          "<h2 class='no-margin-top'>"+LOCALE(260, "Request status")+"</h2>" +
          status(conf) +
        "</div>"
        "<div class='flex col-6'>"
          "<h2 class='no-margin-top'>"+LOCALE(292, "Cache status")+"</h2>"
          "<table class='auto'>\n";

       mapping stats = conf->datacache->get_cache_stats();
       int total = stats->hits + stats->misses;
       res +=
           sprintf("<tr><td><b>" + LOCALE(293, "Hits") + ": </b></td>"
                   "<td align='right'>%d</td><td align='right'>(%d</td>"
                   "<td align='left'>%%)</td></tr>\n",
                   stats->hits,
                   total ? (stats->hits * 100 / total) : 0);
       res +=
           sprintf("<tr><td><b>" + LOCALE(294, "Misses") + ": </b></td>"
                   "<td align='right'>%d</td><td align='right'>(%d</td>"
                   "<td align='left'>%%)</td></tr>\n",
                   stats->misses,
                   total ? (stats->misses * 100 / total) : 0);

       res +=
           sprintf("<tr><td><b>" + LOCALE(295, "Entries") + ": </b></td>"
                   "<td align='right'>%d</td><td align='right'>(%d</td>"
                   "<td align='left'>kB)</td></tr>\n",
                   stats->entries,
                   stats->current_size / 1024);

       res += "</table>\n";
       res += "</div></div>";

       // res += "</td></tr></table>";


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
       res+="<hr class='section'><h1 class='no-margin-top'>"+LOCALE(216, "Events")+"</h1><insert file='log.pike' nocache='1' />";
       if( sizeof( conf->error_log ) )
         res+="<hr class='divider'><submit-gbutton type='clear'>"+LOCALE(247, "Clear Log")+"</submit-gbutton>";
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
  Variable.Variable maxpri_var = c->getvar("max_priority");

  int max_priority = maxpri_var->query();

  array modids = map( indices( c->otomod )-({0}),
                      lambda(mixed q){ return c->otomod[q]; });

  array mod_types = ({
    ([ "title" : "First Try Modules", "type" : MODULE_FIRST    ]),
    ([ "title" : "Filter Modules",    "type" : MODULE_FILTER   ]),
    ([ "title" : "Location Modules",  "type" : MODULE_LOCATION ]),
    ([ "title" : "Last Try Modules",  "type" : MODULE_LAST     ]),
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

  // Update any module priorities before the range change.
  // Otherwise the priority scaling won't work properly.
  foreach( mods, mapping m ) {
    if (!(m->type & (MODULE_FIRST|MODULE_FILTER|MODULE_LAST|MODULE_LOCATION))) {
      continue;
    }
    int modpri = m->pri;
    string varname = "prichange_"+replace(m->id,"#","!");
    if(id->variables[varname]) {
      modpri = (int)m_delete(id->variables, varname);
      if(modpri < 0)
        modpri = 0;
      if(modpri > max_priority)
        modpri = max_priority;

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

  if (id->variables["maxprichange"]) {
    int new_max = (int)m_delete(id->variables, "maxprichange");
    if (new_max != max_priority) {
      maxpri_var->set(new_max);
      c->save_me();
      // Recurse so that we get updated priorities in our variables.
      return module_priorities_page(id, c);
    }
  }

  string tmpl = #"
    <input type=hidden name='section' value='ModulePriorities' />
    <cf-save />
    <h1 class='section'>Module priorities for site {{ sitename }}</h1>
    <select name='maxprichange'>
      {{ #prios }}
      <option value='{{ value }}'{{ #checked }} selected{{ /checked }}>{{ value }}</option>
      {{ /prios }}
    </select> is highest and 0 is lowest.

    {{ #sections }}
      <h2 class='section no-margin-bottom'>{{ title }}</h2>
      <table>
      {{ #mods }}
        <tr>
          <td>{{ name }}
            {{ #changed }}
              <br><div class='notify info inline'>Priority changed from {{ old }} to {{ new }}</div>
            {{ /changed }}
          </td>
          <td><em>{{ location }}</em></td>
          <td class='text-right'>Priority:
            {{ ^numeric }}
              <select name='prichange_{{ id }}'>
              {{ #prios }}
              <option value='{{ value }}'{{ #checked }} selected{{ /checked }}>
                {{ value }}
              </option>
              {{ /prios }}
              </select>
            {{ /numeric }}
            {{ #numeric }}
              <input type='number' class='prio' name='prichange_{{ id }}'
                     value='{{ pri }}' max='{{ max }}' />
            {{ /numeric }}
            {{ #seen }}
              {{ pri }} (change above)
            {{ /seen }}
          </td>
        </tr>
      {{ /mods }}
      </table>
    {{ /sections }}";

  mapping mctx = ([
    "sitename" : c->name,
    "prios"    : ({}),
    "sections" : ({})
  ]);

  foreach(c->getvar("max_priority")->get_choice_list(), int pri) {
    mctx->prios += ({
      ([ "value" : pri,
         "checked" : pri == max_priority ]) });
  }

  mapping modules_seen = ([ ]);

  foreach(mod_types, mapping mt) {
    mapping xmod = ([
      "title" : mt->title,
      "mods"  : ({})
    ]);

    array _mods = Array.filter(mods, lambda(mapping m) { return m->type & mt->type; });
    _mods = Array.sort_array(_mods, lambda(mapping m1, mapping m2) {
                                      if(m2->pri==m1->pri)
                                        return m2->name2 > m1->name2;
                                      return m2->pri > m1->pri;
                                    }
                             );

    mapping seen_pri = ([ ]);
    string pri_warn;

    foreach( _mods, mapping m ) {
      mapping modmap = ([
        "name" : m->name2,
        "pri"  : (string) m->pri,
        "max"  : max_priority,
        "id"   : replace(m->id, "#", "!")
      ]);

      string location = "";
      if ((mt->type & MODULE_LOCATION) && m->modi->query_location) {
        location = m->modi->query_location();
        modmap->location = location || "(none)";
      }

      if (!seen_pri[location])
        seen_pri[location] = ([ m->pri : 1 ]);
      else if(seen_pri[location][m->pri])
        pri_warn = location;
      else
        seen_pri[location][m->pri] = 1;

      if(!modules_seen[m->name2]) {
        if (max_priority == 9) {
          modmap->prios = map(({ 0,1,2,3,4,5,6,7,8,9 }),
              lambda (int pri) {
                return ([ "value" : (string) pri,
                          "checked" : pri == m->pri ]);
              });
        } else {
          modmap->numeric = true;
        }

        modules_seen[m->name2] = 1;
      } else {
        modmap->seen = true;
      }

      if(m->oldpri) {
        modmap->changed = ([
          "old" : m->oldpri,
          "new" : m->pri
        ]);
      }


      xmod->mods += ({ modmap });
    }

    if(pri_warn) {
      mctx->pri_warn = "Some modules have the same priority and will be "
                       "called in random order.";
    }

    mctx->sections += ({ xmod });
  }

  // TRACE("mctx: %O\n", mctx);


  Mustache stache = Mustache();
  string ret = stache->render(tmpl, mctx);
  destruct(stache);

  return ret + "<hr class='section'><cf-save/>";
}
