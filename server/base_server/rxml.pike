// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
//
// The Roxen RXML Parser. See also the RXML Pike modules.
//
// $Id$


inherit "rxmlhelp";
#include <config.h>
#include <request_trace.h>


// ------------------------- RXML Parser ------------------------------

protected class RXMLTagSet
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

  int censor_request;
  // Remove sensitive auth data from the request before parsing. The
  // data is lost and will not be available again afterwards.

  void sort_on_priority()
  {
#if constant (thread_create)
    Thread.MutexKey lock = lists_mutex->lock();
#endif
    int i = search (imported, Roxen.entities_tag_set);
#ifdef DEBUG
    if (i < 0) error ("Module list does not contain "
		      "Roxen.entities_tag_set: %O\n", imported);
    {
      int j = search (imported, Roxen.entities_tag_set, i + 1);
      if (j != -1)
	error ("Module list matches Roxen.entities_tag_set "
	       "more than once (at %d and %d): %O\n", i, j, imported);
    }
#endif

    array(RXML.TagSet) new_imported = imported[..i-1] + imported[i+1..];
    array(RoxenModule) new_modules = modules[..i-1] + modules[i+1..];
    array(string) module_ids = new_modules->module_identifier();
    // Sort on the module identifiers first so that the order is well
    // defined within the same priority. That's important to make
    // get_hash return a stable value.
    sort (module_ids, new_imported, new_modules);
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
    switch (var) {
      case "modules": modules = val; break;
      case "censor_request": censor_request = val; break;
      default: ::`->= (var, val);
    }
    return val;
  }

  void create (object rxml_object)
  {
    ::create (rxml_object, "rxml_tag_set");
    prepare_context = rxml_prepare_context;
    imported = ({Roxen.entities_tag_set});
    modules = ({rxml_object});
  }

  void rxml_prepare_context (RXML.Context ctx)
  {
    RequestID id = ctx->id;
    mapping misc = ctx->misc;

    PROF_ENTER( "rxml", "overhead" );

    // The id->misc->defines mapping is handled in a fairly ugly way:
    // If this is a nested parse, it's temporarily overridden with
    // ctx->misc (to get parse local scope), otherwise it's replaced
    // permanently. The latter is to be compatible with top level code
    // that uses id->misc->defines after the rxml evaluation.
    if (mapping defines = id->misc->defines) {
      if (defines != misc) {
	if (defines->rxml_misc) {
	  SIMPLE_TRACE_ENTER (owner, "Preparing for nested RXML parse - "
			      "moving away existing id->misc->defines");
	  ctx->id_defines = defines;
	}
	else
	  SIMPLE_TRACE_ENTER (owner, "Preparing for top level RXML parse - "
			      "replacing id->misc->defines");

	// These settings ought to be in id->misc but are in this
	// mapping for historical reasons.
	misc->language = defines->language;
	misc->present_languages = defines->present_languages;

	id->misc->defines = misc;
      }
      else
	SIMPLE_TRACE_ENTER (owner, "Preparing for %s RXML parse - "
			    "id->misc->defines is already the same as "
			    "RXML_CONTEXT->misc",
			    defines->rxml_misc ? "nested" : "top level");
    }
    else {
      SIMPLE_TRACE_ENTER (owner, "Preparing for top level RXML parse - "
			  "initializing id->misc->defines");
      id->misc->defines = misc;
    }
    misc->rxml_misc = 1;

    if (censor_request) {
      id->rawauth = 0;
      if (string auth = id->realauth) {
	if (sscanf (auth, "%[^:]%*c", auth) == 2)
	  id->realauth = auth + ":"; // Let's keep the username.
	else
	  id->realauth = 0;
      }

      if (m_delete (id->request_headers, "authorization")) {
	string raw = id->raw;
	int i = search (lower_case (raw), "authorization:");
	if (i >= 0) {
	  id->raw = raw[..i - 1];
	  // Buglet: This doesn't handle header continuations.
	  int j = search (raw, "\n", i);
	  if (j >= 0) id->raw += raw[j + 1..];
	}
      }

      // The Proxy-Authorization header has already been removed from
      // the raw request by the protocol module.
      m_delete (id->request_headers, "proxy-authorization");
      m_delete (id->misc, "proxyauth");
    }

#if ROXEN_COMPAT <= 1.3
    if (old_rxml_compat) ctx->compatible_scope = 1;
#endif

    misc[" _ok"] = misc[" _prev_ok"] = 1;
    misc[" _error"] = 200;
    ctx->add_scope ("header", misc[" _extra_heads"] = ([ ]));
    if(id->misc->stat) misc[" _stat"] = id->misc->stat;
  }

  void eval_finish (RXML.Context ctx)
  {
    RequestID id = ctx->id;
    mapping misc = ctx->misc;

    mapping extra_heads = ctx->get_scope ("header");
#ifdef DEBUG
    if (extra_heads != misc[" _extra_heads"])
      // Someone has probably replaced either of these mappings, which
      // should never be done since they'll get out of synch then.
      // Most likely it's some old code that has replaced
      // id->misc->defines[" _extra_heads"]. Therefore we
      // intentionally propagate the scope mapping here, so that the
      // error is more likely to be discovered.
      report_warning ("Warning: The \"header\" scope %O and "
		      "RXML_CONTEXT->misc[\" _extra_heads\"] %O "
		      "isn't the same mapping.\n",
		      extra_heads, misc[" _extra_heads"]);
#endif
    if(sizeof(extra_heads))
      if (id->misc->moreheads)
	id->misc->moreheads |= extra_heads;
      else
	id->misc->moreheads = extra_heads;

    if (mapping orig_defines = ctx->id_defines) {
      SIMPLE_TRACE_LEAVE ("Finishing nested RXML parse - "
			  "restoring old id->misc->defines");

      // Somehow it seems like these values are stored in the wrong place.. :P
      if (int v = misc[" _error"]) orig_defines[" _error"] = v;
      if (string v = misc[" _rettext"]) orig_defines[" _rettext"] = v;
      id->misc->defines = orig_defines;
    }
    else {
      SIMPLE_TRACE_LEAVE ("Finishing top level RXML parse - "
			  "leaving id->misc->defines");
      m_delete (misc, "rxml_misc");
    }

    PROF_LEAVE( "rxml", "overhead" );
  }
}

RXML.TagSet rxml_tag_set = RXMLTagSet (this);
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
  RXML.PXml parser;
  RXML.Context ctx = RXML_CONTEXT;
  int orig_state_updated = -1;
  int orig_dont_cache_result;

  if (ctx && ctx->id == id) {
    parser = default_content_type->get_parser (ctx, ctx->tag_set, 0);
    orig_state_updated = ctx->state_updated;
    if (ctx->frame)
      orig_dont_cache_result = ctx->frame->flags & RXML.FLAG_DONT_CACHE_RESULT;
#ifdef RXML_PCODE_UPDATE_DEBUG
    report_debug ("%O: Saved p-code update count %d before parse_rxml "
		  "with inherited context\n",
		  ctx, orig_state_updated);
#endif
  }
  else {
    parser = rxml_tag_set->get_parser (default_content_type, id);
    ctx = parser->context;
  }
  parser->recover_errors = 1;

  if (defines) {
    ctx->misc = id->misc->defines = defines;
    if (!defines[" _error"])
      defines[" _error"] = 200;
    if (!defines[" _extra_heads"])
      ctx->add_scope ("header", defines[" _extra_heads"] = ([ ]));
    if (!defines[" _stat"] && id->misc->stat)
      defines[" _stat"] = id->misc->stat;
  }
  else
    defines = ctx->misc;

  if (file) {
    if (!defines[" _stat"])
      defines[" _stat"] = file->stat();
    defines["_source file"] = file;
  }

  int orig_make_p_code = ctx->make_p_code;
  ctx->make_p_code = 0;
  mixed err = catch {
    if (ctx == RXML_CONTEXT)
      parser->finish (what);	// Skip the unnecessary work in write_end. DDTAH.
    else
      parser->write_end (what);
    what = parser->eval();
  };
  ctx->make_p_code = orig_make_p_code;

  if (file) m_delete (defines, "_source file");
  if (orig_state_updated >= 0) {
#ifdef RXML_PCODE_UPDATE_DEBUG
    report_debug ("%O: Restoring p-code update count from %d to %d "
		  "after parse_rxml with inherited context\n",
		  ctx, ctx->state_updated, orig_state_updated);
#endif
    ctx->state_updated = orig_state_updated;
    if (ctx->frame && !orig_dont_cache_result)
      ctx->frame->flags &= ~RXML.FLAG_DONT_CACHE_RESULT;
  }

  if (err) {
#ifdef DEBUG
    if (!parser) {
      report_debug("RXML: Parser destructed!\n");
#if constant(_describe)
      _describe(parser);
#endif /* constant(_describe) */
      error("Parser destructed!\n");
    }
#endif
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

  void create (string _name, int empty, string|COMPAT_TAG_TYPE|COMPAT_CONTAINER_TYPE _fn)
  {
    name = _name, fn = _fn;
    flags = empty && RXML.FLAG_EMPTY_ELEMENT;
    result_types = result_types(RXML.PXml); // Postparsing
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

      if (!content) content = "";
      if (stringp (fn)) return ({fn});
      if (!fn) {
	result_type = result_type (RXML.PNone);
	return ({propagate_tag()});
      }

      mapping defines = RXML_CONTEXT->misc;
      Stdio.File source_file = defines["_source file"];

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
		       pname, pargs || args, pcontent || content)});
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
    mod->query_tag_set ? mod->query_tag_set() : RXML.TagSet (mod, "");
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
    // The following destruct was presumably made to invalidate the
    // tag set thoroughly on a module reload. Reload seems to work
    // well without it, though. It's common that modules initialize
    // the tag set further in start() (and not query_tag_set(), which
    // would be a more accurate place). If we destroy it here and the
    // module remains in use then a new tag set will normally be
    // generated on demand by query_tag_set(), and any initializations
    // in start() won't be made on that one.
    //if (tag_set) destruct (tag_set);
  }
}

void ready_to_receive_requests (object this)
{
  remove_call_out (rxml_tag_set->sort_on_priority);
  rxml_tag_set->sort_on_priority();
}
