//! The standard HTML content parser.
//!
//! Parses tags and entities. Entities on the form &scope.variable;
//! are replaced by variable references.

#pragma strict_types

#define TAGMAP_COMPAT

inherit RXML.TagSetParser : TagSetParser;
inherit Parser.HTML : low_parser;

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

static class TagDef
{
  TAG_TYPE tdef;
  CONTAINER_TYPE cdef;
  RXML.Tag tag;
  void create (TAG_TYPE _tdef, CONTAINER_TYPE _cdef, void|RXML.Tag _tag)
    {tdef = _tdef, cdef = _cdef, tag = _tag;}
}

#ifdef TAGMAP_COMPAT
constant tagmap_compat = 1;

// Local mappings for the tagdefs. Used instead of the one built-in in
// Parser.HTML for compatibility with certain things that changes the
// tag definition maps destructively. This is slower and will go away
// as soon as possible.
mapping(string:TAG_TYPE) tagmap_tags;
mapping(string:CONTAINER_TYPE) tagmap_containers;

static int(1..1)|string|array tagmap_tag_cb (
  Parser.HTML this, string str, mixed... extra)
{
  string name = lower_case (tag_name());
  if (TAG_TYPE tdef = tagmap_tags[name])
    if (stringp (tdef))
      return ({[string] tdef});
    else if (arrayp (tdef))
      return ([TAG_FUNC_TYPE] tdef[0]) (this, tag_args(), @tdef[1..], @extra);
    else
      return ([TAG_FUNC_TYPE] tdef) (this, tag_args(), @extra);
  else if (CONTAINER_TYPE cdef = tagmap_containers[name])
    // A container has been added.
    low_parser::add_container (name, tagmap_container_cb);
  return 1;
}

static int(1..1)|string|array tagmap_container_cb (
  Parser.HTML this, mapping(string:string) args, string content, mixed... extra)
{
  string name = lower_case (tag_name());
  if (CONTAINER_TYPE cdef = tagmap_containers[name])
    if (stringp (cdef))
      return ({[string] cdef});
    else if (arrayp (cdef))
      return ([CONTAINER_FUNC_TYPE] cdef[0]) (this, args, content, @cdef[1..], @extra);
    else
      return ([CONTAINER_FUNC_TYPE] cdef) (this, args, content, @extra);
  else
    // The container has disappeared from the mapping.
    low_parser::add_container (name, 0);
  return 1;
}

this_program add_tag (string name, TAG_TYPE tdef)
{
  if (tdef) tagmap_tags[name] = tdef;
  else m_delete (tagmap_tags, name);
  return this_object();
}

this_program add_container (string name, CONTAINER_TYPE cdef)
{
  if (cdef) tagmap_containers[name] = cdef;
  else m_delete (tagmap_containers, name);
  return this_object();
}

mapping(string:TAG_TYPE) tags() {return tagmap_tags;}

mapping(string:CONTAINER_TYPE) containers() {return tagmap_containers;}

#endif

