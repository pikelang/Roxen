//! Things that belong elsewhere but can't lie there for various silly reasons.
//!
//! E.g. one reason is to avoid circular references in the parser
//! objects when the callbacks are defined in them.
//!
//! Created 2000-01-21 by Martin Stjernholm
//!
//! $Id: utils.pmod,v 1.8 2000/03/04 19:08:41 mast Exp $


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
    if (p->type->quoting_scheme != "xml") {
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
  return p->type->free_text ? 0 : ({});
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
  return p->type->free_text ? 0 : ({});
}
