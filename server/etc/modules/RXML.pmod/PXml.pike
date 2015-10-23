//! The standard RXML content parser.
//!
//! Parses entities and tags according to XML syntax. Entities on the
//! form &scope.variable; are expanded with variables.
//!
//! Note: This parser does not conform to the XML specification in
//! some important ways:
//!
//! o  It does not understand DTD declarations.
//! o  It's not as restrictive in syntax as the standard requires,
//!    i.e. several construct that aren't well-formed are accepted
//!    without error.
//!
//! Created 1999-07-30 by Martin Stjernholm.
//!
//! $Id$

//#pragma strict_types // Disabled for now since it doesn't work well enough.

#include <config.h>

inherit Parser.HTML: low_parser;
inherit RXML.TagSetParser: TagSetParser;

constant unwind_safe = 1;

constant name = "xml";

#define EmptyTagFunc							\
  function(:int(1..1)|string|array)|					\
  function(Parser.HTML,mapping(string:string):				\
	   int(1..1)|string|array)

#define EmptyTagDef string|array|EmptyTagFunc

#define ContainerFunc							\
  function(:int(1..1)|string|array)|					\
  function(Parser.HTML,mapping(string:string),string:			\
	   int(1..1)|string|array)

#define ContainerDef string|array|ContainerFunc

#define QuoteTagFunc							\
  function(:int(1..1)|string|array)|					\
  function(Parser.HTML,string:						\
	   int(1..1)|string|array)

#define QuoteTagDef string|array|QuoteTagFunc

#define EntityDef							\
  string|array|								\
  function(void|Parser.HTML:int(1..1)|string|array) 

#define TagDef array(EmptyTagDef|ContainerDef)
// A tag definition is an array of ({noncontainer definition,
// container definition}).

// Kludge to get to the functions in Parser.HTML from inheriting
// programs.. :P
/*protected*/ this_program _low_add_tag (string name, EmptyTagDef tdef)
  {return [object(this_program)] low_parser::add_tag (name, tdef);}
/*protected*/ this_program _low_add_container (string name, ContainerDef tdef)
  {return [object(this_program)] low_parser::add_container (name, tdef);}
/*protected*/ this_program _low_add_quote_tag (string beg, QuoteTagDef tdef,
					       string end)
  {return [object(this_program)] low_parser::add_quote_tag (beg, tdef, end);}
protected this_program _low_clone (mixed... args)
  {return [object(this_program)] low_parser::clone (@args);}

string html_context() {return low_parser::context();}
string current_input() {return low_parser::current();}

constant reset = 0;

protected void set_quote_tag_cbs (QuoteTagDef unknown_pi_tag_cb,
				  QuoteTagDef cdata_cb)
{
  add_quote_tag ("!--", .utils.p_xml_comment_cb, "--");
  add_quote_tag ("?", unknown_pi_tag_cb, "?");
  add_quote_tag ("![CDATA[", cdata_cb, "]]");
}

this_program clone (RXML.Context ctx, RXML.Type type, RXML.PCode p_code,
		    RXML.TagSet tag_set)
{
#ifdef OLD_RXML_COMPAT
  int new_not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
  if (new_not_compat != not_compat) return this_program (ctx, type, p_code, tag_set);
#endif
  return [object(this_program)] low_parser::clone (
    ctx, type, p_code, tag_set, rt_replacements || 1, rt_pi_replacements);
}

#ifdef OLD_RXML_COMPAT
protected int not_compat = 1;
#endif

// Decide some alternative behaviors at initialization.
protected int alternative;
protected constant FREE_TEXT = 2;
protected constant FREE_TEXT_P_CODE = 3;
protected constant LITERALS = 4;
protected constant LITERALS_P_CODE = 5;
protected constant NO_LITERALS = 6;
protected constant NO_LITERALS_P_CODE = 7;