static array entity_cb (Parser.HTML ignored, string str)
{
  string entity = tag_name();
  if (sizeof (entity)) {
    if (entity[0] == '#') {
      if (!type->free_text) return ({});
      string out;
      if ((<"#x", "#X">)[entity[..1]])
	if (sscanf (entity, "%*2s%x%*c", int c) == 2) out = (string) ({c});
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

/*static*/ void set_cbs()
{
  _set_entity_callback (entity_cb);
#ifdef TAGMAP_COMPAT
  _set_tag_callback (tagmap_tag_cb);
#endif
  if (!type->free_text)
    _set_data_callback (lambda (object this, string str) {return ({});});
}

this_program clone (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
  this_program clone =
    [object(this_program)] low_parser::clone (ctx, type, tag_set, overridden,
#ifdef TAGMAP_COMPAT
					      tagmap_tags, tagmap_containers,
#endif
					     );
  clone->set_cbs();
  return clone;
}

static void create (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set,
		    void|mapping(string:array(TagDef)) orig_overridden,
#ifdef TAGMAP_COMPAT
		    void|mapping(string:TAG_TYPE) orig_tagmap_tags,
		    void|mapping(string:CONTAINER_TYPE) orig_tagmap_containers,
#endif
		   )
{
  TagSetParser::create (ctx, type, tag_set);

  if (orig_overridden) {	// We're cloned.
    overridden = orig_overridden;
#ifdef TAGMAP_COMPAT
    tagmap_tags = orig_tagmap_tags + ([]);
    tagmap_containers = orig_tagmap_containers + ([]);
#endif
    return;
  }
  overridden = ([]);
#ifdef TAGMAP_COMPAT
  tagmap_tags = ([]);
  tagmap_containers = ([]);
#endif

  mixed_mode (!type->free_text);
  lazy_entity_end (1);
  match_tag (0);

  set_cbs();

  // parse_html() compatibility. FIXME: Some sort of old_rxml_compat
  // check here.
  case_insensitive_tag (1);
  ignore_unknown (1);

  array(RXML.TagSet) list = ({tag_set});
  array(string) plist = ({tag_set->prefix});
  mapping(string:TagDef) tagdefs = ([]);

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
    mapping(string:TagDef) new_tagdefs = ([]);

    if (prefix) {
      if (mapping(string:TAG_TYPE) m = tset->low_tags)
	foreach (indices (m), string n) new_tagdefs[prefix + n] = TagDef (m[n], 0);
      if (mapping(string:CONTAINER_TYPE) m = tset->low_containers)
	foreach (indices (m), string n) new_tagdefs[prefix + n] = TagDef (0, m[n]);
      foreach (tlist, RXML.Tag tag)
	new_tagdefs[prefix + [string] tag->name] =
	  tag->flags & RXML.FLAG_CONTAINER ?
	  TagDef (0,
		  [function(Parser.HTML,mapping(string:string),string:array)]
		  tag->_handle_tag,
		  tag) :
	  TagDef ([function(Parser.HTML,mapping(string:string):array)]
		  tag->_handle_tag,
		  0,
		  tag);
    }

    if (!tset->prefix_required) {
      if (mapping(string:TAG_TYPE) m = tset->low_tags)
	foreach (indices (m), string n) new_tagdefs[n] = TagDef (m[n], 0);
      if (mapping(string:CONTAINER_TYPE) m = tset->low_containers)
	foreach (indices (m), string n) new_tagdefs[n] = TagDef (0, m[n]);
      foreach (tlist, RXML.Tag tag)
	new_tagdefs[[string] tag->name] =
	  tag->flags & RXML.FLAG_CONTAINER ?
	  TagDef (0,
		  [function(Parser.HTML,mapping(string:string),string:array)]
		  tag->_handle_tag,
		  tag) :
	  TagDef ([function(Parser.HTML,mapping(string:string):array)]
		  tag->_handle_tag,
		  0,
		  tag);
    }

    foreach (indices (new_tagdefs), string name) {
      if (TagDef tagdef = tagdefs[name])
	if (overridden[name]) overridden[name] += ({tagdef});
	else overridden[name] = ({tagdef});
      TagDef tagdef = tagdefs[name] = new_tagdefs[name];
      add_tag (name, tagdef->tdef);
      add_container (name, tagdef->cdef);
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


// Misc services.

static mapping(string:ENTITY_TYPE) saved_entities;

int parse_entities (int flag)
{
  int oldflag = !saved_entities;
  if (!oldflag != !flag)
    if (flag) {
      add_entities (saved_entities);
      saved_entities = 0;
      _set_entity_callback (entity_cb);
    }
    else {
      saved_entities = entities();
      map (indices (saved_entities), add_entity, 0);
      _set_entity_callback (0);
    }
  return oldflag;
}


// Runtime tags.

static mapping(string:TagDef) rt_replacements;

local static void rt_replace_tag (string name, RXML.Tag tag)
{
  if (!rt_replacements) rt_replacements = ([]);
  if (!rt_replacements[name])
    TagDef tag_def = rt_replacements[name] = TagDef (tags()[name], containers()[name]);
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
  if (TagDef tag_def = rt_replacements && rt_replacements[name]) {
    add_tag (name, tag_def->tdef);
    add_container (name, tag_def->cdef);
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

static mapping(string:array(TagDef)) overridden;
// Contains all tags with overridden definitions. Indexed on the
// effective tag names. The values are arrays of TagDefs, with the
// closest to top last. Shared between clones.

static class OverrideData
{
  string name;
  TagDef orig_def;
  array(TagDef) or_list;
  int pos;
}
static OverrideData or_data;

static array|int(1..1)|string or_tag_cb (
  Parser.HTML this, mapping(string:string) args, void|string content)
{
#ifdef DEBUG
  if (!or_data)
    error ("Internal error: Got no override data in override callback.\n");
  if (tag_name() != or_data->name)
    error ("Internal error: Reparsed tag changed name from %O to %O.\n",
	   or_data->name, tag_name());
#endif
  string name = or_data->name;

  add_tag (name, or_data->orig_def->tdef);
  add_container (name, or_data->orig_def->cdef);

  if (or_data->pos != at_char()) {
    // FIXME: at_char() doesn't always do what we want here.
    or_data = 0;
    return 1;
  }

  TagDef tagdef = or_data->or_list[-1];
  int or_list_len = sizeof (or_data->or_list);
  array|int(1..1)|string res = tagdef->tdef ?
    tagdef->tdef (this, args) : tagdef->cdef (this, args, content);
  if (or_data && sizeof (or_data->or_list) == or_list_len) or_data = 0;
  return res;
}

local static void fix_or_cbs()
{
  string name = or_data->name;
  add_tag (name, 0);
  add_container (name, 0);
  if (TagDef tagdef = sizeof (or_data->or_list) && or_data->or_list[-1])
    if (tagdef->tdef) add_tag (name, or_tag_cb);
    else if (tagdef->cdef) add_container (name, or_tag_cb);
}

void ignore_tag (void|RXML.Tag tag)
{
  string name = tag_name();
  if (or_data && or_data->name == name && or_data->pos == at_char())
    or_data->or_list = or_data->or_list[..sizeof (or_data->or_list) - 2];
  else {
    or_data = OverrideData();
    or_data->name = name;
    or_data->orig_def = TagDef (tags()[name], containers()[name], tag);
    or_data->or_list = overridden[name] || ({});
    if (rt_replacements && rt_replacements[name])
      or_data->or_list += ({rt_replacements[name]});
    or_data->pos = at_char();
  }
  fix_or_cbs();
}

string _sprintf() {return "RXML.PHtml";}
