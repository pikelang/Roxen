<!-- /*
    -*- pike -*- works best for this file.
     Perhaps I should take the hint
  -->
<h1><cf-locale get=add_module></h1>

<!-- */ -->

<pike>
#include <module.h>
#define LS(X) parse_rxml( "<cf-locale get='" +(X)+ "'>", id )
#define LOCALE roxen->locale->get()->config_interface

object module_nomore(string name, object modinfo, object conf)
{
  mapping module;
  object o;
// perror("Module: "+name+"\n");
  // Broken test.
  if(!modinfo->multiple_copies && 
     (module = conf->modules[name]) &&
     module->copies[0] )
    return modinfo;

  if(((modinfo->type & MODULE_DIRECTORIES) && (o=conf->dir_module))
     || ((modinfo->type & MODULE_AUTH)  && (o=conf->auth_module))
     || ((modinfo->type & MODULE_TYPES) && (o=conf->types_module)))
    return roxen->find_module( conf->otomod[o] );
}


string parse(object id )
{
  object conf = id->misc->current_configuration;
  array mods = roxen->all_modules();
  string res = 
         (LS( "select_compact_module" )+
          "<select multiple size=10 name=_add_new_modules>");
  string doubles="";
    
  foreach(mods, object q)
  {
    object b;
    if(b = module_nomore(q->sname, q, conf))
    {
      if(b->sname != q->sname)
        doubles += 
                ("<p><dt><b>"+q->get_name()+"</b><dd>" +
                 "<i>" + 
                 LOCALE->module_type_enabled(b->get_name()) +
                 LOCALE->disable_that_module("", "") +
                 "</i>\n");
    } 
    else
      res += ("<option value=\""+q->sname+"\">"+q->get_name()+"\n");
  }
  if(strlen(doubles))
    doubles = "<dl>"+doubles+"</dl>";
  else 
    doubles = "&nbsp;";
  res += ("</select>\n"
          "<p>"+ doubles);
  return res;
}
</pike>    
