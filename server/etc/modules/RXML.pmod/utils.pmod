//! Things that belong elsewhere but can't lie there for various silly
//! reasons. Everything here is considered internal and not part of
//! the RXML.pmod API.
//!
//! E.g. one reason is to avoid circular references in the parser
//! objects when the callbacks are defined in them.
//!
//! Created 2000-01-21 by Martin Stjernholm
//!
//! $Id: utils.pmod,v 1.13 2000/08/15 01:20:05 mast Exp $


array return_zero (mixed... ignored) {return 0;}
array return_empty_array (mixed... ignored) {return ({});}

int(1..1)|string|array free_text_error (Parser.HTML p, string str)
{
  sscanf (str, "%[ \t\n\r]", string ws);
  if (str != ws) {
    sscanf (reverse (str), "%*[ \t\n\r]%s", str);
    sscanf (reverse (str), "%*[ \t\n\r]%s", str);
    RXML.parse_error ("Free text %O is not allowed in this context.\n", str);
  }
  return ({});
}

int(1..1)|string|array unknown_tag_error (Parser.HTML p, string str)
{
  RXML.parse_error ("Unknown tag %O. Unknown tags are not "
		    "allowed in this context.\n", p->tag_name());
  return ({});
}

int(1..1)|string|array output_error_cb (Parser.HTML p, string str)
{
  if (p->errmsgs) str = p->errmsgs + str, p->errmsgs = 0;
  if (p->type->free_text) p->_set_data_callback (0);
  else p->_set_data_callback (free_text_error);
  return ({str});
}


// PXml and PEnt callbacks.

int(1..1)|string|array p_xml_comment_cb (Parser.HTML p, string str)
// FIXME: This is a kludge until quote tags are handled like other tags.
{
  string name = p->parse_tag_name (str);
  if (sizeof (name)) {
    name = p->tag_name() + name;
    if (string|array|function tdef = p->tags()[name]) {
      if (stringp (tdef))
	return ({tdef});
      else if (arrayp (tdef))
	return tdef[0] (p, p->parse_tag_args (str), @tdef[1..]);
      else
	return tdef (p, p->parse_tag_args (str));
    }
    else if (p->containers()[name])
      RXML.parse_error ("Sorry, can't handle containers beginning with " +
			p->tag_name() + ".\n");
  }
  return p->type->free_text ? 0 : ({});
}

int(1..1)|string|array p_xml_entity_cb (Parser.HTML p, string str)
{
  string entity = p->tag_name();
  if (sizeof (entity)) {
    if (entity[0] != '#')
      return p->handle_var (entity,
			    p->html_context() == "splice_arg" ?
			    // No quoting of splice args. FIXME: Add
			    // some sort of safeguard against splicing
			    // in things like "nice><evil stuff='...'"?
			    RXML.t_text :
			    p->type);
    if (p->type->encoding_type != "xml") {
      // Don't decode any normal entities if we're outputting xml-like stuff.
      if (!p->type->free_text) return ({});
      string out;
      if ((<"#x", "#X">)[entity[..1]]) {
	if (sscanf (entity, "%*2s%x%*c", int c) == 2) out = (string) ({c});
      }
      else
	if (sscanf (entity, "%*c%d%*c", int c) == 2) out = (string) ({c});
      return out && ({out});
    }
  }
  if (!p->type->free_text)
    RXML.parse_error ("Unknown entity &%s; not allowed in this context.\n", entity);
  return 0;
}

int(1..1)|string|array p_xml_compat_entity_cb (Parser.HTML p, string str)
{
  string entity = p->tag_name();
  if (sizeof (entity) && entity[0] != '#')
    return p->handle_var (entity,
			  p->html_context() == "splice_arg" ?
			  // No quoting of splice args. FIXME: Add
			  // some sort of safeguard against splicing
			  // in things like "nice><evil stuff='...'"?
			  RXML.t_text :
			  p->type);
  if (!p->type->free_text)
    RXML.parse_error ("Unknown entity &%s; not allowed in this context.\n", entity);
  return 0;
}
