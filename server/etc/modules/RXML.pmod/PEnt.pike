//! Variant of PHtml that parses only entities.
//!
//! This parser is the default for arguments.
//!
//! Created 2000-01-28 by Martin Stjernholm.
//!
//! $Id: PEnt.pike,v 1.6 2000/02/12 21:27:55 mast Exp $

//#pragma strict_types // Disabled for now since it doesn't work well enough.

inherit RXML.PHtml;

// Block these to avoid confusion.
constant add_tag = 0;
constant add_tags = 0;
constant add_container = 0;
constant add_containers = 0;

this_program clone (RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
  return [object(this_program)] _low_clone (ctx, type, tag_set);
}

static void create (
  RXML.Context ctx, RXML.Type type, RXML.TagSet tag_set)
{
  _tag_set_parser_create (ctx, type, tag_set);

  if (type->quoting_scheme != "xml") {
    // Don't decode entities if we're outputting xml-like stuff.
    array(RXML.TagSet) list = ({tag_set});
    for (int i = 0; i < sizeof (list); i++) {
      array(RXML.TagSet) sublist = list[i]->imported;
      if (sizeof (sublist))
	list = list[..i] + sublist + list[i + 1..];
    }
    for (int i = sizeof (list) - 1; i >= 0; i--)
      if (list[i]->low_entities) add_entities (list[i]->low_entities);
  }

  mixed_mode (!type->free_text);
  ignore_tags (1);
  lazy_entity_end (1);
  match_tag (0);
  _set_entity_callback (.utils.p_html_entity_cb);
  if (!type->free_text) _set_data_callback (.utils.return_empty_array);
}

// These have no effect since we don't parse tags.
void add_runtime_tag (RXML.Tag tag) {}
void remove_runtime_tag (string|RXML.Tag tag) {}

#ifdef OBJ_COUNT_DEBUG
string _sprintf() {return "RXML.PEnt(" + __count + ")";}
#else
string _sprintf() {return "RXML.PEnt";}
#endif
