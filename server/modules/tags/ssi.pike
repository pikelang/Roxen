// This is a roxen module. Copyright © 2000, Idonex AB.
//

inherit "module";
inherit "roxenlib";
#include <module.h>

constant thread_safe=1;
constant cvs_version = "$Id: ssi.pike,v 1.16 2000/01/03 06:01:25 nilsson Exp $";

array register_module()
{
  return ({
    MODULE_PARSER | MODULE_PROVIDER,
    "SSI support module",
    "Adds support for SSI tags.",
    0,1
  });
}

void create() {

  defvar("exec", 0, "Execute command",
	 TYPE_FLAG,
	 "If set Roxen will accept NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt;. "
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

string query_provides() {
  return "ssi";
}

void start(int num, Configuration conf) {
  module_dependencies (conf, ({ "rxmltags" }));
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

function _modified;
string modified(mapping m, RequestID id) {
  if(_modified) return _modified("modified", m, id);
  _modified=id->conf->get_provider("modified")->tag_modified;
  return _modified("modified", m, id);
}

array(string) tag_echo(string tag, mapping m, RequestID id)
{
  if(!m->var)
  {
    if(sizeof(m) == 1)
      m->var = m[indices(m)[0]];
    else
      return ({ id->misc->ssi_errmsg||"You have to select which variable to echo." });
  }

  string ret=get_var(fix_var(m->var, id), id);

  if(ret) return ({ ret });
  return ({ id->misc->ssi_errfmt||"Unknown variable ("+m->var+")." });

}

string get_var(string var, RequestID id)
{

  if(id->misc->ssi_variables && id->misc->ssi_variables[var])
    // Variables set with !--#set.
    return id->misc->ssi_variables[var];

  var = lower_case(replace(var, " ", "_"));
  switch(var)
  {
   case "sizefmt":
   case "errmsg":
    return id->misc["ssi_"+var] || "";
   case "timefmt":
    return id->misc->ssi_timefmt || "%c";

   case "date_local":
    NOCACHE();
    return strftime(id->misc->ssi_timefmt || "%c", time(1));

   case "date_gmt":
    NOCACHE();
    return strftime(id->misc->ssi_timefmt || "%c", time(1) + localtime(time(1))->timezone);

   case "document_name":
    return id->realfile?reverse(id->realfile/"/")[0]:"";

   case "document_uri":
     return http_decode_string(id->not_query);

   case "query_string_unescaped":
    return id->query || "";

   case "last_modified":
     return modified((["ssi":1]), id);

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
    return html_encode_string(id->method);

   case "auth_type":
    return "Basic";

   case "http_cookie": case "cookie":
    NOCACHE();
    return html_encode_string(id->misc->cookies || "");

   case "http_accept":
    NOCACHE();
    return html_encode_string(id->misc->accept && sizeof(id->misc->accept)?
			      id->misc->accept*", ": "None");

   case "http_user_agent":
    NOCACHE();
    return html_encode_string(id->client && sizeof(id->client)?
			      id->client*" " : "Unknown");

   case "http_referer":
    NOCACHE();
    return html_encode_string(id->referer && sizeof(id->referer) ?
			      id->referer*", ": "Unknown");

   default:
    var = upper_case(var);
    mapping myenv =  build_env_vars(0, id, 0);
    if(myenv[var]) {
      NOCACHE();
      return myenv[var];
    }
  }
  return 0;
}

string fix_var(string s, RequestID id) {
  s=replace(s||"",({"\000","\\$"}),({"","\000"}));
  int size;
  if(size=sizeof(s)>2 && s[size-2..]=="--") s=s[..size-3];
  if(s[0]=='$' && s[1]!='{') return get_var(s[1..], id)||"";
  return ""; //FIXME: No in-string-substitution yet.
}

array(string) tag_config(string tag, mapping m, RequestID id)
{
  if (m->sizefmt) {
    m->sizefmt=fix_var(m->sizefmt, id);
    if ((< "abbrev", "bytes" >)[lower_case(m->sizefmt)]) {
      id->misc->ssi_sizefmt = lower_case(m->sizefmt);
    }
    else
      return ({ id->misc->ssi_errmsg||"Unknown SSI sizefmt ("+m->sizefmt+")." });
  }
  if (m->errmsg) {
    id->misc->ssi_errmsg = fix_var(m->errmsg, id);
  }
  if (m->timefmt) {
    // now used by echo tag and last modified
    id->misc->ssi_timefmt = fix_var(m->timefmt, id);
  }
  return ({ "" });
}

string|array(string) tag_include(string tag, mapping m, RequestID id)
{
  if(m->virtual) {
    m->virtual=fix_var(http_decode_string(m->virtual), id);
    string ret=API_read_file(id, m->virtual);
    if(!ret) return ({ id->misc->ssi_errmsg||"No such file ("+m->virtual+")." });
    return ret;
  }

  if(m->file) {
    m->file=replace(fix_var(m->file, id), "../", "");
    string ret=API_read_file(id, m->virtual);
    if(!ret) return ({ id->misc->ssi_errmsg||"No such file ("+m->file+")." });
    return ret;
  }

  return ({ id->misc->ssi_errmsg||"Hm? #include what, my dear?" });
}

string tag_set(string tag, mapping m, RequestID id)
{
  if(m->var && m->value)
  {
    m->var=fix_var(m->var, id);
    m->value=fix_var(m->value, id);
    if(!id->misc->ssi_variables)
      id->misc->ssi_variables = ([]);
    id->misc->ssi_variables[m->var] = m->value;
  }
  return "";
}

array(string) tag_fsize(string tag, mapping m, RequestID id)
{
  array s;
  if(m->virtual) {
    m->virtual=fix_var(http_decode_string(m->virtual), id);
    s=id->conf->stat_file(m->virtual);
  }

  if(m->file) {
    m->file=replace(fix_var(m->file, id), "../", "");
    s=id->conf->stat_file(m->file);
  }

  if(!s) return ({ id->misc->ssi_errmsg||"No such file." });

  CACHE(5);

  if(tag == "!--#fsize") {
    if(id->misc->ssi_sizefmt=="bytes")
      return ({ (string)s[1] });
    return ({ sizetostring(s[1]) });
  }

  return ({ strftime(id->misc->ssi_timefmt || "%c", s[3]) });
}

string|array(string) tag_exec(string tag, mapping m, RequestID id)
{
  if(m->cgi) {
    if(m->cache)
      CACHE((int)m->cache);
    else
      NOCACHE();
    return API_read_file(id, http_decode_string(fix_var(m->cgi, id)))||"";
  }

  if(m->cmd)
  {
    if(QUERY(exec))
    {
      string user="Unknown";
      if(id->auth && id->auth[0])
	user=id->auth[1];
      string addr=id->remoteaddr || "Internal";
      NOCACHE();
      return popen(fix_var(m->cmd, id),
		   getenv()
		   | build_roxen_env_vars(id)
		   | build_env_vars(id->not_query, id, 0),
		   QUERY(execuid) || -2, QUERY(execgid) || -2);
    }
    else
      return ({ id->misc->ssi_errmsg||"Execute command support disabled." });
  }
  return ({ id->misc->ssi_errmsg||"No arguments given." });
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
