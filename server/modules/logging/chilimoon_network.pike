// The ChiliMoon Network module. Copyright © 2000 - 2001, Roxen IS.
//

#include <module.h>
#include <version.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant cvs_version = "$Id: chilimoon_network.pike,v 1.2 2004/05/31 23:48:18 _cvs_stephen Exp $";
constant module_type = MODULE_ZERO;
constant thread_safe = 1;
constant module_name = "ChiliMoon Network module";
constant module_doc  = #"This module advertises the servers capabilities 
on stats.chilimoon.org. In practice that means that the server sends the
following information to the ChiliMoon stats-server:
<ul>
<li>Server version</li>
<li>Pike version</li>
<li>Server identification</li>
<li>Server HTTP URLs</li>
<li>All information that you choose to disclose in the module settings for this module.</li>
</ul>
All the above mentioned information is kept confidential except the URLs and the
disclosed information from the module settings.";

Variable.MapLocation var;
Configuration conf;

class PositionAccess {
  inherit Variable.MapLocation;

  int low_set( mixed to ) {
    return core->variables->global_position->set(to);
  }

  mixed query() {
    return core->variables->global_position->query();
  }
}


void create(Configuration _conf) {

  conf = _conf;

  defvar("owner",
	 Variable.String("", 0, "Server Owner",
			 "The name of the person/company/organization that owns the server"));

  defvar("webmaster",
	 Variable.Email("", 0, "Webmaster e-mail",
			"E-mail addres to the webmaster"))
    -> may_be_empty(1);

  var = [object(Variable.MapLocation)](mixed)
    defvar("location",
	   PositionAccess(0, internal_location, 0,
			  "Geographical location",
			  "The physical location of the server."));

  defvar("ad",
	 Variable.Text("", 0, "Free Text",
		       "Write whatever you like the stats.chilimoon.org visitors "
		       "to know about your server..."));

  defvar("trans_mods",
	 Variable.Flag(1, 0, "Send active modules",
		       "Transmits a list of all active modules in your ChiliMoon server. "
		       "This information is kept confidential and is only used to better "
		       "see how ChiliMoon servers in general are set up."));
}

void start() {
#ifndef OFFLINE
  Poster(build_package);
#endif /* OFFLINE */
}

string internal_location() {
  string server = conf->query("MyWorldLocation");
  if(!server || !sizeof(server)) server = "/";
  return server + (query_internal_location()[1..]);
}

mapping find_internal( string f, RequestID id) {
  return var->cache->http_file_answer( f, id );
}

class Poster
{
  Protocols.HTTP.Query query;
  function mk_pkg;

  void done( Protocols.HTTP.Query qu )
  {
    //    werror("ChiliMoon Network: %s\n", query->data());
  }
  
  void fail( Protocols.HTTP.Query qu )
  {
    report_warning( "ChiliMoon Network: Failed to connect to stats.chilimoon.org.\n" );
    call_out( start, 60 );
  }

  void start( )
  {
    remove_call_out( start );
    call_out( start, 60*60*24 );
    query = Protocols.HTTP.Query( )->set_callbacks( done, fail );
    query->async_request( "stats.chilimoon.org", 80,
			  "POST /register/chilimoon_network.html HTTP/1.0",
			  ([ "Host":"stats.chilimoon.org:80" ]),
			  "data=" + Roxen.http_encode_string(mk_pkg()) );
  }
  
  void create( function _mk_pkg )
  {
    mk_pkg = _mk_pkg;
    start();
  }
}


string build_package() {

  mapping info = ([]);

  info->pike_version = predef::version();
  info->roxen_version = __chilimoon_version__ + "." + __chilimoon_build__;
  info->id_string = core->version();

  foreach( ({ "owner", "webmaster", "ad" }), string var)
    if(sizeof(query(var)))
      info[var] = query(var);

  string pkg = "";

  foreach(indices(info), string var)
    pkg += "<" + var + ">" + Roxen.html_encode_string(info[var]) + "</" + var + ">\n";

  if(query("location"))
    pkg += "<location x=\""+query("location")[0]+"\" y=\""+query("location")[1]+"\"/>\n";

  if(query("trans_mods"))
    pkg += "<active_modules>" + ( sort(indices(conf->modules)) * ", " ) +
      "</active_modules>\n";

  array hosts=({ gethostname() }), dns;
#ifndef NO_DNS
  catch(dns=Protocols.DNS.client()->gethostbyname(hosts[0]));
  if(dns && sizeof(dns))
    hosts+=dns[2];
#endif /* !NO_DNS */
  hosts = Array.uniq(hosts);

  foreach(conf->registered_urls, string url) {
    if(!has_prefix(url, "http")) continue;
    foreach(hosts, string host) {
      string tmpurl = url, port = "80", path = "";
      sscanf(tmpurl, "%*s://%s/%s", tmpurl, path);
      sscanf(tmpurl, "%s:%s", tmpurl, port);
      if(glob(tmpurl, host))
	pkg += "<port url=\"http://" + host + ":" + port + "/" + path + "\"/>\n";
    }
  }

  return pkg;
}
