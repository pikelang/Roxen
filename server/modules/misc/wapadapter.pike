// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#define _id_misc ([mapping(string:mixed)]id->misc)
#define _context_misc ([mapping(string:mixed)] RXML_CONTEXT->misc)
#define _stat _context_misc[" _stat"]
#define _error _context_misc[" _error"]
//#define _extra_heads _context_misc[" _extra_heads"]
#define _rettext _context_misc[" _rettext"]

inherit "module";

constant thread_safe = 1;
constant cvs_version = "$Id$";

constant module_type = MODULE_FIRST|MODULE_FILE_EXTENSION|MODULE_TAG;
constant module_name = "WAP Adapter";
constant module_doc  = "Improves supports flags and variables as well as "
  "doing a better job finding MIME types than the content type module for WAP clients. "
  "It also defines the tag &lt;wimg&gt; that converts the image to an apropriate format for the client.";

#include <module.h>
#include <request_trace.h>

void create() {

  defvar("extensions", ({ "wml" }), "Extensions to parse", TYPE_STRING_LIST,
	 "Files with these extensions will be RXML parsed in a \"WML context\", i.e. "
	 "all tag output will be WML quoted.");

  defvar ("ram_cache_pages", 1, "RAM cache RXML pages",
	  TYPE_FLAG, #"\
The RXML parser will cache the parse trees (known as \"p-code\") for
the RXML pages in RAM when this is enabled, which speeds up the
evaluation of them.");

}

string ram_cache_name;

void start(int num, Configuration conf) {
  module_dependencies (conf, ({ "cimg" }));
  ram_cache_name = query ("ram_cache_pages") && "p-code:" + conf->name;
  query_tag_set()->prepare_context = set_entities;
}

void set_entities(RXML.Context c) {
  c->extend_scope("client", client_scope + ([]));
}

array(string) query_file_extensions() {
  return [array(string)]query("extensions");
}

// Essentially a copy from rxmlparse.
mapping handle_file_extension(Stdio.File file, string e, RequestID id) {
  array stat = [array]_id_misc->stat || file->stat();

  string data = file->read();
  switch( _id_misc->input_charset )
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
     data = [string] (Charset.decoder( [string]_id_misc->input_charset )
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
      RXML.Parser parser = Roxen.get_rxml_parser (id, type, 1);
      context = parser->context;
      parser->write_end (data);
      rxml = parser->eval();
      RXML.PCode p_code = parser->p_code;
      cache_set (ram_cache_name, id->not_query, ({stat[ST_MTIME], p_code}));
    }
    else {
      TRACE_ENTER (sprintf ("Evaluating RXML page %O",
			    id->not_query), this_object());
      RXML.Parser parser = Roxen.get_rxml_parser (id, type);
      context = parser->context;
      parser->write_end (data);
      rxml = parser->eval();
    }
  }
  TRACE_LEAVE ("");

  return (["data":rxml,
	   "type": "text/vnd.wap.wml",
	   "stat":context->misc[" _stat"],
	   "error":context->misc[" _error"],
	   "rettext":context->misc[" _rettext"],
	   "extra_heads":context->misc[" _extra_heads"],
	   ]);
}

// In the first try method we look at the accept HTTP headers
// and tries to find anything wml-related.
void first_try(RequestID id)
{
  if(!id->request_headers->accept) id->request_headers->accept="";

  if(has_value(id->request_headers->accept,"image/vnd.wap.wbmp") ||
     has_value(id->request_headers->accept,"image/x-wap.wbmp"))
    id->supports->wbmp = 1;

  if(id->supports["wml"]) return;

  if(has_value(id->request_headers->accept,"text/vnd.wap.wml") ||
     has_value(id->request_headers->accept,"application/vnd.wap.wml"))
    id->supports["wml"] = 1;

  // Fallback to WAP 1.1 and WBMP-0 support for unknown clients.
  if(id->supports->unknown) {
    id->supports["wml"] = 1;
    id->supports->wbmp = 1;
  }
}

array tag_wimg(string t, mapping m, RequestID id) {

  if(id->supports->pnginline)
    m->format = "png";
  else if(id->supports->wbmp && !id->supports->gifinline)
    m->format = "wbf";
  else
    m->format = "gif";

  ({ 1, "cimg", m });
}

RXML.Type type = TWml()(RXML.PXml);

protected class TWml {
  inherit RXML.TXml;
  constant name = "text/wml";
  RXML.Type conversion_type = RXML.t_xml;

  string encode (mixed val, void|RXML.Type from)  {
    if (from && from->name == local::name)
      return [string]val;
    else
      return replace(::encode(val, from), "$", "$$");
  }

  string decode (mixed val) {
    return ::decode(replace([string]val, "$$", "$"));
  }

  string _sprintf() { return "RXML.t_wml(" + parser_prog->name + ")"; }
}

class EntityClientWapSubscriber {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var,
			string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable = 0;
    if(c->id->request_headers["x-up-subno"])
      return ENCODE_RXML_TEXT( c->id->request_headers["x-up-subno"], type );
    return RXML.nil;
  }
}

mapping client_scope = ([
  "wap-subscriber" : EntityClientWapSubscriber(),
]);

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
  "wimg":#"<desc tag='tag'><p>Converts the image into the most suitable
 format for the client. If PNG is supported, it is preferred, seconded
 by GIF, and finally by WBMP. All the cimg attributes can be used for
 this tag as well.</p></desc>"
]);
#endif
