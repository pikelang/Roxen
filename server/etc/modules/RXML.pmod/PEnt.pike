//! Variant of PHtml that parses only entities.
//!
//! This parser is the default for arguments.
//!
//! Created 2000-01-28 by Martin Stjernholm.
//!
//! $Id: PEnt.pike,v 1.2 2000/01/28 16:48:44 mast Exp $

#pragma strict_types

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

  mixed_mode (!type->free_text);
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