protected void create (
  RXML.Context ctx, RXML.Type type, RXML.PCode p_code, RXML.TagSet tag_set,
  void|int|mapping(string:TagDef) orig_rt_replacements,
  void|mapping(string:QuoteTagDef) orig_rt_pi_replacements
)
{
#ifdef OLD_RXML_COMPAT
  not_compat = !(ctx && ctx->id && ctx->id->conf->old_rxml_compat);
#endif

  if (type->free_text)
    alternative = FREE_TEXT;
  else {
    _set_tag_callback (.utils.unknown_tag_error);
    alternative = type->handle_literals ? LITERALS : NO_LITERALS;
  }

  initialize (ctx, type, p_code, tag_set);

  if (orig_rt_replacements) {	// We're cloned.
    if (mappingp (orig_rt_replacements))
      rt_replacements = orig_rt_replacements + ([]);
    if (orig_rt_pi_replacements)
      rt_pi_replacements = orig_rt_pi_replacements + ([]);
    return;
  }

#ifdef RXML_OBJ_DEBUG
  master_parser = 1;
  __object_marker->create (this_object());
#elif defined (OBJ_COUNT_DEBUG)
  master_parser = 1;
#endif

  array(RXML.TagSet) list = ({tag_set});
  array(string) plist = ({tag_set->prefix});

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

    // Note: Similar things done in add_runtime_tag() and add_runtime_pi_tag().

    if (prefix) {
#ifdef OLD_RXML_COMPAT
      if (not_compat) {
#endif
	foreach (tlist, RXML.Tag tag)
	  if (!(tag->plugin_name || tag->flags & RXML.FLAG_NO_PREFIX)) {
	    string name = prefix + ":" + [string] tag->name;
	    if (tag->flags & RXML.FLAG_PROC_INSTR)
	      add_quote_tag ("?" + name, tag->_p_xml_handle_pi_tag, "?");
	    else
	      add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
	  }
#ifdef OLD_RXML_COMPAT
      }
      else
	foreach (tlist, RXML.Tag tag)
	  if (!(tag->plugin_name || tag->flags & RXML.FLAG_NO_PREFIX)) {
	    string name = prefix + ":" + [string] tag->name;
	    if (tag->flags & RXML.FLAG_PROC_INSTR)
	      add_quote_tag ("?" + name, tag->_p_xml_handle_pi_tag, "?");
	    else
	      if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
		add_tag (name, tag->_p_xml_handle_tag), add_container (name, 0);
	      else
		add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
	  }
#endif
    }

#ifdef OLD_RXML_COMPAT
    if (not_compat) {
#endif
      foreach (tlist, RXML.Tag tag)
	if (!tag->plugin_name &&
	    (!tset->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX)) {
	  string name = [string] tag->name;
	  if (tag->flags & RXML.FLAG_PROC_INSTR)
	    add_quote_tag ("?" + name, tag->_p_xml_handle_pi_tag, "?");
	  else
	    if ((tag->flags & (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)) ==
		(RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT))
	      add_tag (name, tag->_p_xml_handle_tag), add_container (name, 0);
	    else
	      add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
	}
#ifdef OLD_RXML_COMPAT
    }
    else
      foreach (tlist, RXML.Tag tag)
	if (!tag->plugin_name &&
	    (!tset->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX)) {
	  string name = [string] tag->name;
	  if (tag->flags & RXML.FLAG_PROC_INSTR)
	    add_quote_tag ("?" + name, tag->_p_xml_handle_pi_tag, "?");
	  else
	    if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
	      add_tag (name, tag->_p_xml_handle_tag), add_container (name, 0);
	    else
	      add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
	}
#endif
  }

  if (!type->entity_syntax
#ifdef OLD_RXML_COMPAT
      && not_compat
#endif
     )
    // Don't decode normal entities if we're outputting xml-like stuff.
    add_entities (tag_set->get_string_entities());

  lazy_entity_end (1);
  match_tag (0);
  splice_arg ("::");
  xml_tag_syntax (2);

