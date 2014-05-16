// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
//
// The main RXML parser. If this module is not added to a configuration,
// no RXML parsing will be done at all for .html files.
//

//This can be turned on when types in dumped files are working properly.
//#pragma strict_types

#define CTX_MISC ([mapping(string:mixed)] RXML_CONTEXT->misc)

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant language = roxen->language;

#include <config.h>
#include <module.h>
#include <request_trace.h>

inherit "module";


// ------------- Module registration and configuration. ---------------

constant module_type = MODULE_FILE_EXTENSION;
constant module_name = "Tags: RXML parser";
constant module_doc  = 
#"This module handles RXML parsing of pages. Other modules can provide
additional tags that will be parsed. Most common RXML tags are
provided by the <i>RXML tags</i> module.";

string status()
{
  return (bytes/1024 + " Kb parsed.<br />");
}

void create()
{
  defvar("toparse", ({ "html", "htm", "rxml" }), "Extensions to parse",
	 TYPE_STRING_LIST|VAR_NOT_CFIF, 
         "Files with these extensions will be parsed. "
	 "Note: This module must be reloaded before a change to this "
	 "setting take effect.");

  defvar("require_exec", 0, "Require exec bit to parse",
	 TYPE_FLAG|VAR_MORE|VAR_NOT_CFIF,
	 "If enabled, files has to have a execute bit (any of them) set "
	 "to be parsed. The exec bit is the one set by "
	 "<tt>chmod +x filename</tt>");

  defvar("parse_exec", 1, "Parse files with exec bit",
	 TYPE_FLAG|VAR_MORE|VAR_NOT_CFIF,
	 "If enabled, files with the exec bit set will be parsed. If disabled "
	 "and the <i>Require exec bit to parse</i> option is enabled, no "
	 "parsing will occur.");

  defvar ("ram_cache_pages", 1, "RAM cache RXML pages",
	  TYPE_FLAG, #"\
The RXML parser will cache the parse trees (known as \"p-code\") for
the RXML pages in RAM when this is enabled, which speeds up the
evaluation of them.");

  defvar ("censor_request", 0, "Security:Censor sensitive data",
	  TYPE_FLAG, #"\
<p>If this is set, some sensitive data is removed from the incoming
requests before RXML evaluation begins. Specifically, any
authorization data derived from the Authorization or
Proxy-Authorization http headers is removed. A notable effect is that
the RXML variable &amp;client.password; will not reveal the real
password, but it won't be possible to recover the authorization data
any other way either.</p>

<p>Note that this setting only affects the authorization headers as
described above. A web application might have other places, e.g.
cookies or form variables, where potentially sensitive data gets
stored.</p>");

  defvar("logerrorsp", 0, "RXML Errors:Log RXML parse errors", TYPE_FLAG,
	 "If enabled, all RXML parse errors will be logged in the debug log.");

  defvar("logerrorsr", 1, "RXML Errors:Log RXML run errors", TYPE_FLAG,
	 "If enabled, all RXML run errors will be logged in the debug log.");

  defvar("quietp", 0, "RXML Errors:Quiet RXML parse errors", TYPE_FLAG,
	 "If enabled, RXML parse errors will not be shown in a page unless "
	 "debug has been turned on with <tt>&lt;debug on&gt;</tt> or with "
	 "the <i>debug</i> prestate.");

  defvar("quietr", 1, "RXML Errors:Quiet RXML run errors", TYPE_FLAG,
	 "If enabled, RXML run errors will not be shown in a page unless "
	 "debug has been turned on with <tt>&lt;debug on&gt;</tt> or with "
	 "the <i>debug</i> prestate.");
}


void start(int q, Configuration c)
{
  file2type=c->type_from_filename;
  define_API_functions();
  require_exec=[int]query("require_exec");
  parse_exec=[int]query("parse_exec");
  ram_cache_name = query ("ram_cache_pages") && "p-code:" + c->name;
  c->rxml_tag_set->handle_run_error = rxml_run_error;
  c->rxml_tag_set->handle_parse_error = rxml_parse_error;
  c->rxml_tag_set->censor_request = query ("censor_request");
}

array(string) query_file_extensions()
{
  return [array(string)]query("toparse");
}


// ------------------- RXML Parsing -------------------

int require_exec, parse_exec;
int bytes;  // Holds the number of bytes parsed
int ram_cache_pages;
string ram_cache_name;
function(string,int|void,string|void:string) file2type;

mapping handle_file_extension(Stdio.File file, string e, RequestID id)
{
  Stdio.Stat stat = id->misc->stat || file->stat();

  if(require_exec && !(stat[0] & 07111)) return 0;
  if(!parse_exec && (stat[0] & 07111)) return 0;

  bytes += stat[1];

  string data = file->read();
  switch( id->misc->input_charset )
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
     data = (Locale.Charset.decoder( [string]id->misc->input_charset )
	     ->feed( data )
	     ->drain());
     break;
  }

  RXML.Context context;
  string rxml;
#ifdef MAY_OVERRIDE_RXML_PARSING
  if(id->prestate->norxml)
    rxml = data;
  else
#endif
  {
  eval_rxml:
    if (ram_cache_name) {
      array cache_ent;
      if ((cache_ent = cache_lookup (ram_cache_name, id->not_query)) &&
	  cache_ent[0] == stat[ST_MTIME]) {
	TRACE_ENTER (sprintf ("Evaluating RXML page %O from RAM cache",
			      id->not_query), this_object());
	if (cache_ent[1]->is_stale()) {
	  cache_remove (ram_cache_name, id->not_query);
	  TRACE_LEAVE ("RAM cache entry was stale");
	}
	else {
	  context = cache_ent[1]->new_context (id);
	  rxml = cache_ent[1]->eval (context);
	  id->cache_status["pcoderam"] = 1;
	  break eval_rxml;
	}
      }
      TRACE_ENTER (sprintf ("Evaluating and compiling RXML page %O",
			    id->not_query), this_object());
      RXML.Parser parser = Roxen.get_rxml_parser (id, 0, 1);
      context = parser->context;
      parser->write_end (data);
      rxml = parser->eval();
      RXML.PCode p_code = parser->p_code;
      p_code->finish();
      cache_set (ram_cache_name, id->not_query, ({stat[ST_MTIME], p_code}));
    }
    else {
      TRACE_ENTER (sprintf ("Evaluating RXML page %O",
			    id->not_query), this_object());
      RXML.Parser parser = Roxen.get_rxml_parser (id);
      context = parser->context;
      parser->write_end (data);
      rxml = parser->eval();
    }
  }
  TRACE_LEAVE ("");

  return (["data":rxml,
	   "type": file2type((id->realfile
			      || id->no_query
			      || "index.html"),
			     0, e) || "text/html",
	   "stat":context->misc[" _stat"],
	   "error":context->misc[" _error"],
	   "rettext":context->misc[" _rettext"],
	   "extra_heads":context->misc[" _extra_heads"],
	   ]);
}


// ------------------ Error handling -------------------

function _run_error;
string rxml_run_error(RXML.Backtrace err, RXML.Type type)
// This is used to report thrown RXML run errors. See
// RXML.run_error().
{
  RXML.Context ctx = RXML.get_context();
  RequestID id = ctx->id;

  if(id->conf->get_provider("RXMLRunError")) {
    if(!_run_error)
      _run_error=id->conf->get_provider("RXMLRunError")->rxml_run_error;
    string res=_run_error(err, type, id);
    if(res) return res;
  }
  else
    _run_error=0;

#ifdef VERBOSE_RXML_ERRORS
  report_notice ("Error in %s.\n%s",
		 id->raw_url || id->not_query || "UNKNOWN",
		 describe_backtrace (err));
#else
  if(query("logerrorsr"))
    report_notice ("Error in %s.\n%s",
		   id->raw_url || id->not_query || "UNKNOWN",
		   describe_error (err));
#endif

  NOCACHE();
  ctx->misc[" _ok"]=0;		// Unnecessary unless in < 5.0 compat mode.
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml) ||
      type->subtype_of (RXML.t_text)) {
    if(query("quietr") && !id->misc->debug)
      return "";
    if (type->subtype_of (RXML.t_text))
      return "\n" + describe_error (err) + "\n";
    else
      return "<br clear=\"all\" />\n<pre>" +
	Roxen.html_encode_string (describe_error (err)) + "</pre>\n";
  }
  return 0;
}

