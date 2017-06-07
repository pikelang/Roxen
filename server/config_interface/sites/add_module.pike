// $Id$

#include <config_interface.h>
#include <module.h>
#include <module_constants.h>
#include <roxen.h>

int no_reload()
{
  if( sizeof( already_added ) )
    return 1; // Reloading this script now would destroy state.
}

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("roxen_config",X,Y)

// Class is the name of the directory.
array(string) class_description( string d, RequestID id )
{
  string name, doc;
  while(!(< "", "/" >)[d] && !Stdio.is_file( d+"/INFO" ))
    d = dirname(d);
  if((< "", "/" >)[d])
    return ({"Local modules", "" });

  string n = Stdio.read_bytes( d+"/INFO" );
  sscanf( n, "<"+id->misc->config_locale+">%s"
          "</"+id->misc->config_locale+">", n );
  sscanf( n, "%*s<name>%s</name>", name  );
  sscanf( n, "%*s<doc>%s</doc>", doc  );
  if( search(n, "<noshow/>" ) != -1 )
    return ({ "", "" });

  if(!name)
    return ({"Local modules", "" });

  if(!doc)
    doc ="";

  return ({ name, doc });
}

array(string) module_class( object m, RequestID id )
{
  return class_description( m->filename, id );
}

object module_nomore(string name, object modinfo, object conf)
{
  mapping module;
  object o;

  if(!modinfo)
    return 0;

  if(!modinfo->multiple_copies && (module = conf->modules[name]) &&
     sizeof(module->copies) )
    return modinfo;

  if(((modinfo->type & MODULE_DIRECTORIES) && (o=conf->dir_module))
     || ((modinfo->type & MODULE_AUTH)  && (o=conf->auth_module))
     || ((modinfo->type & MODULE_TYPES) && (o=conf->types_module)))
    return roxen.find_module( conf->otomod[o] );
}

// To redirect to when done with module addition
string site_url( RequestID id, string site )
{
  return "/sites/site.html/"+site+"/";
}

string get_method(RequestID id)
{
  //  There really is no difference between Normal and Fast
  string method =
    id->variables->method ||
    replace(config_setting( "addmodulemethod" ), " ", "_");
  if (has_value(method, "\0"))
    method = (method / "\0")[0];
  if (method == "fast")
    method = "normal";
  id->variables->method = method;
  return method;
}


bool show_deprecated(RequestID id)
{
  return !!((int)id->variables->deprecated);
}


string page_base(RequestID id, string content, int|void noform,
                 int|void show_search_form)
{
  string method = get_method(id);
  string tmpl = Stdio.read_file(combine_path(__DIR__, "add_module.mu"));

  mapping ctx = ([
    "title"           : LOCALE(251,"Add Module"),
    "noform"          : noform,
    "list_type_title" : LOCALE(421, "List Type"),
    "method"          : method,
    "search_form"     : show_search_form,
    "content"         : content,
    "list_types" : ([
      "normal"   : LOCALE(280, "Normal"),
      "faster"   : LOCALE(284, "Faster"),
      "compact"  : LOCALE(286, "Compact"),
      "rcompact" : LOCALE(531, "Really Compact")
    ]),
    "button" : ([
      "reload" : LOCALE(272,"Reload Module List"),
      "cancel" : LOCALE(202,"Cancel"),
    ])
  ]);

  return Mustache()->render(tmpl, ctx);
}

string module_name_from_file( string file )
{
  string data, name;

  catch(data = Stdio.read_bytes( file ));

  if( data
      && sscanf( data, "%*smodule_name%*s=%[^;];", name )
      && sscanf( name, "%*[^\"]\"%s\"", name ) )
    return Roxen.html_encode_string(name);
  return Roxen.html_encode_string(((file/"/")[-1]/".")[0]);
}

