<!-- /*
    -*- pike -*- works best for this file.
     Perhaps I should take the hint :)
  -->
<h1><cf-locale get=add_module></h1><p>

<!-- */ -->

<pike>
#include <module.h>
#define LS(X) parse_rxml( "<cf-locale get='" +(X)+ "'>", id )
#define LOCALE roxen->locale->get()->config_interface

object module_nomore(string name, object modinfo, object conf)
{
  mapping module;
  object o;

  if(!modinfo->multiple_copies && (module = conf->modules[name]) &&	
     sizeof(module->copies) )
    return modinfo;

  if(((modinfo->type & MODULE_DIRECTORIES) && (o=conf->dir_module))
     || ((modinfo->type & MODULE_AUTH)  && (o=conf->auth_module))
     || ((modinfo->type & MODULE_TYPES) && (o=conf->types_module)))
    return roxen->find_module( conf->otomod[o] );
}

string parse(object id )
{
  if( !id->misc->config_user->auth( "Add Module" ) )
    return "No such luck, dude, permission denied";

  object conf = id->misc->current_configuration;
  array mods = roxen->all_modules();
  string res = 
         (/*LS( "select_compact_module" )+*/
          "<table><tr><td valign=top>"
          "<select multiple size=20 name=_add_new_modules>");
  string doubles="", already="";
    
  foreach(mods, object q)
  {
    object b;
    if(b = module_nomore(q->sname, q, conf))
    {
      if(b->sname != q->sname)
        doubles += 
                ("\n<dt><b>"+q->get_name()+"</b>\n<dd>" +
                 "<i>" + 
                 LOCALE->module_type_enabled(b->get_name()) +
                 LOCALE->disable_that_module("", "") +
                 "</i>\n");
      else
        already += 
                ("<dt><b>"+q->get_name()+"</b>\n");
 
    } 
    else
      res += ("<option value=\""+q->sname+"\">"+q->get_name()+"\n");
  }
  if(strlen(doubles))
    doubles = "<dl>"+doubles+"</dl>";
  else 
    doubles = "&nbsp;";
  if(strlen(already))
    doubles += "<b>Already enabled:</b><dl>\n"+already+"</dl>\n";
  res += ("</select></td>\n\n<td valign=top>\n"
          + doubles + "</td>\n</tr>\n</table>\n");
  return res;
}
</pike>    
