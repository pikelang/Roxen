#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)


string|mapping parse( RequestID id )
{
  if( !config_perm( "Create Site" ) )
    return LOCALE(226, "Permission denied");

  Configuration cf = roxen->find_configuration( id->variables->site );
  if( !cf ) return "No such configuration: "+id->variables->site;

  if( !id->variables["really.x"] )
  {
    return sprintf( "<use file='/standard/template' />\n"
                    "<tmpl title=' %s'>"
                    "<topmenu base='&cf.num-dotdots;' selected='sites'/>\n"
                    "<content><cv-split>"
                    "<subtablist width='100%%'>"
                    "<st-tabs></st-tabs>"
                    "<st-page>%s<br /><table width='100%'><tr width='100%'>"
                    "<input type=hidden name=site value='"+
                    Roxen.html_encode_string(id->variables->site)+"' />"
                    "<td align='left'><submit-gbutton2 name='really'> %s "
                    "</submit-gbutton2></td><td align='right'>"
                    "<gbutton href=''> %s </gbutton></td></tr></table>"
                    "</st-page></subtablist></td></tr></table>"
                    "</cv-split></content></tmpl>", 
                    LOCALE(258,"Drop Site"), 
                    LOCALE(0,"Are you sure you want to disable the site ")+
                    cf->name+"?",
                    LOCALE(258,"Drop Site"),
                    LOCALE(202,"Cancel") );
  }


  report_notice(LOCALE(255, "Disabling old configuration %s\n"), cf->name);
  string cfname = roxen.configuration_dir + "/" + cf->name;
  mv (cfname, cfname + "~");
  roxen->remove_configuration( cf->name );
  cf->stop();
  destruct( cf );
  return Roxen.http_redirect( "", id );
}
