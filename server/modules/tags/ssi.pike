// This is a roxen module. Copyright © 2000, Roxen IS.
//

inherit "module";
#include <module.h>

constant thread_safe=1;
constant cvs_version = "$Id: ssi.pike,v 1.31 2000/07/02 16:59:40 nilsson Exp $";


constant module_type = MODULE_PARSER;
constant module_name = "SSI support";
constant module_doc  = 
#"Provides support for the SSI standard tags.";

void create() {

  defvar("exec", 0, "Execute command",
	 TYPE_FLAG,
	 "If set, it will be possible to use the "
	 "&lt;!--#exec cmd=\"XXX\" --&gt; tag to execute arbitrary commands "
	 "from any web page." );

#if constant(getpwnam)
  array nobody = getpwnam("nobody") || ({ "nobody", "x", 65534, 65534 });
#else /* !constant(getpwnam) */
  array nobody = ({ "nobody", "x", 65534, 65534 });
#endif /* constant(getpwnam) */

  defvar("execuid", nobody[2] || 65534, "Execute command uid",
	 TYPE_INT,
	 "UID to run the &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands as.");

  defvar("execgid", nobody[3] || 65534, "Execute command gid",
	 TYPE_INT,
	 "GID to run the &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands as.");
}

void start(int num, Configuration conf) {
  module_dependencies (conf, ({ "rxmltags" }));
  query_tag_set()->prepare_context=set_entities;
}

class ScopeSSI {
  inherit RXML.Scope;
  function get_var;

  void create(function _get_var) {
    get_var=_get_var;
  }