#ifdef OLD_RXML_COMPAT
  if (not_compat) {
#endif
    _set_entity_callback (.utils.p_xml_entity_cb);
    if (type->free_text)
      set_quote_tag_cbs (
	.utils.return_zero,
	// Decode CDATA sections if the type doesn't have xml syntax.
	type->entity_syntax ? .utils.return_zero : .utils.p_xml_cdata_cb);
    else
      set_quote_tag_cbs (
	.utils.unknown_pi_tag_error,
	type->handle_literals ? .utils.p_xml_cdata_cb : .utils.invalid_cdata_error);
#ifdef OLD_RXML_COMPAT
  }
  else {
    case_insensitive_tag (1);
    ignore_unknown (1);
    ws_before_tag_name (1);
    _set_entity_callback (.utils.p_xml_compat_entity_cb);
  }
#endif
}

protected void initialize (RXML.Context ctx, RXML.Type type,
			   RXML.PCode p_code, RXML.TagSet tag_set)
{
  TagSetParser::initialize (ctx, type, p_code, tag_set);

  if (type->sequential)
    if (type->empty_value == "")
      value = String.Buffer();
    else
      value = type->empty_value;
  else
    value = RXML.nil;

  if (p_code) alternative |= 1;
  else alternative &= ~1;
}

protected mixed value;

void add_value (mixed val)
{
  if (type->sequential)
    // Keep one ref to value. (This is probably not necessary in
    // modern pikes.)
    value = value + (value = 0, val);
  else {
    if (value != RXML.nil)
      RXML.parse_error (
	"Cannot append another value %s to non-sequential type %s.\n",
	.utils.format_short (val), type->name);
    value = val;
  }
}

void drain_output()
{
  switch (alternative) {
    case FREE_TEXT: {
      value = value + (value = 0, low_parser::read()); // Keep one ref to value.
      break;
    }

    case FREE_TEXT_P_CODE: {
      string literal = low_parser::read();
      value = value + (value = 0, literal); // Keep one ref to value.
      if (sizeof (literal)) p_code->add (context, literal, literal);
      break;
    }

    case LITERALS:
    case LITERALS_P_CODE:
      if (mixed err = catch {
	string literal = String.trim_all_whites (low_parser::read());
	if (sizeof (literal)) {
	  mixed newval;
	  if (type->sequential)
	    value = value + (value = 0, newval = type->encode (literal));
	  else {
	    if (value != RXML.nil)
	      RXML.parse_error (
		"Cannot append another value %s to non-sequential type %s.\n",
		.utils.format_short (literal), type->name);
	    value = newval = type->encode (literal);
	  }
	  if (p_code) p_code->add (context, newval, newval);
	}
      }) context->handle_exception (err, this_object(), p_code);
      break;

    case NO_LITERALS:
    case NO_LITERALS_P_CODE: {
      string literal = low_parser::read();
      sscanf (literal, "%[ \t\n\r]", string ws);
      if (literal != ws)
	context->handle_exception (
	  catch (RXML.parse_error (
		   "Free text %s is not allowed in context of type %s.\n",
		   .utils.format_short (literal), type->name)),
	  this_object(), p_code);
      break;
    }

    default:
      error ("Bogus alternative %d\n", alternative);
  }
}

mixed read()
{
  if (objectp (value) && object_program (value) == String.Buffer)
    return value->get();
  else {
    mixed val = value;
    value = RXML.nil;
    return val;
  }
}

protected string errmsgs;

int output_errors()
{
  if (errmsgs) {
    value = value + (value = 0, errmsgs); // Keep one ref to value.
    errmsgs = 0;
  }
}

int report_error (string msg)
{
  if (errmsgs) errmsgs += msg;
  else errmsgs = msg;
  if (low_parser::context() != "data")
    _set_data_callback (.utils.output_error_cb);
  else output_errors();
  return 1;
}

mixed feed (string in)
{
  return low_parser::feed (in);
}

void finish (void|string in)
{
  low_parser::finish (in);
  drain_output();
  output_errors();
  context->eval_finish();
}


// Runtime tags.

protected mapping(string:TagDef) rt_replacements;
protected mapping(string:QuoteTagDef) rt_pi_replacements;

