//! Compatibility variant of RXML.PHtml for parsing old style tags.
//!
//! The difference from RXML.PHtml is mainly that only variable
//! reference entities are parsed. It also provides mappings for tags
//! and containers that allows destructive modifications.
//!
//! Created 2000-01-08 by Martin Stjernholm.
//!
//! $Id: PHtmlCompat.pike,v 1.10 2000/02/08 06:28:14 mast Exp $

//#pragma strict_types // Disabled for now since it doesn't work well enough.

inherit RXML.PHtml;

constant unwind_safe = 0;
// Used from do_parse() in rxml.pike where we recurse without support
// for unwinding. Hence not unwind safe.

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

/*static*/ int flag_parse_html_compat;

// Local mappings for the tagdefs. Used instead of the one built-in in
// Parser.HTML for compatibility with certain things that changes the
// tag definition maps destructively. This is slower and will go away
// as soon as possible.
mapping(string:TAG_TYPE) tagmap_tags;
mapping(string:CONTAINER_TYPE) tagmap_containers;

this_program add_tag (string name, TAG_TYPE tdef)
{
  if (tdef) tagmap_tags[name] = tdef;
  else m_delete (tagmap_tags, name);
  return this_object();
}

this_program add_tags (mapping(string:TAG_TYPE) tdefs)
{
  foreach (indices (tdefs), string name)
    if (tdefs[name]) tagmap_tags[name] = tdefs[name];
    else m_delete (tagmap_tags, name);
  return this_object();
}

this_program add_container (string name, CONTAINER_TYPE cdef)
{
  if (cdef) tagmap_containers[name] = cdef;
  else m_delete (tagmap_containers, name);
  return this_object();
}

this_program add_containers (mapping(string:CONTAINER_TYPE) cdefs)
{
  foreach (indices (cdefs), string name)
    if (cdefs[name]) tagmap_containers[name] = cdefs[name];
    else m_delete (tagmap_containers, name);
  return this_object();
}

// Disable registration of low entities that shouldn't be parsed in
// compatibility mode.
this_program add_entity (string name, ENTITY_TYPE edef)
  {return this_object();}
this_program add_entities (mapping(string:ENTITY_TYPE) edefs)
  {return this_object();}

mapping(string:TAG_TYPE) tags() {return tagmap_tags;}

mapping(string:CONTAINER_TYPE) containers() {return tagmap_containers;}

this_program clone (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
  return [object(this_program)] _low_clone (ctx, type, tag_set, overridden,
					    tagmap_tags, tagmap_containers,
					    flag_parse_html_compat);
}

static void create (
  RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set,
  void|mapping(string:array(array(TAG_TYPE|CONTAINER_TYPE))) orig_overridden,
  void|mapping(string:TAG_TYPE) orig_tagmap_tags,
  void|mapping(string:CONTAINER_TYPE) orig_tagmap_containers,
  void|int orig_parse_html_compat)
{
  if (orig_overridden) { // We're cloned.
    tagmap_tags = orig_tagmap_tags + ([]);
    tagmap_containers = orig_tagmap_containers + ([]);
    flag_parse_html_compat = orig_parse_html_compat;
  }
  else {
    tagmap_tags = ([]);
    tagmap_containers = ([]);
  }

  ::create (ctx, type, tag_set, orig_overridden);

  _set_entity_callback (.utils.p_html_compat_entity_cb);
  _set_tag_callback (.utils.p_html_compat_tagmap_tag_cb);

  if (flag_parse_html_compat)
    parse_html_compat (1);
}

int parse_html_compat (void|int flag)
//! Set to preserve parse_html() compatibility:
//! o  Treat comments and unknown tags as text, continuing to parse
//!    for tags in them.
//! o  Be case insensitive when matching tag names. It's assumed that
//!    the registered tags are already lowercased.
{
  int oldflag = flag_parse_html_compat;
  if (!zero_type (flag) && !oldflag != !flag) {
    if (flag) {
      xml_tag_syntax (1);
      case_insensitive_tag (1);
      ignore_unknown (1);
      ws_before_tag_name (1);
      add_quote_tag ("!--", 0);
      add_quote_tag ("?", 0);
      add_quote_tag ("[CDATA[", 0);
    }
    else {
      xml_tag_syntax (2);
      case_insensitive_tag (0);
      ignore_unknown (0);
      ws_before_tag_name (0);
      set_quote_tag_cbs();
    }
    flag_parse_html_compat = flag;
  }
  return oldflag;
}

#ifdef OBJ_COUNT_DEBUG
string _sprintf() {return "RXML.PHtmlCompat(" + __count + ")";}
#else
string _sprintf() {return "RXML.PHtmlCompat";}
#endif