  string|int `[] (string var, void|RXML.Context c, void|string scope) {
    return get_var(var, c->id)||"";
  }

  array(string) _indices(void|RXML.Context c) {
    array ind=({ "sizefmt", "errmsg", "timefmt", "date_local", "date_gmt",
		 "document_name", "document_uri", "query_string_unescaped",
		 "last_modified", "server_software", "server_name",
		 "gateway_interface", "server_protocol", "auth_type",
		 "http_cookie", "cookie" });
    if(c->id) {
      ind += indices(Roxen.build_env_vars(0, c->id, 0));
      if(c->id->misc->ssi_variables) ind += indices(c->id->misc->ssi_variables);
    }
    return ind;
  }
}

RXML.Scope scope_ssi=ScopeSSI(get_var);
void set_entities(RXML.Context c) {
  c->extend_scope("ssi", scope_ssi);
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"!--#config":#"<desc tag><short>
 The config command is used to configure how things should be printed.</short>
</desc>

<attr name=errmsg value=string>
 Where msg is a message that is sent back to the client if an error
 occurs while parsing the SSI-tag.
</attr>

<attr name=sizefmt value=bytes|abbrev>
 The value sets the format to be used when displaying the size of a
 file. Bytes gives a count in bytes while abbrev gives a count in KB
 or MB, as appropriate.
</attr>

<attr name=timefmt value=value>
 The value is a string to be used when displaying SSI date output.
</attr>",

"!--#echo":#"
<desc tag><short>
 Prints a variable from the server or request.</short>

 <p>Some of the most useful ones are \"http referrer\" (the page
 which contained the link to the current page), \"last modified\"
 (date of the file for this document), \"remote user\" (name of the
 user), and \"remote addr\" (IP number of the user/client
 machine).</p>

 <p>Note that these variables are SSI-related. You cannot access them
 as RXML variables, nor use this tag to print RXML variables.</p>
</desc>

<attr name=var value=sizefmt>
 Print format for file sizes.
</attr>

<attr name=var value='document name'>
 Name of the current document (= page). RXML counterpart: &amp;page.self;
 <ex type=vert><!--#echo var=\"document name\" --></ex>
</attr>

<attr name=var value='document uri'>
 URI (URL) to the current page. RXML counterpart: &amp;page.url;
 <ex type=vert><!--#echo var=\"document uri\" --></ex>
</attr>

<attr name=var value='date local'>
 Time and date, in current time zone.
 RXML counterpart: &lt;date strftime=\"%c\"/&gt;
</attr>

<attr name=var value='date gmt'>
 Time and date, GMT time zone.
 RXML counterpart: &lt;date timezone=\"GMT\" strftime=\"%c\"/&gt;
</attr>

<attr name=var value='last modified'>
 Last time this document was modified. RXML counterpart: &lt;modified/&gt;
</attr>

<attr name=var value='server software'>
 The web server software. RXML counterpart: &amp;roxen.version;
</attr>

<attr name=var value='server name'>
 The web server name. RXML counterpart: &amp;roxen.domain;
</attr>

<attr name=var value='remote host'>
 Name of client machine. RXML counterpart: &amp;client.host;
</attr>

<attr name=var value='remote addr'>
 Numeric IP address of client machine. RXML counterpart: &amp;client.ip;
</attr>

<attr name=var value='auth type'>
 Authentication type (typically Basic)
</attr>

<attr name=var value='remote user'>
 Client user name
</attr>

<attr name=var value='http referrer'>
 URL of the referring page. RXML counterpart: &amp;client.referrer;
</attr>

<attr name=var value='gateway interface'>
 Answears \"CGI/1.1\".
</attr>

<attr name=var value='http cookie'>
 A list of the set cookies.
 <ex type=vert><!--#echo var=\"http cookie\" --></ex>
</attr>

<attr name=var value=cookie>
 A list of the set cookies. Same as http cookie.
</attr>

<attr name=var value='http accept'>
 A list of the http accept formats.
 <ex type=vert><!--#echo var=\"http accept\" --></ex>
</attr>

<attr name=var value='http user agent'>
 The user agent string. RXML counterpart: &amp;client.Fullname;
</attr>

<attr name=var value='path translated'>
 Translated path.
</attr>

<attr name=var value='query string unescaped'>
 The query string.
</attr>

<attr name=var value='request method'>
 Request method (typically GET)
</attr>

<attr name=var value='server protocol'>
 Protocol used for request.
</attr>

<attr name=var value='server port'>
 Server's port number
</attr>",

"!--#exec":#"
<desc tag><short>
 Executes a CGI script or shell command.</short> This command has security
 implications and therefore, might not be available on all web sites.

</desc>

<attr name=cgi value=URL> Path to the CGI script URL encoded. That is,
 a character can be quoted by % followed by its hex value. The CGI
 script is given the PATH_INFO and QUERY_STRING of the original
 request from the client. The variables available in
 <tag>!--#echo</tag> will be available to the script in addition to
 the standard CGI environment. If the script returns a Location
 header, then this will be translated into an HTML anchor.
</attr>

<attr name=cmd value=path>
 The server will execute the command using /bin/sh. The variables
 available in <tag>!--#echo</tag> will be available to the script.
</attr>",

"!--#flastmod":#"
<desc tag><short hide>
 This tag prints the last modification date of the specified file,
 subject to timefmt format specification used in the <!--#config> SSI
 tag.</short> This tag prints the last modification date of the
 specified file, subject to timefmt format specification used in the
 <ref type=tag>!--#config</ref> SSI tag. </desc>

<attr name=file value=path>
 Path to the file.
</attr>

<attr name=virtual value=URL>
 Path to the file URL encoded. That is, a character can be quoted by %
 followed by its hex value.
</attr>",

"!--#fsize":#"
<desc tag><short hide>

 Prints the size of the specified file, subject to the sizefmt format
 specification used in the <!--#config> SSI tag. </short>Prints the
 size of the specified file, subject to the sizefmt format
 specification used in the <ref type=tag>!--#config</ref> SSI tag.
 </desc>

<attr name=file value=path>
 Path to the file.
</attr>

<attr name=virtual value=URL>
 Path to the file URL encoded. That is, a character can be quoted by %
 followed by its hex value.
</attr>",

"!--#include":#"
<desc tag><short>
 Insert a text from another file into the page.</short>
</desc>

<attr name=file value=path>
 The file as a path relative to the directory containing the current
 page. It cannot contain ../, nor can it be an absolute path.
</attr>

<attr name=virtual value=URL>
 The path to the file, URL encoded. That is, a character can be quoted
 by % followed by its hex value. The path may contain ../ and may be
 absolute, i e starting with a /
</attr>",

"!--#printenv":#"
<desc tag><short>
 This tag outputs a listing of all existing variables and their
 values.</short> Attributes won't be printed.
 <ex type=vert><pre><!--#printenv --></pre></ex>
</desc>",

"!--#set":#"<desc tag><short>
 Sets a value of a variable.</short>
</desc>

<attr name=var value=value>
 The name of the variable to set. Value sets the variables value.
</attr>",
]);
#endif

function _modified;
string modified(mapping m, RequestID id) {
  if(_modified) return _modified("modified", m, id);
  _modified=id->conf->get_provider("modified")->tag_modified;
  return _modified("modified", m, id);
}

array(string) simpletag_echo(string tag, mapping m, string c, RequestID id)
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
    return Roxen.strftime(id->misc->ssi_timefmt || "%c", time(1));

   case "date_gmt":
    NOCACHE();
    return Roxen.strftime(id->misc->ssi_timefmt || "%c", time(1) + localtime(time(1))->timezone);

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
    string tmp=id->conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    return tmp;

   case "gateway_interface":
    return "CGI/1.1";

   case "server_protocol":
    return "HTTP/1.0";

   case "auth_type":
    return "Basic";

   case "http_cookie": case "cookie":
    NOCACHE();
    return Roxen.html_encode_string(id->misc->cookies || "");

   default:
    var = upper_case(var);
    mapping myenv = Roxen.build_env_vars(0, id, 0);
    if(myenv[var]) {
      NOCACHE();
      return myenv[var];
    }
  }
  return 0;
}

array(string) simpletag_printenv(string t, mapping m, string c, RequestID id) {
  string res="";
  NOCACHE();
  if(id->misc->ssi_variables)
    foreach(indices(id->misc->ssi_variables), string var)
      res+=var+" = "+id->misc->ssi_variables[var]+"\n";

  foreach(({"sizefmt","errmsg","timefmt","date_local","date_gmt",
	    "document_name","document_uri","query_string_unescaped",
	    "last_modified","server_software","server_name",
	    "gateway_interface","server_protocol","request_method",
	    "auth_type","http_cookie","cookie","http_accept",
	    "http_user_agent","http_referer"}), string var)
    res+=var+" = "+get_var(var,id)+"\n";

  mapping myenv =  Roxen.build_env_vars(0, id, 0);
  foreach(indices(myenv), string var)
    res+=var+" = "+myenv[var]+"\n";

  return ({res});
}

string fix_var(string s, RequestID id) {
  s=replace(s||"",({"\000","\\$"}),({"","\000"}));
  int size=sizeof(s);
  if(size>2 && s[size-2..]=="--") s=s[..size-3];
  if(s[0]=='$' && s[1]!='{') return get_var(s[1..], id)||"";
  return s; //FIXME: No in-string-substitution yet.
}

array(string) simpletag_config(string tag, mapping m, string c, RequestID id)
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

string|array(string) simpletag_include(string tag, mapping m, string c, RequestID id)
{
  if(!m->virtual && !m->file)
    return ({ id->misc->ssi_errmsg||"Hm? #include what, my dear?" });

  if(!m->file) m->file=http_decode_string(m->virtual);

  m->file=fix_var(m->file, id);
  string ret=id->conf->try_get_file(Roxen.fix_relative(m->file,id),id);
  if(!ret) return ({ id->misc->ssi_errmsg||"No such file ("+m->file+")." });
  return ret;
}

string simpletag_set(string tag, mapping m, string c, RequestID id)
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

array(string) simpletag_fsize(string tag, mapping m, string c, RequestID id)
{
  if(!m->virtual && !m->file)
    return ({ id->misc->ssi_errmsg||"No file given." });

  if(!m->file) m->file=http_decode_string(m->virtual);

  m->file=fix_var(m->file, id);
  array s=id->conf->stat_file(m->file, id);
  if(!s) return ({ id->misc->ssi_errmsg||"No such file ("+m->file+")." });

  CACHE(5);

  if(tag == "!--#fsize") {
    if(id->misc->ssi_sizefmt=="bytes")
      return ({ (string)s[1] });
    return ({ Roxen.sizetostring(s[1]) });
  }

  return ({ Roxen.strftime(id->misc->ssi_timefmt || "%c", s[3]) });
}

string|array(string) simpletag_exec(string tag, mapping m, string c, RequestID id)
{
  if(m->cgi) {
    if(m->cache)
      CACHE((int)m->cache);
    else
      NOCACHE();
    return id->conf->try_get_file
      (Roxen.fix_relative( http_decode_string(fix_var(m->cgi,id)) , id),id)||"";
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
		   | Roxen.build_roxen_env_vars(id)
		   | Roxen.build_env_vars(id->not_query, id, 0),
		   QUERY(execuid) || -2, QUERY(execgid) || -2);
    }
    else
      return ({ id->misc->ssi_errmsg||"Execute command support disabled." });
  }
  return ({ id->misc->ssi_errmsg||"No arguments given." });
}

mapping query_simpletag_callers()
{
  int flags = RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_COMPAT_PARSE;
  return ([
    "!--#echo": ({flags, simpletag_echo}),
    "!--#exec": ({flags, simpletag_exec}),
    "!--#flastmod": ({flags, simpletag_fsize}),
    "!--#fsize": ({flags, simpletag_fsize}),
    "!--#set": ({flags, simpletag_set}),
    "!--#include": ({flags, simpletag_include}),
    "!--#config": ({flags, simpletag_config}),
    "!--#printenv": ({flags, simpletag_printenv}),
    "!--#printenv--": ({flags, simpletag_printenv})
  ]);
}