function _parse_error;
string rxml_parse_error(RXML.Backtrace err, RXML.Type type)
// This is used to report thrown RXML parse errors. See
// RXML.parse_error().
{
  RequestID id = RXML.get_context()->id;

  if(id->conf->get_provider("RXMLParseError")) {
    if(!_parse_error)
      _parse_error=id->conf->get_provider("RXMLParseError")->rxml_parse_error;
    string res=_parse_error(err, type, id);
    if(res) return res;
  }
  else
    _parse_error=0;

#ifdef VERBOSE_RXML_ERRORS
  report_notice ("Error in %s.\n%s",
		 id->raw_url || id->not_query || "UNKNOWN",
		 describe_backtrace (err));
#else
  if(query("logerrorsp"))
    report_notice ("Error in %s.\n%s",
		   id->raw_url || id->not_query || "UNKNOWN",
		   describe_error (err));
#endif

  NOCACHE();
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml) ||
      type->subtype_of (RXML.t_text)) {
    if(query("quietp") && !id->misc->debug)
      return "";
    if (type->subtype_of (RXML.t_text))
      return "\n" + describe_error (err) + "\n";
    else
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
  CTX_MISC[what]=to;
  return ([])[0];
}

string api_query_define(RequestID id, string what)
{
  return (string)CTX_MISC[what];
}

string api_query_variable(RequestID id, string what, void|string scope)
{
  return (string)RXML.get_context()->user_get_var(what, scope);
}

string api_query_cookie(RequestID id, string f)
{
  return id->cookies[f];
}

void api_add_header(RequestID id, string h, string v)
{
  id->add_response_header(h, v);
}

int api_set_cookie(RequestID id, string c, string v, void|string p)
{
  if(!c) return 0;
  Roxen.set_cookie(id, c, v, 3600*24*365*2, 0, p);
  return 1;
}

int api_remove_cookie(RequestID id, string c, string v)
{
  if(!c) return 0;
  Roxen.remove_cookie(id, c, v);
  return 1;
}

int api_prestate(RequestID id, string p)
{
  return id->prestate[p];
}

int api_set_prestate(RequestID id, string p)
{
  return id->prestate[p]=1;
}

int api_supports(RequestID id, string p)
{
  NOCACHE();
  return id->supports[p];
}

int api_set_supports(RequestID id, string p)
{
  NOCACHE();
  return id->supports[p]=1;
}

int api_set_return_code(RequestID id, int c, void|string p)
{
  if (RXML.Context ctx = RXML_CONTEXT) {
    if(c) ctx->set_misc (" _error", c);
    if(p) ctx->set_misc (" _rettext", p);
  }
  return 1;
}

string api_get_referer(RequestID id)
{
  NOCACHE();
  if(id->referer && sizeof(id->referer))
    return id->referer*"";
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
