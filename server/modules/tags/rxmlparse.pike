// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.
//
// The main RXML parser. If this module is not added to a configuration,
// no RXML parsing will be done at all for .html files.
//

//This can be turned on when types in dumped files are working properly.
//#pragma strict_types

#define _misc ([mapping(string:mixed)]id->misc)
#define _defines ([mapping(string:mixed)]_misc->defines)
#define _stat _defines[" _stat"]
#define _error _defines[" _error"]
#define _extra_heads _defines[" _extra_heads"]
#define _rettext _defines[" _rettext"]
#define _ok _defines[" _ok"]

constant cvs_version="$Id: rxmlparse.pike,v 1.48 2000/08/28 06:51:28 per Exp $";
constant thread_safe=1;
constant language = roxen->language;

#include <config.h>
#include <module.h>

inherit "module";


// ------------- Module registration and configuration. ---------------

constant module_type = MODULE_FILE_EXTENSION | MODULE_PROVIDER;
constant module_name = "RXML 2.0 parser";
constant module_doc  = 
#"This module handles RXML parsing of pages. Other modules can provide 
additional tags that will be parsed. Most common RXML tags is provided by
the <i>RXML 2.0 tags</i> module. This module provide some fundamental tags; 
<tt>&lt;case&gt;</tt>, <tt>&lt;cond&gt;</tt>, <tt>&lt;comment&gt;</tt>, 
<tt>&lt;define&gt;</tt>, <tt>&lt;elif&gt;</tt>, <tt>&lt;else&gt;</tt>, 
<tt>&lt;elseif&gt;</tt>, <tt>&lt;emit&gt;</tt>, <tt>&lt;eval&gt;</tt>, 
<tt>&lt;false&gt;</tt>, <tt>&lt;help&gt;</tt>, <tt>&lt;if&gt;</tt>, 
<tt>&lt;nooutput&gt;</tt>, <tt>&lt;noparse&gt;</tt>, <tt>&lt;number&gt;</tt>, 
<tt>&lt;strlen&gt;</tt>, <tt>&lt;then&gt;</tt>, <tt>&lt;trace&gt;</tt>, 
<tt>&lt;true&gt;</tt>, <tt>&lt;undefine&gt;</tt> and <tt>&lt;use&gt;</tt>.";

string status()
{
  return (bytes/1024 + " Kb parsed.<br />");
}

void create()
{
  defvar("toparse", ({ "html", "htm", "rxml" }), "Extensions to parse",
	 TYPE_STRING_LIST, "Files with these extensions will be parsed. "
	 "Note: This module must be reloaded before a change to this "
	 "setting take effect.");

  defvar("require_exec", 0, "Require exec bit to parse",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files has to have a execute bit (any of them) set "
	 "to be parsed. The exec bit is the one set by "
	 "<tt>chmod +x filename</tt>");

  defvar("parse_exec", 1, "Parse files with exec bit",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files with the exec bit set will be parsed. If not set "
	 "and the <i>Require exec bit to parse</i> option is set, no "
	 "parsing will occur.");

  defvar("logerrorsp", 0, "RXML Errors:Log RXML parse errors", TYPE_FLAG,
	 "If set, all RXML parse errors will be logged in the debug log.");

  defvar("logerrorsr", 1, "RXML Errors:Log RXML run errors", TYPE_FLAG,
	 "If set, all RXML run errors will be logged in the debug log.");

  defvar("quietp", 0, "RXML Errors:Quiet RXML parse errors", TYPE_FLAG,
	 "If set, RXML parse errors will not be shown in a page unless "
	 "debug has been turned on with <tt>&lt;debug on&gt;</tt> or with "
	 "the <i>debug</i> prestate.");

  defvar("quietr", 1, "RXML Errors:Quiet RXML run errors", TYPE_FLAG,
	 "If set, RXML run errors will not be shown in a page unless "
	 "debug has been turned on with <tt>&lt;debug on&gt;</tt> or with "
	 "the <i>debug</i> prestate.");
}


