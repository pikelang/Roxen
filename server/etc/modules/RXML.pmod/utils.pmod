//! Things that belong elsewhere but can't lie there for various silly
//! reasons. Everything here is considered internal and not part of
//! the RXML.pmod API.
//!
//! E.g. one reason is to avoid circular references in the parser
//! objects when the callbacks are defined in them.
//!
//! Created 2000-01-21 by Martin Stjernholm
//!
//! $Id: utils.pmod,v 1.20 2001/04/18 04:51:42 mast Exp $


final string format_short (mixed val)
{
  if (stringp (val))
    if (sizeof (val) <= 30)
      return sprintf ("%O", val);
    else
      return sprintf ("%O/.../", val[..29]);
  else {
    val = sprintf ("%O", val);
    if (sizeof (val) <= 30)
      return val;
    else
      return val[..29] + "/.../";
  }
}

final array return_zero (mixed... ignored) {return 0;}
final array return_empty_array (mixed... ignored) {return ({});}

final int(1..1)|string|array free_text_error (object/*(RMXL.PXml)*/ p, string str)
{
  sscanf (str, "%[ \t\n\r]", string ws);
  if (str != ws)
    RXML.parse_error ("Free text %s is not allowed in context of type %s.\n",
		      format_short (String.trim_all_whites (str)), p->type->name);
  return ({});
}

final int(1..1)|string|array unknown_tag_error (object/*(RMXL.PXml)*/ p, string str)
{
  RXML.parse_error ("Unknown tag %s is not allowed in context of type %s.\n",
		    format_short (p->tag_name()), p->type->name);
  return ({});
}

final int(1..1)|string|array unknown_pi_tag_error (object/*(RMXL.PXml)*/ p, string str)
{
  sscanf (str, "%[^ \t\n\r]", str);
  RXML.parse_error (
    "Unknown processing instruction %s not allowed in context of type %s.\n",
    format_short ("<" + p->tag_name() + str), p->type->name);
  return ({});
}

final int(1..1)|string|array invalid_cdata_error (object/*(RXML.PXml)*/ p, string str)
{
  RXML.parse_error ("CDATA text %O is not allowed in context of type %s.\n",
		    format_short (str), p->type->name);
  return ({});
}

final int(1..1)|string|array output_error_cb (object/*(RMXL.PXml)*/ p, string str)
{
  if (p->errmsgs) str = p->errmsgs + str, p->errmsgs = 0;
  if (p->type->free_text) p->_set_data_callback (0);
  else p->_set_data_callback (free_text_error);
  return ({str});
}


// PXml and PEnt callbacks.

final int(1..1)|string|array p_xml_comment_cb (object/*(RXML.PXml)*/ p, string str)
// FIXME: This is a kludge until quote tags are handled like other tags.
{
  if (p->type->handle_literals) p->handle_literal();
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

final int(1..1)|string|array p_xml_cdata_cb (object/*(RXML.PXml)*/ p, string str)
{
  return ({str});
}

final int(1..1)|string|array p_xml_entity_cb (object/*(RXML.PXml)*/ p, string str)
{
  RXML.Type type = p->type;
  string entity = p->tag_name();
  if (sizeof (entity))
    if (entity[0] == '#') {
      if (!p->type->entity_syntax) {
	// Don't decode normal entities if we're outputting xml-like stuff.
	if (sscanf (entity,
		    (<"#x", "#X">)[entity[..1]] ? "%*2s%x%*c" : "%*c%d%*c",
		    int char) == 2)
	  catch (str = (string) ({char}));
	// Lax error handling: Just let it through if it can't be
	// converted. Not really good, though.
      }
    }
    else
      if (entity[0] == ':') str = entity[1..];
      else if (has_value (entity, ".")) {
	if (type->handle_literals) p->handle_literal();
	mixed value = p->handle_var (
	  entity,
	  // No quoting of splice args. FIXME: Add some sort of
	  // safeguard against splicing in things like "nice><evil
	  // stuff='...'"?
	  p->html_context() == "splice_arg" ? RXML.t_string : type);
	if (value != RXML.nil) {
	  if (type->free_text) return ({value});
	  p->add_value (value);
	}
	return ({});
      }
  if (!type->free_text)
    RXML.parse_error ("Unknown entity \"&%s;\" not allowed context of type %s.\n",
		      entity, type->name);
  return ({str});
}

final int(1..1)|string|array p_xml_compat_entity_cb (object/*(RMXL.PXml)*/ p, string str)
{
  RXML.Type type = p->type;
  string entity = p->tag_name();
  if (sizeof (entity) && entity[0] != '#')
    if (entity[0] == ':') str = entity[1..];
    else if (has_value (entity, ".")) {
      if (type->handle_literals) p->handle_literal();
      mixed value = p->handle_var (
	entity,
	// No quoting of splice args. FIXME: Add some sort of
	// safeguard against splicing in things like "nice><evil
	// stuff='...'"?
	p->html_context() == "splice_arg" ? RXML.t_string : p->type);
      if (value != RXML.nil) {
	if (type->free_text) return ({value});
	p->add_value (value);
      }
      return ({});
    }
  if (!type->free_text)
    RXML.parse_error ("Unknown entity \"&%s;\" not allowed in context of type %s.\n",
		      entity, type->name);
  return ({str});
}
