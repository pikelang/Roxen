#include <config_interface.h>
#include <module.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("roxen_config",X,Y)

string site_url(RequestID id, string site)
{
  return "/sites/site.html/"+site+"/";
}

string page_base(RequestID id, string content)
{
  return sprintf("<use file=/template />"
                 "<tmpl title=''>"
                 "<topmenu base='&cf.num-dotdots;' selected='sites' />"
                 "<content><cv-split>"
                 "<subtablist>"
                 "<st-tabs></st-tabs>"
                 "<st-page>"
                 "<cf-title>Drop module</cf-title>"
                 "<ul class='nolist button-list'>"
                 "%s"
                 "</ul>"
                 "</st-page></subtablist>"
                 "</cv-split></content></tmpl>", content);
}

mapping|string parse(RequestID id)
{
  if (!config_perm("Add Module")) {
    return LOCALE(226, "Permission denied");
  }

  Configuration c = roxen.find_configuration(id->variables->config);

  if (!config_perm("Site:"+c->name)) {
    return LOCALE(226,"Permission denied");
  }

  if (id->variables->drop) {
    c->disable_module(replace(id->variables->drop,"!","#"));
    c->save();
    c->save_me();
    c->forcibly_added = ([]);
    return Roxen.http_redirect(site_url(id, id->variables->config), id);
  }
  string res ="";
  array mods = map( indices( c->otomod )-({0}),
                    lambda(mixed q){ return c->otomod[q]; });

  array pos = map( mods,
                   lambda(string q) {
                     return roxen.find_module( (q/"#")[0] )->get_name()+q;
                   } );

  sort(pos, mods);
  foreach( mods, string q )
  {
    RoxenModule m = roxen.find_module( (q/"#")[0] );
    int c = (int)((q/"#")[-1]);
    res +=  "<li><link-gbutton href='drop_module.pike?config=&form.config;&amp;"
            "drop="+replace(q,"#","!")+"&amp;&usr.set-wiz-id;' type='remove'> "+
            "" + (m->get_name() + (c?" #"+(c+1):"")) + ""
            "</link-gbutton></li>";
  }
  return page_base( id, res );
}