void start(int q, Configuration c)
{
  file2type=c->type_from_filename;
  define_API_functions();
  require_exec=[int]query("require_exec");
  parse_exec=[int]query("parse_exec");
}

array(string) query_file_extensions()
{
  return [array(string)]query("toparse");
}

multiset query_provides() { return (< "RXMLRunError", "RXMLParseError" >); }


// ------------------- RXML Parsing -------------------

int require_exec, parse_exec;
int bytes;  // Holds the number of bytes parsed
function(string:string) file2type;

mapping handle_file_extension(Stdio.File file, string e, RequestID id)
{
  if(!_misc->defines)
    _misc->defines=([" _ok":1]);

  array stat;
  if(_stat)
    stat=[array]_stat;
  else
    stat=_stat=[array]_misc->stat || file->stat();

  if(require_exec && !(stat[0] & 07111)) return 0;
  if(!parse_exec && (stat[0] & 07111)) return 0;

  bytes += stat[1];

  string data = file->read();
  switch( _misc->input_charset )
  {
   case 0:
   case "iso-8859-1":
     break;
   case "utf-8":
     data = utf8_to_string( data );
     break;
   case "unicode":
     data = unicode_to_string( data );
     break;
   default:
     data = [string] (Locale.Charset.decoder( [string]_misc->input_charset )
		      ->feed( data )
		      ->drain());
     break;
  }

  return Roxen.http_rxml_answer(data, id, file,
				file2type([string](id->realfile || id->no_query || "index.html")) );
}


// ------------------ Error handling -------------------

string rxml_run_error(RXML.Backtrace err, RXML.Type type, RequestID id) {
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml)) {
    if(query("logerrorsr"))
      report_notice ("Error in %s.\n%s", id->raw_url, describe_error (err));
    _ok=0;
    if(query("quietr") && !_misc->debug && !([multiset(string)]id->prestate)->debug)
      return "";
    return "<br clear=\"all\" />\n<pre>" +
      Roxen.html_encode_string (describe_error (err)) + "</pre>\n";
  }
  return 0;
}

string rxml_parse_error(RXML.Backtrace err, RXML.Type type, RequestID id) {
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml)) {
    if(query("logerrorsp"))
      report_notice ("Error in %s.\n%s", id->raw_url, describe_error (err));
    if(query("quietp") && !_misc->debug && !([multiset(string)]id->prestate)->debug)
      return "";
    return "<br clear=\"all\" />\n<pre>" +
      Roxen.html_encode_string (describe_error (err)) + "</pre>\n";
  }
  return 0;
}


// ------------- Define the API functions --------------

string api_parse_rxml(RequestID id, string r)
{
  return Roxen.parse_rxml( r, id );
}

string api_tagtime(RequestID id, int ti, string t, string l)
{
  mapping m = ([ "type":t, "lang":l ]);
  NOCACHE();
  return Roxen.tagtime( ti, m, id, language );
}

string api_relative(RequestID id, string path)
{
  return Roxen.fix_relative( path, id );
}

string api_set(RequestID id, string what, string to, void|string scope)
{
  RXML.get_context()->user_set_var(what, to, scope);
  return ([])[0];
}

string api_define(RequestID id, string what, string to)
{
  _defines[what]=to;
  return ([])[0];
}

string api_query_define(RequestID id, string what)
{
  return (string)_defines[what];
}

string api_query_variable(RequestID id, string what, void|string scope)
{
  return (string)RXML.get_context()->user_get_var(what, scope);
}

string api_query_cookie(RequestID id, string f)
{
  return ([mapping(string:string)]id->cookies)[f];
}

void api_add_header(RequestID id, string h, string v)
{
  Roxen.add_http_header([mapping(string:string)]_extra_heads, h, v);
}

