#include <config_interface.h>
#include <module.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string site_url( RequestID id, string site )
{
  return "/"+id->misc->cf_locale+"/sites/site.html/"+site+"/";
}

string page_base( RequestID id, string content )
{
  return sprintf( "<use file=/standard/template />\n"
                  "<tmpl title=''>"
                  "<topmenu base='&cf.num-dotdots;' selected=sites />\n"
                  "<content><cv-split>"
                  "<subtablist width=100%%>"
                  "<st-tabs></st-tabs>"
                  "<st-page>"
                  "\n%s\n"
                  "</st-page></subtablist></td></tr></table>"
                  "</cv-split></content></tmpl>", content );
}

mapping|string parse( RequestID id )
{
  if( !config_perm( "Add Module" ) )
    return LOCALE(226, "Permission denied");

  object c = roxen.find_configuration( id->variables->config );
  if( id->variables->drop )
  {
    c->disable_module( replace(id->variables->drop,"!","#") );
    c->save_me();
    return Roxen.http_redirect( site_url( id, id->variables->config ),id );
  }
  string res ="";
  array mods = map( indices( c->otomod )-({0}),
                    lambda(mixed q){ return c->otomod[q]; });
  foreach( sort(mods), string q )
  {
    object m = roxen.find_module( (q/"#")[0] );
    int c = (int)((q/"#")[-1]);
    res += ("<p><gbutton preparse href='drop_module.pike?config=&form.config;&"
            "drop="+replace(q,"#","!")+"'> "+LOCALE(252, "Drop Module")+
            " </gbutton>"+"&nbsp; <font size=+2>&nbsp;"+m->get_name()+"</font> "+(c?" #"+(c+1):"")+"</p>" );
  }
  return page_base( id, res );
}
