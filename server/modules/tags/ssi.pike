// This is a roxen module. Copyright © 1999, Idonex AB.
//

inherit "module";
inherit "roxenlib";
#include <module.h>

constant thread_safe=1;
constant cvs_version = "$Id: ssi.pike,v 1.13 1999/12/14 01:40:49 nilsson Exp $";

array register_module()
{
  return ({
    MODULE_PARSER,
    "SSI support module",
    "Adds support for SSI tags.",
    0,1
  });
}

void create() {

  defvar("exec", 0, "Execute command", 
	 TYPE_FLAG,
	 "If set and if server side include support is enabled, Roxen "
	 "will accept NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt;. "
	 "Note that this will allow your users to execute arbitrary "
	 "commands.");

#if constant(getpwnam)
  array nobody = getpwnam("nobody") || ({ "nobody", "x", 65534, 65534 });
#else /* !constant(getpwnam) */
  array nobody = ({ "nobody", "x", 65534, 65534 });
#endif /* constant(getpwnam) */

  defvar("execuid", nobody[2] || 65534, "Execute command uid",
	 TYPE_INT,
	 "UID to run NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands with.");

  defvar("execgid", nobody[3] || 65534, "Execute command gid",
	 TYPE_INT,
	 "GID to run NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands with.");
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["!--#echo":"<desc tag></desc>",
    "!--#exec":"<desc tag></desc>",
    "!--#flastmod":"<desc tag></desc>",
    "!--#fsize":"<desc tag></desc>",
    "!--#set":"<desc tag></desc>",
    "!--#include":"<desc tag></desc>",
    "!--#config":"<desc tag></desc>"
]);
#endif

string trimvar(string var) {
  int s;
  if(s=sizeof(var)>2 && var[s-2..]=="--") var=var[..s-3];
  return var;
}

string|array(string) tag_echo(string tag, mapping m, RequestID id)
{
  if(!m->var)
  {
    if(sizeof(m) == 1)
      m->var = m[indices(m)[0]];
    else 
      return rxml_error(tag,"You have to select which variable to echo.",id);
  }

  if(id->misc->ssi_variables && id->misc->ssi_variables[m->var])
    // Variables set with !--#set.
    return id->misc->ssi_variables[m->var];

  mapping myenv =  build_env_vars(0,  id, 0);
  m->var = lower_case(replace(m->var, " ", "_"));
  m->var=trimvar(m->var);
  switch(m->var)
  {
   case "sizefmt":
   case "errmsg":
    return ({ id->misc->defines[m->var] || "" });
   case "timefmt":
    return ({ id->misc->defines[m->var] || "%c" });
    
   case "date_local":
    NOCACHE();
    return ({ strftime(id->misc->defines->timefmt || "%c", time(1)) });

   case "date_gmt":
    NOCACHE();
    return ({ strftime(id->misc->defines->timefmt || "%c", time(1) + localtime(time(1))->timezone) });
      
   case "query_string_unescaped":
    return id->query || "";

   case "last_modified":
     return make_tag("modified", m+(["ssi":1])); //FIXME: Performance
      
   case "server_software":
    return ({ roxen->version() });
      
   case "server_name":
    string tmp;
    tmp=id->conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    return ({ tmp });
      
   case "gateway_interface":
    return ({ "CGI/1.1" });
      
   case "server_protocol":
    return ({ "HTTP/1.0" });
      
   case "request_method":
    return ({ html_encode_string(id->method) });

   case "auth_type":
    return ({ "Basic" });
      
   case "http_cookie": case "cookie":
    NOCACHE();
    return ({ html_encode_string(id->misc->cookies || "") });

   case "http_accept":
    NOCACHE();
    return ({ html_encode_string(id->misc->accept && sizeof(id->misc->accept)?
				 id->misc->accept*", ": "None") });
      
   case "http_user_agent":
    NOCACHE();
    return ({ html_encode_string(id->client && sizeof(id->client)? 
				 id->client*" " : "Unknown") });
      
   case "http_referer":
    NOCACHE();
    return ({ html_encode_string(id->referer && sizeof(id->referer) ? 
				 id->referer*", ": "Unknown") });
      
   default:
    m->var = upper_case(m->var);
    if(myenv[m->var]) {
      NOCACHE();
      return myenv[m->var];
    }

    return rxml_error(tag,"Unknown variable ("+m->var+").",id);
  }
}

string tag_config(string tag, mapping m, RequestID id)
{
  if (m->sizefmt) {
    if ((< "abbrev", "bytes" >)[lower_case(m->sizefmt||"")]) {
      id->misc->defines->sizefmt = lower_case(m->sizefmt);
    } else {
      return rxml_error(tag,"Unknown SSI sizefmt ("+m->sizefmt+").",id);
    }
  }
  if (m->errmsg) {
    // FIXME: Not used yet. What would it be used for, really?
    id->misc->defines->errmsg = m->errmsg;
  }
  if (m->timefmt) {
    // now used by echo tag and last modified
    id->misc->defines->timefmt = m->timefmt;
  }
  return "";
}

