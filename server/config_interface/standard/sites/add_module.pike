inherit "roxenlib";
#include <config_interface.h>
#include <module.h>

// Class is the name of the directory.
array(string) class_description( string d, object id )
{
  string name, doc;
  while(!(< "", "/" >)[d] && !file_stat( d+"/INFO" ))
    d = dirname(d);
  if((< "", "/" >)[d])
    return ({"Local modules", "" });

  string n = Stdio.read_bytes( d+"/INFO" );
  sscanf( n, "<"+id->misc->config_locale+">%s"
          "</"+id->misc->config_locale+">", n );
  sscanf( n, "%*s<name>%s</name>", name  );
  sscanf( n, "%*s<doc>%s</doc>", doc  );

  if(!name)
    return ({"Local modules", "" });

  if(!doc)
    doc ="";

  return ({ name, doc });
}

array(string) module_class( object m, object id )
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
    return roxen->find_module( conf->otomod[o] );
}

// To redirect to when done with module addition
string site_url( RequestID id, string site )
{
  return "/"+id->misc->cf_locale+"/sites/site.html/"+site+"/";
}

string page_base( RequestID id, string content )
{
  return sprintf( "<use file=/standard/template>\n"
                  "<tmpl title=''>"
                  "<topmenu base='&cf.num-dotdots;' selected=sites>\n"
                  "<content><cv-split>"
                  "<subtablist width=100%%>"
                  "<st-tabs></st-tabs>"
                  "<st-page>"
                  "\n%s\n"
                  "</st-page></subtablist></td></tr></table>"
                  "</cv-split></content></tmpl>", content );
}

array(string) get_module_list( function describe_module,
                               function class_visible,
                               RequestID id )
{
  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  master()->set_inhibit_compile_errors( ec );

  array mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  string res = "";

  string doubles="", already="";

  array w = map(mods, module_class, id);

  mapping classes = ([
  ]);
  sort(w,mods);
  for(int i=0; i<sizeof(w); i++)
  {
    mixed r = w[i];
    if(!classes[r[0]])
      classes[r[0]] = ([ "doc":r[1], "modules":({}) ]);
    classes[r[0]]->modules += ({ mods[i] });
  }

  foreach( sort(indices(classes)), string c )
  {
    mixed r;
    if( (r = class_visible( c, classes[c]->doc, id )) && r[0] )
    {
      res += r[1];
      foreach(classes[c]->modules, object q)
      {
        if( q->get_description() == "Undocumented" &&
            q->type == 0 )
          continue;
        object b = module_nomore(q->sname, q, conf);
        res += describe_module( q, b );
      }
    } else
      res += r[1];
  }
  master()->set_inhibit_compile_errors( 0 );
  return ({ res, ec->get() });
}

string module_image( int type )
{
  return "";
}

function describe_module_normal( int image )
{
  return lambda( object module, object block)
  {
    if(!block)
    {
return sprintf(
#"
    <tr><td colspan=2><table width='100%%'><td><font size=+2>%s</font></td><td align=right>%s</td></table></td></tr>
    <tr><td valign=top><form method=post action='add_module.pike'><input type=hidden name=module_to_add value='%s'><input type=hidden name='config' value='&form.config;'><submit-gbutton preparse>&locale.add_module;</submit-gbutton></form></td><td valign=top>%s<p>%s</td>
    </tr>
",
     module->get_name(),
     (image?module_image(module->type):""),
     module->sname,
     module->get_description(),
     "Will be loaded from: "+module->filename
);
    } else {
      if( block == module )
        return "";
      return "";
    }
  };
}

array(int|string) class_visible_normal( string c, string d, object id )
{
  string header = ("<tr><td colspan=2><table width=100% cellspacing=0 border=0 cellpadding=3 bgcolor=&usr.content-titlebg;><tr><td>UNFOLD</td><td width=100%>"
                   "<font color=&usr.content-titlefg; size=+2>"+c+"</font>"
                   "<br>"+d+"</td></tr></table></td></tr>");
  if( id->variables->unfolded == c )
    return ({ 1, replace(header,"UNFOLD","<gbutton preparse dim> "
                       "View </gbutton>") });

  return ({ 0, replace(header,"UNFOLD","<gbutton preparse "
                       "href='add_module.pike?config=&form.config;"
                       "&unfolded="+http_encode_string(c)+"' > "
                       "View </gbutton>") }) ;
}

string page_normal( RequestID id, int|void noimage )
{
  string content = "";
  content += "<table>";
  string desc, err;
  [desc,err] = get_module_list( describe_module_normal(!noimage),
                                class_visible_normal, id );
  content += desc;
  content += ("</table>"+
              "<pre>"+html_encode_string(err)+"</pre>");
  return page_base( id, content );
}

string page_fast( RequestID id )
{
  return page_normal( id, 1 );
}

int first;

array(int|string) class_visible_compact( string c, string d, object id )
{
  string res="";
  if(first++)
    res = "</select><br><submit-gbutton> &locale.add_module; </submit-gbutton> ";
  res += "<p><font size=+2>"+c+"</font><br>"+d+"<p><select multiple name=module_to_add>";
  return ({ 1, res });
}

string describe_module_compact( object module, object block )
{
  if(!block)
    return "<option value='"+module->sname+"'>"+module->get_name();
}

string page_compact( RequestID id )
{
  first=0;
  string desc, err;
  [desc,err] = get_module_list( describe_module_compact,
                                class_visible_compact, id );
  return page_base(id,
                   "<form action=add_module.pike method=POST>"
                   "<input type=hidden name=config value=&form.config;>"+
                   desc+"</select><br><submit-gbutton> "
                   "&locale.add_module; </submit-gbutton><p><pre>"
                   +html_encode_string(err)+"</pre></form>",
                   );
}

mixed do_it( RequestID id )
{
  object conf = roxen.find_configuration( id->variables->config );
  string last_module;
  if(!conf)
    return "Configuration gone!\n";

  foreach( id->variables->module_to_add/"\0", string mod )
    last_module = replace((conf->otomod[ conf->enable_module( mod ) ]||""),
                          "#", "!" );

  if( strlen( last_module ) )
    return http_redirect( site_url( id, id->variables->config )+
                          "modules/"+last_module+"/?initial=1&section=_all", id );
  return http_redirect( site_url( id, id->variables->config )+"modules/",id);
}

mixed parse( RequestID id )
{
  if( !config_perm( "Add Module" ) )
    return "Permission denied\n";

  if( id->variables->module_to_add )
    return do_it( id );

  return this_object()["page_"+config_setting( "addmodulemethod" )]( id );
}