string pafeaw( string errors, string warnings, array(ModuleInfo) locked_modules)
// Parse And Format Errors And Warnings (and locked modules).
// Your ordinary prettyprinting function.
{
  mapping by_module = ([]);
  int cnt = 0;
  foreach( (errors+warnings)/"\n", string e )
  {
    string file;
    int row;
    string type, error;
    sscanf( e, "%s:%d%s", file, row, error );
    if( error )
    {
      sscanf( error, "%*[ \t]%s", error );
      sscanf( error, "%s: %s", type, error );
      if( by_module[ file ] )
        by_module[ file ] += ({ ({ row*10000 + cnt++, row, type, error }) });
      else
        by_module[ file ] = ({ ({ row*10000 + cnt++, row, type, error }) });
    }
  }


  string da_string = "";

  int header_added;
  foreach( sort((array)by_module), [string module, array errors] )
  {
    array res = ({ });
    int remove_suspicious = 0;
    sort( errors );
    foreach( errors, array e )
    {
      if( e[2]  == "Error" )
      {
        remove_suspicious = 1;
        switch( e[3] )
        {
         case "Must return a value for a non-void function.":
         case "Class definition failed.":
         case "Illegal program pointer.":
         case "Illegal program identifier":
           continue;
        }
      }
      res += ({ e });
    }
    if( sizeof( res ) )
    {
      string he( string what )
      {
        if( what == "Error" )
          return "<span class='notify warn inline'>"+what+"</span>";
        return what;
      };

      string hc( string what )
      {
        return what;
      };

      string trim_name( string what )
      {
        array q = (what / "/");
        return q[sizeof(q)-2..]*"/";
      };

#define RELOAD(X) sprintf("<link-gbutton "                                    \
                          "type='reload' "                                    \
                          "href='add_module.pike?config=&form.config:http;"   \
                          "&amp;method=&form.method;"                         \
                          "&amp;random=%d&amp;only=%s"                        \
                          "&amp;reload_module_list=yes"                       \
                          "&amp;&usr.set-wiz-id;"                             \
                          "#errors_and_warnings'>%s</link-gbutton>",          \
                          random(4711111),                                    \
                          (X),                                                \
                          LOCALE(253, "Reload"))

      if( !header_added++ )
        da_string +=
                  "<p><a name='errors_and_warnings'></a><br />"
                  "<font size='+2'><b><font color='&usr.warncolor;'>"
                  "Compile errors and warnings</font></b><br />"
                  "<table width=100% cellpadding='3' cellspacing='0' border='0'>";

      da_string += "<tr><td></td>"
                "<td colspan='3' bgcolor='&usr.content-titlebg;'>"
                + "<b><font color='&usr.content-titlefg;' size='+1'>"
                + module_name_from_file(module)+"</font></b></td>"
                + "<td align='right' bgcolor='&usr.content-titlebg;'>"
                "<font color='&usr.content-titlefg;' size='+1'>"
                + trim_name(module)
                + "</font>&nbsp;"+RELOAD(module)+"</td><td></td></tr>";

      foreach( res, array e )
        da_string +=
                  "<tr valign='top'><td></td><td><img src='/internal-roxen-unit' width='30' height='1' alt='' />"
                  "</td><td align='right'>"
                  "<tt>"+e[1]+":</tt></td><td align='right'><tt>"+
                  he(e[2])+":</tt></td><td><tt>"+hc(e[3])+"</tt></td></tr>\n";
      da_string += "<tr valign='top'><td colspan='5'>&nbsp;</td><td></td></tr>\n";

    }
  }
  if( strlen( da_string ) )
    da_string += "</table>";
// "<pre>"+Roxen.html_encode_string( sprintf( "%O", by_module ) )+"</pre>";

  return da_string + format_locked_modules(locked_modules);
}

string format_locked_modules(array(ModuleInfo) locked_modules)
{
  if(!sizeof(locked_modules))
    return "";

  return
    "<p class='large'>Locked modules</p>\n"
    "<p>These modules are locked and can not be enabled because they are "
    "not part of the license key for this configuration.</p>\n"
    "<div class='notify error'>"+
    (((array(string))locked_modules->get_name())*"<br />\n")+"</div>";
}