string tag_include(string tag, mapping m, RequestID id)
{
  if(m->virtual) {
    int debug=id->misc->debug;
    id->misc->debug=-1;
    m->virtual=trimvar(m->virtual);
    string ret=API_read_file(id, m->virtual)||"";
    id->misc->debug=debug;

    if(ret=="")
      return rxml_error(tag,"No such file ("+m->virtual+")",id);

    return ret;
  }

  if(m->file)
  {
    array tmp;
    string fname1 = m->file;
    string fname2;
    if(m->file[0] != '/')
    {
      if(id->not_query[-1] == '/')
	m->file = id->not_query + m->file;
      else
	m->file = ((tmp = id->not_query / "/")[0..sizeof(tmp)-2] +
		   ({ m->file }))*"/";
      m->file=trimvar(m->file);
      fname1 = id->conf->real_file(m->file, id);
      if ((sizeof(m->file) > 2) && (m->file[sizeof(m->file)-2..] == "--")) {
	fname2 = id->conf->real_file(m->file[..sizeof(m->file)-3], id);
      }
    } else if ((sizeof(fname1) > 2) && (fname1[sizeof(fname1)-2..] == "--")) {
      fname2 = fname1[..sizeof(fname1)-3];
    }
    return((fname1 && Stdio.read_bytes(fname1)) ||
	   (fname2 && Stdio.read_bytes(fname2)) ||
           (id->misc->debug?
	   ("No such file: " +
	    (fname1 || fname2 || m->file) +
	    "!"):
           ""));
  }
  return rxml_error(tag, "Hm? #include what, my dear?", id);
}

string tag_set(string tag, mapping m, RequestID id)
{
  if(m->var && m->value)
  {
    m->var=trimvar(m->var);
    m->value=trimvar(m->value);
    if(!id->misc->ssi_variables)
      id->misc->ssi_variables = ([]);
    id->misc->ssi_variables[m->var] = m->value;
  }
  return "";
}

string tag_fsize(string tag, mapping m, RequestID id)
{
  if(m->virtual && sizeof(m->virtual))
  {
    m->virtual = http_decode_string(m->virtual);
    if (m->virtual[0] != '/') {
      // Fix relative path.
      m->virtual = combine_path(id->not_query, "../" + m->virtual);
    }
    m->file = id->conf->real_file(m->virtual, id);
    m_delete(m, "virtual");
  } else if (m->file && sizeof(m->file) && (m->file[0] != '/')) {
    // Fix relative path
    m->file = combine_path(id->conf->real_file(id->not_query, id) || "/", "../" + m->file);
  }
  if(m->file)
  {
    array s;
    s = file_stat(m->file);
    CACHE(5);
    if(s)
    {
      if(tag == "!--#fsize")
      {
	if(id->misc->defines->sizefmt=="bytes")
	  return (string)s[1];
        return sizetostring(s[1]);
      }
      return strftime(id->misc->defines->timefmt || "%c", s[3]);
    }
    return rxml_error(tag, "Couldn't stat file.", id);
  }
  return rxml_error(tag, "No such file.", id);
}

string tag_exec(string tag, mapping m, RequestID id)
{
  if(m->cgi) {
    if(m->cache)
      CACHE((int)m->cache);
    else
      NOCACHE();
    return API_read_file(id, http_decode_string(m->cgi))||"";
  }

  if(m->cmd)
  {
    if(QUERY(exec))
    {
      string tmp;
      tmp=id->conf->query("MyWorldLocation");
      sscanf(tmp, "%*s//%s", tmp);
      sscanf(tmp, "%s:", tmp);
      sscanf(tmp, "%s/", tmp);
      string user;
      user="Unknown";
      if(id->auth && id->auth[0])
	user=id->auth[1];
      string addr=id->remoteaddr || "Internal";
      NOCACHE();
      return popen(m->cmd,
		   getenv()
		   | build_roxen_env_vars(id)
		   | build_env_vars(id->not_query, id, 0),
		   QUERY(execuid) || -2, QUERY(execgid) || -2);
    }
    else
      return rxml_error(tag, "Execute command support disabled.", id);
  }
  return rxml_error(tag, "No arguments given.", id);
}

mapping query_tag_callers() {
  return ([
    "!--#echo":tag_echo,
    "!--#exec":tag_exec,
    "!--#flastmod":tag_fsize,
    "!--#fsize":tag_fsize, 
    "!--#set":tag_set, 
    "!--#include":tag_include, 
    "!--#config":tag_config
  ]);
}   