int api_set_cookie(RequestID id, string c, string v, void|string p)
{
  if(!c)
    return 0;

  Roxen.add_http_header([mapping(string:string)]_extra_heads, "Set-Cookie",
    c+"="+Roxen.http_encode_cookie(v||"")+
    "; expires="+Roxen.http_date(time(1)+(3600*24*365*2))+
    "; path=" +(p||"/")
  );

  return 1;
}

int api_remove_cookie(RequestID id, string c, string v)
{
  if(!c)
    return 0;

  Roxen.add_http_header([mapping(string:string)]_extra_heads, "Set-Cookie",
			c+"="+Roxen.http_encode_cookie(v||"")+"; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/"
  );

  return 1;
}

int api_prestate(RequestID id, string p)
{
  return ([multiset(string)]id->prestate)[p];
}

int api_set_prestate(RequestID id, string p)
{
  return ([multiset(string)]id->prestate)[p]=1;
}

int api_supports(RequestID id, string p)
{
  NOCACHE();
  return ([multiset(string)]id->supports)[p];
}

int api_set_supports(RequestID id, string p)
{
  NOCACHE();
  return ([multiset(string)]id->supports)[p]=1;
}

int api_set_return_code(RequestID id, int c, void|string p)
{
  if(c) _error=c;
  if(p) _rettext=p;
  return 1;
}

string api_get_referer(RequestID id)
{
  NOCACHE();
  if([array(string)]id->referer && sizeof([array(string)]id->referer))
    return [array(string)]id->referer*"";
  return "";
}

string api_html_quote(RequestID id, string what)
{
  return Roxen.html_encode_string(what);
}

string api_html_dequote(RequestID id, string what)
{
  return Roxen.html_decode_string(what);
}

string api_html_quote_attr(RequestID id, string value)
{
  return sprintf("\"%s\"", replace(value, "\"", "&quot;"));
}

string api_read_file(RequestID id, string file) {
  return id->conf->try_get_file(Roxen.fix_relative(file,id),id);
}

// void add_api_function(string name, function f, void|array(string) types)
// {
//   if(this_object()["_api_functions"])
//     this_object()["_api_functions"][name] = ({ f, types });
// }


// Variables after 0 are optional.
void define_API_functions()
{
  add_api_function("parse_rxml", api_parse_rxml, ({ "string" }));
  add_api_function("tag_time", api_tagtime, ({ "int", 0,"string", "string" }));
  add_api_function("fix_relative", api_relative, ({ "string" }));
  add_api_function("set_variable", api_set, ({ "string", "string", 0, "string" }));
  add_api_function("define", api_define, ({ "string", "string" }));

  add_api_function("query_define", api_query_define, ({ "string", }));
  add_api_function("query_variable", api_query_variable, ({ "string", }));
  add_api_function("query_cookie", api_query_cookie, ({ "string", }));

  add_api_function("read_file", api_read_file, ({ "string"}));
  add_api_function("add_header", api_add_header, ({"string", "string"}));
  add_api_function("add_cookie", api_set_cookie, ({"string", "string"}));
  add_api_function("remove_cookie", api_remove_cookie, ({"string", "string"}));

  add_api_function("html_quote", api_html_quote, ({"string"}));
  add_api_function("html_dequote", api_html_dequote, ({"string"}));
  add_api_function("html_quote_attr", api_html_quote_attr, ({"string"}));

  add_api_function("prestate", api_prestate, ({"string"}));
  add_api_function("set_prestate", api_set_prestate, ({"string"}));

  add_api_function("supports", api_supports, ({"string"}));
  add_api_function("set_supports", api_set_supports, ({"string"}));

  add_api_function("set_return_code", api_set_return_code, ({ "int", 0, "string" }));
  add_api_function("query_referer", api_get_referer, ({}));

  add_api_function("roxen_version", lambda(){return roxen.version();}, ({}));
}