array(string) get_module_list( function describe_module,
                               function class_visible,
                               RequestID id,
                               void|bool fast)
{
  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  int do_reload;
  master()->set_inhibit_compile_errors( ec );

  if( id->variables->reload_module_list )
    roxen->clear_all_modules_cache();

  array(ModuleInfo) mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  foreach( mods, ModuleInfo m ) {
    if (m->deprecated && !show_deprecated(id)) {
      mods -= ({ m });
    }
    if( module_nomore( m->sname, m, conf ) ) {
      mods -= ({ m });
    }
  }

  string res = "";
  string doubles="", already="";
  array w = map(mods, module_class, id);

  mapping classes = ([]);
  sort(w,mods);
  for(int i=0; i<sizeof(w); i++)
  {
    mixed r = w[i];
    if(!classes[r[0]])
      classes[r[0]] = ([ "doc":r[1], "modules":({}) ]);
    classes[r[0]]->modules += ({ mods[i] });
  }

  multiset(ModuleInfo) search_modules;
  if (string mod_query = id->variables->mod_query) {
    array(string) mod_query_words = (lower_case(mod_query) / " ") - ({ "" });
    search_modules = (< >);
    foreach(mods, ModuleInfo m) {
      string compare =
        lower_case(((string) m->get_name() || "") + "\0" +
                   m->sname + "\0" +
                   m->filename + "\0" +
                   Roxen.html_decode_string((string) m->get_description() ||
                                            LOCALE(1023, "Undocumented")));
    search_miss:
      {
        foreach(mod_query_words, string w)
          if (!has_value(compare, w))
            break search_miss;
        search_modules[m] = 1;
      }
    }
  }

  License.Key license_key = conf->getvar("license")->get_key();
  array(RoxenModule) locked_modules = ({});

  foreach( sort(indices(classes)), string c )
  {
    mixed r;
    if( c == "" )
      continue;
    if( (r = class_visible( c, classes[c]->doc, sizeof(classes[c]->modules), id, fast)) &&
        r[0] &&
        (!search_modules ||
         sizeof(classes[c]->modules & indices(search_modules))))
    {
      res += r[1];
      array m = classes[c]->modules;
      array q = m->get_name();
      sort( q, m );
      int hits = 0;
      foreach(m, object q)
      {
        if( q->get_description() == "Undocumented" &&
            q->type == 0 )
          continue;
        if (search_modules && !search_modules[q])
          continue;
        object b = module_nomore(q->sname, q, conf);
        if( !b && q->locked &&
            (!license_key || !q->unlocked(license_key, conf)) )
        {
          locked_modules += ({ q });
          continue;
        }
        hits += 1;
        res += describe_module( q, b );
      }

      if (!hits) {
        res +=
          "<div class='module no-modules'>"
            "<span class='notify info inline'>No available modules</span>"
          "</div>";
      }
    } else {
      if (!search_modules)
        res += r[1];
    }
  }
  master()->set_inhibit_compile_errors( 0 );
  return ({ res, pafeaw( ec->get(), ec->get_warnings(), locked_modules) });
}

string module_image( int type )
{
  return "";
}

string strip_leading( LocaleString what )
{
  if( !what ) return 0;
  sscanf( (string)what, "%*s:%*[ \t]%s", what );
  return what;
}

