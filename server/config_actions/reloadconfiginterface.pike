/*
 * $Id: reloadconfiginterface.pike,v 1.9 1998/11/18 04:54:05 per Exp $
 */

inherit "roxenlib";
inherit "configlocale";
constant name= "Development//Reload the configuration interface from disk";
constant doc = ("Force a reload of the configuration interface.");
constant name_svenska= "Utveckling//Ladda om konfigurationsgränssnittet från disk";
constant doc_svenska = ("Tvinga fram en omladdning av konfigurationsgränssnittet från disk.");
constant more=1;

constant programs = ({
  "mainconfig",
  "builders",
  "wizard",
  "savers",
  "draw_things",
  "describers",
});

mixed handle(object id, object mc)
{
  if (roxen->unload_configuration_interface) {
    /* Fool the type-checker of in old Roxen's */
    mixed foo = roxen->unload_configuration_interface;
    foo();
  } else {
    /* Some backward compatibility */
    roxen->configuration_interface_obj=0;
    roxen->loading_config_interface=0;
    roxen->enabling_configurations=0;
    roxen->build_root=0;
    catch{roxen->root->dest();};
    roxen->root=0;
  }

//   report_notice("Reloading the configuration interface from disk...\n");

  foreach(indices(master()->programs), string s)
    foreach(programs, string s2)
      if(search(s,s2)!=-1) {
	werror("Unloading "+s+"\n");
	m_delete(master()->programs, s);
      }

//   report_notice("Configuration interface reloaded from disk.\n");
  
  return http_redirect(roxen->config_url()+"Actions/?"+time(1));
}
