inherit "module";
inherit "roxenlib";
#include <module.h>

array register_module()
{
  return ({
    MODULE_PARSER,
    "SSI support module",
    "Adds support for SSI tags.",
    0,1
  });
}

void create(object c) {

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

string tag_compat_echo(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(m->help) 
    return ("This tag outputs the value of different configuration and "
            "request local variables. They are not really used by Roxen."
            " This tag is included only to provide compatibility "
            "with \"normal\" WWW-servers");
  if(!m->var)
  {
    if(sizeof(m) == 1)
      m->var = m[indices(m)[0]];
    else 
      return id->misc->debug?
        "Que? You have to select which variable to echo":"";
  }

  if(id->misc->ssi_variables && id->misc->ssi_variables[m->var])
    // Variables set with !--#set.
    return id->misc->ssi_variables[m->var];

  mapping myenv =  build_env_vars(0,  id, 0);
  m->var = lower_case(replace(m->var, " ", "_"));
  if(sizeof(m->var)>2 && m->var[sizeof(m->var)-2..]=="--") m->var=m->var[..sizeof(m->var)-3];
  switch(m->var)
  {
   case "sizefmt":
   case "errmsg":
    return defines[m->var] || "";
   case "timefmt":
    return defines[m->var] || "%c";
    
   case "date_local":
    NOCACHE();
    return strftime(defines->timefmt || "%c", time(1));

   case "date_gmt":
    NOCACHE();
    return strftime(defines->timefmt || "%c", time(1) + localtime(time(1))->timezone);
      
   case "query_string_unescaped":
    return id->query || "";

   case "last_modified":
     // FIXME: Use defines->timefmt
     return make_tag("modified", m+(["ssi":1])); //FIXME: Performance
      
   case "server_software":
    return roxen->version();
      
   case "server_name":
    string tmp;
    tmp=id->conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    return tmp;
      
   case "gateway_interface":
    return "CGI/1.1";
      
   case "server_protocol":
    return "HTTP/1.0";
      
   case "request_method":
    return id->method;

   case "auth_type":
    return "Basic";
      
   case "http_cookie": case "cookie":
    NOCACHE();
    return (id->misc->cookies || "");

   case "http_accept":
    NOCACHE();
    return (id->misc->accept && sizeof(id->misc->accept)? 
	    id->misc->accept*", ": "None");
      
   case "http_user_agent":
    NOCACHE();
    return id->client && sizeof(id->client)? 
      id->client*" " : "Unknown";
      
   case "http_referer":
    NOCACHE();
    return id->referer && sizeof(id->referer) ? 
      id->referer*", ": "Unknown";
      
   default:
    m->var = upper_case(m->var);
    if(myenv[m->var]) {
      NOCACHE();
      return myenv[m->var];
    }

    return "<i>Unknown variable</i>: '"+m->var+"'";
  }
}

string tag_compat_config(string tag,mapping m,object id,object file,
			 mapping defines)
{
  if(m->help) 
    return ("See the Apache documentation.");

  if (m->sizefmt) {
    if ((< "abbrev", "bytes" >)[lower_case(m->sizefmt||"")]) {
      defines->sizefmt = lower_case(m->sizefmt);
    } else {
      return(sprintf("Unknown SSI sizefmt:%O", m->sizefmt));
    }
  }
  if (m->errmsg) {
    // FIXME: Not used yet. What would it be used for, really?
    defines->errmsg = m->errmsg;
  }
  if (m->timefmt) {
    // now used by echo tag and last modified
    defines->timefmt = m->timefmt;
  }
  return "";
}

string tag_compat_include(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(m->help) 
    return ("This tag is more or less equivalent to the "
            "RXML command \"insert\", so why not use that one instead.");

  if(m->virtual) {
    string s;
    string f;
    f = fix_relative(m->virtual, id);
    id = id->clone_me();

    if(id->scan_for_query)
      f = id->scan_for_query( f );
    s = id->conf->try_get_file(f, id);


    if(!s) {
      if ((sizeof(f)>2) && (f[sizeof(f)-2..] == "--")) {
	s = id->conf->try_get_file(f[..sizeof(f)-3], id);
      }
      if (!s) {

	// Might be a PATH_INFO type URL.
	array a = id->conf->open_file( f, "r", id );
	if(a && a[0])
	{
	  s = a[0]->read();
	  if(a[1]->raw)
	  {
	    s -= "\r";
	    if(!sscanf(s, "%*s\n\n%s", s))
	      sscanf(s, "%*s\n%s", s);
	  }
	}
	if(!s)
	  return id->misc->debug?"No such file: "+f+"!":"";
      }
    }

    return s;
  }

  if(m->file)
  {
    mixed tmp;
    string fname1 = m->file;
    string fname2;
    if(m->file[0] != '/')
    {
      if(id->not_query[-1] == '/')
	m->file = id->not_query + m->file;
      else
	m->file = ((tmp = id->not_query / "/")[0..sizeof(tmp)-2] +
		   ({ m->file }))*"/";
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
  return "<!-- Hm? #include what, my dear? -->";
}

string tag_compat_set(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(m->var && m->value)
  {
    if(sizeof(m->var)>2 && m->var[sizeof(m->var)-2..]=="--") m->var=m->var[..sizeof(m->var)-3];
    if(sizeof(m->value)>2 && m->value[sizeof(m->value)-2..]=="--") m->value=m->value[..sizeof(m->value)-3];
    if(!id->misc->ssi_variables)
      id->misc->ssi_variables = ([]);
    id->misc->ssi_variables[m->var] = m->value;
  }
  return "";
}

string tag_compat_fsize(string tag,mapping m,object id,object file,
			mapping defines)
{
  if(m->help) 
    return ("Returns the size of the file specified (as virtual=... or file=...)");

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
	if(defines->sizefmt=="bytes")
	  return (string)s[1];
	else
	  return sizetostring(s[1]);
      } else {
	return strftime(defines->timefmt || "%c", s[3]);
      }
    }
    return "Error: Cannot stat file";
  }
  return id->misc->debug?"No such file?":"";
}

string tag_compat_exec(string tag,mapping m,object id,object file,
		       mapping defines)
{
  if(m->help) 
    return ("See the Apache documentation. This tag is more or less "
            "equivalent to &lt;insert file=...&gt;, but you can run "
            "any command. Please note that this can present a severe "
            " security hole when allowed.");

  if(m->cgi)
  {
    m->file = http_decode_string(m->cgi);
    m_delete(m, "cgi");
    return make_tag("insert", m); //FIXME: Performance
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
    } else {
      return "<b>Execute command support disabled."+
        (id->misc->debug?
	"Check \"Main RXML Parser\"/\"SSI support\".":
	"<!-- Check \"Main RXML Parser\"/\"SSI support\". -->"
        )+"</b>";
    }
  }
  return id->misc->debug?
    "No arguments given to SSI-#exec":
    "<!-- exec what? -->";
}


mapping query_tag_callers() {
  return ([
    "!--#echo":tag_compat_echo,
    "!--#exec":tag_compat_exec,
    "!--#flastmod":tag_compat_fsize,
    "!--#fsize":tag_compat_fsize, 
    "!--#set":tag_compat_set, 
    "!--#include":tag_compat_include, 
    "!--#config":tag_compat_config
  ]);
}   
