//! The standard HTML content parser.
//!
//! Parses tags and entities. Entities on the form &scope.variable;
//! are replaced by variable references.
//!
//! Created 1999-07-30 by Martin Stjernholm.
//!
//! $Id: PXml.pike,v 1.13 2000/01/10 21:56:00 mast Exp $

#pragma strict_types

inherit RXML.TagSetParser : TagSetParser;
inherit Parser.HTML : low_parser;

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

static mapping(string:array(array(TAG_TYPE|CONTAINER_TYPE))) overridden;
// Contains all tags with overridden definitions. Indexed on the
// effective tag names. The values are arrays of ({tag_definition,
// container_definition}) tuples, with the closest to top last. Shared
// between clones.

static array entity_cb (Parser.HTML this, string str)
{
  string entity = tag_name();
  if (sizeof (entity)) {
    if (entity[0] == '#') {
      if (!type->free_text) return ({});
      string out;
      if ((<"#x", "#X">)[entity[..1]]) {
	if (sscanf (entity, "%*2s%x%*c", int c) == 2) out = (string) ({c});
      }
      else
	if (sscanf (entity, "%*c%d%*c", int c) == 2) out = (string) ({c});
      return out ? ({out}) : ({str});
    }
    array(string) split = entity / ".";
    if (sizeof (split) == 2) {
      mixed val = context->get_var (split[1], split[0]);
      return val == RXML.Void ? ({}) : ({val});
    }
  }
  return type->free_text ? ({str}) : ({});
}

// Kludge to get to the functions in Parser.HTML from inheriting
// programs.. :P
static this_program _low_add_tag (string name, TAG_TYPE tdef)
  {return [object(this_program)] low_parser::add_tag (name, tdef);}
static this_program _low_add_container (string name, CONTAINER_TYPE tdef)
  {return [object(this_program)] low_parser::add_container (name, tdef);}
static this_program _low_clone (mixed... args)
  {return [object(this_program)] low_parser::clone (@args);}

/*static*/ void set_cbs()
{
  _set_entity_callback (entity_cb);
  if (!type->free_text) {
    _set_data_callback (lambda (Parser.HTML this, string str) {return ({});});
    add_quote_tag (
      "!--",
      lambda (Parser.HTML this, string str) {return ({});},
      "--");
  }
  else
    add_quote_tag (
      "!--",
      lambda (Parser.HTML this, string str) {return ({this->current()});},
      "--");
}

this_program clone (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
  this_program clone =
    [object(this_program)] low_parser::clone (ctx, type, tag_set, overridden);
  clone->set_cbs();
  return clone;
}

static void create (
  RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set,
  void|mapping(string:array(array(TAG_TYPE|CONTAINER_TYPE))) orig_overridden)
{
  TagSetParser::create (ctx, type, tag_set);

  if (orig_overridden) { // We're cloned.
    overridden = orig_overridden;
    return;
  }
  overridden = ([]);

  mixed_mode (!type->free_text);
  lazy_entity_end (1);
  match_tag (0);

  set_cbs();

  array(RXML.TagSet) list = ({tag_set});
  array(string) plist = ({tag_set->prefix});
  mapping(string:array(TAG_TYPE|CONTAINER_TYPE)) tagdefs = ([]);

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
    mapping(string:array(TAG_TYPE|CONTAINER_TYPE)) new_tagdefs = ([]);

    if (prefix) {
      if (mapping(string:TAG_TYPE) m = tset->low_tags)
	foreach (indices (m), string n) new_tagdefs[prefix + n] = ({m[n], 0});
      if (mapping(string:CONTAINER_TYPE) m = tset->low_containers)
	foreach (indices (m), string n) new_tagdefs[prefix + n] = ({0, m[n]});
      foreach (tlist, RXML.Tag tag)
	new_tagdefs[prefix + [string] tag->name] =
	  tag->flags & RXML.FLAG_CONTAINER ?
	  ({0,
	    [function(Parser.HTML,mapping(string:string),string:array)]
	    tag->_handle_tag}) :
	  ({({[function(Parser.HTML,mapping(string:string):array)]
	      tag->_handle_tag,
	      0}),		// Necessary as long as we use set_extra().
	    0});
    }

    if (!tset->prefix_required) {
      if (mapping(string:TAG_TYPE) m = tset->low_tags)
	foreach (indices (m), string n) new_tagdefs[n] = ({m[n], 0});
      if (mapping(string:CONTAINER_TYPE) m = tset->low_containers)
	foreach (indices (m), string n) new_tagdefs[n] = ({0, m[n]});
      foreach (tlist, RXML.Tag tag)
	new_tagdefs[[string] tag->name] =
	  tag->flags & RXML.FLAG_CONTAINER ?
	  ({0,
	    [function(Parser.HTML,mapping(string:string),string:array)]
	    tag->_handle_tag}) :
	  ({({[function(Parser.HTML,mapping(string:string):array)]
	      tag->_handle_tag,
	      0}),		// Necessary as long as we use set_extra().
	    0});
    }

    foreach (indices (new_tagdefs), string name) {
      if (array(TAG_TYPE|CONTAINER_TYPE) tagdef = tagdefs[name])
	if (overridden[name]) overridden[name] += ({tagdef});
	else overridden[name] = ({tagdef});
      array(TAG_TYPE|CONTAINER_TYPE) tagdef = tagdefs[name] = new_tagdefs[name];
      add_tag (name, [TAG_TYPE] tagdef[0]);
      add_container (name, [CONTAINER_TYPE] tagdef[1]);
    }

    if (tset->low_entities) add_entities (tset->low_entities);
  }
}

