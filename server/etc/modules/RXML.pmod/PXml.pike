//! The standard RXML content parser.
//!
//! Parses entities and tags according to XML syntax. Entities on the
//! form &scope.variable; are expanded with variables.
//!
//! Note: This is not a real XML parser according to the spec in any
//! way; it just understands the non-DTD syntax of XML.
//!
//! Created 1999-07-30 by Martin Stjernholm.
//!
//! $Id: PXml.pike,v 1.41 2000/03/16 10:39:16 mast Exp $

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

#define ENTITY_TYPE							\
  string|array|								\
  function(void|Parser.HTML:int(1..1)|string|array)

#define TAG_DEF_TYPE array(TAG_TYPE|CONTAINER_TYPE)
// A tag definition is an array of ({noncontainer definition,
// container definition}).

static mapping(string:array(TAG_DEF_TYPE)) overridden;
// Contains all tags with overridden definitions. Indexed on the
// effective tag names. The values are arrays of the tag definitions
// with the closest to top last. Shared between clones.

// Kludge to get to the functions in Parser.HTML from inheriting
// programs.. :P
/*static*/ this_program _low_add_tag (string name, TAG_TYPE tdef)
  {return [object(this_program)] low_parser::add_tag (name, tdef);}
/*static*/ this_program _low_add_container (string name, CONTAINER_TYPE tdef)
  {return [object(this_program)] low_parser::add_container (name, tdef);}
static this_program _low_clone (mixed... args)
  {return [object(this_program)] low_parser::clone (@args);}
static void _tag_set_parser_create (RXML.Context ctx, RXML.Type type,
				    RXML.TagSet tag_set, mixed... args)
  {TagSetParser::create (ctx, type, tag_set, @args);}

string html_context() {return low_parser::context();}

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
    ctx, type, tag_set, overridden, rt_replacements
  );
}

#ifdef OLD_RXML_COMPAT
static int not_compat = 1;
#endif

static void create (
  RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set,
  void|mapping(string:array(TAG_DEF_TYPE)) orig_overridden,
  void|mapping(string:TAG_DEF_TYPE) orig_rt_replacements
)
{
#ifdef OLD_RXML_COMPAT
  not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
#endif

  TagSetParser::create (ctx, type, tag_set);

  if (orig_overridden) {	// We're cloned.
    overridden = orig_overridden;
    if (orig_rt_replacements)
      rt_replacements = orig_rt_replacements + ([]);
    return;
  }
  overridden = ([]);

  array(RXML.TagSet) list = ({tag_set});
  array(string) plist = ({tag_set->prefix});
  mapping(string:TAG_DEF_TYPE) tagdefs = ([]);

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
    mapping(string:TAG_DEF_TYPE) new_tagdefs = ([]);

    if (prefix) {
      if (mapping(string:TAG_TYPE) m = tset->low_tags)
	foreach (indices (m), string n) new_tagdefs[prefix + ":" + n] = ({m[n], 0});
      if (mapping(string:CONTAINER_TYPE) m = tset->low_containers)
	foreach (indices (m), string n) new_tagdefs[prefix + ":" + n] = ({0, m[n]});
#ifdef OLD_RXML_COMPAT
      if (not_compat) {
#endif
	foreach (tlist, RXML.Tag tag)
	  if (!(tag->plugin_name || tag->flags & RXML.FLAG_NO_PREFIX))
	    new_tagdefs[prefix + ":" + [string] tag->name] =
	      ({0, tag->_handle_tag});
#ifdef OLD_RXML_COMPAT
      }
      else
	foreach (tlist, RXML.Tag tag)
	  if (!(tag->plugin_name || tag->flags & RXML.FLAG_NO_PREFIX))
	    new_tagdefs[prefix + ":" + [string] tag->name] =
	      tag->flags & RXML.FLAG_EMPTY_ELEMENT ?
	      ({tag->_handle_tag, 0}) : ({0, tag->_handle_tag});
#endif
    }

    if (!tset->prefix_req) {
      if (mapping(string:TAG_TYPE) m = tset->low_tags)
	foreach (indices (m), string n) new_tagdefs[n] = ({m[n], 0});
      if (mapping(string:CONTAINER_TYPE) m = tset->low_containers)
	foreach (indices (m), string n) new_tagdefs[n] = ({0, m[n]});
    }
#ifdef OLD_RXML_COMPAT
    if (not_compat) {
#endif
      foreach (tlist, RXML.Tag tag)
	if (!tag->plugin_name && (!tset->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX))
	  new_tagdefs[[string] tag->name] =
	    ((tag->flags & (RXML.FLAG_NO_PREFIX|RXML.FLAG_EMPTY_ELEMENT)) ==
	     (RXML.FLAG_NO_PREFIX|RXML.FLAG_EMPTY_ELEMENT)) ?
	    ({tag->_handle_tag, 0}) : ({0, tag->_handle_tag});
#ifdef OLD_RXML_COMPAT
    }
    else
      foreach (tlist, RXML.Tag tag)
	if (!tag->plugin_name && (!tset->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX))
	  new_tagdefs[[string] tag->name] =
	    tag->flags & RXML.FLAG_EMPTY_ELEMENT ?
	    ({tag->_handle_tag, 0}) : ({0, tag->_handle_tag});
#endif

    foreach (indices (new_tagdefs), string name) {
      if (TAG_DEF_TYPE tagdef = tagdefs[name])
	if (overridden[name]) overridden[name] += ({tagdef});
	else overridden[name] = ({tagdef});
      TAG_DEF_TYPE tagdef = tagdefs[name] = new_tagdefs[name];
      add_tag (name, [TAG_TYPE] tagdef[0]);
      add_container (name, [CONTAINER_TYPE] tagdef[1]);
    }

    if (tset->low_entities && type->quoting_scheme != "xml"
#ifdef OLD_RXML_COMPAT
	&& not_compat
#endif
       )
      // Don't decode entities if we're outputting xml-like stuff.
      add_entities (tset->low_entities);
  }

  if (!type->free_text) {
    mixed_mode (1);
    _set_data_callback (.utils.free_text_error);
    _set_tag_callback (.utils.unknown_tag_error);
  }
  lazy_entity_end (1);
  match_tag (0);
  splice_arg ("::");

