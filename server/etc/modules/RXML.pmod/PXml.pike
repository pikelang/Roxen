//! The standard HTML content parser.
//!
//! Parses tags and entities. Entities on the form &scope.variable;
//! are replaced by variable references.

#pragma strict_types

inherit RXML.TagSetParser;
inherit Parser.HTML : low_parser;

this_program clone (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
  return [object(this_program)] low_parser::clone (ctx, type, tag_set, 1);
}

static void create (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set,
		    void|int is_cloned)
{
  ::create (ctx, type, tag_set);
  if (is_cloned) return;

  mixed_mode (!type->free_text);
  
  array(RXML.TagSet) list = ({tag_set});
  array(string) plist = ({tag_set->prefix});

  while (sizeof (list)) {
    for (array(RXML.TagSet) sublist = list[0]->imported; sizeof (sublist);) {
      list = sublist + list;
      plist = replace (sublist->prefix, 0, plist[0]) + plist;
    }
    RXML.TagSet tset = list[0];
    array(RXML.Tag) tlist = tset->get_local_tags();
    tlist = tlist[1..];
    string prefix = plist[0];
    plist = plist[1..];

    if (tset->prefix_required && prefix) {
      if (mapping(string:string|
		  function(:int(1..1)|string|array)|
		  function(object,mapping(string:string),string:
			   int(1..1)|string|array)) m = tset->low_containers)
	foreach (indices (m), string n) add_container (prefix + n, m[n]);
      if (mapping(string:string|
		  function(:int(1..1)|string|array)|
		  function(object,mapping(string:string):
			   int(1..1)|string|array)) m = tset->low_tags)
	foreach (indices (m), string n) add_tag (prefix + n, m[n]);
      foreach (tlist, RXML.Tag tag)
	if (tag->flags & RXML.FLAG_CONTAINER)
	  add_container (prefix + [string] tag->name,
			 [function(Parser.HTML,mapping(string:string),string:array)]
			 tag->_handle_tag);
	else
	  add_tag (prefix + [string] tag->name,
		   [function(Parser.HTML,mapping(string:string):array)]
		   tag->_handle_tag);
    }

    if (!tset->prefix_required) {
      if (tset->low_containers) add_containers (tset->low_containers);
      if (tset->low_tags) add_tags (tset->low_tags);
      foreach (tlist, RXML.Tag tag)
	if (tag->flags & RXML.FLAG_CONTAINER)
	  add_container ([string] tag->name,
			 [function(Parser.HTML,mapping(string:string),string:array)]
			 tag->_handle_tag);
	else
	  add_tag ([string] tag->name,
		   [function(Parser.HTML,mapping(string:string):array)]
		   tag->_handle_tag);
    }

    if (tset->low_entities) add_entities (tset->low_entities);
  }

  _set_entity_callback (entity_callback);

  lazy_entity_end (1);
  match_tag (0);

  // parse_html() compatibility. FIXME: Some sort of old_rxml_compat
  // check here.
  case_insensitive_tag (1);
  ignore_unknown (1);

  if (!type->free_text)
    _set_data_callback (lambda (object this, string str) {
			  return ({});
			});
}

mixed read()
{
  if (type->free_text) return ::read();
  else {
    array seq = ::read();
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

mapping(RXML.Tag:string) runtime_tags;

void add_runtime_tag (RXML.Tag tag)
{
  if (!runtime_tags) runtime_tags = ([]);
  if (!runtime_tags[tag]) {
    if (string prefix = tag_set->prefix_required && tag_set->prefix) {
      if (tag->flags & RXML.FLAG_CONTAINER)
	add_container (prefix + [string] tag->name,
		       [function(Parser.HTML,mapping(string:string),string:array)]
		       /*[function(this_program,mapping(string:string),string:array)]*/
		       tag->_handle_tag);
      else
	add_tag (prefix + [string] tag->name,
		 [function(Parser.HTML,mapping(string:string):array)]
		 tag->_handle_tag);
      runtime_tags[tag] = prefix + "\0" + [string] tag->name;
    }
    else runtime_tags[tag] = [string] tag->name;
    if (!tag_set->prefix_required)
      if (tag->flags & RXML.FLAG_CONTAINER)
	add_container ([string] tag->name,
		       [function(Parser.HTML,mapping(string:string),string:array)]
		       tag->_handle_tag);
      else
	add_tag ([string] tag->name,
		 [function(Parser.HTML,mapping(string:string):array)]
		 tag->_handle_tag);
  }
}

void remove_runtime_tag (string|RXML.Tag tag)
{
  if (!runtime_tags) return;
  if (stringp (tag)) {
    array(RXML.Tag) arr_tags = indices (runtime_tags);
    int i = search (arr_tags->name, tag);
    if (i < 0) return;
    tag = arr_tags[i];
  }
  if (string name = runtime_tags[tag]) {
    if (([object(RXML.Tag)] tag)->flags & RXML.FLAG_CONTAINER) {
      add_container (name - "\0", 0);
      add_container ((name / "\0")[-1], 0);
    }
    else {
      add_tag (name - "\0", 0);
      add_tag ((name / "\0")[-1], 0);
    }
    m_delete (runtime_tags, tag);
  }
}

static array entity_callback (object this, string str)
{
  array(string) split = str / ".";
  if (sizeof (split) == 2) {
    mixed val = context->get_var (split[1], split[0]);
    return val == RXML.Void ? ({}) : ({val});
  }
  return type->free_text ? ({"&" + str + ";"}) : ({});
}