mixed read()
{
  if (type->free_text) return low_parser::read();
  else {
    array seq = [array] low_parser::read();
    if (type->sequential) {
      if (!sizeof (seq)) return RXML.Void;
      else if (sizeof (seq) <= 10000) return `+(@seq);
      else {
	mixed res = RXML.Void;
	foreach (seq / 10000.0, array slice) res += `+(@slice);
	return res;
      }
    }
    else {
      for (int i = sizeof (seq); --i >= 0;)
	if (seq[i] != RXML.Void) return seq[i];
      return RXML.Void;
    }
  }
  // Not reached.
}

// mixed feed (string in) {return low_parser::feed (in);}
// void finish (void|string in) {low_parser::finish (in);}


// Runtime tags.

static mapping(string:array(TAG_TYPE|CONTAINER_TYPE)) rt_replacements;

local static void rt_replace_tag (string name, RXML.Tag tag)
{
  if (!rt_replacements) rt_replacements = ([]);
  if (!rt_replacements[name])
    array(TAG_TYPE|CONTAINER_TYPE) tag_def =
      rt_replacements[name] = ({tags()[name], containers()[name]});
  if (tag)
    if (tag->flags & RXML.FLAG_CONTAINER) {
      add_tag (name, 0);
      add_container (name,
		     [function(Parser.HTML,mapping(string:string),string:array)]
		     tag->_handle_tag);
    }
    else {
      add_container (name, 0);
      add_tag (name,
	       [function(Parser.HTML,mapping(string:string):array)]
	       tag->_handle_tag);
    }
  else {
    add_tag (name, 0);
    add_container (name, 0);
  }
}

local static void rt_restore_tag (string name)
{
  if (array(TAG_TYPE|CONTAINER_TYPE) tag_def = rt_replacements && rt_replacements[name]) {
    add_tag (name, [TAG_TYPE] tag_def[0]);
    add_container (name, [CONTAINER_TYPE] tag_def[1]);
    m_delete (rt_replacements, name);
  }
}

static mapping(RXML.Tag:string) rt_tag_names;

local void add_runtime_tag (RXML.Tag tag)
{
  remove_runtime_tag (tag);
  if (!rt_tag_names) rt_tag_names = ([]);
  if (!tag_set->prefix_required)
    rt_replace_tag (rt_tag_names[tag] = [string] tag->name, tag);
  if (string prefix = tag_set->prefix) {
    rt_tag_names[tag] = prefix + "\0" + [string] tag->name;
    rt_replace_tag (tag_set->prefix + [string] tag->name, tag);
  }
}

local void remove_runtime_tag (string|RXML.Tag tag)
{
  if (!rt_tag_names) return;
  if (stringp (tag)) {
    array(RXML.Tag) arr_tag_names = indices (rt_tag_names);
    int i = search (arr_tag_names->name, tag);
    if (i < 0) return;
    tag = arr_tag_names[i];
  }
  if (string name = rt_tag_names[tag]) {
    array(string) parts = name / "\0";
    if (sizeof (parts)) {
#ifdef MODULE_DEBUG
      if (sizeof (parts) > 2)
	error ("Whoa! I didn't expect a tag name containing \\0: %O\n", name);
#endif
      rt_restore_tag (parts * "");
      rt_restore_tag (parts[-1]);
    }
    else rt_restore_tag (name);
    m_delete (rt_tag_names, tag);
  }
}


// Traversing overridden tag definitions.

array(TAG_TYPE|CONTAINER_TYPE) get_overridden_low_tag (
  string name, void|TAG_TYPE|CONTAINER_TYPE overrider)
//! Returns the tag definition that is overridden by the given
//! overrider tag definition on the given tag name, or the currently
//! active definition if overrider is zero. The returned values are on
//! the form ({tag_definition, container_definition}), where one
//! element always is zero.
{
  if (overrider) {
    if (array(array(TAG_TYPE|CONTAINER_TYPE)) tagdefs = overridden[name]) {
      if (array(TAG_TYPE|CONTAINER_TYPE) rt_tagdef =
	  rt_replacements && rt_replacements[name])
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

string _sprintf() {return "RXML.PHtml";}
