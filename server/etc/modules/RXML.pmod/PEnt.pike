//! Variant of PXml that parses only entities.
//!
//! This parser is the default for arguments.
//!
//! Created 2000-01-28 by Martin Stjernholm.
//!
//! $Id$

//#pragma strict_types // Disabled for now since it doesn't work well enough.

#include <config.h>

inherit RXML.PXml;

constant name = "xml-entity";

// Block these to avoid confusion.
constant add_tag = 0;
constant add_tags = 0;
constant add_container = 0;
constant add_containers = 0;

protected void init_entities()
{
  if (!type->entity_syntax) {
    // Don't decode normal entities if we're outputting xml-like stuff.
#ifdef OLD_RXML_COMPAT
    clear_entities();
    if (not_compat) {
#endif
      add_entities (tag_set->get_string_entities());
#ifdef OLD_RXML_COMPAT
    }
#endif
  }

#ifdef OLD_RXML_COMPAT
  if (not_compat)
#endif
    _set_entity_callback (.utils.p_xml_entity_cb);
#ifdef OLD_RXML_COMPAT
  else
    _set_entity_callback (.utils.p_xml_compat_entity_cb);
#endif
}

void reset (RXML.Context ctx, RXML.Type _type,
	    RXML.PCode p_code, RXML.TagSet _tag_set)
{
#ifdef DEBUG
  if (type != _type) error ("Internal error: Type change in reset().\n");
  if (tag_set != _tag_set) error ("Internal error: Tag set change in reset().\n");
#endif
  initialize (ctx, _type, p_code, _tag_set);

#ifdef OLD_RXML_COMPAT
  int new_not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
  if (new_not_compat == not_compat) return;
  not_compat = new_not_compat;
  init_entities();
#endif
}

this_program clone (RXML.Context ctx, RXML.Type type,
		    RXML.PCode p_code, RXML.TagSet tag_set)
{
#ifdef OLD_RXML_COMPAT
  int new_not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
  if (new_not_compat != not_compat) return this_program (ctx, type, p_code, tag_set);
#endif
  return [object(this_program)] _low_clone (ctx, type, p_code, tag_set, 1);
}

protected void create (RXML.Context ctx, RXML.Type type,
		       RXML.PCode p_code, RXML.TagSet tag_set, void|int cloned)
{
#ifdef OLD_RXML_COMPAT
  not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
#endif

  if (type->free_text)
    alternative = FREE_TEXT;
  else
    alternative = type->handle_literals ? LITERALS : NO_LITERALS;

  initialize (ctx, type, p_code, tag_set);

  if (cloned) return;

  ignore_tags (1);
  lazy_entity_end (1);
  match_tag (0);

  init_entities();
}

// These have no effect since we don't parse tags.
constant add_runtime_tag = 0;
constant remove_runtime_tag = 0;

#ifdef OBJ_COUNT_DEBUG
string _sprintf()
{
  return sprintf ("RXML.PEnt(%O,%O)%s", type, tag_set,
		  __object_marker ? "[" + __object_marker->count + "]" : "");
}
#else
string _sprintf()
{
  return sprintf ("RXML.PEnt(%O,%O)", type, tag_set);
}
#endif
