//! The standard RXML content parser.
//!
//! Parses entities and tags according to XML syntax. Entities on the
//! form &scope.variable; are expanded with variables.
//!
//! Note: This parser does not conform to the XML specification in
//! some important ways:
//!
//! o  It does not understand DTD declarations.
//! o  It's not as restrictive in syntax as the standard requires,
//!    i.e. several construct that aren't well-formed are accepted
//!    without error.
//!
//! Created 1999-07-30 by Martin Stjernholm.
//!
//! $Id: PXml.pike,v 1.49 2000/08/12 04:49:25 mast Exp $

//#pragma strict_types // Disabled for now since it doesn't work well enough.

#include <config.h>

inherit Parser.HTML : low_parser;
inherit RXML.TagSetParser : TagSetParser;

constant unwind_safe = 1;

#define TAG_FUNC_TYPE							\
  function(:int(1..1)|string|array)|					\
  function(Parser.HTML,mapping(string:string):				\
	   int(1..1)|string|array)

#define TAG_TYPE string|array|TAG_FUNC_TYPE

#define CONTAINER_FUNC_TYPE						\
  function(:int(1..1)|string|array)|					\
  function(Parser.HTML,mapping(string:string),string:			\
	   int(1..1)|string|array)

#define CONTAINER_TYPE string|array|CONTAINER_FUNC_TYPE

#define QUOTE_TAG_FUNC_TYPE						\
  function(:int(1..1)|string|array)|					\
  function(Parser.HTML,string:						\
	   int(1..1)|string|array)

#define QUOTE_TAG_TYPE string|array|QUOTE_TAG_FUNC_TYPE

#define ENTITY_TYPE							\
  string|array|								\
  function(void|Parser.HTML:int(1..1)|string|array)

#define TAG_DEF_TYPE array(TAG_TYPE|CONTAINER_TYPE)
// A tag definition is an array of ({noncontainer definition,
// container definition}).

// Kludge to get to the functions in Parser.HTML from inheriting
// programs.. :P
/*static*/ this_program _low_add_tag (string name, TAG_TYPE tdef)
  {return [object(this_program)] low_parser::add_tag (name, tdef);}
/*static*/ this_program _low_add_container (string name, CONTAINER_TYPE tdef)
  {return [object(this_program)] low_parser::add_container (name, tdef);}
/*static*/ this_program _low_add_quote_tag (string beg, QUOTE_TAG_TYPE tdef, string end)
  {return [object(this_program)] low_parser::add_quote_tag (beg, tdef, end);}
static this_program _low_clone (mixed... args)
  {return [object(this_program)] low_parser::clone (@args);}
static void _tag_set_parser_create (RXML.Context ctx, RXML.Type type,
				    RXML.TagSet tag_set, mixed... args)
  {TagSetParser::create (ctx, type, tag_set, @args);}

string html_context() {return low_parser::context();}
string current_input() {return low_parser::current();}

constant reset = 0;

static void set_quote_tag_cbs()
{
  add_quote_tag ("!--", .utils.p_xml_comment_cb, "--");
  add_quote_tag ("?", .utils.return_zero, "?");
  add_quote_tag ("![CDATA[", .utils.return_zero, "]]");
}

this_program clone (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
#ifdef OLD_RXML_COMPAT
  int new_not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
  if (new_not_compat != not_compat) return this_program (ctx, type, tag_set);
#endif
  return [object(this_program)] low_parser::clone (
    ctx, type, tag_set, rt_replacements || 1, rt_pi_replacements
  );
}

#ifdef OLD_RXML_COMPAT
static int not_compat = 1;
#endif