#ifdef OLD_RXML_COMPAT
  if (not_compat) {
#endif
    xml_tag_syntax (2);
    _set_entity_callback (.utils.p_xml_entity_cb);
    set_quote_tag_cbs();
#ifdef OLD_RXML_COMPAT
  }
  else {
    xml_tag_syntax (1);
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
      if (!(seq && sizeof (seq))) return RXML.Void;
      else if (sizeof (seq) <= 10000) return `+(@seq);
      else {
	mixed res = RXML.Void;
	foreach (seq / 10000.0, array slice) res += `+(@slice);
	return res;
      }
    }
    else {
      for (int i = seq && sizeof (seq); --i >= 0;)
	if (seq[i] != RXML.Void) return seq[i];
      return RXML.Void;
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

local void add_runtime_tag (RXML.Tag tag)
{
  remove_runtime_tag (tag);
  if (!rt_replacements) rt_replacements = ([]);
  string name = tag->name;

  if (!tag_set->prefix_req) {
    rt_replacements[name] = ({tags()[name], containers()[name]});
#ifdef OLD_RXML_COMPAT
    if (not_compat)
#endif
      if ((tag->flags & (RXML.FLAG_NO_PREFIX|RXML.FLAG_EMPTY_ELEMENT)) ==
	  (RXML.FLAG_NO_PREFIX|RXML.FLAG_EMPTY_ELEMENT))
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

  if (string prefix = tag_set->prefix) {
    name = prefix + ":" + name;
    rt_replacements[name] = ({tags()[name], containers()[name]});
#ifdef OLD_RXML_COMPAT
    if (not_compat)
#endif
      if ((tag->flags & (RXML.FLAG_NO_PREFIX|RXML.FLAG_EMPTY_ELEMENT)) ==
	  (RXML.FLAG_NO_PREFIX|RXML.FLAG_EMPTY_ELEMENT))
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

local void remove_runtime_tag (string|RXML.Tag tag)
{
  if (!stringp (tag)) tag = tag->name;
  if (TAG_DEF_TYPE def = rt_replacements && rt_replacements[tag]) {
    m_delete (rt_replacements, tag);
    if (!tag_set->prefix_req)
      add_tag (tag, def[0]), add_container (tag, def[1]);
    if (string prefix = tag_set->prefix)
      if ((def = rt_replacements[tag = prefix + ":" + tag])) {
	m_delete (rt_replacements, tag);
	add_tag (tag, def[0]), add_container (tag, def[1]);
      }
  }
}


// Traversing overridden tag definitions.

TAG_DEF_TYPE get_overridden_low_tag (string name, void|TAG_TYPE|CONTAINER_TYPE overrider)
//! Returns the tag definition that is overridden by the given
//! overrider tag definition on the given tag name, or the currently
//! active definition if overrider is zero. The returned values are on
//! the form ({tag_definition, container_definition}), where one
//! element always is zero.
//!
//! Note: This function may go away in the future. Don't use.
{
  if (overrider) {
    if (array(TAG_DEF_TYPE) tagdefs = overridden[name]) {
      if (TAG_DEF_TYPE rt_tagdef = rt_replacements && rt_replacements[name])
	tagdefs += ({rt_tagdef});
      TAG_TYPE tdef = tags()[name];
      CONTAINER_TYPE cdef = containers()[name];
      for (int i = sizeof (tagdefs) - 1; i >= 0; i--) {
	if (overrider == tdef || overrider == cdef)
	  return tagdefs[i];
	[tdef, cdef] = tagdefs[i];
      }
    }
    return 0;
  }
  else
    return ({tags()[name], containers()[name]});
}

#ifdef OBJ_COUNT_DEBUG
string _sprintf() {return "RXML.PXml(" + __count + ")";}
#else
string _sprintf() {return "RXML.PXml";}
#endif
