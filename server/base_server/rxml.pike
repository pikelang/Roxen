// This file is part of Roxen WebServer.
// Copyright © 1996 - 2001, Roxen IS.
//
// The Roxen RXML Parser. See also the RXML Pike modules.
//
// $Id: rxml.pike,v 1.306 2001/06/30 15:44:05 mast Exp $


inherit "rxmlhelp";
#include <config.h>


// ------------------------- RXML Parser ------------------------------

RXML.TagSet rxml_tag_set = class
// This tag set always has the highest priority.
{
  inherit RXML.TagSet;

  string prefix = RXML_NAMESPACE;

#if constant (thread_create)
  Thread.Mutex lists_mutex = Thread.Mutex();
  // Locks destructive changes to the arrays modules and imported.
#endif

  array(RoxenModule) modules;
  // Each element in the imported array is the registered tag set of a
  // parser module. This array contains the corresponding module
  // object.

  void sort_on_priority()
  {
#if constant (thread_create)
    Thread.MutexKey lock = lists_mutex->lock();
#endif
    int i = search (imported, Roxen.entities_tag_set);
    array(RXML.TagSet) new_imported = imported[..i-1] + imported[i+1..];
    array(RoxenModule) new_modules = modules[..i-1] + modules[i+1..];
    array(int) priorities = new_modules->query ("_priority", 1);
    priorities = replace (priorities, 0, 4);
    sort (priorities, new_imported, new_modules);
    new_imported = reverse (new_imported) + ({imported[i]});
    if (equal (imported, new_imported)) return;
    new_modules = reverse (new_modules) + ({modules[i]});
    `->= ("imported", new_imported);
    modules = new_modules;
  }

  mixed `->= (string var, mixed val)
  // Currently necessary due to misfeature in Pike.
  {
    if (var == "modules") modules = val;
    else ::`->= (var, val);
    return val;
  }

  void create (object rxml_object)
  {
    ::create (rxml_object->name + "/rxml_tag_set");
    imported = ({Roxen.entities_tag_set});
    modules = ({rxml_object});
  }

  void prepare_context (RXML.Context ctx)
  {
    RequestID id = ctx->id;

    PROF_ENTER( "rxml", "overhead" );

    id->misc->defines = ctx->misc; // Mostly for compatibility.

    ctx->misc[" _ok"] = 1;
    ctx->misc[" _error"] = 200;
    ctx->misc[" _extra_heads"] = ([ ]);
    if(id->misc->stat) ctx->misc[" _stat"] = id->misc->stat;
  }

  void eval_finish (RXML.Context ctx)
  {
    RequestID id = ctx->id;

    if(sizeof(ctx->misc[" _extra_heads"]) && !id->misc->moreheads)
    {
      id->misc->moreheads= ([]);
      id->misc->moreheads |= ctx->misc[" _extra_heads"];
    }

    PROF_LEAVE( "rxml", "overhead" );
  }
} (this_object());

RXML.Type default_content_type = RXML.t_html (RXML.PXml);
RXML.Type default_arg_type = RXML.t_text (RXML.PEnt);

int old_rxml_compat;

// A note on tag overriding: It's possible for old style tags to
// propagate their results to the tags they have overridden (new style
// tags can use RXML.Frame.propagate_tag()). This is done by an
// extension to the return value:
//
// If an array of the form
//
// ({int 1, string name, mapping(string:string) args, void|string content})
//
// is returned, the tag function with the given name is called with
// these arguments. If the name is the same as the current tag, the
// overridden tag function is called. If there's no overridden
// function, the tag is generated in the output. Any argument may be
// left out to default to its value in the current tag. ({1, 0, 0}) or
// ({1, 0, 0, 0}) may be shortened to ({1}).
//
// Note that there's no other way to handle tag overriding -- the page
// is no longer parsed multiple times.

string parse_rxml(string what, RequestID id,
		  void|Stdio.File file,
		  void|mapping defines )
// Note: Don't use this function to do recursive parsing inside an
// rxml parse session. The RXML module provides several different ways
// to accomplish that.
{
  RXML.PXml parent_parser = id->misc->_parser; // Don't count on that this exists.
  RXML.PXml parser;
  RXML.Context ctx;

  if (parent_parser && (ctx = parent_parser->context) && ctx->id == id) {
    parser = default_content_type->get_parser (ctx, 0, parent_parser);
    parser->recover_errors = parent_parser->recover_errors;
  }
  else {
    parser = rxml_tag_set->get_parser (default_content_type, id);
    parser->recover_errors = 1;
    parent_parser = 0;
    ctx = parser->context;
#if ROXEN_COMPAT <= 1.3
    if (old_rxml_compat) parser->context->compatible_scope = 1;
#endif
  }
  id->misc->_parser = parser;

  if (defines) {
    ctx->misc = id->misc->defines = defines;
    if (!defines[" _error"])
      defines[" _error"] = 200;
    if (!defines[" _extra_heads"])
      defines[" _extra_heads"] = ([ ]);
    if (!defines[" _stat"] && id->misc->stat)
      defines[" _stat"] = id->misc->stat;
  }
  else
    defines = ctx->misc;

  if (file) {
    if (!defines[" _stat"])
      defines[" _stat"] = file->stat();
    parser->_source_file = file;
  }

  if (mixed err = catch {
    if (parent_parser && ctx == RXML_CONTEXT)
      parser->finish (what);	// Skip the unnecessary work in write_end. DDTAH.
    else
      parser->write_end (what);
    what = parser->eval();
    id->misc->_parser = parent_parser;
  }) {
#ifdef DEBUG
    if (!parser) {
      report_debug("RXML: Parser destructed!\n");
#if constant(_describe)
      _describe(parser);
#endif /* constant(_describe) */
      error("Parser destructed!\n");
    }
#endif
    id->misc->_parser = parent_parser;
    if (objectp (err) && err->thrown_at_unwind)
      error ("Can't handle RXML parser unwinding in "
	     "compatibility mode (error=%O).\n", err);
    else throw (err);
  }

  return what;
}

#define COMPAT_TAG_TYPE \
  function(string,mapping(string:string),RequestID,void|Stdio.File,void|mapping: \
	   string|array(int|string))

#define COMPAT_CONTAINER_TYPE \
  function(string,mapping(string:string),string,RequestID,void|Stdio.File,void|mapping: \
	   string|array(int|string))

class CompatTag
{
  inherit RXML.Tag;
  constant is_compat_tag=1;

  string name;
  int flags;
  string|COMPAT_TAG_TYPE|COMPAT_CONTAINER_TYPE fn;

  RXML.Type content_type = RXML.t_same; // No preparsing.
  array(RXML.Type) result_types =
    ({RXML.t_xml (RXML.PXml), RXML.t_html (RXML.PXml)}); // Postparsing.

  void create (string _name, int empty, string|COMPAT_TAG_TYPE|COMPAT_CONTAINER_TYPE _fn)
  {
    name = _name, fn = _fn;
    flags = empty && RXML.FLAG_EMPTY_ELEMENT;
  }

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_enter (RequestID id)
    {
      if (args->preparse)
	content_type = content_type (RXML.PXml);
    }

    array do_return (RequestID id)
    {
      id->misc->line = "0";	// No working system for this yet.

      if (stringp (fn)) return ({fn});
      if (!fn) {
	result_type = result_type (RXML.PNone);
	return ({propagate_tag()});
      }

      Stdio.File source_file;
      mapping defines;
      if (id->misc->_parser) {
	source_file = id->misc->_parser->_source_file;
	defines = id->misc->defines;
      }

      string|array(string) result;
      if (flags & RXML.FLAG_EMPTY_ELEMENT)
	result = fn (name, args, id, source_file, defines);
      else {
	if(args->trimwhites) content = String.trim_all_whites(content);
	result = fn (name, args, content, id, source_file, defines);
      }

      if (arrayp (result)) {
	result_type = result_type (RXML.PNone);
	if (sizeof (result) && result[0] == 1) {
	  [string pname, mapping(string:string) pargs, string pcontent] =
	    (result[1..] + ({0, 0, 0}))[..2];
	  if (!pname || pname == name)
	    return ({!pargs && !pcontent ? propagate_tag () :
		     propagate_tag (pargs || args, pcontent || content)});
	  else
	    return ({RXML.make_unparsed_tag (
		       pname, pargs || args, pcontent || content || "")});
	}
	else return result;
      }
      else if (result) {
	if (args->noparse) result_type = result_type (RXML.PNone);
	return ({result});
      }
      else {
	result_type = result_type (RXML.PNone);
	return ({propagate_tag()});
      }
    }
  }
}

class GenericTag {
  inherit RXML.Tag;
  constant is_generic_tag=1;
  string name;
  int flags;

  function(string,mapping(string:string),string,RequestID,RXML.Frame:
	   array|string) _do_return;

  void create(string _name, int _flags,
	      function(string,mapping(string:string),string,RequestID,RXML.Frame:
		       array|string) __do_return) {
    name=_name;
    flags=_flags;
    _do_return=__do_return;
    if(flags&RXML.FLAG_DONT_PREPARSE)
      content_type = RXML.t_same;
  }

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id, void|mixed piece) {
      // Note: args may be zero here since this function is inherited
      // by GenericPITag.
      if (flags & RXML.FLAG_POSTPARSE)
	result_type = result_type (RXML.PXml);
      if (!(flags & RXML.FLAG_STREAM_CONTENT))
	piece = content || "";
      array|string res = _do_return(name, args, piece, id, this_object());
      return stringp (res) ? ({res}) : res;
    }
  }
}

class GenericPITag
{
  inherit GenericTag;

  void create (string _name, int _flags,
	       function(string,mapping(string:string),string,RequestID,RXML.Frame:
			array|string) __do_return)
  {
    ::create (_name, _flags | RXML.FLAG_PROC_INSTR, __do_return);
    content_type = RXML.t_text;
    // The content is always treated literally;
    // RXML.FLAG_DONT_PREPARSE has no effect.
  }
}

void add_parse_module (RoxenModule mod)
{
  RXML.TagSet tag_set =
    mod->query_tag_set ? mod->query_tag_set() : RXML.TagSet (mod->module_identifier());
  mapping(string:mixed) defs;

  if (mod->query_tag_callers &&
      mappingp (defs = mod->query_tag_callers()) &&
      sizeof (defs))
    tag_set->add_tags (map (indices (defs),
			    lambda (string name) {
			      return CompatTag (name, 1, defs[name]);
			    }));

  if (mod->query_container_callers &&
      mappingp (defs = mod->query_container_callers()) &&
      sizeof (defs))
    tag_set->add_tags (map (indices (defs),
			    lambda (string name) {
			      return CompatTag (name, 0, defs[name]);
			    }));

  if (mod->query_simpletag_callers &&
      mappingp (defs = mod->query_simpletag_callers()) &&
      sizeof (defs))
    tag_set->add_tags(Array.map(indices(defs),
				lambda(string tag){ return GenericTag(tag, @defs[tag]); }));

  if (mod->query_simple_pi_tag_callers &&
      mappingp (defs = mod->query_simple_pi_tag_callers()) &&
      sizeof (defs))
    tag_set->add_tags (map (indices (defs),
			    lambda (string name) {
			      return GenericPITag (name, @defs[name]);
			    }));

  if (search (rxml_tag_set->imported, tag_set) < 0) {
#ifdef THREADS
    Thread.MutexKey lock = rxml_tag_set->lists_mutex->lock();
#endif
    rxml_tag_set->modules += ({mod});
    rxml_tag_set->imported += ({tag_set});
#ifdef THREADS
    lock = 0;
#endif
    remove_call_out (rxml_tag_set->sort_on_priority);
    call_out (rxml_tag_set->sort_on_priority, 0);
  }
}

void remove_parse_module (RoxenModule mod)
{
  int i = search (rxml_tag_set->modules, mod);
  if (i >= 0) {
    RXML.TagSet tag_set = rxml_tag_set->imported[i];
    rxml_tag_set->modules =
      rxml_tag_set->modules[..i - 1] + rxml_tag_set->modules[i + 1..];
    rxml_tag_set->imported =
      rxml_tag_set->imported[..i - 1] + rxml_tag_set->imported[i + 1..];
    if (tag_set) destruct (tag_set);
  }
}

void ready_to_receive_requests (object this)
{
  remove_call_out (rxml_tag_set->sort_on_priority);
  rxml_tag_set->sort_on_priority();
}