function describe_module_normal(void|bool faster)
{
  return lambda(object module, object block)
  {
    if (!block) {
      string tmpl = #"
        <div class='module{{#deprecated}} deprecated{{/deprecated}}'>
          <div class='flex-row header'>
            <div class='flex flex-grow'><h3>{{ name }}</h3></div>
            <div class='flex flex-shrink'><span class='dim'>({{ sname }})</span></div>
          </div>
          <div class='row'>
            <div class='float-right'>
              {{ #faster }}
                <label for='mod-{{ sname }}' class='module-checkbox' tabindex='0'
                       data-toggle-cb-event=''>
                  <input type='checkbox' value='{{ sname }}' name='module_to_add'
                         id='mod-{{ sname }}' data-toggle-cb=''>
                  <span>Select</span>
                </label>
              {{ /faster }}
              {{ ^faster }}
              <form method='post' action='add_module.pike'>
                <roxen-automatic-charset-variable/>
                <roxen-wizard-id-variable />
                <input type='hidden' name='module_to_add' value='{{ sname }}'>
                <input type='hidden' name='config' value='&form.config;'>
                <submit-gbutton type='add'>{{ add_label }}</submit-gbutton>
              </form>
              {{ /faster }}
            </div>
            <div class='doc'>
              {{ &doc }}
              <p class='dim'>{{ load_path }}</p>
            </div>
          </div>
        </div>";

      string doc = module->get_description();

      if (doc) {
        if (objectp(doc)) {
          doc = (string) doc;
        }

        doc = String.trim_all_whites(doc);

        if (search(doc, "<p") == -1) {
          doc = "<p>" + doc + "</p>";
        }
      }
      else {
        doc = "<p>" + ((string)LOCALE(1023, "Undocumented")) + "</p>";
      }

      mapping ctx = ([
        "name"       : module->get_name(),
        "sname"      : module->sname,
        "add_label"  : LOCALE(251, "Add Module"),
        "doc"        : doc,
        "load_path"  : LOCALE(266, "Will be loaded from: ")+module->filename,
        "faster"     : faster,
        "deprecated" : module->deprecated
      ]);

      return Mustache()->render(tmpl, ctx);
    }

    return "";
  };
}

array(int|string) class_visible_normal(string c, string d, int size,
                                       RequestID id, void|bool fast)
{
  int x;
  string method = get_method(id);
  string header;

  // LOCALE(168, "Hide")
  // LOCALE(267, "View")

  array(array(string)) qs = ({
    ({ "config", "&form.config;" }),
    ({ "method", "&form.method;" })
  });

  if (id->variables->mod_query) {
    x = 1;
  }
  else if( id->variables->unfolded == c) {
    x = 1;
  }
  else {
    qs += ({ ({ "unfolded", Roxen.http_encode_url(c) }) });
  }

  if (show_deprecated(id)) {
    qs += ({ ({ "deprecated", "1" }) });
  }

  string qss = sprintf("%{%s=%s&amp;%}", qs);

  qss += "&usr.set-wiz-id;#" + Roxen.http_encode_url(c);

  string content = sprintf("<a href='add_module.pike?%s'><dl><dt>%s</dt>",
                           qss, c);

  if (d && sizeof(String.trim_all_whites(d))) {
    content += "<dd>" + d + "</dd>";
  }

  content += "</dl></a>";

  if (x && fast) {
    content =
      "<div class='float-right select-multiple'>"
        "<submit-gbutton2 type='add'>Add modules</submit-gbutton2>"
      "</div>" +
      content;
  }

  header = sprintf("<div class='group-header action-group%s' id='%s'>%s</div>\n",
                   x ? " open" : " closed",
                   Roxen.html_encode_string(c),
                   content);

  return ({ x, header });
}


string page_normal_low(RequestID id, int|void fast)
{
  TRACE("page_normal_low: %O : faster(%O)\n", id, fast);
  string desc, err;
  [desc,err] = get_module_list(describe_module_normal(fast),
                               class_visible_normal, id, fast);

  string ret = "<div class='add-modules-wrapper'>";

  if (fast) {
    ret =
      "<form method='post' action='add_module.pike'>"
        "<input type='hidden' name='config' value='&form.config;'>"
        "<roxen-wizard-id-variable/>" +
      ret;
  }

  return ret + desc + "</div>" + (fast ? "</form>" : "") + err;
}

string page_normal_search(RequestID id, void|bool fast)
{
  return
    "<use file='/template-insert' />\n"
    "<tmpl>" +
    page_normal_low(id, fast) +
    "</tmpl>";
}

string page_normal( RequestID id, void|bool fast )
{
  string content =
    "<form id='mod_results' method='post' action='add_module.pike' style='display: none'>"
    "</form>"
    "<div id='mod_default'>" +
    page_normal_low(id, fast) +
    "</div>";
  return page_base( id, content, 1, 1);
}

string page_fast( RequestID id )
{
  return page_normal(id);
}

string page_faster_search(RequestID id)
{
  TRACE("Faster search: %O\n", id);
  return
    "<use file='/template-insert' />\n"
    "<tmpl>" +
    page_normal_low(id, true) +
    "</tmpl>";
}

string page_faster( RequestID id )
{
  string content =
    "<form id='mod_results' method='post' action='add_module.pike' style='display: none'>"
    "</form>"
    "<div id='mod_default'>" +
    page_normal_low(id, true) +
    "</div>";
  return page_base( id, content, 0, 1);
}

int first;

array(int|string) class_visible_compact( string c, string d, int size,
                                         RequestID id )
{
  string res="";
  if(first++)
    res = "</select><br /><submit-gbutton vspace='3'> "+
      LOCALE(200, "Add Modules")+ " </submit-gbutton> ";
  res += "<p><a name='"+Roxen.html_encode_string(c)+
    "'></a><font size='+2'>"+c+"</font><br />"+d+"<p>"
    "<select size='"+size+"' multiple name='module_to_add' class='add-module-select'>";
  return ({ 1, res });
}

string describe_module_compact( object module, object block )
{
  if(!block) {
    //string modname = strip_leading (module->get_name());
    string modname = module->get_name();
    return "<option value='"+module->sname+"'>"+
      Roxen.html_encode_string(modname)
      + "&nbsp;" * max (0, (int) ((49 - sizeof (modname)))) +
      " (" + Roxen.html_encode_string(module->sname) + ")"+
      "</option>\n";
  }
  return "";
}

string page_compact( RequestID id )
{
  first=0;
  string desc, err;
  [desc,err] = get_module_list( describe_module_compact,
                                class_visible_compact, id );
  return page_base(id,
                   "<form action='add_module.pike' method='POST'>"
                   "<roxen-wizard-id-variable />"
                   "<input type='hidden' name='config' value='&form.config;'>"+
                   desc+"</select><br /><submit-gbutton vspace='3'> "
                   +LOCALE(200, "Add Modules")+" </submit-gbutton><p>"
                   +err+"</form>",
                   );
}

string page_really_compact( RequestID id )
{
  first=0;

  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  master()->set_inhibit_compile_errors( ec );

  if( id->variables->reload_module_list )
  {
    if( id->variables->only )
    {
      master()->clear_compilation_failures();
      m_delete( roxen->modules, (((id->variables->only/"/")[-1])/".")[0] );
      roxen->all_modules_cache = 0;
    }
    else
      roxen->clear_all_modules_cache();
  }

  array mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  sort(map(mods->get_name(), lambda(LocaleString in) {
                               in = lower_case((string)in);
                               //sscanf(in, "%*s: %s", in);
                               return in;
                             }), mods);
  string res = "";

  mixed r;
  License.Key license_key = conf->getvar("license")->get_key();
  array(RoxenModule) locked_modules = ({});

  if( (r = class_visible_compact( LOCALE(200,"Add Modules"),
                                  LOCALE(273,"Select one or several modules to add."),
                                  sizeof(mods), id )) && r[0] ) {
    res += r[1];
    foreach(mods, object q) {
      if( (!q->get_description() ||
           (q->get_description() == "Undocumented")) &&
          q->type == 0 )
        continue;
      object b = module_nomore(q->sname, q, conf);
      if( !b && q->locked &&
          (!license_key || !q->unlocked(license_key, conf)) )
      {
        locked_modules += ({ q });
        continue;
      }
      res += describe_module_compact( q, b );
    }
  } else {
    res += r[1];
  }

  master()->set_inhibit_compile_errors( 0 );

  return page_base(id,
                   "<form action=\"add_module.pike\" method=\"post\">"
                   "<roxen-wizard-id-variable />"
                   "<input type=\"hidden\" name=\"config\" value=\"&form.config;\" />"+
                   res+"</select><br /><submit-gbutton> "
                   +LOCALE(200, "Add Modules")+" </submit-gbutton><br />"
                   +pafeaw(ec->get(),ec->get_warnings(),
                           locked_modules)+"</form>",
                   );
}

string decode_site_name( string what )
{
  if( (int)what )
    return (string)((array(int))(what/","-({""})));
  return what;
}




array initial_form( RequestID id, Configuration conf, array modules )
{
  id->variables->initial = "1";
  id->real_variables->initial = ({ "1" });

  string res = "";
  int num;

  foreach( modules, string mod )
  {
    ModuleInfo mi = roxen.find_module( (mod/"!")[0] );
    RoxenModule moo = conf->find_module( replace(mod,"!","#") );
    foreach( indices(moo->query()), string v )
    {
      if( moo->getvar( v )->get_flags() & VAR_INITIAL )
      {
        num++;
        res += "<tr><td colspan='3'><h3>"
        +LOCALE(1,"Initial variables for ")+
          //Roxen.html_encode_string(strip_leading(mi->get_name()))
          Roxen.html_encode_string(mi->get_name())
          +"</h3></td></tr>"
        "<emit source='module-variables' "
          " configuration=\""+conf->name+"\""
        " module=\""+mod+#"\"/>
        <emit noset='1' source='module-variables' "
          " configuration=\""+conf->name+"\""
        " module=\""+mod+#"\">
         <tr>
          <td width='150' valign='top' colspan='2'><b>&_.name;</b></td>
          <td valign='top'><eval>&_.form:none;</eval></td></tr>
         <tr>
          <td width='30'><img src='/internal-roxen-unit' width=50 height=1 alt='' /></td>
          <td colspan=2>&_.doc:none;</td></tr>
         <tr><td colspan='3'><img src='/internal-roxen-unit' height='18' /></td></tr>
        </emit>";
        break;
      }
    }
  }
  return ({res,num});
}

mapping already_added =  ([]);

mixed do_it_pass_2( array modules, Configuration conf,
                    RequestID id )
{
  id->misc->do_not_goto = 1;
  foreach( modules, string mod )
  {
    if( already_added[mod] )
      mod = already_added[ mod ];
    if( !has_value(mod, "!") || !conf->find_module( replace(mod,"!","#") ) )
    {
      RoxenModule mm = conf->enable_module( mod,0,0,1 );
      if( !mm || !conf->otomod[mm] )
      {
        report_error(LOCALE(382,"Failed to enable %s")+"\n");
        return Roxen.http_redirect( site_url(id,conf->name), id );
      }
      conf->call_low_start_callbacks( mm,
                                      roxen.find_module( (mod/"!")[0] ),
                                      conf->modules[ mod ] );
      modules = replace( modules, mod,
                         (already_added[mod]=(mod/"!")[0]+"!"+
                          (conf->otomod[mm]/"#")[-1]) );
    }
  }

  [string cf_form, int num] = initial_form( id, conf, modules );
  if( !num || id->variables["ok.x"] )
  {
    // set initial variables from form variables...
    if( num ) Roxen.parse_rxml( cf_form, id );
    foreach( modules, string mod )
     conf->call_high_start_callbacks( conf->find_module( replace(mod,"!","#") ),
                                      roxen.find_module( (mod/"!")[0] ),
                                      1);
    already_added = ([ ]);
    conf->save( ); // save it all in one go
    conf->forcibly_added = ([]);
    return Roxen.http_redirect(
      site_url(id,conf->name)+"-!-/"+modules[-1]+"/" ,
      id);
  }
  return page_base(id,"<table>"+
                   map( modules, lambda( string q ) {
                                   return "<input type='hidden' "
                                          "name='module_to_add' "
                                          "value='"+q+"' />";
                                 } )*"\n"
                   +"<input type='hidden' name='config' "
                   "value='"+conf->name+"' />"+cf_form+"</table><p><cf-ok />");
}

mixed do_it( RequestID id )
{
  if( id->variables->encoded )
    id->variables->config = decode_site_name( id->variables->config );

  Configuration conf;
  foreach(id->variables->config/"\0", string config) {
    if (conf = roxen.find_configuration( config )) {
      id->variables->config = config;
      break;
    }
  }

  if (!conf) {
    return sprintf(LOCALE(356, "Configuration %O not found."),
                   id->variables->config);
  }

  if( !conf->inited )
    conf->enable_all_modules();

  array modules = (id->variables->module_to_add/"\0")-({""});
  if( !sizeof( modules ) )
    return Roxen.http_redirect( site_url(id,conf->name ), id );
  return do_it_pass_2( modules, conf, id );
}

mixed parse( RequestID id )
{
  if( !config_perm( "Add Module" ) )
    return LOCALE(226, "Permission denied");

  if (!id->variables->config) {
    return Roxen.http_redirect("/sites/", id);
  }

  if( id->variables->module_to_add && !id->variables->reload) {
    return do_it( id );
  }

  Configuration conf;
  foreach(id->variables->config/"\0", string config) {
    if (conf = roxen.find_configuration(config)) {
      id->variables->config = config;
      break;
    }
  }

  if( !config_perm( "Site:"+conf->name ) )
    return LOCALE(226,"Permission denied");

  if( !conf->inited )
    conf->enable_all_modules();

  string method = get_method(id);

  if (id->variables->mod_query) {
    //  Force UTF-8 to please some browsers that can't guess charset in
    //  XMLHttpRequest communication.
    id->set_output_charset && id->set_output_charset("UTF-8");

    //  This can be invoked from both Normal and Faster methods
    return (method == "faster" ?
            page_faster_search(id) :
            page_normal_search(id));
  }

  return this_object()["page_" + method]( id );
}
