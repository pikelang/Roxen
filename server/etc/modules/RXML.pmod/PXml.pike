//! The standard HTML content parser.
//!
//! Parses tags and entities. Entities on the form &scope.variable;
//! are replaced by variable references.

inherit RXML.TagSetParser;
inherit Parser.HTML : low_parser;

object clone (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
  return low_parser::clone (ctx, type, tag_set, 1);
}

void create (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set, void|int is_cloned)
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
      mapping(string:mixed) m;
      if ((m = tset->low_containers))
	foreach (indices (m), string n) add_container (prefix + n, m[n]);
      if ((m = tset->low_tags))
	foreach (indices (m), string n) add_tag (prefix + n, m[n]);
      foreach (tlist, RXML.Tag tag)
	if (tag->flags & RXML.FLAG_CONTAINER)
	  add_container (prefix + tag->name, tag->_parsed_tag_cb);
	else
	  add_tag (prefix + tag->name, tag->_parsed_tag_cb);
    }

    if (!tset->prefix_required) {
      if (tset->low_containers) add_containers (tset->low_containers);
      if (tset->low_tags) add_tags (tset->low_tags);
      foreach (tlist, RXML.Tag tag)
	if (tag->flags & RXML.FLAG_CONTAINER)
	  add_container (tag->name, tag->_parsed_tag_cb);
	else
	  add_tag (tag->name, tag->_parsed_tag_cb);
    }

    if (tset->low_entities) add_entities (tset->low_entities);
  }

  _set_entity_callback (entity_callback);

  _set_tag_callback (1);

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

void recheck_tags()
{
  //HERE
}

static string|array(string) entity_callback (object this, string str)
{
  array(string) split = str / ".";
  if (sizeof (split) == 2) {
    mixed val = context->get_var (split[1], split[0]);
    return val == RXML.Void ? ({}) : ({val});
  }
  return type->free_text ? ({"&" + str + ";"}) : ({});
}
