// The Roxen Network module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant cvs_version = "$Id: roxen_network.pike,v 1.1 2000/12/02 16:17:54 nilsson Exp $";
constant module_type = MODULE_ZERO;
constant thread_safe = 1;
constant module_name = "Roxen Network module";
constant module_doc  = #"This module advertises the servers capabilities 
on community.roxen.com. In practice that means that the server sends the
following information to Roxen:
<ul>
<li>Server version</li>
<li>Pike version</li>
<li>Server identification</li>
<li>URLs to all servers on port 80</li>
<li>All information that you choose to disclose in the module settings for this module.</li>
</ul>
All the above mentioned information is kept confidential except the URLs and the
disclosed information from the module settings.";

Variable.MapLocation var;
Configuration conf;

void create(Configuration _conf) {

  conf = _conf;

  defvar("owner",
	 Variable.String("", 0, "Server Owner",
			 "The name of the person/company/organization that owns the server"));

  defvar("webmaster",
	 Variable.Email("", 0, "Webmaster e-mail",
			"E-mail addres to the webmaster"));

  var = defvar("location",
	       Variable.MapLocation(0, internal_location, 0,
				    "Geographical location",
				    "The physical location of the server."));

  defvar("ad",
	 Variable.Text("", 0, "Free Text",
		       "Write whatever you like the community.roxen.com visitors "
		       "to know about your server..."));

  defvar("trans_mods",
	 Variable.Flag(1, 0, "Send active modules",
		       "Transmits a list of all active modules in your Roxen WebServer. "
		       "This information is kept confidential and is only used to better "
		       "see how Roxen WebServers in general are set up."));
}

string internal_location() {
  return conf->query("MyWorldLocation") + (query_internal_location()[1..]);
}

mapping find_internal( string f, RequestID id) {
  return var->cache->http_file_answer( f, id );
}