static void create (
  RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set,
  void|int|mapping(string:TAG_DEF_TYPE) orig_rt_replacements,
  void|mapping(string:QUOTE_TAG_TYPE) orig_rt_pi_replacements
)
{
#ifdef OLD_RXML_COMPAT
  not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
#endif

  TagSetParser::create (ctx, type, tag_set);

  if (orig_rt_replacements) {	// We're cloned.
    if (mappingp (orig_rt_replacements))
      rt_replacements = orig_rt_replacements + ([]);
    if (orig_rt_pi_replacements)
      rt_pi_replacements = orig_rt_pi_replacements + ([]);
    return;
  }

#ifdef RXML_OBJ_DEBUG
  master_parser = 1;
  __object_marker->create (this_object());
#elif defined (OBJ_COUNT_DEBUG)
  master_parser = 1;
#endif

  array(RXML.TagSet) list = ({tag_set});
  array(string) plist = ({tag_set->prefix});

  for (int i = 0; i < sizeof (list); i++) {
    array(RXML.TagSet) sublist = list[i]->imported;
    if (sizeof (sublist)) {
      list = list[..i] + sublist + list[i + 1..];
      plist = plist[..i] + replace (sublist->prefix, 0, plist[i]) + plist[i + 1..];
    }
  }

  for (int i = sizeof (list) - 1; i >= 0; i--) {
    RXML.TagSet tset = list[i];
    string prefix = plist[i];

    array(RXML.Tag) tlist = tset->get_local_tags();

    // Note: Similar things done in add_runtime_tag() and add_runtime_pi_tag().

    if (prefix) {
#ifdef OLD_RXML_COMPAT
      if (not_compat) {
#endif
	foreach (tlist, RXML.Tag tag)
	  if (!(tag->plugin_name || tag->flags & RXML.FLAG_NO_PREFIX)) {
	    string name = prefix + ":" + [string] tag->name;
	    if (tag->flags & RXML.FLAG_PROC_INSTR)
	      add_quote_tag ("?" + name, tag->_handle_pi_tag, "?");
	    else
	      add_tag (name, 0), add_container (name, tag->_handle_tag);
	  }
#ifdef OLD_RXML_COMPAT
      }
      else
	foreach (tlist, RXML.Tag tag)
	  if (!(tag->plugin_name || tag->flags & RXML.FLAG_NO_PREFIX)) {
	    string name = prefix + ":" + [string] tag->name;
	    if (tag->flags & RXML.FLAG_PROC_INSTR)
	      add_quote_tag ("?" + name, tag->_handle_pi_tag, "?");
	    else
	      if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
		add_tag (name, tag->_handle_tag), add_container (name, 0);
	      else
		add_tag (name, 0), add_container (name, tag->_handle_tag);
	  }
#endif
    }

#ifdef OLD_RXML_COMPAT
    if (not_compat) {
#endif
      foreach (tlist, RXML.Tag tag)
	if (!tag->plugin_name &&
	    (!tset->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX)) {
	  string name = [string] tag->name;
	  if (tag->flags & RXML.FLAG_PROC_INSTR)
	    add_quote_tag ("?" + name, tag->_handle_pi_tag, "?");
	  else
	    if ((tag->flags & (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)) ==
		(RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT))
	      add_tag (name, tag->_handle_tag), add_container (name, 0);
	    else
	      add_tag (name, 0), add_container (name, tag->_handle_tag);
	}
#ifdef OLD_RXML_COMPAT
    }
    else
      foreach (tlist, RXML.Tag tag)
	if (!tag->plugin_name &&
	    (!tset->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX)) {
	  string name = [string] tag->name;
	  if (tag->flags & RXML.FLAG_PROC_INSTR)
	    add_quote_tag ("?" + name, tag->_handle_pi_tag, "?");
	  else
	    if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
	      add_tag (name, tag->_handle_tag), add_container (name, 0);
	    else
	      add_tag (name, 0), add_container (name, tag->_handle_tag);
	}
#endif
  }

  if (type->quoting_scheme != "xml"
#ifdef OLD_RXML_COMPAT
      && not_compat
#endif
     )
    // Don't decode entities if we're outputting xml-like stuff.
    add_entities (tag_set->get_string_entities());

  if (!type->free_text) {
    mixed_mode (1);
    _set_data_callback (.utils.free_text_error);
    _set_tag_callback (.utils.unknown_tag_error);
  }
  lazy_entity_end (1);
  match_tag (0);
  splice_arg ("::");
  xml_tag_syntax (2);

#ifdef OLD_RXML_COMPAT
  if (not_compat) {
#endif
    _set_entity_callback (.utils.p_xml_entity_cb);
    set_quote_tag_cbs();
#ifdef OLD_RXML_COMPAT
  }
  else {
    case_insensitive_tag (1);
    ignore_unknown (1);
    ws_before_tag_name (1);
    _set_entity_callback (.utils.p_xml_compat_entity_cb);
  }
#endif
}

mixed read()
{
  if (type->free_text) return low_parser::read();
  else {
    array seq = [array] low_parser::read();
    if (type->sequential) {
      if (!(seq && sizeof (seq))) return RXML.nil;
      else if (sizeof (seq) <= 10000) return `+(@seq);
      else {
	mixed res = RXML.nil;
	foreach (seq / 10000.0, array slice) res += `+(@slice);
	return res;
      }
    }
    else {
      for (int i = seq && sizeof (seq); --i >= 0;)
	if (seq[i] != RXML.nil) return seq[i];
      return RXML.nil;
    }
  }
  // Not reached.
}

/*static*/ string errmsgs;