local void add_runtime_tag (RXML.Tag tag)
{
  string name = tag->name;

  if (tag->flags & RXML.FLAG_PROC_INSTR) {
    if (!rt_pi_replacements) rt_pi_replacements = ([]);
    else remove_runtime_tag (tag);

    if (!tag_set->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX) {
      rt_pi_replacements[name] = quote_tags()[name];
      add_quote_tag ("?" + name, tag->_p_xml_handle_pi_tag, "?");
    }

    if (tag_set->prefix && !(tag->flags & RXML.FLAG_NO_PREFIX)) {
      name = tag_set->prefix + ":" + name;
      rt_pi_replacements[name] = quote_tags()[name];
      add_quote_tag ("?" + name, tag->_p_xml_handle_pi_tag, "?");
    }
  }

  else {
    if (!rt_replacements) rt_replacements = ([]);
    else remove_runtime_tag (tag);

    if (!tag_set->prefix_req || tag->flags & RXML.FLAG_NO_PREFIX) {
      rt_replacements[name] = ({tags()[name], containers()[name]});
#ifdef OLD_RXML_COMPAT
      if (not_compat)
#endif
	if ((tag->flags & (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)) ==
	    (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT))
	  add_tag (name, tag->_p_xml_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
#ifdef OLD_RXML_COMPAT
      else
	if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
	  add_tag (name, tag->_p_xml_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
#endif
    }

    if (tag_set->prefix && !(tag->flags & RXML.FLAG_NO_PREFIX)) {
      name = tag_set->prefix + ":" + name;
      rt_replacements[name] = ({tags()[name], containers()[name]});
#ifdef OLD_RXML_COMPAT
      if (not_compat)
#endif
	if ((tag->flags & (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)) ==
	    (RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT))
	  add_tag (name, tag->_p_xml_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
#ifdef OLD_RXML_COMPAT
      else
	if (tag->flags & RXML.FLAG_EMPTY_ELEMENT)
	  add_tag (name, tag->_p_xml_handle_tag), add_container (name, 0);
	else
	  add_tag (name, 0), add_container (name, tag->_p_xml_handle_tag);
#endif
    }
  }
}

local void remove_runtime_tag (string|RXML.Tag tag, void|int proc_instr)
{
  int no_prefix = 0;
  if (!stringp (tag)) {
    proc_instr = tag->flags & RXML.FLAG_PROC_INSTR;
    no_prefix = tag->flags & RXML.FLAG_NO_PREFIX;
    tag = tag->name;
  }

  if (proc_instr) {
    if (!stringp (tag)) {
      tag = tag->name;
      no_prefix = tag->flags & RXML.FLAG_NO_PREFIX;
    }

    if (!tag_set->prefix_req || no_prefix)
      if (TagDef def = rt_pi_replacements && rt_pi_replacements[tag]) {
	m_delete (rt_pi_replacements, tag);
	add_quote_tag ("?" + tag, def, "?");
      }
    if (tag_set->prefix && !no_prefix)
      if (TagDef def = rt_pi_replacements[tag = tag_set->prefix + ":" + tag]) {
	m_delete (rt_pi_replacements, tag);
	add_quote_tag ("?" + tag, def, "?");
      }
  }

  else {
    if (!tag_set->prefix_req || no_prefix)
      if (TagDef def = rt_replacements && rt_replacements[tag]) {
	m_delete (rt_replacements, tag);
	add_tag (tag, def[0]), add_container (tag, def[1]);
      }
    if (tag_set->prefix && !no_prefix)
      if (TagDef def = rt_replacements &&
	  rt_replacements[tag = tag_set->prefix + ":" + tag]) {
	m_delete (rt_replacements, tag);
	add_tag (tag, def[0]), add_container (tag, def[1]);
      }
  }
}

#if defined (OBJ_COUNT_DEBUG) || defined (RXML_OBJ_DEBUG)
protected int master_parser;
protected string _sprintf()
{
  return sprintf ("RXML.PXml(%s,%O,%O)%s",
		  master_parser ? "master" : "clone", type, tag_set,
		  __object_marker ? "[" + __object_marker->count + "]" : "");
}
#else
protected string _sprintf()
{
  return sprintf ("RXML.PXml(%O,%O)", type, tag_set);
}
#endif
