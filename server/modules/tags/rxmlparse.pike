// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.
//
// The main RXML parser. If this module is not added to a configuration,
// no RXML parsing will be done at all for .html files.
//

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

constant cvs_version="$Id: rxmlparse.pike,v 1.30 1999/11/15 16:10:31 nilsson Exp $";
constant thread_safe=1;
constant language = roxen->language;

#include <config.h>
#include <module.h>

inherit "module";
inherit "roxenlib";

int bytes;  // Holds the number of bytes parsed

// ------------- Module registration and configuration. ---------------

string status()
{
  return (bytes/1024 + " Kb parsed.<br>");
}

void create(object c)
{
  defvar("toparse", ({ "rxml","spml", "html", "htm" }), "Extensions to parse",
	 TYPE_STRING_LIST, "Parse all files ending with these extensions. "
	 "Note: This module must be reloaded for a change here to take "
	 "effect.");

  defvar("require_exec", 0, "Require exec bit on files for parsing",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files has to have the execute bit (any of them) set "
	 "in order for them to be parsed by this module. The exec bit "
	 "is the one that is set by 'chmod +x filename'");

  defvar("parse_exec", 1, "Parse files with exec bit",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files with the exec bit set will be parsed. If not set, "
	 "and the 'Require exec bit on files for parsing' flag is set, no "
	 "parsing will occur.");

  defvar("max_parse", 100, "Maximum file size", TYPE_INT|VAR_MORE,
	 "Maximum file size to parse, in Kilo Bytes.");
}


void start(int q, object c)
{
  define_API_functions();
}

array register_module()
{
  return ({ MODULE_FILE_EXTENSION|MODULE_PARSER,
	    "RXML 1.4 parser",
	    "This module handles rxml parsing of HTML pages. It is recommended to also "
            "add the \"RXML 1.4 tags\" module so that this modules gets some tags to parse. "
            "Some bare bones logic tags are already provided by this module (case, cond, "
            "comment, define, elif, else, elseif, false, for, foreach, help, if, "
            "line, list-tags, nooutput, noparse, number, strlen, then, "
            "trace, true, undefine and use)."
            , 0, 1 });
}

array(string) query_file_extensions()
{
  return query("toparse");
}

// ------------------- RXML Parsing -------------------

mapping handle_file_extension(object file, string e, object id)
{
  string to_parse;

  array stat;
  if(id->misc->defines)
    stat=_stat;
  else {
    id->misc+=(["defines":([" _ok":1])]);
    stat=_stat=id->misc->stat || file->stat();
  }

  if(QUERY(require_exec) && !(stat[0] & 07111)) return 0;
  if(!QUERY(parse_exec) && (stat[0] & 07111)) return 0;

  bytes += strlen(to_parse = file->read());

  return http_rxml_answer( to_parse, id, file, id->conf->type_from_filename(id->realfile) );
}

array(string) tag_version() { return ({ roxen.version() }); }


// ------------- Define the API functions --------------

string api_configurl(string f, mapping m) { return roxen->config_url(); }

string api_parse_rxml(object id, string r)
{
  return parse_rxml( r, id );
}

string api_tagtime(object id, int ti, string t, string l)
{
  mapping m = ([ "type":t, "lang":l ]);
  NOCACHE();
  return tagtime( ti, m, id, language );
}

string api_relative(object id, string path)
{
  return fix_relative( path, id );
}

string api_set(object id, string what, string to)
{
  if (id->variables[ what ])
    id->variables[ what ] += to;
  else
    id->variables[ what ] = to;
  return ([])[0];
}

string api_define(object id, string what, string to)
{
  id->misc->defines[what]=to;
  return ([])[0];
}

string api_query_define(object id, string what)
{
  return id->misc->defines[what];
}

string api_query_variable(object id, string what)
{
  return id->variables[what];
}

string api_query_cookie(object id, string f)
{
  return id->cookies[f];
}

void api_add_header(object id, string h, string v)
{
  add_http_header(_extra_heads, h, v);
}

int api_set_cookie(object id, string c, string v, void|string p)
{
  if(!c)
    return 0;

  add_http_header(_extra_heads, "Set-Cookie",
    c+"="+http_encode_cookie(v||"")+
    "; expires="+http_date(time(1)+(3600*24*365*2))+
    "; path=" +(p||"/")
  );

  return 1;
}

int api_remove_cookie(object id, string c, string v)
{
  if(!c)
    return 0;

  add_http_header(_extra_heads, "Set-Cookie",
    c+"="+http_encode_cookie(v||"")+"; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/"
  );

  return 1;
}

int api_prestate(object id, string p)
{
  return id->prestate[p];
}

int api_set_prestate(object id, string p)
{
  return id->prestate[p]=1;
}

int api_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p];
}

int api_set_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p]=1;
}

int api_set_return_code(object id, int c, void|string p)
{
  if(c) _error=c;
  if(p) _rettext=p;
  return 1;
}

string api_get_referer(object id)
{
  NOCACHE();
  if(id->referer && sizeof(id->referer)) return id->referer*"";
  return "";
}

string api_html_quote(object id, string what)
{
  return html_encode_string(what);
}

string api_html_dequote(object id, string what)
{
  return html_decode_string(what);
}

string api_html_quote_attr(object id, string value)
{
  return sprintf("\"%s\"", replace(value, "\"", "&quot;"));
}

void add_api_function( string name, function f, void|array(string) types)
{
  if(this_object()["_api_functions"])
    this_object()["_api_functions"][name] = ({ f, types });
}

string api_read_file(object id, string file) {
  return API_read_file(id,file)||rxml_error("insert", "No such file ("+file+").", id);
}


// Variables after 0 are optional.
void define_API_functions()
{
  add_api_function("parse_rxml", api_parse_rxml, ({ "string" }));
  add_api_function("tag_time", api_tagtime, ({ "int", 0,"string", "string" }));
  add_api_function("fix_relative", api_relative, ({ "string" }));
  add_api_function("set_variable", api_set, ({ "string", "string" }));
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

  add_api_function("roxen_version", tag_version, ({}));
  add_api_function("config_url", api_configurl, ({}));
}