int report_error (string msg)
{
  if (errmsgs) errmsgs += msg;
  else errmsgs = msg;
  if (low_parser::context() != "data")
    _set_data_callback (.utils.output_error_cb);
  else
    low_parser::write_out (errmsgs), errmsgs = 0;
  return 1;
}

mixed feed (string in) {return low_parser::feed (in);}
void finish (void|string in)
{
  low_parser::finish (in);
  if (errmsgs) low_parser::write_out (errmsgs), errmsgs = 0;
}


// Runtime tags.

static mapping(string:TAG_DEF_TYPE) rt_replacements;
static mapping(string:QUOTE_TAG_TYPE) rt_pi_replacements;

local void add_runtime_tag (RXML.Tag tag)
{
  string name = tag->name;

  if (tag->flags & RXML.FLAG_PROC_INSTR) {
    if (!rt_pi_replacements) rt_pi_replacements = ([]);
    else remove_runtime_tag (tag);

    if (!tag_set->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX) {
      rt_pi_replacements[name] = quote_tags()[name];
      add_quote_tag ("?" + name, tag->_handle_pi_tag, "?");
    }

    if (tag_set->prefix && !(tag->flags & RXML.FLAG_NO_PREFIX)) {
      name = tag_set->prefix + ":" + name;
      rt_pi_replacements[name] = quote_tags()[name];
      add_quote_tag ("?" + name, tag->_handle_pi_tag, "?");
    }
  }

  else {
    if (!rt_replacements) rt_replacements = ([]);
    else remove_runtime_tag (tag);

    if (!tag_set->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX) {
      rt_replacements[name] = ({tags()[name], containers()[name]});
#ifdef OLD_RXML_COMPAT
      if (not_compat)
#endif
	if ((tag->flags & (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)) ==
	    (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT))
	  add_tag (name, tag->_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_handle_tag);
#ifdef OLD_RXML_COMPAT
      else
	if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
	  add_tag (name, tag->_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_handle_tag);
#endif
    }

    if (tag_set->prefix && !(tag->flags & RXML.FLAG_NO_PREFIX)) {
      name = tag_set->prefix + ":" + name;
      rt_replacements[name] = ({tags()[name], containers()[name]});
#ifdef OLD_RXML_COMPAT
      if (not_compat)
#endif
	if ((tag->flags & (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)) ==
	    (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT))
	  add_tag (name, tag->_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_handle_tag);
#ifdef OLD_RXML_COMPAT
      else
	if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
	  add_tag (name, tag->_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_handle_tag);
#endif
    }
  }
}

local void remove_runtime_tag (string|RXML.Tag tag, void|int proc_instr)
{
  int no_prefix = 0;
  if (!stringp (tag)) {
    proc_instr = tag->flags & RXML.FLAG_PROC_INSTR;
    no_prefix = tag->flags & RXML.FLAG_NO_PREFIX;
    tag = tag->name;
  }

  if (proc_instr) {
    if (!stringp (tag)) {
      tag = tag->name;
      no_prefix = tag->flags & RXML.FLAG_NO_PREFIX;
    }

    if (!tag_set->prefix_req || no_prefix)
      if (TAG_DEF_TYPE def = rt_pi_replacements && rt_pi_replacements[tag]) {
	m_delete (rt_pi_replacements, tag);
	add_quote_tag ("?" + tag, def, "?");
      }
    if (tag_set->prefix && !no_prefix)
      if (TAG_DEF_TYPE def = rt_pi_replacements[tag = tag_set->prefix + ":" + tag]) {
	m_delete (rt_pi_replacements, tag);
	add_quote_tag ("?" + tag, def, "?");
      }
  }

  else {
    if (!tag_set->prefix_req || no_prefix)
      if (TAG_DEF_TYPE def = rt_replacements && rt_replacements[tag]) {
	m_delete (rt_replacements, tag);
	add_tag (tag, def[0]), add_container (tag, def[1]);
      }
    if (tag_set->prefix && !no_prefix)
      if (TAG_DEF_TYPE def = rt_replacements[tag = tag_set->prefix + ":" + tag]) {
	m_delete (rt_replacements, tag);
	add_tag (tag, def[0]), add_container (tag, def[1]);
      }
  }
}

#if defined (OBJ_COUNT_DEBUG) || defined (RXML_OBJ_DEBUG)
static int master_parser;
string _sprintf()
{
  return sprintf ("RXML.PXml(%s,%O,%O,%O)%s",
		  master_parser ? "master" : "clone",
		  context, type, tag_set,
		  __object_marker ? "[" + __object_marker->count + "]" : "");
}
#else
string _sprintf()
{
  return sprintf ("RXML.PXml(%O,%O,%O)", context, type, tag_set);
}
#endif
