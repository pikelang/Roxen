// This is a roxen module. (c) Informationsvävarna AB 1996.

string cvs_version = "$Id: configure.pike,v 1.3 1997/10/03 17:16:56 grubba Exp $";
// Mounts the configuration interface on a location in the virtual
// filesystem.


#include <module.h>

inherit "module";
inherit "roxenlib";

void create()
{
  defvar("mountpoint", "/configure/", "Mount point", TYPE_LOCATION, 
	 "Configration interface location in the filesystem.");

  defvar("anonread", 0, "Allow anonymous read-only access", TYPE_FLAG,
	 "If set, read only access _will_ be allowed for anyone, "
	 "if their IP-number match the ip-pattern in the configuration"
	 " interface. This might be useful for some.");
}

mixed *register_module()
{
  return ({ 
    MODULE_LOCATION,
    "Configuration interface", 
    ("This module can be used to access the configuration interface from " 
     "a location, like a normal filesystem. It can be used to access the "
     "configuration interface through a firewall."),
    });
}

string query_location() { return query("mountpoint"); }

string tags(mapping from)
{
  string t, res="";
  foreach(indices(from), t)
    res += " " + t+"=\""+from[t]+"\"";
  return res;
}

inline string fix_it(string from)
{
  string pre;
  if(strlen(from) && from[0]=='/')
  {
    sscanf(from, "/(%s)/%s", pre, from);
    while(strlen(from) && from[0]=='/') from = from[1..];
    if(pre)
      return "/("+pre+")" + QUERY(mountpoint) + from;
    return QUERY(mountpoint) + from;
  }
  return from;
}

string do_href(string t, mapping m) 
{
  if(m->__parsed) return 0;
  if(!m->href) return 0;
  m->__parsed="yes";
  m->href = fix_it(m->href);
  return "<"+t+tags(m)+">";
}

string do_src(string t, mapping m)
{
  if(m->__parsed)    return 0;
  if(!m->src) return 0;
  m->__parsed="yes";
  m->src = fix_it(m->src);
  return "<"+t+tags(m)+">";
}

string do_action(string t, mapping m)
{
  if(m->__parsed)    return 0;
  if(!m->action) return 0;
  m->__parsed="yes";
  m->action = fix_it(m->action);
  return "<"+t+tags(m)+">";
}

string do_background(string t, mapping m)
{
  if(m->__parsed)    return 0;
  if(!m->background) return 0;
  m->__parsed="yes";
  m->background = fix_it(m->background);
  return "<"+t+tags(m)+">";
}


string fix_absolute(string from)
{
  return parse_html(from, ([ "a":do_href, "img":do_src, "form":do_action, 
			   "input":do_src, "body":do_background  ]), ([ ]));
}

array find_dir( string f, object id )
{
  if(f=="")
    return ({ "Configurations", "Globals", "Status", "Errors" });
}

array stat_file( string f, object id)
{
  mapping map;
  map = roxen->configuration_parse( id );
  if(map->code/100 == 2)
    if(map->file)
      return map->file->stat();
    else
      return ({0600,map->data?strlen(map->data):0,time(),time(),time(),0,0});
}

mapping find_file( string f, object id )
{
  mixed ret;
  int pass;
  array old_auth;
  object old_conf;
  string old_file;

  if(QUERY(anonread))
  {
    pass = 1;
    if(sizeof(id->prestate) && !(id->prestate->fold || id->prestate->unfold))
      pass = 0;
    else if(sizeof(id->variables))
      pass = 0;
  }
  
  old_file=id->not_query;
  old_conf=id->conf;
  old_auth = id->auth;
  
  if(id->auth)
    id->auth = ({ 0, id->realauth||"" });
  else if(pass)
    id->misc->read_allow = 1;
  
  id->conf = 0;
  id->not_query = "/" + f;
  ret = roxen->configuration_parse( id );
  id->not_query = old_file;
  id->conf = old_conf;
  id->auth = old_auth;
  if(ret->extra_heads && ret->extra_heads->Location)
  {
    string nl;
    if(sscanf(ret->extra_heads->Location, roxen->config_url()+"%s", nl))
      return http_redirect(query("mountpoint") + nl);
  }
  if(ret->type == "text/html" && ret->data && strlen(ret->data))
    ret->data = fix_absolute(ret->data);
  return ret;
}

string query_name()
{
  return "Configuration interface ("+query("mountpoint")+")";
}

