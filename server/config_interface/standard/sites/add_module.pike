inherit "roxenlib";
#include <config_interface.h>
#include <module.h>

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
  return "/"+id->misc->config_locale+"/sites/site.html/"+site+"/";
}

string page_base( RequestID id, string content )
{
  return sprintf( "<use file=/standard/template>\n"
                  "<tmpl title=''>"
                  "<topmenu base='<cf-num-dotdots>' selected=sites>\n"
                  "<content><table>\n<tr>\n"
                  "<td valign=top width=200><br><p><br>"
                  " <img src=/internal-roxen-unit width=199> "
                  "</td><td valign=top width=100%% height=100%%>"
                  "<subtablist width=100%%>"
                  "<st-tabs></st-tabs>"
                  "<st-page>"
                  "\n%s\n"
                  "</st-page></subtablist></td></tr></table>"
                  "</content></tmpl>", content );
}

array(string) get_module_list( function describe_module, RequestID id )
{
  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  master()->set_inhibit_compile_errors( ec );

  array mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  string res =
         ("<table><tr><td valign=top>"
          "<select multiple size=20 name=_add_new_modules>");
  string doubles="", already="";

  foreach(mods, object q)
  {
    object b = module_nomore(q->sname, q, conf);
    res += describe_module( q, b );
  }
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
    if( module->get_description() == "Undocumented" &&
        module->type == 0 )
      return "";
    if(!block)
    {
return sprintf(
#"
    <tr><td colspan=2><hr><table width='100%%'><td><font size=+2>%s</font></td><td align=right>%s</td></table></td></tr>
    <tr><td valign=top><form method=post action='add_module.pike'><input type=hidden name=module_to_add value='%s'><input type=hidden name='config' value='&form.config;'><submit-gbutton preparse><cf-locale get=add_module></submit-gbutton></form></td><td valign=top>%s<p>%s</td>
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
      return "<tr><td>... cannot be enabled ... blablabla</td></tr>\n";
    }
  };
}

string page_normal( RequestID id, int|void noimage )
{
  string content = "<h1> <cf-locale get=add_module> </h1>";
  content += "<br><table>";
  string desc, err;
  [desc,err] = get_module_list( describe_module_normal(!noimage), id );
  content += desc;
  content += "</table>"+err;
  return page_base( id, content );
}

string page_fast( RequestID id )
{
  return page_normal( id, 1 );
}

string page_compact( RequestID id )
{
}

mixed do_it( RequestID id )
{
  object conf = roxen.find_configuration( id->variables->config );
  string last_module;
  if(!conf)
    return "Configuration gone!\n";

  foreach( id->variables->module_to_add/"\0", string mod )
    last_module = replace(conf->otomod[ conf->enable_module( mod ) ],
                          "#", "!" );

  return http_redirect( site_url( id, id->variables->config )+
                        "modules/"+last_module+"/", id );
}

mixed parse( RequestID id )
{
  if( !config_perm( "Add Module" ) )
    return "Permission denied\n";

  if( id->variables->module_to_add )
    return do_it( id );

  return this_object()["page_"+config_setting( "addmodulemethod" )]( id );
}
