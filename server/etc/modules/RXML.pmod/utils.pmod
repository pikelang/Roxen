//! Things that belong elsewhere but can't lie there for various silly reasons.
//!
//! E.g. one reason is to avoid circular references in the parser
//! objects when the callbacks are defined in them.
//!
//! Created 2000-01-21 by Martin Stjernholm
//!
//! $Id: utils.pmod,v 1.2 2000/02/11 01:04:01 mast Exp $


array return_zero (mixed... ignored) {return 0;}
array return_empty_array (mixed... ignored) {return ({});}

int(1..1)|string|array unknown_tag_error (Parser.HTML p, string str)
{
  RXML.rxml_fatal ("Unknown tag %O. Unknown tags are not "
		   "allowed in this context.\n", p->tag_name());
  return ({});
}


// PHtml callbacks.

int(1..1)|string|array p_html_entity_cb (Parser.HTML p, string str)
{
  string entity = p->tag_name();
  if (sizeof (entity)) {
    if (entity[0] == '#') {
      if (!p->type->free_text) return ({});
      string out;
      if ((<"#x", "#X">)[entity[..1]]) {
	if (sscanf (entity, "%*2s%x%*c", int c) == 2) out = (string) ({c});
      }
      else
	if (sscanf (entity, "%*c%d%*c", int c) == 2) out = (string) ({c});
      return out && ({out});
    }
    return p->handle_var (entity);
  }
  return p->type->free_text ? 0 : ({});
}


// PHtmlCompat callbacks.

int(1..1)|string|array p_html_compat_tagmap_tag_cb (
  Parser.HTML p, string str, mixed... extra)
{
  string name = p->flag_parse_html_compat ? lower_case (p->tag_name()) : p->tag_name();
  if (mixed tdef = p->tagmap_tags[name])
    if (stringp (tdef))
      return ({tdef});
    else if (arrayp (tdef))
      return tdef[0] (p, p->tag_args(), @tdef[1..], @extra);
    else
      return tdef (p, p->tag_args(), @extra);
  else if (mixed cdef = p->tagmap_containers[name])
    // A container has been added.
    p->_low_add_container (name, p_html_compat_tagmap_container_cb);
  return 1;
}

int(1..1)|string|array p_html_compat_tagmap_container_cb (
  Parser.HTML p, mapping(string:string) args, string content, mixed... extra)
{
  string name = p->flag_parse_html_compat ? lower_case (p->tag_name()) : p->tag_name();
  if (mixed cdef = p->tagmap_containers[name])
    if (stringp (cdef))
      return ({cdef});
    else if (arrayp (cdef))
      return cdef[0] (p, args, content, @cdef[1..], @extra);
    else
      return cdef (p, args, content, @extra);
  else
    // The container has disappeared from the mapping.
    p->_low_add_container (name, 0);
  return 1;
}

array p_html_compat_entity_cb (Parser.HTML p, string str)
{
  string entity = p->tag_name();
  if (sizeof (entity) && entity[0] != '#') return p->handle_var (entity);
  return p->type->free_text ? 0 : ({});
}
