//! RXML parser and compiler framework.
//!
//! Created 1999-07-30 by Martin Stjernholm.
//!
//! $Id: module.pmod,v 1.109 2000/09/14 21:55:53 mast Exp $

//! Kludge: Must use "RXML.refs" somewhere for the whole module to be
//! loaded correctly.
static object Roxen;
class RequestID { };

//! API stability notes:
//!
//! The API in this file regarding the global functions and the Tag,
//! TagSet, Context, Frame and Type classes and their descendants is
//! intended to not change in incompatible ways. There are however
//! some areas where incompatible changes still must be expected:
//!
//! o  The namespace handling will likely change to conform to XML
//!    namespaces. The currently implemented system is inadequate then
//!    and will probably be removed.
//!
//! o  The semantics for caching and reuse of Frame objects is
//!    deliberatily documented vaguely (see the class doc for the
//!    Frame class). The currently implemented behavior will change
//!    when the cache system becomes reality. So never assume that
//!    you'll always get fresh Frame instances every time a tag is
//!    evaluated.
//!
//! o  The parser currently doesn't stream data according to the
//!    interface for streaming tags (but the implementation still
//!    follows the documented API for it). Therefore there's a risk
//!    that incompatible changes must be made in it due to design bugs
//!    when it's tested out. That is considered very unlikely, though.
//!
//! o  The type system will be developed further, and the API in the
//!    Type class might change as advanced types gets implemented.
//!    Don't make assumptions about undocumented behavior. Declare
//!    data properly with the types RXML.TXml, RXML.THtml and
//!    RXML.TText to let the parser handle the necessary conversions
//!    instead of doing it yourself. Try to avoid implementing types.
//!
//! o  Various utilities have FIXME's in their documentation. Needless
//!    to say they don't work as documented yet, and the doc should be
//!    considered as ideas only; it might work differently when it's
//!    actually implemented.
//!
//! Note that the API for parsers, p-code evaluators etc is not part
//! of the "official" API. (The syntax _parsed_ by the currently
//! implemented parsers is well defined, of course.)

//#pragma strict_types // Disabled for now since it doesn't work well enough.

#include <config.h>
#include <request_trace.h>

#ifdef RXML_OBJ_DEBUG
#  define MARK_OBJECT \
     Debug.ObjectMarker __object_marker = Debug.ObjectMarker (this_object())
#  define MARK_OBJECT_ONLY \
     Debug.ObjectMarker __object_marker = Debug.ObjectMarker (0)
#else
#  define MARK_OBJECT
#  define MARK_OBJECT_ONLY
#endif

#ifdef OBJ_COUNT_DEBUG
// This debug mode gives every object a unique number in the
// _sprintf() string.
#  ifndef RXML_OBJ_DEBUG
#    undef MARK_OBJECT
#    undef MARK_OBJECT_ONLY
#    define MARK_OBJECT \
       mapping __object_marker = (["count": ++all_constants()->_obj_count])
#    define MARK_OBJECT_ONLY \
       mapping __object_marker = (["count": ++all_constants()->_obj_count])
#  endif
#  define OBJ_COUNT (__object_marker ? "[" + __object_marker->count + "]" : "")
#else
#  define OBJ_COUNT ""
#endif

#ifdef DEBUG
#  define TAG_DEBUG(frame, msg) (frame)->tag_debug ("%O: %s", (frame), (msg))
#else
#  define TAG_DEBUG(frame, msg) 0
#endif

#define HASH_INT2(m, n) (n < 65536 ? (m << 16) + n : sprintf ("%x,%x", m, n))


class Tag
//! Interface class for the static information about a tag.
{
  constant is_RXML_Tag = 1;

  //! Interface.

  //!string name;
  //! The name of the tag. Required and considered constant.

  /*extern*/ int flags;
  //! Various bit flags that affect parsing; see the FLAG_* constants.
  //! RXML.Frame.flags is initialized from this.

  mapping(string:Type) req_arg_types = ([]);
  mapping(string:Type) opt_arg_types = ([]);
  //! The names and types of the required and optional arguments. If a
  //! type specifies a parser, it'll be used on the argument value.
  //! Note that the order in which arguments are parsed is arbitrary.

  Type def_arg_type = t_text (PEnt);
  //! The type used for arguments that isn't present in neither
  //! req_arg_types nor opt_arg_types. This default is a parser that
  //! only parses XML-style entities.

  Type content_type = t_same (PXml);
  //! The handled type of the content, if the tag gets any.
  //!
  //! This default is the special type t_same, which means the type is
  //! taken from the effective type of the result. The PXml argument
  //! causes the standard XML parser to be used to read it, which
  //! means that the content is preparsed with XML syntax. Use no
  //! parser to get the raw text.
  //!
  //! Note: You probably want to change this to t_text (without
  //! parser) if the tag is a processing instruction (see
  //! FLAG_PROC_INSTR).

  array(Type) result_types = ({t_xml, t_html, t_text});
  //! The possible types of the result, in order of precedence. If a
  //! result type has a parser, it'll be used to parse any strings in
  //! the exec array returned from Frame.do_enter() and similar
  //! callbacks.
  //!
  //! When the tag is used in content of some type, it suffices that
  //! the content type is a subtype of any type in result_types. The
  //! tag must therefore be prepared to produce result of more
  //! specific types than those declared here. I.e. the extreme case,
  //! t_any, means that this tag takes the responsibility to produce
  //! result of any type that's asked for, not that it has the liberty
  //! to produce results of any type it chooses.

  //!program Frame;
  //!object(Frame) Frame();
  //! This program/function is used to clone the objects used as
  //! frames. A frame object must (in practice) inherit RXML.Frame.
  //! (It can, of course, be any function that requires no arguments
  //! and returns a new frame object.) This is not used for plugin
  //! tags.

  //!string plugin_name;
  //! If this is defined, this is a so-called plugin tag. That means
  //! it plugs in some sort of functionality in another Tag object
  //! instead of handling the actual tags of its own. It works as
  //! follows:
  //!
  //! o  Instead of installing the callbacks for this tag, the parser
  //!    uses another registered "socket" Tag object that got the same
  //!    name as this one. Socket tags have the FLAG_SOCKET_TAG flag
  //!    set to signify that they accept plugins.
  //!
  //! o  When the socket tag is parsed or evaluated, it can get the
  //!    Tag objects for the registered plugins with the function
  //!    Frame.get_plugins(). It's then up to the socket tag to use
  //!    the plugins according to some API it defines.
  //!
  //! o  plugin_name is the name of the plugin. It's used as index in
  //!    the mapping that the Frame.get_plugins() returns.
  //!
  //! o  The plugin tag is registered in the tag set with the
  //!    identifier
  //!
  //!			name + "#" + plugin_name
  //!
  //!	 It overrides other plugin tags with that name according to
  //!    the normal tag set rules, but, as said above, is never
  //!    registered for actual parsing at all.
  //!
  //!    It's undefined whether plugin tags override normal tags --
  //!    '#' should never be used in normal tag names.
  //!
  //! o  It's not an error to register a plugin for which there is no
  //!    socket. Such plugins are simply ignored.

  //! Services.

  inline object/*(Frame)HMM*/ `() (mapping(string:mixed) args, void|mixed content)
  //! Make an initialized frame for the tag. Typically useful when
  //! returning generated tags from e.g. RXML.Frame.do_process(). The
  //! argument values and the content are normally not parsed.
  {
    Tag this = this_object();
    object/*(Frame)HMM*/ frame = ([function(:object/*(Frame)HMM*/)] this->Frame)();
    frame->tag = this;
    frame->flags = flags;
    frame->args = args;
    frame->content = zero_type (content) ? nil : content;
    frame->result = nil;
    return frame;
  }

  int eval_args (mapping(string:mixed) args, void|int dont_throw, void|Context ctx)
  //! Parses and evaluates the tag arguments according to
  //! req_arg_types and opt_arg_types. The args mapping contains the
  //! unparsed arguments on entry, and they get replaced by the parsed
  //! results. Arguments not mentioned in req_arg_types or
  //! opt_arg_types are not touched. RXML errors, such as missing
  //! argument, are thrown if dont_throw is zero or left out,
  //! otherwise zero is returned for such errors. ctx specifies the
  //! context to use; it defaults to the current context.
  {
    // Note: Code duplication in Frame._eval().
    mapping(string:Type) atypes = args & req_arg_types;
    if (sizeof (atypes) < sizeof (req_arg_types))
      if (dont_throw) return 0;
      else {
	array(string) missing = sort (indices (req_arg_types - atypes));
	parse_error ("Required " +
		     (sizeof (missing) > 1 ?
		      "arguments " + String.implode_nicely (missing) + " are" :
		      "argument " + missing[0] + " is") + " missing.\n");
      }
    atypes += args & opt_arg_types;
#ifdef MODULE_DEBUG
    if (mixed err = catch {
#endif
      foreach (indices (atypes), string arg)
	args[arg] = atypes[arg]->eval (args[arg], ctx); // Should not unwind.
#ifdef MODULE_DEBUG
    }) {
      if (objectp (err) && ([object] err)->thrown_at_unwind)
	fatal_error ("Can't save parser state when evaluating arguments.\n");
      throw_fatal (err);
    }
#endif
    return 1;
  }

  // Internals.

  array _handle_tag (TagSetParser parser, mapping(string:string) args,
		     void|string content)
  // Callback for tag set parsers to handle non-PI tags. Returns a
  // sequence of result values to be added to the result queue. Note
  // that this function handles an unwind frame for the parser.
  {
    // Note: args may be zero since this is called from _handle_pi_tag().

    Context ctx = parser->context;
    // FIXME: P-code generation.

    string splice_args;
    if (args && (splice_args = args["::"])) {
      // Somewhat kludgy solution for the time being.
#ifdef MODULE_DEBUG
      if (mixed err = catch {
#endif
	splice_args = t_text (PEnt)->eval (splice_args, ctx, 0, parser, 1);
#ifdef MODULE_DEBUG
      }) {
	if (objectp (err) && ([object] err)->thrown_at_unwind)
	  fatal_error ("Can't save parser state when evaluating splice argument.\n");
	throw_fatal (err);
      }
#endif
      m_delete (args, "::");
      args += parser->parse_tag_args (splice_args);
    }

    object/*(Frame)HMM*/ frame;
    do {
      if (mapping(string:mixed)|mapping(object:array) ustate = ctx->unwind_state)
	if (ustate[parser]) {
	  frame = [object/*(Frame)HMM*/] ustate[parser][0];
	  m_delete (ustate, parser);
	  if (!sizeof (ustate)) ctx->unwind_state = 0;
	  break;
	}
      frame = `() (args, nil);
      TAG_DEBUG (frame, "New frame\n");
    } while (0);		// The break goes here.

    if (!zero_type (frame->raw_tag_text)) {
      if (splice_args)
	frame->raw_tag_text =
	  t_xml->format_tag (parser->tag_name(), args, content, flags | FLAG_RAW_ARGS);
      else frame->raw_tag_text = parser->current_input();
    }

    mixed err = catch {
      frame->_eval (parser, args, content);
      mixed res;
      if ((res = frame->result) == nil) return ({});
      if (frame->result_type->encoding_type ?
	  frame->result_type->encoding_type != parser->type->encoding_type :
	  frame->result_type != parser->type) {
	TAG_DEBUG (frame, sprintf (
		     "Converting result from %s to %s of surrounding content\n",
		     frame->result_type->name, parser->type->name));
	res = parser->type->encode (res, frame->result_type);
      }
      return ({res});
    };

    if (objectp (err) && ([object] err)->thrown_at_unwind) {
      mapping(string:mixed)|mapping(object:array) ustate = ctx->unwind_state;
      if (!ustate) ustate = ctx->unwind_state = ([]);
#ifdef DEBUG
      if (err != frame)
	fatal_error ("Internal error: Unexpected unwind object catched.\n");
      if (ustate[parser])
	fatal_error ("Internal error: Clobbering unwind state for parser.\n");
#endif
      ustate[parser] = ({err});
      throw (err = parser);
    }
    else {
      ctx->handle_exception (err, parser); // Will rethrow unknown errors.
      return ({});
    }
  }

  array _handle_pi_tag (TagSetParser parser, string content)
  // Callback similar to _handle_tag() for tag set parsers to handle
  // PI tags.
  {
    sscanf (content, "%[ \t\n\r]%s", string ws, string rest);
    if (ws == "" && rest != "")
      // The parser didn't match a complete name, so this is a false
      // alarm for an unknown PI tag.
      return 0;
    return _handle_tag (parser, 0, content);
  }

  /* Can't define `== here due to Pike bugs..
  int __hash()
  {
    return hash (this_object()->name);
  }

  int `== (mixed other)
  {
    return objectp (other) && other->is_RXML_Tag && other->name == this_object()->name;
  }
  */

  MARK_OBJECT;

  string _sprintf()
  {
    return "RXML.Tag(" + [string] this_object()->name +
      (this_object()->plugin_name ? "#" + [string] this_object()->plugin_name : "") +
      ([int] this_object()->flags & FLAG_PROC_INSTR ? " [PI]" : "") + ")" +
      OBJ_COUNT;
  }
}


class TagSet
//! Contains a set of tags. Tag sets can import other tag sets, and
//! later changes are propagated. Parser instances (contexts) to parse
//! data are created from this. TagSet objects may somewhat safely be
//! destructed explicitly; the tags in a destructed tag set will not
//! be active in parsers that are instantiated later, but will work in
//! current instances. Element (i.e. non-PI) tags and PI tags have
//! separate namespaces.
//!
//! Note: A Tag object may not be registered in more than one tag set
//! at the same time.
{
  string name;
  //! Used for identification only.

  string prefix;
  //! A namespace prefix that may precede the tags. If it's zero, it's
  //! up to the importing tag set(s). A ':' is always inserted between
  //! the prefix and the tag name.

  int prefix_req;
  //! The prefix must precede the tags.

  array(TagSet) imported = ({});
  //! Other tag sets that will be used. The precedence is local tags
  //! first, then imported from left to right. It's not safe to
  //! destructively change entries in this array.

  function(Context:void) prepare_context;
  //! If set, this is a function that will be called before a new
  //! Context object is taken into use. It'll typically prepare
  //! predefined scopes and variables. The functions will be called in
  //! order of precedence; highest last.

  int generation = 1;
  //! A number that is increased every time something changes in this
  //! object or in some tag set it imports.

  int id_number;
  //! Unique number identifying this tag set.

  static void create (string _name, void|array(Tag) _tags)
  //!
  {
    id_number = ++tag_set_count;
    name = _name;
    if (_tags) add_tags (_tags);
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  void add_tag (Tag tag)
  //!
  {
#ifdef MODULE_DEBUG
    if (!stringp (tag->name))
      error ("Trying to register a tag %O without a name.\n", tag);
    if (!functionp (tag->Frame) && !tag->plugin_name)
      error ("Trying to register a tag %O without a Frame class or function.\n", tag);
    if (tag->name[..3] != "!--#" && // Ugly special case for SSI tags.
	replace (tag->name, "#<>& \t\n\r" / "", ({""}) * 8) != tag->name)
      error ("Invalid character(s) in name for tag %O.\n", tag);
#endif
    if (tag->flags & FLAG_PROC_INSTR) {
      if (!proc_instrs) proc_instrs = ([]);
      if (tag->plugin_name) proc_instrs[tag->name + "#" + tag->plugin_name] = tag;
      else proc_instrs[tag->name] = tag;
    }
    else
      if (tag->plugin_name) tags[tag->name + "#" + tag->plugin_name] = tag;
      else tags[tag->name] = tag;
    changed();
  }

  void add_tags (array(Tag) _tags)
  //!
  {
    foreach (_tags, Tag tag) {
#ifdef MODULE_DEBUG
      if (!stringp (tag->name))
	error ("Trying to register a tag %O without a name.\n", tag);
      if (!functionp (tag->Frame) && !tag->plugin_name)
	error ("Trying to register a tag %O without a Frame class or function.\n", tag);
      if (tag->name[..3] != "!--#" && // Ugly special case for SSI tags.
	  replace (tag->name, "#<>& \t\n\r" / "", ({""}) * 8) != tag->name)
	error ("Invalid character(s) in name for tag %O.\n", tag);
#endif
      if (tag->flags & FLAG_PROC_INSTR) {
	if (!proc_instrs) proc_instrs = ([]);
	if (tag->plugin_name) proc_instrs[tag->name + "#" + tag->plugin_name] = tag;
	else proc_instrs[tag->name] = tag;
      }
      else
	if (tag->plugin_name) tags[tag->name + "#" + tag->plugin_name] = tag;
	else tags[tag->name] = tag;
    }
    changed();
  }

  void remove_tag (string|Tag tag, void|int proc_instr)
  //! If tag is a Tag object, it's removed if this tag set contains
  //! it. If tag is a string, the tag with that name is removed. In
  //! the latter case, if proc_instr is nonzero the set of PI tags is
  //! searched, else the set of normal element tags.
  {
    if (stringp (tag))
      if (proc_instr) {
	if (proc_instrs) m_delete (proc_instrs, tag);
      }
      else
	m_delete (tags, tag);
    else {
      string n;
      if (tag->flags & FLAG_PROC_INSTR) {
	if (proc_instrs && !zero_type (n = search (tags, [object(Tag)] tag)))
	  m_delete (proc_instrs, n);
      }
      else
	if (!zero_type (n = search (tags, [object(Tag)] tag)))
	  m_delete (tags, n);
    }
    changed();
  }

  local Tag get_local_tag (string name, void|int proc_instr)
  //! Returns the Tag object for the given name in this tag set, if
  //! any. If proc_instr is nonzero the set of PI tags is searched,
  //! else the set of normal element tags.
  {
    return proc_instr ? proc_instrs && proc_instrs[name] : tags[name];
  }

  local array(Tag) get_local_tags()
  //! Returns all the Tag objects in this tag set.
  {
    array(Tag) res = values (tags);
    if (proc_instrs) res += values (proc_instrs);
    return res;
  }

  local Tag get_tag (string name, void|int proc_instr)
  //! Returns the Tag object for the given name, if any, that's
  //! defined by this tag set (including its imported tag sets). If
  //! proc_instr is nonzero the set of PI tags is searched, else the
  //! set of normal element tags.
  {
    if (object(Tag) def = get_local_tag (name, proc_instr))
      return def;
    foreach (imported, TagSet tag_set)
      if (object(Tag) tag = [object(Tag)] tag_set->get_tag (name, proc_instr))
	return tag;
    return 0;
  }

  local int has_tag (Tag tag)
  //! Returns nonzero if the given tag is contained in this tag set
  //! (including its imported tag sets).
  {
    return !!get_tag (tag->name, tag->flags & FLAG_PROC_INSTR);
  }

  local multiset(string) get_tag_names()
  //! Returns the names of all non-PI tags that this tag set defines.
  {
    return `| ((multiset) indices (tags), @imported->get_tag_names());
  }

  local multiset(string) get_proc_instr_names()
  //! Returns the names of all PI tags that this tag set defines.
  {
    return `| (proc_instrs ? (multiset) indices (proc_instrs) : (<>),
	       @imported->get_proc_instr_names());
  }

  local Tag get_overridden_tag (Tag overrider)
  //! Returns the tag definition that the given one overrides, or zero
  //! if none.
  {
    if (!mappingp (overridden_tag_lookup))
      overridden_tag_lookup = set_weak_flag (([]), 1);
    Tag tag;
    if (zero_type (tag = overridden_tag_lookup[overrider]))
      tag = overridden_tag_lookup[overrider] =
	overrider->flags & FLAG_PROC_INSTR ?
	find_overridden_proc_instr (overrider) :
	find_overridden_tag (overrider);
    return tag;
  }

  local array(Tag) get_overridden_tags (string name, void|int proc_instr)
  //! Returns all tag definitions for the given name, i.e. including
  //! the overridden ones. A tag to the left overrides one to the
  //! right. If proc_instr is nonzero the set of PI tags is searched,
  //! else the set of normal element tags.
  {
    if (object(Tag) def = get_local_tag (name, proc_instr))
      return ({def}) + imported->get_overridden_tags (name, proc_instr) * ({});
    else
      return imported->get_overridden_tags (name, proc_instr) * ({});
  }

  void add_string_entities (mapping(string:string) entities)
  //! Adds a set of entitity replacements that are used foremost by
  //! the PXml parser to decode simple entities like &amp;. The
  //! indices are the entity names without & and ;.
  {
    if (string_entities) string_entities |= entities;
    else string_entities = entities + ([]);
    changed();
  }

  void clear_string_entities()
  //!
  {
    string_entities = 0;
    changed();
  }

  local mapping(string:string) get_string_entities()
  //! Returns the set of entity replacements, including those from
  //! imported tag sets.
  {
    if (string_entities)
      return `+(@imported->get_string_entities(), string_entities);
    else
      return `+(@imported->get_string_entities(), ([]));
  }

  local mapping(string:Tag) get_plugins (string name, void|int proc_instr)
  //! Returns the registered plugins for the given tag name. Don't be
  //! destructive on the returned mapping. If proc_instr is nonzero,
  //! the function searches for processing instruction plugins,
  //! otherwise it searches for plugins to normal element tags.
  {
    mapping(string:Tag) res;
    if (proc_instr) {
      if (!pi_plugins) pi_plugins = ([]);
      if ((res = pi_plugins[name])) return res;
      low_get_pi_plugins (name + "#", res = ([]));
      return pi_plugins[name] = res;
    }
    else {
      if (!plugins) plugins = ([]);
      if ((res = plugins[name])) return res;
      low_get_plugins (name + "#", res = ([]));
      return plugins[name] = res;
    }
  }

  local int has_effective_tags (TagSet tset)
  //! This one deserves some explanation.
  {
    return tset == top_tag_set && !got_local_tags;
  }

  local mixed `->= (string var, mixed val)
  {
    switch (var) {
      case "imported":
	if (!val) return val;	// Pike can call us with 0 as part of an optimization.
	filter (imported, "dont_notify", changed);
	imported = [array(TagSet)] val;
	imported->do_notify (changed);
	top_tag_set = sizeof (imported) && imported[0];
	break;
      default:
	::`->= (var, val);
    }
    changed();
    return val;
  }

  local mixed `[]= (string var, mixed val) {return `->= (var, val);}

  Parser `() (Type top_level_type, void|RequestID id)
  //! Creates a new context for parsing content of the specified type,
  //! and returns the parser object for it. id is put into the
  //! context.
  {
    Context ctx = Context (this_object(), id);
    if (!prepare_funs) prepare_funs = get_prepare_funs();
    (prepare_funs -= ({0})) (ctx);
    return ctx->new_parser (top_level_type);
  }

  void changed()
  //! Should be called whenever something is changed. Done
  //! automatically most of the time, however.
  {
    generation++;
    prepare_funs = 0;
    overridden_tag_lookup = 0;
    plugins = pi_plugins = 0;
    (notify_funcs -= ({0}))();
    set_weak_flag (notify_funcs, 1);
    got_local_tags = sizeof (tags) || (proc_instrs && sizeof (proc_instrs));
  }

  // Internals.

  void do_notify (function(:void) func)
  {
    notify_funcs |= ({func});
    set_weak_flag (notify_funcs, 1);
  }

  void dont_notify (function(:void) func)
  {
    notify_funcs -= ({func});
    set_weak_flag (notify_funcs, 1);
  }

  void destroy()
  {
    catch (changed());
  }

  static mapping(string:Tag) tags = ([]), proc_instrs;
  // Static since we want to track changes in these.

  static mapping(string:string) string_entities;
  // Used by e.g. PXml to hold normal entities that should be replaced
  // during parsing.

  static TagSet top_tag_set;
  // The imported tag set with the highest priority.

  static int got_local_tags;
  // Nonzero if there are local element tags or PI tags.

  static array(function(:void)) notify_funcs = ({});
  // Weak (when nonempty).

  static array(function(Context:void)) prepare_funs;

  /*static*/ array(function(Context:void)) get_prepare_funs()
  {
    if (prepare_funs) return prepare_funs;
    array(function(Context:void)) funs = ({});
    for (int i = sizeof (imported) - 1; i >= 0; i--)
      funs += imported[i]->get_prepare_funs();
    if (prepare_context) funs += ({prepare_context});
    // We don't cache in prepare_funs; do that only at the top level.
    return funs;
  }

  static mapping(Tag:Tag) overridden_tag_lookup;

  /*static*/ Tag find_overridden_tag (Tag overrider)
  {
    if (tags[overrider->name] == overrider) {
      foreach (imported, TagSet tag_set)
	if (object(Tag) overrider = tag_set->get_tag (overrider->name))
	  return overrider;
    }
    else {
      int found = 0;
      foreach (imported, TagSet tag_set)
	if (object(Tag) subtag = tag_set->get_tag (overrider->name))
	  if (found) return subtag;
	  else if (subtag == overrider)
	    if ((subtag = tag_set->find_overridden_tag (overrider)))
	      return subtag;
	    else found = 1;
    }
    return 0;
  }

  /*static*/ Tag find_overridden_proc_instr (Tag overrider)
  {
    if (proc_instrs && proc_instrs[overrider->name] == overrider) {
      foreach (imported, TagSet tag_set)
	if (object(Tag) overrider = tag_set->get_proc_instr (overrider->name))
	  return overrider;
    }
    else {
      int found = 0;
      foreach (imported, TagSet tag_set)
	if (object(Tag) subtag = tag_set->get_proc_instr (overrider->name))
	  if (found) return subtag;
	  else if (subtag == overrider)
	    if ((subtag = tag_set->find_overridden_proc_instr (overrider)))
	      return subtag;
	    else found = 1;
    }
    return 0;
  }

  void call_prepare_funs (Context ctx)
  // Kludge function used from rxml.pike.
  {
    if (!prepare_funs) prepare_funs = get_prepare_funs();
    (prepare_funs -= ({0})) (ctx);
  }

  static mapping(string:mapping(string:Tag)) plugins, pi_plugins;

  /*static*/ void low_get_plugins (string prefix, mapping(string:Tag) res)
  {
    for (int i = sizeof (imported) - 1; i >= 0; i--)
      imported[i]->low_get_plugins (prefix, res);
    foreach (indices (tags), string name)
      if (name[..sizeof (prefix) - 1] == prefix) {
	Tag tag = tags[name];
	if (tag->plugin_name) res[[string] tag->plugin_name] = tag;
      }
    // We don't cache in plugins; do that only at the top level.
  }

  /*static*/ void low_get_pi_plugins (string prefix, mapping(string:Tag) res)
  {
    for (int i = sizeof (imported) - 1; i >= 0; i--)
      imported[i]->low_get_pi_plugins (prefix, res);
    if (proc_instrs)
      foreach (indices (proc_instrs), string name)
	if (name[..sizeof (prefix) - 1] == prefix) {
	  Tag tag = proc_instrs[name];
	  if (tag->plugin_name) res[[string] tag->plugin_name] = tag;
	}
    // We don't cache in pi_plugins; do that only at the top level.
  }

  string _sprintf()
  {
    return sprintf ("RXML.TagSet(%O,%d)%s", name, id_number, OBJ_COUNT);
  }

  MARK_OBJECT_ONLY;
}

TagSet empty_tag_set;
//! The empty tag set.


class Value
//! Interface for objects used as variable values that are evaluated
//! when referenced.
{
  mixed rxml_var_eval (Context ctx, string var, string scope_name, void|Type type)
  //! This is called to get the value of the variable. ctx, var and
  //! scope_name are set to where this Value object was found.
  //!
  //! If the type argument is given, it's the type the returned value
  //! should have. If the value can't be converted to that type, an
  //! RXML error should be thrown. If you don't want to do any special
  //! handling of this, it's enough to call type->encode(value),
  //! since the encode functions does just that.
  {
    mixed val = rxml_const_eval (ctx, var, scope_name, type);
    ctx->set_var(var, val, scope_name);
    return val;
  }

  mixed rxml_const_eval (Context ctx, string var, string scope_name, void|Type type);
  //! If the variable value is the same throughout the life of the context,
  //! this method could be used instead of rxml_var_eval.

  string _sprintf() {return "RXML.Value";}
}

class Scope
//! Interface for objects that emulates a scope mapping.
{
  mixed `[] (string var, void|Context ctx, void|string scope_name)
    {parse_error ("Cannot query variable" + _in_the_scope (scope_name) + ".\n");}

  mixed `[]= (string var, mixed val, void|Context ctx, void|string scope_name)
    {parse_error ("Cannot set variable" + _in_the_scope (scope_name) + ".\n");}

  array(string) _indices (void|Context ctx, void|string scope_name)
    {parse_error ("Cannot list variables" + _in_the_scope (scope_name) + ".\n");}

  void m_delete (string var, void|Context ctx, void|string scope_name)
    {parse_error ("Cannot delete variable" + _in_the_scope (scope_name) + ".\n");}

  private string _in_the_scope (string scope_name)
  {
    if (scope_name)
      if (scope_name != "_") return " in the scope " + scope_name;
      else return " in the current scope";
    else return "";
  }

  string _sprintf() {return "RXML.Scope";}
}

#define SCOPE_TYPE mapping(string:mixed)|object(Scope)

class Context
//! A parser context. This contains the current variable bindings and
//! so on. The current context can always be retrieved with
//! get_context().
//!
//! Note: Don't store pointers to this object since that will likely
//! introduce circular references. It can be retrieved easily through
//! get_context() or parser->context.
{
  Frame frame;
  //! The currently evaluating frame.

  int frame_depth;
  //! Number of frames currently on the frame stack.

  int max_frame_depth = 100;
  //! Maximum number of frames allowed on the frame stack.

  RequestID id;
  //!

  int type_check;
  //! Whether to do type checking.

  int error_count;
  //! Number of RXML errors that has occurred.

  TagSet tag_set;
  //! The current tag set that will be inherited by subparsers.

#ifdef OLD_RXML_COMPAT
  int compatible_scope = 0;
  //! If set, the default scope is form, otherwise it is the present
  //! scope.
#endif

  array parse_user_var (string var, void|string scope_name)
  //! Tries to decide what variable and scope to use. Handles cases
  //! where the variable also contains the scope, e.g. "scope.var".
  {
    if(!var || !sizeof(var)) return ([])[0];
    if(scope_name) return ({ scope_name, var });
    array(string) splitted = Array.map( replace(var, "..", ";") / ".",
					lambda(string in) { return replace(in, ";", "."); });
    if(sizeof(splitted)>2) splitted[-1] = splitted[1..]*".";
    if(sizeof(splitted)==2)
      scope_name=splitted[0];
#ifdef OLD_RXML_COMPAT
    else if (compatible_scope)
      scope_name = scope_name || "form";
#endif
    return ({ scope_name, splitted[-1] });
  }

  local mixed get_var (string var, void|string scope_name, void|Type want_type)
  //! Returns the value a variable in the specified scope, or the
  //! current scope if none is given. Returns zero with zero_type 1 if
  //! there's no such variable.
  //!
  //! If the type argument is set, the value is converted to that type
  //! with Type.encode(). If the value can't be converted, an RXML
  //! error is thrown.
  {
    if (SCOPE_TYPE vars = scopes[scope_name || "_"]) {
      mixed val;
      if (objectp (vars)) {
	if (zero_type (val = ([object(Scope)] vars)->`[] (
			 var, this_object(), scope_name || "_")) ||
	    val == nil)
	  return ([])[0];
      }
      else
	if (zero_type (val = vars[var]))
	  return ([])[0];
      if (objectp (val) && ([object] val)->rxml_var_eval) {
	return
	  zero_type (val = ([object(Value)] val)->rxml_var_eval (
		       this_object(), var, scope_name || "_", want_type)) ||
	  val == nil ? ([])[0] : val;
      }
      else
	if (want_type)
	  return
	    // FIXME: Some system to find out the source type?
	    zero_type (val = want_type->encode (val)) ||
	    val == nil ? ([])[0] : val;
	else
	  return val;
    }
    else if ((<0, "_">)[scope_name]) parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  mixed user_get_var (string var, void|string scope_name, void|Type want_type)
  //! As get_var, but can handle cases where the variable also
  //! contains the scope, e.g. "scope.var".
  {
    if(!var || !sizeof(var)) return ([])[0];
    if(scope_name) return get_var(var, scope_name, want_type);
    array(string) splitted = Array.map( replace(var, "..", ";") / ".",
					lambda(string in) { return replace(in, ";", "."); });
    if(sizeof(splitted)>2) splitted[-1] = splitted[1..]*".";
    if(sizeof(splitted)==2)
      scope_name=splitted[0];
#ifdef OLD_RXML_COMPAT
    else if (compatible_scope)
      scope_name = scope_name || "form";
#endif
    return get_var(splitted[-1], scope_name, want_type);
  }

  local mixed set_var (string var, mixed val, void|string scope_name)
  //! Sets the value of a variable in the specified scope, or the
  //! current scope if none is given. Returns val.
  {
    if (SCOPE_TYPE vars = scopes[scope_name || "_"])
      if (objectp (vars))
	return ([object(Scope)] vars)->`[]= (var, val, this_object(), scope_name || "_");
      else
	return vars[var] = val;
    else if ((<0, "_">)[scope_name]) parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  mixed user_set_var (string var, mixed val, void|string scope_name)
  //! As set_var, but can handle cases where the variable also
  //! contains the scope, e.g. "scope.var".
  {
    if(!var || !sizeof(var)) parse_error ("No variable specified.\n");
    if(scope_name) return set_var(var, val, scope_name);
    array(string) splitted = Array.map( replace(var, "..", ";") / ".",
					lambda(string in) { return replace(in, ";", "."); });
    if(sizeof(splitted)>2) splitted[-1] = splitted[1..]*".";
    if(sizeof(splitted)==2)
      scope_name=splitted[0];
#ifdef OLD_RXML_COMPAT
    else if (compatible_scope)
      scope_name = scope_name || "form";
#endif
    return set_var(splitted[-1], val, scope_name);
  }

  local void delete_var (string var, void|string scope_name)
  //! Removes a variable in the specified scope, or the current scope
  //! if none is given.
  {
    if (SCOPE_TYPE vars = scopes[scope_name || "_"])
      if (objectp (vars))
	([object(Scope)] vars)->m_delete (var, this_object(), scope_name || "_");
      else
	m_delete ([mapping(string:mixed)] vars, var);
    else if ((<0, "_">)[scope_name]) parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  void user_delete_var (string var, void|string scope_name)
  //! As delete_var, but can handle cases where the variable also
  //! contains the scope, e.g. "scope.var".
  {
    if(!var || !sizeof(var)) return;
    if(scope_name) {
      delete_var(var, scope_name);
      return;
    }
    array(string) splitted = Array.map( replace(var, "..", ";") / ".",
					lambda(string in) { return replace(in, ";", "."); });
    if(sizeof(splitted)>2) splitted[-1] = splitted[1..]*".";
    if(sizeof(splitted)==2)
      scope_name=splitted[0];
#ifdef OLD_RXML_COMPAT
    else if (compatible_scope)
      scope_name = scope_name || "form";
#endif
    delete_var(splitted[-1], scope_name);
  }

  array(string) list_var (void|string scope_name)
  //! Returns the names of all variables in the specified scope, or
  //! the current scope if none is given.
  {
    if (SCOPE_TYPE vars = scopes[scope_name || "_"])
      if (objectp (vars))
	return ([object(Scope)] vars)->_indices (this_object(), scope_name || "_");
      else
	return indices ([mapping(string:mixed)] vars);
    else if ((<0, "_">)[scope_name]) parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  array(string) list_scopes()
  //! Returns the names of all defined scopes.
  {
    return indices (scopes) - ({"_"});
  }

  int exist_scope (void|string scope_name)
  //!
  {
    return !!scopes[scope_name || "_"];
  }

  void add_scope (string scope_name, SCOPE_TYPE vars)
  //! Adds or replaces the specified scope at the global level. A
  //! scope can be a mapping or a Scope object. A global "_" scope may
  //! also be defined this way.
  {
    if (scopes[scope_name])
      if (scope_name == "_") {
	array(SCOPE_TYPE) hid;
	for (Frame f = frame; f; f = f->up)
	  if (array(SCOPE_TYPE) h = hidden[f]) hid = h;
	if (hid) hid[0] = vars;
	else scopes["_"] = vars;
      }
      else {
	Frame outermost;
	for (Frame f = frame; f; f = f->up)
	  if (f->scope_name == scope_name) outermost = f;
	if (outermost) hidden[outermost][1] = vars;
	else scopes[scope_name] = vars;
      }
    else scopes[scope_name] = vars;
  }

  int extend_scope (string scope_name, SCOPE_TYPE vars)
  //! Adds or extends the specified scope at the global level.
  //! Returns 1 on success and 0 on failure.
  {
    if (scopes[scope_name]) {
      SCOPE_TYPE oldvars;
      if (scope_name == "_") {
	array(SCOPE_TYPE) hid;
	for (Frame f = frame; f; f = f->up)
	  if (array(SCOPE_TYPE) h = hidden[f]) hid = h;
	if (hid) oldvars = hid[0];
	else oldvars = scopes["_"];
      }
      else {
	Frame outermost;
	for (Frame f = frame; f; f = f->up)
	  if (f->scope_name == scope_name) outermost = f;
	if (outermost) oldvars = hidden[outermost][1];
	else oldvars = scopes[scope_name];
      }
#ifdef DEBUG
      if (!oldvars) fatal_error ("Internal error: I before e except after c.\n");
#endif
      if (!mappingp(vars)) {
	return 0;
      }
      foreach (indices(vars), string var)
	set_var(var, vars[var], scope_name);
    }
    else scopes[scope_name] = vars;
    return 1;
  }

  void remove_scope (string scope_name)
  //! Removes the named scope from the global level, if it exists.
  {
#ifdef MODULE_DEBUG
    if (scope_name == "_") fatal_error ("Cannot remove current scope.\n");
#endif
    Frame outermost;
    for (Frame f = frame; f; f = f->up)
      if (f->scope_name == scope_name) outermost = f;
    if (outermost) m_delete (hidden, outermost);
    else m_delete (scopes, scope_name);
  }

  string current_scope()
  //! Returns the name of the current scope, if it has any.
  {
    if (SCOPE_TYPE vars = scopes["_"]) {
      string scope_name;
      while (scope_name = search (scopes, vars, scope_name))
	if (scope_name != "_") return scope_name;
    }
    return 0;
  }

  void add_runtime_tag (Tag tag)
  //! Adds a tag that will exist from this point forward in the
  //! current context only.
  {
#ifdef MODULE_DEBUG
    if (tag->plugin_name)
      fatal_error ("Can't currently handle adding of plugin tags at runtime.\n");
#endif
    if (!new_runtime_tags) new_runtime_tags = NewRuntimeTags();
    new_runtime_tags->add_tag (tag);
  }

  void remove_runtime_tag (string|Tag tag, void|int proc_instr)
  //! If tag is a Tag object, it's removed from the set of runtime
  //! tags. If tag is a string, the tag with that name is removed. In
  //! the latter case, if proc_instr is nonzero the set of runtime PI
  //! tags is searched, else the set of normal element runtime tags.
  {
    if (!new_runtime_tags) new_runtime_tags = NewRuntimeTags();
    if (objectp (tag)) tag = tag->name;
    new_runtime_tags->remove_tag (tag);
  }

  multiset(Tag) get_runtime_tags()
  //! Returns all currently active runtime tags.
  {
    mapping(string:Tag) tags = runtime_tags;
    if (new_runtime_tags) tags = new_runtime_tags->filter_tags (tags);
    return mkmultiset (values (tags));
  }

  void handle_exception (mixed err, PCode|Parser evaluator)
  //! This function gets any exception that is catched during
  //! evaluation. evaluator is the object that catched the error.
  {
    error_count++;
    if (objectp (err) && err->is_RXML_Backtrace) {
      string msg;
      for (object(PCode)|object(Parser) e = evaluator->_parent; e; e = e->_parent)
	e->error_count++;
      if (id && id->conf)
	while (evaluator) {
	  object(PCode)|object(Parser) reporter = 0;
	  for (; evaluator; evaluator = evaluator->_parent)
	    if (evaluator->report_error && evaluator->type->free_text)
	      if (evaluator->disable_report_error) reporter = 0;
	      else if (!reporter) reporter = evaluator;
	  if (reporter) {
	    string msg = err->type == "help" ? err->msg :
	      (err->type == "run" ?
	       ([function(Backtrace,Type:string)]
		([object] id->conf)->handle_run_error) :
	       ([function(Backtrace,Type:string)]
		([object] id->conf)->handle_parse_error)
	      ) ([object(Backtrace)] err, reporter->type);
	    if (reporter->report_error (msg))
	      break;
	  }
	  evaluator = reporter->_parent;
	}
      else {
#ifdef MODULE_DEBUG
	report_notice (describe_backtrace (err));
#else
	report_notice (err->msg);
#endif
      }
    }
    else throw_fatal (err);
  }

  // Internals.

  string current_var;
  // Used to get the parsed variable into the RXML error backtrace.

  Parser new_parser (Type top_level_type)
  // Returns a new parser object to start parsing with this context.
  // Normally TagSet.`() should be used instead of this.
  {
#ifdef MODULE_DEBUG
    if (in_use || frame) fatal_error ("Context already in use.\n");
#endif
    return top_level_type->get_parser (this_object());
  }

  mapping(string:SCOPE_TYPE) scopes = ([]);
  // The variable mappings for every currently visible scope. A
  // special entry "_" points to the current local scope.

  mapping(Frame:array(SCOPE_TYPE)) hidden = ([]);
  // The currently hidden scopes. The indices are frame objects which
  // introduce scopes. The values are tuples of the current scope and
  // the named scope they hide.

  void enter_scope (Frame frame)
  {
#ifdef DEBUG
    if (!frame->vars) fatal_error ("Internal error: Frame has no variables.\n");
#endif
    if (string scope_name = [string] frame->scope_name) {
      if (!hidden[frame])
	hidden[frame] = ({scopes["_"], scopes[scope_name]});
      scopes["_"] = scopes[scope_name] = [SCOPE_TYPE] frame->vars;
    }
    else {
      if (!hidden[frame])
	hidden[frame] = ({scopes["_"], 0});
      scopes["_"] = [SCOPE_TYPE] frame->vars;
    }
  }

  void leave_scope (Frame frame)
  {
    if (array(SCOPE_TYPE) back = hidden[frame]) {
      if (SCOPE_TYPE cur = back[0]) scopes["_"] = cur;
      else m_delete (scopes, "_");
      if (SCOPE_TYPE named = back[1]) {
#ifdef MODULE_DEBUG
	if (!stringp (frame->scope_name))
	  fatal_error ("Scope named changed to %O during parsing.\n", frame->scope_name);
#endif
	scopes[[string] frame->scope_name] = named;
      }
      else m_delete (scopes, [string] frame->scope_name);
      m_delete (hidden, frame);
    }
  }

#define ENTER_SCOPE(ctx, frame) (frame->vars && ctx->enter_scope (frame))
#define LEAVE_SCOPE(ctx, frame) (frame->vars && ctx->leave_scope (frame))

  mapping(string:Tag) runtime_tags = ([]);
  // The active runtime tags. PI tags are stored in the same mapping
  // with their names prefixed by '?'.

  NewRuntimeTags new_runtime_tags;
  // Used to record the result of any add_runtime_tag() and
  // remove_runtime_tag() calls since the last time the parsers ran.

  void create (TagSet _tag_set, void|RequestID _id)
  // Normally TagSet.`() should be used instead of this.
  {
    tag_set = _tag_set;
    id = _id;
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  mapping(string:mixed)|mapping(object:array) unwind_state;
  // If this is a mapping, we have an unwound stack state. It contains
  // strings with arbitrary exception info, and the objects being
  // unwound with arrays containing the extra state info they need.
  // The first entry in these arrays are always the subobject. The
  // special entries are:
  //
  // "top": ({Frame|Parser|PCode (top object)})
  // "stream_piece": mixed (When continuing, do a streaming
  //	do_process() with this stream piece.)
  // "exec_left": array (Exec array left to evaluate. Only used
  //	between Frame._exec_array() and Frame._eval().)

  MARK_OBJECT_ONLY;

  string _sprintf() {return "RXML.Context" + OBJ_COUNT;}

#ifdef MODULE_DEBUG
#if constant (thread_create)
  Thread.Thread in_use;
#else
  int in_use;
#endif
#endif
}

static class NewRuntimeTags
// Tool class used to track runtime tags in Context.
{
  static mapping(string:Tag) add_tags;
  static mapping(string:int|string) remove_tags;

  void add_tag (Tag tag)
  {
    if (!add_tags) add_tags = ([]);
    if (tag->flags & FLAG_PROC_INSTR) {
      add_tags["?" + tag->name] = tag;
      // By doing the following, we can let remove_proc_instrs take precedence.
      if (remove_tags) m_delete (remove_tags, "?" + tag->name);
    }
    else {
      add_tags[tag->name] = tag;
      if (remove_tags) m_delete (remove_tags, tag->name);
    }
  }

  void remove_tag (string name, int proc_instr)
  {
    if (!remove_tags) remove_tags = ([]);
    if (proc_instr) remove_tags["?" + name] = name;
    else remove_tags[name] = 1;
  }

  array(Tag) added_tags()
  {
    if (!add_tags) return ({});
    if (remove_tags) return values (add_tags - remove_tags);
    return values (add_tags);
  }

  array(string) removed_tags()
  {
    return remove_tags ? indices (filter (remove_tags, intp)) : ({});
  }

  array(string) removed_pi_tags()
  {
    return remove_tags ? values (remove_tags) - ({1}) : ({});
  }

  mapping(string:Tag) filter_tags (mapping(string:Tag) tags)
  {
    if (add_tags) tags |= add_tags;
    if (remove_tags) tags -= remove_tags;
    return tags;
  }
}

class Backtrace
//! The object used to throw RXML errors.
{
  constant is_generic_error = 1;
  constant is_RXML_Backtrace = 1;

  string type;			// Currently "run" or "parse".
  string msg;
  Context context;
  Frame frame;
  string current_var;
  array backtrace;

  void create (void|string _type, void|string _msg, void|Context _context,
	       void|array _backtrace)
  {
    type = _type;
    msg = _msg;
    if (context = _context || get_context()) {
      frame = context->frame;
      current_var = context->current_var;
    }
    if (_backtrace) backtrace = _backtrace;
    else {
      backtrace = predef::backtrace();
      backtrace = backtrace[..sizeof (backtrace) - 2];
    }
  }

  string describe_rxml_backtrace (void|int no_msg)
  //! Returns a formatted RXML frame backtrace.
  {
    string txt = no_msg ? "" : "RXML" + (type ? " " + type : "") + " error";
    if (context) {
      if (!no_msg) txt += ": " + (msg || "(no error message)\n");
      txt += current_var ? " | &" + current_var + ";\n" : "";
      for (Frame f = frame; f; f = f->up) {
	string name;
	if (f->tag) name = f->tag->name;
	else if (!f->up) break;
	else name = "(unknown)";
	if (f->flags & FLAG_PROC_INSTR)
	  txt += " | <?" + name + "?>\n";
	else {
	  txt += " | <" + name;
	  if (f->args)
	    foreach (sort (indices (f->args)), string arg) {
	      mixed val = f->args[arg];
	      txt += " " + arg + "=";
	      if (arrayp (val)) txt += map (val, error_print_val) * ",";
	      else txt += error_print_val (val);
	    }
	  else txt += " (no argmap)";
	  txt += ">\n";
	}
      }
    }
    else
      if (!no_msg) txt += " (no context): " + (msg || "(no error message)\n");
    return txt;
  }

  private string error_print_val (mixed val)
  {
    if (arrayp (val)) return "array";
    else if (mappingp (val)) return "mapping";
    else if (multisetp (val)) return "multiset";
    else return sprintf ("%O", val);
  }

  string|array `[] (int i)
  {
    switch (i) {
      case 0: return describe_rxml_backtrace();
      case 1: return backtrace;
    }
  }

  string _sprintf() {return "RXML.Backtrace(" + (type || "") + ")";}
}


//! Current context.

//! It's set before any function in RXML.Tag or RXML.Frame is called.

#if constant (thread_create)
private Thread.Local _context = thread_local();
local void set_context (Context ctx) {_context->set (ctx);}
local Context get_context() {return [object(Context)] _context->get();}
#else
private Context _context;
local void set_context (Context ctx) {_context = ctx;}
local Context get_context() {return _context;}
#endif

#if defined (MODULE_DEBUG) && constant (thread_create)

// Got races in this debug check, but looks like we have to live with that. :\

#define ENTER_CONTEXT(ctx)						\
  Context __old_ctx = get_context();					\
  set_context (ctx);							\
  if (ctx) {								\
    if (ctx->in_use && ctx->in_use != this_thread())			\
      fatal_error ("Attempt to use context asynchronously.\n");		\
    ctx->in_use = this_thread();					\
  }

#define LEAVE_CONTEXT()							\
  if (Context ctx = get_context())					\
    if (__old_ctx != ctx) ctx->in_use = 0;				\
  set_context (__old_ctx);

#else

#define ENTER_CONTEXT(ctx)						\
  Context __old_ctx = get_context();					\
  set_context (ctx);

#define LEAVE_CONTEXT()							\
  set_context (__old_ctx);

#endif


//! Constants for the bit field RXML.Frame.flags.

constant FLAG_NONE		= 0x00000000;
//! The no-flags flag. In case you think 0 is too ugly. ;)

constant FLAG_DEBUG		= 0x40000000;
//! Write a lot of debug during the execution of the tag, showing what
//! type conversions are done, what callbacks are being called etc.
//! Note that DEBUG must be defined for the debug printouts to be
//! compiled in (normally enabled with the --debug flag to Roxen).

//! Static flags (i.e. tested in the Tag object).

constant FLAG_PROC_INSTR	= 0x00000010;
//! Flags this as a processing instruction tag (i.e. one parsed with
//! the <?name ... ?> syntax in XML). The string after the tag name to
//! the ending separator constitutes the content of the tag. Arguments
//! are not used.

constant FLAG_EMPTY_ELEMENT	= 0x00000001;
//! If set, the tag does not use any content. E.g. with an HTML parser
//! this defines whether the tag is a container or not, and in XML
//! parsing it simply causes the content (if any) to be thrown away.

constant FLAG_COMPAT_PARSE	= 0x00000002;
//! Makes the PXml parser parse the tag in an HTML compatible way: If
//! FLAG_EMPTY_ELEMENT is set and the tag doesn't end with '/>', it
//! will be parsed as an empty element. The effect of this flag in
//! other parsers is currently undefined.

constant FLAG_NO_PREFIX		= 0x00000004;
//! Never apply any prefix to this tag.

constant FLAG_SOCKET_TAG	= 0x00000008;
//! Declare the tag to be a socket tag, which accepts plugin tags (see
//! Tag.plugin_name for details).

constant FLAG_DONT_PREPARSE	= 0x00000040;
//! Don't preparse the content with the PXml parser. This is always
//! the case for PI tags, so this flag doesn't have any effect for
//! those. This is only used in the simple tag wrapper. Defined here
//! as placeholder.

constant FLAG_POSTPARSE		= 0x00000080;
//! Postparse the result with the PXml parser. This is only used in
//! the simple tag wrapper. Defined here as placeholder.

//! The rest of the flags are dynamic (i.e. tested in the Frame object).

constant FLAG_PARENT_SCOPE	= 0x00000100;
//! If set, exec arrays will be interpreted in the scope of the parent
//! tag, rather than in the current one.

constant FLAG_NO_IMPLICIT_ARGS	= 0x00000200;
//! If set, the parser won't apply any implicit arguments. FIXME: Not
//! yet implemented.

constant FLAG_STREAM_RESULT	= 0x00000400;
//! If set, the do_process() function will be called repeatedly until
//! it returns 0 or no more content is wanted.

constant FLAG_STREAM_CONTENT	= 0x00000800;
//! If set, the tag supports getting its content in streaming mode:
//! do_process() will be called repeatedly with successive parts of the
//! content then. Can't be changed from do_process().

//! Note: It might be obvious, but using streaming is significantly
//! less effective than nonstreaming, so it should only be done when
//! big delays are expected.

constant FLAG_STREAM		= FLAG_STREAM_RESULT | FLAG_STREAM_CONTENT;

constant FLAG_UNPARSED		= 0x00001000;
//! If set, args and content in the frame contain unparsed strings.
//! The frame will be parsed before it's evaluated. This flag should
//! never be set in Tag.flags, but it's useful when creating frames
//! directly.

constant FLAG_DONT_REPORT_ERRORS = 0x00002000;
//! This flag avoids RXML errors which occurs when parsing the content
//! in the tag to be reported in it, instead the error report will be
//! propagated to the parent tag.
//!
//! When an error occurs, the parser searches upward in the frame
//! stack until it comes to one which looks like it can accept an
//! error report in its content.
//!
//! The criteria for the frame which will get the error report is that
//! its content type has the free_text property, and that the parser
//! that parses it has an report_error function (which e.g. RXML.PXml
//! has). With this flag, a frame can declare that it isn't suitable
//! to receive error reports even if it satisfies this.

constant FLAG_RAW_ARGS		= 0x00004000;
//! Special flag to TXml.format_tag(); only defined here as a
//! placeholder. When this is given to TXml.format_tag(), it only
//! encodes the argument quote character with the "Roxen encoding"
//! when writing argument values, instead of encoding with entity
//! references. It's intended for reformatting a tag which has been
//! parsed by Parser.HTML() (or parse_html()) but hasn't been
//! processed further.

//! The following flags specifies whether certain conditions must be
//! met for a cached frame to be considered (if RXML.Frame.is_valid()
//! is defined). They may be read directly after do_return() returns.
//! The tag name is always the same. FIXME: These are ideas only;
//! nothing is currently implemented and they might change
//! arbitrarily.

constant FLAG_CACHE_DIFF_ARGS	= 0x00010000;
//! If set, the arguments to the tag need not be the same (using
//! equal()) as the cached args.

constant FLAG_CACHE_DIFF_CONTENT = 0x00020000;
//! If set, the content need not be the same.

constant FLAG_CACHE_DIFF_RESULT_TYPE = 0x00040000;
//! If set, the result type need not be the same. (Typically
//! not useful unless cached_return() is used.)

constant FLAG_CACHE_DIFF_VARS	= 0x00080000;
//! If set, the variables with external scope in vars (i.e. normally
//! those that has been accessed with get_var()) need not have the
//! same values (using equal()) as the actual variables.

constant FLAG_CACHE_DIFF_TAG_INSTANCE = 0x00100000;
//! If set, the tag in the source document needs to be the same, so
//! the same frame may be used when the tag occurs in another context.

constant FLAG_CACHE_EXECUTE_RESULT = 0x00200000;
//! If set, an exec array will be stored in the frame instead of the
//! final result. On a cache hit it'll be executed to produce the
//! result.

class Frame
//! A tag instance. A new frame is normally created for every parsed
//! tag in the source document. It might be reused both when the
//! document is requested again and when the tag is reevaluated in a
//! loop, but it's not certain in either case. Therefore, be careful
//! about using variable initializers.
{
  constant is_RXML_Frame = 1;
  constant thrown_at_unwind = 1;

  //! Interface.

  Frame up;
  //! The parent frame. This frame is either created from the content
  //! inside the up frame, or it's in an exec array produced by the up
  //! frame.

  Tag tag;
  //! The RXML.Tag object this frame was created from.

  int flags;
  //! Various bit flags that affect parsing. See the FLAG_* constants.
  //! It's copied from Tag.flag when the frame is created.

  mapping(string:mixed) args;
  //! The (parsed and evaluated) arguments passed to the tag. Set
  //! every time the frame is executed, before any frame callbacks are
  //! called. Not set for processing instruction (FLAG_PROC_INSTR)
  //! tags.

  Type content_type;
  //! The type of the content.

  mixed content = nil;
  //! The content, if any. Set before do_process() and do_return() are
  //! called. Initialized to RXML.nil every time the frame executed.

  Type result_type;
  //! The required result type. If it has a parser, it will affect how
  //! execution arrays are handled; see the return value for
  //! do_return() for details.
  //!
  //! This is set by the type inference from Tag.result_types before
  //! any frame callbacks are called. The frame may change this type,
  //! but it must produce a result value which matches it. The value
  //! is converted before being inserted into the parent content if
  //! necessary. An exception (which this frame can't catch) is thrown
  //! if conversion is impossible.

  mixed result = nil;
  //! The result, which is assumed to be either RXML.nil or a valid
  //! value according to result_type. The exec arrays returned by e.g.
  //! do_return() changes this. It may also be set directly.
  //! Initialized to RXML.nil every time the frame executed.
  //!
  //! If result_type has a parser set, it will be used by do_return()
  //! etc before assigning to this variable. Thus it contains the
  //! value after any parsing and will not be parsed again.

  //!mapping(string:mixed) vars;
  //! Set this to introduce a new variable scope that will be active
  //! during parsing of the content and return values (but see also
  //! FLAG_PARENT_SCOPE).

  //!string scope_name;
  //! The scope name for the variables. Must be set before the scope
  //! is used for the first time, and can't be changed after that.

  //!TagSet additional_tags;
  //! If set, the tags in this tag set will be used in addition to the
  //! tags inherited from the surrounding parser. The additional tags
  //! will in turn be inherited by subparsers.

  //!TagSet local_tags;
  //! If set, the tags in this tag set will be used in the parser for
  //! the content, instead of the one inherited from the surrounding
  //! parser. The tags are not inherited by subparsers.

  //!Frame parent_frame;
  //! If this variable exists, it gets set to the frame object of the
  //! closest surrounding tag that defined this tag in its
  //! additional_tags or local_tags. Useful to access the "mother tag"
  //! from the subtags it defines.

  //!string raw_tag_text;
  //! If this variable exists, it gets the raw text representation of
  //! the tag, if there is any. Note that it's after parsing of any
  //! splice argument.

  //!array do_enter (RequestID id);
  //!array do_process (RequestID id, void|mixed piece);
  //!array do_return (RequestID id);
  //! do_enter() is called first thing when processing the tag.
  //! do_process() is called after (some of) the content has been
  //! processed. do_return() is called lastly before leaving the tag.
  //!
  //! For tags that loops more than one time (see do_iterate):
  //! do_enter() is only called initially before the first call to
  //! do_iterate(). do_process() is called after each iteration.
  //! do_return() is called after the last call to do_process().
  //!
  //! The result_type variable is set to the type of result the parser
  //! wants. The tag may change it; the value will then be converted
  //! to the type that the parser wants. If the result type is
  //! sequential, it's spliced into the surrounding content, otherwise
  //! it replaces the previous value of the content, if any. If the
  //! result is RXML.nil, it does not affect the surrounding content
  //! at all.
  //!
  //! Return values:
  //!
  //! array -	A so-called execution array to be handled by the
  //!		parser. The elements are processed in order, and have
  //!		the following usage:
  //!
  //!	string - Added or put into the result. If the result type has
  //!		a parser, the string will be parsed with it before
  //!		it's assigned to the result variable and passed on.
  //!	RXML.Frame - Already initialized frame to process. Neither
  //!		arguments nor content will be parsed. It's result is
  //!		added or put into the result of this tag.
  //!	mapping(string:mixed) - Fields to merge into the headers.
  //!		FIXME: Not yet implemented.
  //!	object - Treated as a file object to read in blocking or
  //!		nonblocking mode. FIXME: Not yet implemented, details
  //!		not decided.
  //!	multiset(mixed) - Should only contain one element that'll be
  //!		added or put into the result. Normally not necessary;
  //!		assign it directly to the result variable instead.
  //!	propagate_tag() - Use a call to this function to propagate the
  //!		tag to be handled by an overridden tag definition, if
  //!		any exists. If this is used, it's probably necessary
  //!		to define the raw_tag_text variable. For further
  //!		details see the doc for propagate_tag() in this class.
  //!
  //! 0 -	Do nothing special. Exits the tag when used from
  //!		do_process() and FLAG_STREAM_RESULT is set.
  //!
  //! Note that the intended use is not to postparse by setting a
  //! parser on the result type, but instead to return an array with
  //! literal strings and RXML.Frame objects where parsing (or, more
  //! accurately, evaluation) needs to be done.
  //!
  //! If an array instead of a function is given, the array is handled
  //! as above. If the result variable is RXML.nil (which it defaults
  //! to), content is used as result if it's of a compatible type.
  //!
  //! If there is no do_return() and the result from parsing the
  //! content is not RXML.nil, it's assigned to or added to the
  //! content variable. Assignment is used if the content type is
  //! nonsequential, addition otherwise. Thus earlier values are
  //! simply overridden for nonsequential types.
  //!
  //! Regarding do_process only:
  //!
  //! Normally the content variable is set to the parsed content of
  //! the tag before do_process() is called. This may be RXML.nil if
  //! the content parsing didn't produce any result.
  //!
  //! piece is used when the tag is operating in streaming mode (i.e.
  //! FLAG_STREAM_CONTENT is set). It's then set to each successive
  //! part of the content in the stream, and the content variable is
  //! never touched. do_process() is also called "normally" with no
  //! piece argument afterwards. Note that tags that support streaming
  //! mode might still be used nonstreaming (it might also vary
  //! between iterations).
  //!
  //! As long as FLAG_STREAM_RESULT is set, do_process() will be
  //! called repeatedly until it returns 0. It's only the result piece
  //! from the execution array that is propagated after each turn; the
  //! result variable only accumulates all these pieces.

  //!int do_iterate (RequestID id);
  //! Controls the number of passes in the tag done by the parser. In
  //! every pass, the content of the tag (if any) is processed, then
  //! do_process() is called.
  //!
  //! Before doing any pass, do_iterate() is called. If the return
  //! value is nonzero, that many passes is done, then do_iterate() is
  //! called again and the process repeats. If the return value is
  //! zero, the tag exits and the value in result is used in the
  //! surrounding content as described above.
  //!
  //! The most common way to iterate is to do the setup before every
  //! pass (e.g. setup the variable scope) and return 1 to do one pass
  //! through the content. This will repeat until 0 is returned.
  //!
  //! If do_iterate is a positive integer, that many passes is done
  //! and then the tag exits. If do_iterate is zero or missing, one
  //! pass is done. If do_iterate is negative, no pass is done.

  //!int|function(RequestID:int) is_valid;
  //! When defined, the frame may be cached. First the name of the tag
  //! must be the same. Then the conditions specified by the cache
  //! bits in flag are checked. Then, if this is a function, it's
  //! called. If it returns 1, the frame is reused. FIXME: Not yet
  //! implemented.

  optional array cached_return (Context ctx, void|mixed piece);
  //! If defined, this will be called to get the value from a cached
  //! frame (that's still valid) instead of using the cached result.
  //! It's otherwise handled like do_return(). Note that the cached
  //! frame may be used from several threads. FIXME: Not yet
  //! implemented.

  //! Services.

  local mixed get_var (string var, void|string scope_name, void|Type want_type)
  //! A wrapper for easy access to RXML.Context.get_var().
  {
    return get_context()->get_var (var, scope_name, want_type);
  }

  local mixed set_var (string var, mixed val, void|string scope_name)
  //! A wrapper for easy access to RXML.Context.set_var().
  {
    return get_context()->set_var (var, val, scope_name);
  }

  local void delete_var (string var, void|string scope_name)
  //! A wrapper for easy access to RXML.Context.delete_var().
  {
    get_context()->delete_var (var, scope_name);
  }

  void run_error (string msg, mixed... args)
  //! A wrapper for easy access to RXML.run_error().
  {
    _run_error (msg, @args);
  }

  void parse_error (string msg, mixed... args)
  //! A wrapper for easy access to RXML.parse_error().
  {
    _parse_error (msg, @args);
  }

  local void tag_debug (string msg, mixed... args)
  //! Writes the message to the debug log if this tag has FLAG_DEBUG
  //! set.
  {
    if (flags & FLAG_DEBUG) werror (msg, @args);
  }

  void terminate()
  //! Makes the parser abort. The data parsed so far will be returned.
  //! Does not return; throws a special exception instead.
  {
    fatal_error ("FIXME\n");
  }

  void suspend()
  //! Used together with resume() for nonblocking mode. May be called
  //! from any frame callback to suspend the parser: The parser will
  //! just stop, leaving the context intact. If it returns, the parser
  //! is used in a place that doesn't support nonblocking, so just go
  //! ahead and block.
  {
    fatal_error ("FIXME\n");
  }

  void resume()
  //! Makes the parser continue where it left off. The function that
  //! called suspend() will be called again.
  {
    fatal_error ("FIXME\n");
  }

  mapping(string:Tag) get_plugins()
  //! Returns the plugins registered for this tag, which is assumed to
  //! be a socket tag, i.e. to have FLAG_SOCKET_TAG set (see
  //! Tag.plugin_name for details). Indices are the plugin_name values
  //! for the plugin Tag objects, values are the plugin objects
  //! themselves. Don't be destructive on the returned mapping.
  {
#ifdef MODULE_DEBUG
    if (!(flags & FLAG_SOCKET_TAG))
      fatal_error ("This tag is not a socket tag.\n");
#endif
    return get_context()->tag_set->get_plugins (tag->name, tag->flags & FLAG_PROC_INSTR);
  }

  Frame|string propagate_tag (void|mapping(string:string) args, void|string content)
  //! This function is intended to be used in the execution array from
  //! do_return() etc to propagate the tag to the next overridden tag
  //! definition, if any exists. It either returns a frame from the
  //! overridden tag or, if no overridden tag exists, a string
  //! containing a formatted tag (which requires that the result type
  //! supports formatted tags, i.e. has a working format_tag()
  //! function). If args and content are given, they will be used in
  //! the tag after parsing, otherwise the raw_tag_text variable is
  //! used, which must have a string value.
  {
    Context ctx = get_context();
    object(Tag) overridden = ctx->tag_set->get_overridden_tag (tag);
    if (arrayp (overridden))
      fatal_error ("Getting frames for low level tags are currently not implemented.\n");

    if (overridden) {
      Frame frame;
      if (!args) {
#ifdef MODULE_DEBUG
	if (zero_type (this_object()->raw_tag_text))
	  fatal_error ("The variable raw_tag_text must be defined.\n");
	if (!stringp (this_object()->raw_tag_text))
	  fatal_error ("raw_tag_text must have a string value.\n");
#endif
	Parser_HTML()
	  ->add_container (tag->name,
			   lambda (object p, mapping(string:string) a, string c) {
			     args = a;
			     content = c;
			     return ({});
			   })
	  ->finish (this_object()->raw_tag_text);
      }
      frame = overridden (args, content || "");
      frame->flags |= FLAG_UNPARSED;
      return frame;
    }

    else
      if (args) return result_type->format_tag (tag, args, content);
      else {
#ifdef MODULE_DEBUG
	if (zero_type (this_object()->raw_tag_text))
	  fatal_error ("The variable raw_tag_text must be defined.\n");
	if (!stringp (this_object()->raw_tag_text))
	  fatal_error ("raw_tag_text must have a string value.\n");
#endif
	if (flags & FLAG_PROC_INSTR)
	  return this_object()->raw_tag_text;
	else {
#ifdef MODULE_DEBUG
	  if (mixed err = catch {
#endif
	    return t_xml (PEnt)->eval (this_object()->raw_tag_text, ctx, empty_tag_set);
#ifdef MODULE_DEBUG
	  }) {
	    if (objectp (err) && ([object] err)->thrown_at_unwind)
	      fatal_error ("Can't save parser state when evaluating arguments.\n");
	    throw_fatal (err);
	  }
#endif
	}
      }
  }

  // Internals.

#ifdef DEBUG
#  define THIS_TAG_TOP_DEBUG(msg) tag_debug ("%O: %s", this_object(), (msg))
#  define THIS_TAG_DEBUG(msg) tag_debug ("%O:   %s", this_object(), (msg))
#  define THIS_TAG_DEBUG_ENTER_SCOPE(ctx, this, msg) \
     if (this->vars && ctx->scopes["_"] != this->vars) THIS_TAG_DEBUG (msg)
#  define THIS_TAG_DEBUG_LEAVE_SCOPE(ctx, this, msg) \
     if (this->vars && ctx->scopes["_"] == this->vars) THIS_TAG_DEBUG (msg)
#else
#  define THIS_TAG_TOP_DEBUG(msg) 0
#  define THIS_TAG_DEBUG(msg) 0
#  define THIS_TAG_DEBUG_ENTER_SCOPE(ctx, this, msg) 0
#  define THIS_TAG_DEBUG_LEAVE_SCOPE(ctx, this, msg) 0
#endif

  mixed _exec_array (TagSetParser parser, array exec, int parent_scope)
  {
    Frame this = this_object();
    Context ctx = parser->context;
    int i = 0;
    mixed res = nil;
    Parser subparser = 0;

    mixed err = catch {
      if (parent_scope) {
	THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this, "Exec: Temporary leaving scope\n");
	LEAVE_SCOPE (ctx, this);
      }

      for (; i < sizeof (exec); i++) {
	mixed elem = exec[i], piece = nil;

	switch (sprintf ("%t", elem)) {
	  case "string":
	    if (result_type->_parser_prog == PNone) {
	      THIS_TAG_DEBUG (sprintf ("Exec[%d]: String\n", i));
	      piece = elem;
	    }
	    else {
	      subparser = result_type->get_parser (ctx, 0, parser);
	      if (flags & FLAG_DONT_REPORT_ERRORS)
		subparser->disable_report_error = 1;
	      THIS_TAG_DEBUG (sprintf ("Exec[%d]: Parsing string with %O\n",
				       i, subparser));
	      subparser->finish ([string] elem); // Might unwind.
	      piece = subparser->eval(); // Might unwind.
	      subparser = 0;
	    }
	    break;

	  case "mapping":
	    THIS_TAG_DEBUG (sprintf ("Exec[%d]: Header mapping\n", i));
	    fatal_error ("Header mappings not yet implemented.\n");
	    break;

	  case "multiset":
	    if (sizeof ([multiset] elem) == 1) {
	      piece = ((array) elem)[0];
	      THIS_TAG_DEBUG (sprintf ("Exec[%d]: Verbatim %t value\n", i, piece));
	    }
	    else if (sizeof ([multiset] elem) > 1)
	      fatal_error (sizeof ([multiset] elem) +
			   " values in multiset in exec array.\n");
	    else fatal_error ("No value in multiset in exec array.\n");
	    break;

	  default:
	    if (objectp (elem))
	      // Can't count on that sprintf ("%t", ...) on an object
	      // returns "object".
	      if (([object] elem)->is_RXML_Frame) {
		THIS_TAG_DEBUG (sprintf ("Exec[%d]: Evaluating frame %O\n",
					 i, ([object] elem)));
		([object(Frame)] elem)->_eval (parser); // Might unwind.
		piece = ([object(Frame)] elem)->result;
	      }
	      else if (([object] elem)->is_RXML_Parser) {
		// The subparser above unwound.
		THIS_TAG_DEBUG (sprintf ("Exec[%d]: Continuing eval of frame %O\n",
					 i, ([object] elem)));
		([object(Parser)] elem)->finish(); // Might unwind.
		piece = ([object(Parser)] elem)->eval(); // Might unwind.
	      }
	      else
		fatal_error ("File objects not yet implemented.\n");
	    else
	      fatal_error ("Invalid type %t in exec array.\n", elem);
	}

	if (result_type->sequential) {
	  THIS_TAG_DEBUG (sprintf ("Exec[%d]: Adding %t to result\n", i, piece));
	  res += piece;
	}
	else if (piece != nil) {
	  THIS_TAG_DEBUG (sprintf ("Exec[%d]: Setting result to %t\n", i, piece));
	  result = res = piece;
	}
      }

      if (result_type->sequential) result += res;
      if (parent_scope) {
	THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this, "Exec: Reentering scope\n");
	ENTER_SCOPE (ctx, this);
      }
      return res;
    };

    if (parent_scope) {
      THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this, "Exec: Reentering scope\n");
      ENTER_SCOPE (ctx, this);
    }
    if (result_type->sequential) result += res;

    if (objectp (err) && ([object] err)->thrown_at_unwind) {
      THIS_TAG_DEBUG (sprintf ("Exec: Interrupted at position %d\n", i));
      mapping(string:mixed)|mapping(object:array) ustate;
      if ((ustate = ctx->unwind_state) && !zero_type (ustate->stream_piece)) {
	// Subframe wants to stream. Update stream_piece and send it on.
	if (result_type->encoding_type ?
	    result_type->encoding_type != parser->type->encoding_type :
	    result_type != parser->type)
	  res = parser->type->encode (res, result_type);
	if (result_type->sequential)
	  ustate->stream_piece = res + ustate->stream_piece;
	else if (ustate->stream_piece == nil)
	  ustate->stream_piece = res;
      }
      ustate->exec_left = exec[i..]; // Left to execute.
      if (subparser)
	// Replace the string with the subparser object so that we'll
	// continue in it later. It's done here to keep the original
	// exec array untouched.
	([array] ustate->exec_left)[0] = subparser;
      throw (err);
    }
    throw_fatal (err);
  }

  private void _handle_runtime_tags (Context ctx, TagSetParser parser)
  {
    // FIXME: PCode handling.
    array(Tag) arr_add_tags = ctx->new_runtime_tags->added_tags();
    array(string) arr_rem_tags = ctx->new_runtime_tags->removed_tags();
    array(string) arr_rem_pi_tags = ctx->new_runtime_tags->removed_pi_tags();
    for (Parser p = parser; p; p = p->_parent)
      if (p->tag_set_eval && !p->_local_tag_set && p->add_runtime_tag) {
	foreach (arr_add_tags, Tag tag) {
	  THIS_TAG_DEBUG (sprintf ("Adding runtime tag %O\n", tag));
	  ([object(TagSetParser)] p)->add_runtime_tag (tag);
	}
	foreach (arr_rem_tags, string tag) {
	  THIS_TAG_DEBUG (sprintf ("Removing runtime tag %s\n", tag));
	  ([object(TagSetParser)] p)->remove_runtime_tag (tag);
	}
	foreach (arr_rem_pi_tags, string tag) {
	  THIS_TAG_DEBUG (sprintf ("Removing runtime tag %s\n", tag));
	  ([object(TagSetParser)] p)->remove_runtime_tag (tag, 1);
	}
      }
    ctx->runtime_tags = ctx->new_runtime_tags->filter_tags (ctx->runtime_tags);
    ctx->new_runtime_tags = 0;
  }

  void _eval (TagSetParser parser,
	      void|mapping(string:string) raw_args,
	      void|string raw_content)
  // Note: It might be somewhat tricky to override this function.
  // Note: Might be destructive on raw_args.
  {
    Frame this = this_object();
    Context ctx = parser->context;
    RequestID id = ctx->id;

    // Unwind state data:
    //raw_content
#define EVSTAT_BEGIN 0
#define EVSTAT_ENTERED 1
#define EVSTAT_LAST_ITER 2
#define EVSTAT_ITER_DONE 3
    int eval_state = EVSTAT_BEGIN;
    int iter;
#ifdef DEBUG
    int debug_iter = 1;
#endif
    Parser subparser;
    mixed piece;
    array exec;
    TagSet orig_tag_set;	// Flags that we added additional_tags to ctx->tag_set.
    //ctx->new_runtime_tags

#define PRE_INIT_ERROR(X) (ctx->frame = this, fatal_error (X))
#ifdef DEBUG
    // Internal sanity checks.
    if (ctx != get_context())
      PRE_INIT_ERROR ("Internal error: Context not current.\n");
    if (!parser->tag_set_eval)
      PRE_INIT_ERROR ("Internal error: Calling _eval() with non-tag set parser.\n");
#endif
#ifdef MODULE_DEBUG
    if (ctx->new_runtime_tags)
      PRE_INIT_ERROR ("Looks like Context.add_runtime_tag() or "
		      "Context.remove_runtime_tag() was used outside any parser.\n");
#endif

    if (array state = ctx->unwind_state && ctx->unwind_state[this]) {
#ifdef DEBUG
      if (!up)
	PRE_INIT_ERROR ("Internal error: Resuming frame without up pointer.\n");
      if (raw_args || raw_content)
	PRE_INIT_ERROR ("Internal error: Can't feed new arguments or content "
			"when resuming parse.\n");
#endif
      object ignored;
      [ignored, eval_state, iter, raw_content, subparser, piece, exec, orig_tag_set,
       ctx->new_runtime_tags
#ifdef DEBUG
       , debug_iter
#endif
      ] = state;
      m_delete (ctx->unwind_state, this);
      if (!sizeof (ctx->unwind_state)) ctx->unwind_state = 0;
      THIS_TAG_TOP_DEBUG ("Continuing evaluation" +
			  (piece ? " with stream piece\n" : "\n"));
    }
    else {
      if (flags & FLAG_UNPARSED) {
#ifdef DEBUG
	if (raw_args || raw_content)
	  PRE_INIT_ERROR ("Internal error: raw_args or raw_content given for "
			  "unparsed frame.\n");
#endif
	raw_args = args, args = 0;
	raw_content = content, content = nil;
#ifdef MODULE_DEBUG
	if (!stringp (raw_content))
	  PRE_INIT_ERROR ("Content is not a string in unparsed tag frame.\n");
#endif
	THIS_TAG_TOP_DEBUG ("Evaluating unparsed\n");
      }
      else THIS_TAG_TOP_DEBUG ("Evaluating\n");

#ifdef MODULE_DEBUG
      if (up && up != ctx->frame)
	PRE_INIT_ERROR ("Reuse of frame in different context.\n");
#endif
      up = ctx->frame;
      piece = nil;
      if (++ctx->frame_depth >= ctx->max_frame_depth) {
	ctx->frame = this;
	ctx->frame_depth--;
	_run_error ("Too deep recursion -- exceeding %d nested tags.\n",
		    ctx->max_frame_depth);
      }
    }

#undef PRE_INIT_ERROR
    ctx->frame = this;

    do {			// Target for breaks (goto wouldn't be all bad, really).
      if (tag) {
	if ((raw_args || args || ([]))->help) {
	  TRACE_ENTER ("tag &lt;" + tag->name + " help&gt;", tag);
	  string help = id->conf->find_tag_doc (tag->name, id);
	  TRACE_LEAVE ("");
	  THIS_TAG_TOP_DEBUG ("Reporting help - frame done\n");
	  ctx->handle_exception ( // Will throw if necessary.
	    Backtrace ("help", help, ctx), parser);
	  break;
	}

	TRACE_ENTER("tag &lt;" + tag->name + "&gt;", tag);

#ifdef MODULE_LEVEL_SECURITY
	if (id->conf->check_security (tag, id, id->misc->seclevel)) {
	  THIS_TAG_TOP_DEBUG ("Access denied - exiting\n");
	  TRACE_LEAVE("access denied");
	  break;
	}
#endif
      }

      if (raw_args) {
#ifdef MODULE_DEBUG
	if (flags & FLAG_PROC_INSTR)
	  fatal_error ("Can't pass arguments to a processing instruction tag.\n");
#endif
	if (sizeof (raw_args)) {
	  // Note: Code duplication in Tag.eval_args().
	  mapping(string:Type) atypes = raw_args & tag->req_arg_types;
	  if (sizeof (atypes) < sizeof (tag->req_arg_types)) {
	    array(string) missing = sort (indices (tag->req_arg_types - atypes));
	    parse_error ("Required " +
			 (sizeof (missing) > 1 ?
			  "arguments " + String.implode_nicely (missing) + " are" :
			  "argument " + missing[0] + " is") + " missing.\n");
	  }
	  atypes += raw_args & tag->opt_arg_types;
#ifdef MODULE_DEBUG
	  if (mixed err = catch {
#endif
	    foreach (indices (raw_args), string arg) {
#ifdef DEBUG
	      Type t = atypes[arg] || tag->def_arg_type;
	      if (t->_parser_prog != PNone) {
		Parser p = t->get_parser (ctx, 0, parser);
		THIS_TAG_DEBUG (sprintf ("Evaluating argument %O with %O\n", arg, p));
		p->finish (raw_args[arg]); // Should not unwind.
		raw_args[arg] = p->eval(); // Should not unwind.
	      }
#else
	      raw_args[arg] = (atypes[arg] || tag->def_arg_type)->
		eval (raw_args[arg], ctx, 0, parser, 1); // Should not unwind.
#endif
	    }
#ifdef MODULE_DEBUG
	  }) {
	    if (objectp (err) && ([object] err)->thrown_at_unwind)
	      fatal_error ("Can't save parser state when evaluating arguments.\n");
	    throw_fatal (err);
	  }
#endif
	}
	args = raw_args;
      }
#ifdef MODULE_DEBUG
      else if (!args && !(flags & FLAG_PROC_INSTR)) fatal_error ("args not set.\n");
#endif

      if (!zero_type (this->parent_frame))
	if (up->local_tags && up->local_tags->has_tag (tag)) {
	  THIS_TAG_DEBUG (sprintf ("Setting parent_frame to %O from local_tags\n", up));
	  this->parent_frame = up;
	}
	else
	  for (Frame f = up; f; f = f->up)
	    if (f->additional_tags && f->additional_tags->has_tag (tag)) {
	      THIS_TAG_DEBUG (sprintf ("Setting parent_frame to %O "
				       "from additional_tags\n", f));
	      this->parent_frame = f;
	      break;
	    }

      if (TagSet add_tags = raw_content && [object(TagSet)] this->additional_tags) {
	TagSet tset = ctx->tag_set;
	if (!tset->has_effective_tags (add_tags)) {
	  THIS_TAG_DEBUG (sprintf ("Installing additional_tags %O\n", add_tags));
	  int hash = HASH_INT2 (tset->id_number, add_tags->id_number);
	  orig_tag_set = tset;
	  TagSet local_ts;
	  if (!(local_ts = local_tag_set_cache[hash])) {
	    local_ts = TagSet (add_tags->name + "+" + orig_tag_set->name);
	    local_ts->imported = ({add_tags, orig_tag_set});
	    local_tag_set_cache[hash] = local_ts; // Race, but it doesn't matter.
	  }
	  ctx->tag_set = local_ts;
	}
	else
	  THIS_TAG_DEBUG (sprintf ("Not installing additional_tags %O "
				   "since they're already in the tag set\n", add_tags));
      }

      if (!result_type) {
#ifdef MODULE_DEBUG
	if (!tag) fatal_error ("result_type not set in Frame object %O, "
			       "and it has no Tag object to use for inferring it.\n",
			       this_object());
#endif
	Type ptype = parser->type;
	foreach (tag->result_types, Type rtype)
	  if (ptype == rtype) {
	    result_type = rtype;
	    break;
	  }
	  else if (ptype->subtype_of (rtype)) {
	    result_type = ptype (rtype->_parser_prog);
	    break;
	  }
	if (!result_type)
	  parse_error (
	    "Tag returns " +
	    String.implode_nicely ([array(string)] tag->result_types->name, "or") +
	    " but " + [string] parser->type->name + " is expected.\n");
	THIS_TAG_DEBUG (sprintf ("Resolved result_type to %O from surrounding %O\n",
				 result_type, ptype));
      }
      else THIS_TAG_DEBUG (sprintf ("Keeping result_type %O\n", result_type));

      if (!content_type) {
#ifdef MODULE_DEBUG
	if (!tag) fatal_error ("content_type not set in Frame object %O, "
			       "and it has no Tag object to use for inferring it.\n",
			       this_object());
#endif
	content_type = tag->content_type;
	if (content_type == t_same) {
	  content_type = result_type (content_type->_parser_prog);
	  THIS_TAG_DEBUG (sprintf ("Resolved t_same to content_type %O\n",
				   content_type));
	}
	else THIS_TAG_DEBUG (sprintf ("Setting content_type to %O from tag\n",
				      content_type));
      }
      else THIS_TAG_DEBUG (sprintf ("Keeping content_type %O\n", content_type));

      if (raw_content) {
	THIS_TAG_DEBUG ("Initializing the content variable to nil\n");
	content = content_type->empty_value;
      }

      mixed err = catch {
	switch (eval_state) {
	  case EVSTAT_BEGIN:
	    if (array|function(RequestID:array) do_enter =
		[array|function(RequestID:array)] this->do_enter) {
	      if (!exec) {
		if (arrayp (do_enter)) {
		  THIS_TAG_DEBUG ("Getting exec array from do_enter\n");
		  exec = [array] do_enter;
		}
		else {
		  THIS_TAG_DEBUG ("Calling do_enter\n");
		  exec = ([function(RequestID:array)] do_enter) (id); // Might unwind.
		  THIS_TAG_DEBUG ((exec ? "Exec array" : "Zero") +
				  " returned from do_enter\n");
		}
		if (ctx->new_runtime_tags)
		  _handle_runtime_tags (ctx, parser);
	      }

	      if (exec) {
		if (!(flags & FLAG_PARENT_SCOPE)) {
		  THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this, "Entering scope\n");
		  ENTER_SCOPE (ctx, this);
		}
		mixed res = _exec_array (parser, exec, 0); // Might unwind.

		if (flags & FLAG_STREAM_RESULT) {
#ifdef DEBUG
		  if (ctx->unwind_state)
		    fatal_error ("Internal error: Clobbering unwind_state "
				 "to do streaming.\n");
		  if (piece != nil)
		    fatal_error ("Internal error: Thanks, we think about how nice "
				 "it must be to play the harmonica...\n");
#endif
		  if (result_type->encoding_type ?
		      result_type->encoding_type != parser->type->encoding_type :
		      result_type != parser->type) {
		    THIS_TAG_DEBUG (sprintf ("Converting result from %s to %s of "
					     "surrounding content\n",
					     result_type->name, parser->type->name));
		    res = parser->type->encode (res, result_type);
		  }
		  ctx->unwind_state = (["stream_piece": res]);
		  THIS_TAG_DEBUG (sprintf ("Streaming %t from do_enter\n", res));
		  throw (this);
		}

		exec = 0;
	      }
	    }
	    eval_state = EVSTAT_ENTERED;

	    /* Fall through. */
	  case EVSTAT_ENTERED:
	  case EVSTAT_LAST_ITER:
	    do {
	      if (eval_state != EVSTAT_LAST_ITER) {
		int|function(RequestID:int) do_iterate =
		  [int|function(RequestID:int)] this->do_iterate;
		if (intp (do_iterate)) {
		  iter = [int] do_iterate || 1;
		  eval_state = EVSTAT_LAST_ITER;
#ifdef DEBUG
		  if (iter > 1)
		    THIS_TAG_DEBUG (sprintf ("Getting %d iterations from do_iterate\n",
					     iter));
		  else if (iter < 0)
		    THIS_TAG_DEBUG ("Skipping to finish since do_iterate is negative\n");
#endif
		}
		else {
		  THIS_TAG_DEBUG ("Calling do_iterate\n");
		  iter = (/*[function(RequestID:int)]HMM*/ do_iterate) (
		    id); // Might unwind.
		  THIS_TAG_DEBUG (sprintf ("%O returned from do_iterate\n", iter));
		  if (ctx->new_runtime_tags)
		    _handle_runtime_tags (ctx, parser);
		  if (!iter) eval_state = EVSTAT_LAST_ITER;
		}
	      }

	      THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this, "Entering scope\n");
	      ENTER_SCOPE (ctx, this);

	      for (; iter > 0;
		   iter--
#ifdef DEBUG
		     , debug_iter++
#endif
		  ) {
		if (raw_content && raw_content != "")
		  if (flags & FLAG_EMPTY_ELEMENT)
		    parse_error ("This tag doesn't handle content.\n");

		  else {	// Got nested parsing to do.
		    int finished = 0;
		    if (!subparser) { // The nested content is not yet parsed.
		      if (this->local_tags) {
			subparser = content_type->get_parser (
			  ctx, [object(TagSet)] this->local_tags, parser);
			subparser->_local_tag_set = 1;
			THIS_TAG_DEBUG (
			  sprintf ("Iter[%d]: Evaluating content with %O "
				   "from local_tags\n", debug_iter, subparser));
		      }
		      else {
			subparser = content_type->get_parser (ctx, 0, parser);
#ifdef DEBUG
			if (content_type->_parser_prog != PNone)
			  THIS_TAG_DEBUG (sprintf ("Iter[%d]: Evaluating content "
						   "with %O\n", debug_iter, subparser));
#endif
		      }
		      if (flags & FLAG_DONT_REPORT_ERRORS)
			subparser->disable_report_error = 1;
		      subparser->finish (raw_content); // Might unwind.
		      finished = 1;
		    }

		    do {
		      if (flags & FLAG_STREAM_CONTENT && subparser->read) {
			// Handle a stream piece.
			// Squeeze out any free text from the subparser first.
			mixed res = subparser->read();
			if (content_type->sequential) piece = res + piece;
			else if (piece == nil) piece = res;
			THIS_TAG_DEBUG (
			  sprintf ("Iter[%d]: Got %s %t stream piece\n",
				   debug_iter, finished ? "ending" : "a", piece));

			if (piece != nil) {
			  array|function(RequestID,void|mixed:array) do_process;
			  if ((do_process =
			       [array|function(RequestID,void|mixed:array)]
			       this->do_process) &&
			      !arrayp (do_process)) {
			    if (!exec) {
			      THIS_TAG_DEBUG (sprintf ("Iter[%d]: Calling do_process in "
						       "streaming mode\n", debug_iter));
			      exec = do_process (id, piece); // Might unwind.
			      THIS_TAG_DEBUG (sprintf ("Iter[%d]: %s returned from "
						       "do_process\n", debug_iter,
						       exec ? "Exec array" : "Zero"));
			      if (ctx->new_runtime_tags)
				_handle_runtime_tags (ctx, parser);
			    }

			    if (exec) {
			      THIS_TAG_DEBUG_ENTER_SCOPE (
				ctx, this, sprintf ("Iter[%d]: Entering scope\n",
						    debug_iter));
			      ENTER_SCOPE (ctx, this);
			      mixed res = _exec_array (
				parser, exec, flags & FLAG_PARENT_SCOPE); // Might unwind.

			      if (flags & FLAG_STREAM_RESULT) {
#ifdef DEBUG
				if (!zero_type (ctx->unwind_state->stream_piece))
				  fatal_error ("Internal error: Clobbering "
					       "unwind_state->stream_piece.\n");
#endif
				if (result_type->encoding_type ?
				    result_type->encoding_type !=
				    parser->type->encoding_type :
				    result_type != parser->type) {
				  THIS_TAG_DEBUG (
				    sprintf ("Iter[%d]: Converting result from %s to %s"
					     " of surrounding content\n", debug_iter,
					     result_type->name, parser->type->name));
				  res = parser->type->encode (res, result_type);
				}
				ctx->unwind_state->stream_piece = res;
				THIS_TAG_DEBUG (
				  sprintf ("Iter[%d]: Streaming %t from "
					   "do_process\n", debug_iter, res));
				throw (this);
			      }

			      exec = 0;
			    }
			    else if (flags & FLAG_STREAM_RESULT) {
			      THIS_TAG_DEBUG (
				sprintf ("Iter[%d]: do_process finished the stream; "
					 "ignoring remaining content\n", debug_iter));
			      ctx->unwind_state = 0;
			      piece = nil;
			      break;
			    }
			  }
			  piece = nil;
			}

			if (finished) break;
		      }
		      else {	// The frame doesn't handle streamed content.
			piece = nil;
			if (finished) {
			  mixed res = subparser->eval(); // Might unwind.
			  if (content_type->sequential) {
			    THIS_TAG_DEBUG (sprintf ("Iter[%d]: Adding %t to content\n",
						     debug_iter, res));
			    content += res;
			  }
			  else if (res != nil) {
			    THIS_TAG_DEBUG (sprintf ("Iter[%d]: Setting content to %t\n",
						     debug_iter, res));
			    content = res;
			  }
			  break;
			}
		      }

		      subparser->finish(); // Might unwind.
		      finished = 1;
		    } while (1); // Only loops when an unwound subparser has been recovered.
		    subparser = 0;
		  }

		if (array|function(RequestID,void|mixed:array) do_process =
		    [array|function(RequestID,void|mixed:array)] this->do_process) {
		  if (!exec) {
		    if (arrayp (do_process)) {
		      THIS_TAG_DEBUG (sprintf ("Iter[%d]: Getting exec array from "
					       "do_process\n", debug_iter));
		      exec = [array] do_process;
		    }
		    else {
		      THIS_TAG_DEBUG (sprintf ("Iter[%d]: Calling do_process\n",
					       debug_iter));
		      exec = ([function(RequestID,void|mixed:array)] do_process) (
			id); // Might unwind.
		      THIS_TAG_DEBUG (sprintf ("Iter[%d]: %s returned from do_process\n",
					       debug_iter, exec ? "Exec array" : "Zero"));
		    }
		    if (ctx->new_runtime_tags)
		      _handle_runtime_tags (ctx, parser);
		  }

		  if (exec) {
		    THIS_TAG_DEBUG_ENTER_SCOPE (
		      ctx, this, sprintf ("Iter[%d]: Entering scope\n", debug_iter));
		    ENTER_SCOPE (ctx, this);
		    mixed res = _exec_array (
		      parser, exec, flags & FLAG_PARENT_SCOPE); // Might unwind.

		    if (flags & FLAG_STREAM_RESULT) {
#ifdef DEBUG
		      if (ctx->unwind_state)
			fatal_error ("Internal error: Clobbering unwind_state "
				     "to do streaming.\n");
		      if (piece != nil)
			fatal_error ("Internal error: Thanks, we think about how nice "
				     "it must be to play the harmonica...\n");
#endif
		      if (result_type->encoding_type ?
			  result_type->encoding_type != parser->type->encoding_type :
			  result_type != parser->type) {
			THIS_TAG_DEBUG (sprintf ("Iter[%d]: Converting result from "
						 "type %s to type %s of surrounding "
						 "content\n", debug_iter,
						 result_type->name, parser->type->name));
			res = parser->type->encode (res, result_type);
		      }
		      ctx->unwind_state = (["stream_piece": res]);
		      THIS_TAG_DEBUG (sprintf ("Iter[%d]: Streaming %t from "
					       "do_process\n", debug_iter, res));
		      throw (this);
		    }

		    exec = 0;
		  }
		}

	      }
	    } while (eval_state != EVSTAT_LAST_ITER);

	    /* Fall through. */
	  case EVSTAT_ITER_DONE:
	    if (array|function(RequestID:array) do_return =
		[array|function(RequestID:array)] this->do_return) {
	      eval_state = EVSTAT_ITER_DONE; // Only need to record this state here.
	      if (!exec) {
		if (arrayp (do_return)) {
		  THIS_TAG_DEBUG ("Getting exec array from do_return\n");
		  exec = [array] do_return;
		}
		else {
		  THIS_TAG_DEBUG ("Calling do_return\n");
		  exec = ([function(RequestID:array)] do_return) (id); // Might unwind.
		  THIS_TAG_DEBUG ((exec ? "Exec array" : "Zero") +
				  " returned from do_return\n");
		}
		if (ctx->new_runtime_tags)
		  _handle_runtime_tags (ctx, parser);
	      }

	      if (exec) {
		THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this, "Entering scope\n");
		ENTER_SCOPE (ctx, this);
		_exec_array (parser, exec, flags & FLAG_PARENT_SCOPE); // Might unwind.
		exec = 0;
	      }
	    }

	    else if (result == nil && !(flags & FLAG_EMPTY_ELEMENT)) {
	      if (result_type->_parser_prog == PNone) {
		if (content_type->encoding_type ?
		    content_type->encoding_type != result_type->encoding_type :
		    content_type != result_type) {
		  THIS_TAG_DEBUG (sprintf ("Assigning content to result after "
					   "converting from %s to %s\n",
					   content_type->name, result_type->name));
		  result = result_type->encode (content, content_type);
		}
		else {
		  THIS_TAG_DEBUG ("Assigning content to result\n");
		  result = content;
		}
	      }
	      else
		if (stringp (content)) {
		  eval_state = EVSTAT_ITER_DONE; // Only need to record this state here.
		  if (!exec) {
		    THIS_TAG_DEBUG ("Parsing content with exec array "
				    "for assignment to result\n");
		    exec = ({content});
		  }
		  _exec_array (parser, exec, flags & FLAG_PARENT_SCOPE); // Might unwind.
		  exec = 0;
		}
	    }
	    else {
#ifdef DEBUG
	      if (!(flags & FLAG_EMPTY_ELEMENT))
		THIS_TAG_DEBUG ("Skipping nil result\n");
#endif
	    }

	    THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this, "Leaving scope\n");
	    LEAVE_SCOPE (ctx, this);
	}

	if (ctx->new_runtime_tags)
	  _handle_runtime_tags (ctx, parser);
      };

      ctx->frame_depth--;

      if (err) {
	THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this, "Leaving scope\n");
	LEAVE_SCOPE (ctx, this);
	string action;
	if (objectp (err) && ([object] err)->thrown_at_unwind) {
	  mapping(string:mixed)|mapping(object:array) ustate = ctx->unwind_state;
	  if (!ustate) ustate = ctx->unwind_state = ([]);
#ifdef DEBUG
	  if (ustate[this])
	    fatal_error ("Internal error: Frame already has an unwind state.\n");
#endif

	  if (ustate->exec_left) {
	    exec = [array] ustate->exec_left;
	    m_delete (ustate, "exec_left");
	  }

	  if (err == this || exec && sizeof (exec) && err == exec[0])
	    // This frame or a frame in the exec array wants to stream.
	    if (parser->unwind_safe) {
	      // Rethrow to continue in parent since we've already done
	      // the appropriate do_process stuff in this frame in
	      // either case.
	      if (err == this) err = 0;
	      if (orig_tag_set) ctx->tag_set = orig_tag_set, orig_tag_set = 0;
	      action = "break";
	      THIS_TAG_TOP_DEBUG ("Interrupted for streaming - "
				  "breaking to parent frame\n");
	    }
	    else {
	      // Can't stream since the parser isn't unwind safe. Just
	      // continue.
	      m_delete (ustate, "stream_piece");
	      action = "continue";
	      THIS_TAG_TOP_DEBUG ("Interrupted for streaming - "
				  "continuing since parser isn't unwind safe\n");
	    }
	  else if (!zero_type (ustate->stream_piece)) {
	    // Got a stream piece from a subframe. We handle it above;
	    // store the state and tail recurse.
	    piece = ustate->stream_piece;
	    m_delete (ustate, "stream_piece");
	    action = "continue";
	  }
	  else {
	    action = "break";	// Some other reason - back up to the top.
	    THIS_TAG_TOP_DEBUG ("Interrupted\n");
	  }

	  ustate[this] = ({err, eval_state, iter, raw_content, subparser, piece,
			   exec, orig_tag_set, ctx->new_runtime_tags,
#ifdef DEBUG
			   debug_iter,
#endif
			 });
	  TRACE_LEAVE (action);
	}
	else {
	  THIS_TAG_TOP_DEBUG ("Exception\n");
	  TRACE_LEAVE ("exception");
	  ctx->handle_exception (err, parser); // Will rethrow unknown errors.
	  result = nil;
	  action = "return";
	}

	switch (action) {
	  case "break":		// Throw and handle in parent frame.
#ifdef MODULE_DEBUG
	    if (!parser->unwind_state)
	      fatal_error ("Trying to unwind inside a parser that isn't unwind safe.\n");
#endif
	    throw (this);
	  case "continue":	// Continue in this frame through tail recursion.
	    _eval (parser);
	    return;
	  case "return":		// A normal return.
	    break;
	  default:
	    fatal_error ("Internal error: Don't you come here and %O on me!\n", action);
	}
      }
      else {
	THIS_TAG_TOP_DEBUG ("Done\n");
	TRACE_LEAVE ("");
      }
    } while (0);		// Breaks go here.

    if (orig_tag_set) ctx->tag_set = orig_tag_set;
    ctx->frame = up;
  }

  MARK_OBJECT;

  string _sprintf()
  {
    return "RXML.Frame(" + (tag && [string] tag->name) + ")" + OBJ_COUNT;
  }
}


// Global services.

//! Shortcuts to some common functions in the current context.
mixed get_var (string var, void|string scope_name, void|Type want_type)
  {return get_context()->get_var (var, scope_name, want_type);}
mixed user_get_var (string var, void|string scope_name, void|Type want_type)
  {return get_context()->user_get_var (var, scope_name, want_type);}
mixed set_var (string var, mixed val, void|string scope_name)
  {return get_context()->set_var (var, val, scope_name);}
mixed user_set_var (string var, mixed val, void|string scope_name)
  {return get_context()->user_set_var (var, val, scope_name);}
void delete_var (string var, void|string scope_name)
  {get_context()->delete_var (var, scope_name);}
void user_delete_var (string var, void|string scope_name)
  {get_context()->user_delete_var (var, scope_name);}

void run_error (string msg, mixed... args)
//! Throws an RXML run error with a dump of the parser stack in the
//! current context. This is intended to be used by tags for errors
//! that can occur during normal operation, such as when the
//! connection to an SQL server fails.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  throw (Backtrace ("run", msg, get_context(), bt[..sizeof (bt) - 2]));
}

void parse_error (string msg, mixed... args)
//! Throws an RXML parse error with a dump of the parser stack in the
//! current context. This is intended to be used for programming
//! errors in the RXML code, such as lookups in nonexisting scopes and
//! invalid arguments to a tag.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  throw (Backtrace ("parse", msg, get_context(), bt[..sizeof (bt) - 2]));
}

void fatal_error (string msg, mixed... args)
//! Throws a Pike error that isn't catched and handled anywhere. It's
//! just like the common error() function, but includes the RXML frame
//! backtrace.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  throw_fatal (({msg, bt[..sizeof (bt) - 2]}));
}

void throw_fatal (mixed err)
//! Mainly used internally to throw an error that includes the RXML
//! frame backtrace.
{
  if (arrayp (err) && sizeof (err) == 2 ||
      objectp (err) && !err->is_RXML_Backtrace && err->is_generic_error) {
    string msg;
    if (catch (msg = err[0])) throw (err);
    if (stringp (msg) && !has_value (msg, "\nRXML frame backtrace:\n")) {
      string descr = Backtrace (0, 0)->describe_rxml_backtrace (1);
      if (sizeof (descr)) {
	if (sizeof (msg) && msg[-1] != '\n') msg += "\n";
	msg += "RXML frame backtrace:\n" + descr;
	catch (err[0] = msg);
      }
    }
  }
  throw (err);
}

local void tag_debug (string msg, mixed... args)
//! Writes the message to the debug log if the innermost tag being
//! executed has FLAG_DEBUG set.
{
  if (Frame f = get_context()->frame) // It's intentional that this assumes a context.
    if (f->flags & FLAG_DEBUG)
      werror (msg, @args);
}

Frame make_tag (string name, mapping(string:mixed) args, void|mixed content,
		void|Tag overridden_by)
//! Returns a frame for the specified tag, or 0 if no such tag exists.
//! The tag definition is looked up in the current context and tag
//! set. args and content are not parsed or evaluated. If
//! overridden_by is given, the returned frame will come from the tag
//! that overridden_by overrides, if there is any (name is not used in
//! that case).
{
  TagSet tag_set = get_context()->tag_set;
  Tag tag = overridden_by ? tag_set->get_overridden_tag (overridden_by) :
    tag_set->get_tag (name);
  return tag && tag (args, content);
}

Frame make_unparsed_tag (string name, mapping(string:string) args, void|string content,
			 void|Tag overridden_by)
//! Returns a frame for the specified tag, or 0 if no such tag exists.
//! The tag definition is looked up in the current context and tag
//! set. args and content are given unparsed in this variant; they're
//! parsed when the frame is about to be evaluated. If overridden_by
//! is given, the returned frame will come from the tag that
//! overridden_by overrides, if there is any (name is not used in that
//! case).
{
  TagSet tag_set = get_context()->tag_set;
  Tag tag = overridden_by ? tag_set->get_overridden_tag (overridden_by) :
    tag_set->get_tag (name);
  if (!tag) return 0;
  Frame frame = tag (args, content);
  frame->flags |= FLAG_UNPARSED;
  return frame;
}

class parse_frame /* (Type type, string to_parse) */
//! Returns a frame that, when evaluated, parses the given string
//! according to the type (which typically has a parser set).
{
  inherit Frame;
  constant flags = FLAG_UNPARSED;
  mapping(string:mixed) args = ([]);

  void create (Type type, string to_parse)
  {
    content_type = type, result_type = type (PNone);
    content = to_parse;
  }

  string _sprintf() {return sprintf ("RXML.parse_frame(%O)", content_type);}
}


//! Parsers.


class Parser
//! Interface class for a syntax parser that scans, parses and
//! evaluates an input stream. Access to a parser object is assumed to
//! be done in a thread safe way except where noted.
{
  constant is_RXML_Parser = 1;
  constant thrown_at_unwind = 1;

  //! Services.

  int error_count;
  //! Number of RXML errors that occurred during evaluation. If this
  //! is nonzero, the value from eval() shouldn't be trusted.

  function(Parser:void) data_callback;
  //! A function to be called when data is likely to be available from
  //! eval(). It's always called when the source stream closes.

  //! write() and write_end() are the functions to use from outside
  //! the parser system, not feed() or finish().

  int write (string in)
  //! Writes some source data to the parser. Returns nonzero if there
  //! might be data available in eval().
  {
    int res;
    ENTER_CONTEXT (context);
    if (mixed err = catch {
      if (context && context->unwind_state && context->unwind_state->top) {
#ifdef MODULE_DEBUG
	if (context->unwind_state->top != this_object())
	  fatal_error ("The context got an unwound state from another parser. "
		       "Can't rewind.\n");
#endif
	m_delete (context->unwind_state, "top");
	if (!sizeof (context->unwind_state)) context->unwind_state = 0;
      }
      if (feed (in)) res = 1; // Might unwind.
      if (res && data_callback) data_callback (this_object());
    })
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
#ifdef DEBUG
	if (err != this_object()) {
	  LEAVE_CONTEXT();
	  fatal_error ("Internal error: Unexpected unwind object catched.\n");
	}
#endif
	if (!context->unwind_state) context->unwind_state = ([]);
	context->unwind_state->top = err;
      }
      else {
	LEAVE_CONTEXT();
	throw_fatal (err);
      }
    LEAVE_CONTEXT();
    return res;
  }

  void write_end (void|string in)
  //! Closes the source data stream, optionally with a last bit of
  //! data.
  {
    int res;
    ENTER_CONTEXT (context);
    if (mixed err = catch {
      if (context && context->unwind_state && context->unwind_state->top) {
#ifdef MODULE_DEBUG
	if (context->unwind_state->top != this_object())
	  fatal_error ("The context got an unwound state from another parser. "
		       "Can't rewind.\n");
#endif
	m_delete (context->unwind_state, "top");
	if (!sizeof (context->unwind_state)) context->unwind_state = 0;
      }
      finish (in); // Might unwind.
      if (data_callback) data_callback (this_object());
    })
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
#ifdef DEBUG
	if (err != this_object()) {
	  LEAVE_CONTEXT();
	  fatal_error ("Internal error: Unexpected unwind object catched.\n");
	}
#endif
	if (!context->unwind_state) context->unwind_state = ([]);
	context->unwind_state->top = err;
      }
      else {
	LEAVE_CONTEXT();
	throw_fatal (err);
      }
    LEAVE_CONTEXT();
  }

  array handle_var (string varref, Type surrounding_type)
  // Parses and evaluates a possible variable reference, with the
  // appropriate error handling.
  {
    // We're always evaluating here, so context is always set.
    if(varref[0]==':') return ({ "&"+varref[1..]+";" });
    array(string) split = Array.map( replace(varref, "..", ";") / ".",
				     lambda(string in) { return replace(in, ";", "."); });
    if (sizeof (split) == 2)
      if (mixed err = catch {
	sscanf (split[1], "%[^:]:%s", split[1], string encoding);
	context->current_var = varref;
	mixed val;
	if (zero_type (val = context->get_var ( // May throw.
			 split[1], split[0], encoding ? t_text : surrounding_type))) {
	  context->current_var = 0;
	  if(split[1]!="scopename") return ({});
	  val = context->frame->scope_name;
	}
	context->current_var = 0;
	return encoding ? ({Roxen->roxen_encode (val, encoding)}) : ({val});
      }) {
	context->current_var = 0;
	context->handle_exception (err, this_object()); // May throw.
	return ({});
      }
    if (!surrounding_type->free_text)
      parse_error ("Unknown variable reference &%s; not allowed in this context.\n",
		   varref);
    return 0;
  }

  //! Interface.

  Context context;
  //! The context to do evaluation in. It's assumed to never be
  //! modified asynchronously during the time the parser is working on
  //! an input stream.

  Type type;
  //! The expected result type of the current stream. (The parser
  //! should not do any type checking on this.)

  int compile;
  //! Must be set to nonzero before a stream is fed which should be
  //! compiled to p-code.

  //!int unwind_safe;
  //! If nonzero, the parser supports unwinding with throw()/catch().
  //! Whenever an exception is thrown from some evaluation function,
  //! it should be able to call that function again with identical
  //! arguments the next time it continues.

  int disable_report_error;
  //! Set to nonzero to avoid reporting errors in this parser. I.e.
  //! report_error() will never be called if this is nonzero.

  mixed feed (string in);
  //! Feeds some source data to the parse stream. The parser may do
  //! scanning and parsing before returning. If context is set, it may
  //! also do evaluation in that context. Returns nonzero if there
  //! could be new data to get from eval().

  void finish (void|string in);
  //! Like feed(), but also finishes the parse stream. A last bit of
  //! data may be given. It should work to call this on an already
  //! finished stream if no argument is given to it.

  optional int report_error (string msg);
  //! Used to report errors to the end user through the output. This
  //! is only called when type->free_text is nonzero and
  //! disable_report_error is zero. msg should be stored in the output
  //! queue to be returned by eval(). If the context is bad for an
  //! error message, do nothing and return zero. Return nonzero if a
  //! message was written.

  optional mixed read();
  //! Define to allow streaming operation. Returns the evaluated
  //! result so far, but does not do any evaluation. Returns RXML.nil
  //! if there's no data (for sequential types the empty value is also
  //! ok).

  mixed eval();
  //! Evaluates the data fed so far and returns the result. The result
  //! returned by previous eval() calls should not be returned again
  //! as (part of) this return value. Returns RXML.nil if there's no
  //! data (for sequential types the empty value is also ok).

  optional PCode p_compile();
  //! Define this to return a p-code representation of the current
  //! stream, which always is finished.

  optional void reset (Context ctx, Type type, mixed... args);
  //! Define to support reuse of a parser object. It'll be called
  //! instead of making a new object for a new stream. It keeps the
  //! static configuration, i.e. the type (and tag set when used in
  //! TagSetParser). Note that this function needs to deal with
  //! leftovers from add_runtime_tag() for TagSetParser objects.

  optional Parser clone (Context ctx, Type type, mixed... args);
  //! Define to create new parser objects by cloning instead of
  //! creating from scratch. It returns a new instance of this parser
  //! with the same static configuration, i.e. the type (and tag set
  //! when used in TagSetParser).

  static void create (Context ctx, Type _type, mixed... args)
  {
    context = ctx;
    type = _type;
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  string current_input() {return 0;}
  //! Should return the representation in the input stream for the
  //! current tag or entity being parsed, or 0 if it isn't known.

  // Internals.

  Parser _next_free;
  // Used to link together unused parser objects for reuse.

  Parser _parent;
  // The parent parser if this one is nested.

  Stdio.File _source_file;
  mapping _defines;
  // These two are compatibility kludges for use with parse_rxml().

  MARK_OBJECT_ONLY;

  string _sprintf()
  {
    return sprintf ("RXML.Parser(%O)%s", type, OBJ_COUNT);
  }
}


class TagSetParser
//! Interface class for parsers that evaluates using the tag set. It
//! provides the evaluation and compilation functionality. The parser
//! should call Tag._handle_tag() from feed() and finish() for every
//! encountered element tag and Tag._handle_pi_tag() for every PI tag.
//! Parser.handle_var() should be called for encountered variable
//! references. It must be able to continue cleanly after throw() from
//! Tag._handle_tag() and Tag._handle_pi_tag().
{
  inherit Parser;

  constant is_RXML_TagSetParser = 1;
  constant tag_set_eval = 1;

  // Services.

  mixed eval() {return read();}

  // Interface.

  TagSet tag_set;
  //! The tag set used for parsing.

  optional void reset (Context ctx, Type _type, TagSet tag_set, mixed... args);
  optional Parser clone (Context ctx, Type _type, TagSet tag_set, mixed... args);
  static void create (Context ctx, Type _type, TagSet _tag_set, mixed... args)
  {
    //::create (ctx, _type);
    context = ctx;
    type = _type;
    tag_set = _tag_set;
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }
  //! In addition to the type, the tag set is part of the static
  //! configuration.

  mixed read();
  //! No longer optional in this class. Since the evaluation is done
  //! in Tag._handle_tag() or similar, this always does the same as
  //! eval().

  optional void add_runtime_tag (Tag tag);
  //! Adds a tag that will exist from this point forward in the
  //! current parser instance only. This may only be left undefined if
  //! the parser doesn't parse tags at all.

  optional void remove_runtime_tag (string|Tag tag, void|int proc_instr);
  //! If tag is a Tag object, it's removed from the set of runtime
  //! tags that's been added by add_runtime_tag(). If tag is a string,
  //! the tag with that name is removed. In this case, if proc_instr
  //! is nonzero the set of runtime PI tags is searched, else the set
  //! of normal element runtime tags. This may only be left undefined
  //! if the parser doesn't parse tags at all.

  // Internals.

  int _local_tag_set;

  string _sprintf()
  {
    return sprintf ("RXML.TagSetParser(%O,%O)%s", type, tag_set, OBJ_COUNT);
  }
}

class PNone
//! The identity parser. It only returns its input.
{
  inherit Parser;

  string data = "";
  int evalpos = 0;

  int feed (string in)
  {
    data += in;
    return 1;
  }

  void finish (void|string in)
  {
    if (in) data += in;
  }

  string eval()
  {
    string res = data[evalpos..];
    evalpos = sizeof (data);
    return res;
  }

  string byte_compile()
  {
    return data;
  }

  string byte_interpret (string byte_code, Context ctx)
  {
    return byte_code;
  }

  void reset (Context ctx)
  {
    context = ctx;
    data = "";
    evalpos = 0;
  }

  string _sprintf() {return "RXML.PNone" + OBJ_COUNT;}
}


mixed simple_parse (string in, void|program parser)
//! A convenience function to parse a string with no type info, no tag
//! set, and no variable references. The parser defaults to PExpr.
{
  // FIXME: Recycle contexts?
  return t_any (parser || PExpr)->eval (in, Context (empty_tag_set));
}


//! Types.


class Type
//! A static type definition. It does type checking and specifies some
//! properties of the type. It may also contain a Parser program that
//! will be used to read text and evaluate values of this type. Note
//! that the parser is not relevant for type checking.
{
  constant is_RXML_Type = 1;

  //! Interface.

  //!string name;
  //! Unique type identifier. Required and considered constant. Type
  //! hierarchies are currently implemented with glob patterns, e.g.
  //! "image/png" is a subtype of "image/*". However, this syntax will
  //! be developed further, so for now use only characters [a-zA-Z/]
  //! to write MIME-like types and use only * for globbing.

  //!int sequential;
  //! Nonzero if data of this type is sequential, defined as:
  //! o  One or more data items can be concatenated with `+.
  //! o  (Sane) parsers are homomorphic on the type, i.e.
  //!	    eval ("da") + eval ("ta") == eval ("da" + "ta")
  //!    and
  //!	    eval ("data") + eval ("") == eval ("data")
  //!	 provided the data is only split between (sensibly defined)
  //!	 atomic elements.

  //!mixed empty_value;
  //! The empty value, i.e. what eval ("") would produce.

  //!int free_text;
  //! Nonzero if the type keeps the free text between parsed tokens,
  //! e.g. the plain text between tags in XML. The type must be
  //! sequential and use strings.

  void type_check (mixed val);
  //! Checks whether the given value is a valid one of this type. Type
  //! errors are thrown with RXML.parse_error().

  //!string encoding_type;
  //! A type name identifying the encoding in this type, if
  //! applicable. Conversion between two types with identical
  //! encoding_type is always a nop, so the call to encode() may be
  //! skipped.
  //!
  //! Types that have no encoding_type is taken to represent values in
  //! internal "raw" form, e.g. for strings this means that they are
  //! literals with no encoding scheme, so that every character
  //! represents only itself.

  mixed encode (mixed val, void|Type from);
  //! Converts the given value to this type. If the from type is
  //! given, it's the type of the value. If it's not given, the value
  //! is assumed to be in raw form (see encoding_type) If the type
  //! can't be converted, an RXML parse error should be thrown.

  mixed decode (mixed val);
  //! Converts the value, which is of this type, to the raw form (see
  //! encoding_type). If the type can't be converted, an RXML parse
  //! error should be thrown. That might happen if the value contains
  //! markup or similar that can't be represented in raw form.
  //!
  //! E.g. when converting some XML text, the function should return a
  //! literal string only if the text doesn't contain tags, otherwise
  //! it should throw an error (since there currently exists no
  //! internal representation of an XML node tree). It should never
  //! both decode e.g. "&lt;" to "<" and just leave literal "<" in the
  //! string. It should also not parse the value with some evaluating
  //! parser (see get_parser) since the value should not be evaluated,
  //! it should only change representation.

  Type clone()
  //! Returns a copy of the type. Exists only for overriding purposes;
  //! it's normally not useful to call this since type objects are
  //! shared.
  {
    Type newtype = object_program ((object(this_program)) this_object())();
    newtype->_parser_prog = _parser_prog;
    newtype->_parser_args = _parser_args;
    newtype->_t_obj_cache = _t_obj_cache;
    return newtype;
  }

  string format_tag (string|Tag tag, void|mapping(string:string) args,
		     void|string content, void|int flags)
  //! Returns a formatted tag according to the type. tag is either a
  //! tag object or the name of the tag. Throws an error if this type
  //! cannot format tags.
  {
    parse_error ("Cannot format tags with type %s.\n", this_object()->name);
  }

  string format_entity (string entity)
  //! Returns a formatted entity according to the type. Throws an
  //! error if this type cannot format entities.
  {
    parse_error ("Cannot format entities with type %s.\n", this_object()->name);
  }

  //! Services.

  int `== (mixed other)
  //!
  {
    return objectp (other) && ([object] other)->is_RXML_Type &&
      ([object(Type)] other)->name == this_object()->name;
  }

  int subtype_of (Type other)
  //!
  {
    return glob ([string] other->name, [string] this_object()->name);
  }

  Type `() (program/*(Parser)HMM*/ newparser, mixed... parser_args)
  //! Returns a type identical to this one, but which has the given
  //! parser. parser_args is passed as extra arguments to the
  //! create()/reset()/clone() functions.
  {
    Type newtype;
    if (sizeof (parser_args)) {	// Can't cache this.
      newtype = clone();
      newtype->_parser_prog = newparser;
      newtype->_parser_args = parser_args;
      if (newparser->tag_set_eval) newtype->_p_cache = set_weak_flag (([]), 1);
    }
    else {
      if (!_t_obj_cache) _t_obj_cache = ([]);
      if (!(newtype = _t_obj_cache[newparser]))
	if (newparser == _parser_prog)
	  _t_obj_cache[newparser] = newtype = this_object();
	else {
	  _t_obj_cache[newparser] = newtype = clone();
	  newtype->_parser_prog = newparser;
	  if (newparser->tag_set_eval) newtype->_p_cache = set_weak_flag (([]), 1);
	}
    }
    return newtype;
  }

  inline Parser get_parser (Context ctx, void|TagSet tag_set, void|Parser|PCode parent)
  //! Returns a parser instance initialized with the given context.
  {
    Parser p;
    if (_p_cache) {		// It's a tag set parser.
      TagSet tset = tag_set || ctx->tag_set;

      if (parent && parent->is_RXML_TagSetParser &&
	  tset == parent->tag_set && sizeof (ctx->runtime_tags) &&
	  parent->clone && parent->type == this_object()) {
	// There are runtime tags. Try to clone the parent parser if
	// all conditions are met.
	p = parent->clone (ctx, this_object(), tset, @_parser_args);
	p->_parent = parent;
	return p;
      }

      // vvv Using interpreter lock from here.
      PCacheObj pco = _p_cache[tset];
      if (pco && pco->tag_set_gen == tset->generation) {
	if ((p = pco->free_parser)) {
	  pco->free_parser = p->_next_free;
	  // ^^^ Using interpreter lock to here.
	  p->data_callback = p->compile = 0;
	  p->reset (ctx, this_object(), tset, @_parser_args);
#ifdef RXML_OBJ_DEBUG
	  p->__object_marker->create (p);
#endif
	}

	else
	  // ^^^ Using interpreter lock to here.
	  if (pco->clone_parser)
	    p = pco->clone_parser->clone (ctx, this_object(), tset, @_parser_args);
	  else if ((p = _parser_prog (ctx, this_object(), tset, @_parser_args))->clone) {
	    // pco->clone_parser might already be initialized here due
	    // to race, but that doesn't matter.
	    p->context = 0;	// Don't leave the context in the clone master.
#ifdef RXML_OBJ_DEBUG
	    p->__object_marker->create (p);
#endif
	    p = (pco->clone_parser = p)->clone (ctx, this_object(), tset, @_parser_args);
	  }
      }

      else {
	// ^^^ Using interpreter lock to here.
	pco = PCacheObj();
	pco->tag_set_gen = tset->generation;
	_p_cache[tset] = pco;	// Might replace an object due to race, but that's ok.
	if ((p = _parser_prog (ctx, this_object(), tset, @_parser_args))->clone) {
	  // pco->clone_parser might already be initialized here due
	  // to race, but that doesn't matter.
	  p->context = 0;	// Don't leave the context in the clone master.
#ifdef RXML_OBJ_DEBUG
	  p->__object_marker->create (p);
#endif
	  p = (pco->clone_parser = p)->clone (ctx, this_object(), tset, @_parser_args);
	}
      }

      if (ctx->tag_set == tset && p->add_runtime_tag && sizeof (ctx->runtime_tags))
	foreach (values (ctx->runtime_tags), Tag tag)
	  p->add_runtime_tag (tag);
    }

    else {
      if ((p = free_parser)) {
	// Relying on interpreter lock here.
	free_parser = p->_next_free;
	p->data_callback = p->compile = 0;
	p->reset (ctx, this_object(), @_parser_args);
#ifdef RXML_OBJ_DEBUG
	p->__object_marker->create (p);
#endif
      }

      else if (clone_parser)
	// Relying on interpreter lock here.
	p = clone_parser->clone (ctx, this_object(), @_parser_args);

      else if ((p = _parser_prog (ctx, this_object(), @_parser_args))->clone) {
	// clone_parser might already be initialized here due to race,
	// but that doesn't matter.
	p->context = 0;		// Don't leave the context in the clone master.
#ifdef RXML_OBJ_DEBUG
	p->__object_marker->create (p);
#endif
	p = (clone_parser = p)->clone (ctx, this_object(), @_parser_args);
      }
    }

    p->_parent = parent;
    return p;
  }

  mixed eval (string in, void|Context ctx, void|TagSet tag_set,
	      void|Parser|PCode parent, void|int dont_switch_ctx)
  //! Parses and evaluates the value in the given string. If a context
  //! isn't given, the current one is used. The current context and
  //! ctx are assumed to be the same if dont_switch_ctx is nonzero.
  {
    mixed res;
    if (!ctx) ctx = get_context();
    if (_parser_prog == PNone) res = in;
    else {
      Parser p = get_parser (ctx, tag_set, parent);
      p->_parent = parent;
      if (dont_switch_ctx) p->finish (in); // Optimize the job in p->write_end().
      else p->write_end (in);
      res = p->eval();
      if (p->reset) {
	p->context = p->disable_report_error = p->_parent = 0;
#ifdef RXML_OBJ_DEBUG
	p->__object_marker->create (p);
#endif
	if (_p_cache) {
	  if (PCacheObj pco = _p_cache[tag_set || ctx->tag_set]) {
	    // Relying on interpreter lock here.
	    p->_next_free = pco->free_parser;
	    pco->free_parser = p;
	  }
	}
	else {
	  // Relying on interpreter lock in this block.
	  p->_next_free = free_parser;
	  free_parser = p;
	}
      }
    }
    if (ctx->type_check) type_check (res);
    return res;
  }

  // Internals.

  program/*(Parser)HMM*/ _parser_prog = PNone;
  // The parser to use. Should never be changed in a type object.

  /*private*/ array(mixed) _parser_args = ({});

  /*private*/ mapping(program:Type) _t_obj_cache;
  // To avoid creating new type objects all the time in `().

  // Cache used for parsers that doesn't depend on the tag set.
  private Parser clone_parser;	// Used with Parser.clone().
  private Parser free_parser;	// The list of objects to reuse with Parser.reset().

  // Cache used for parsers that depend on the tag set.
  /*private*/ mapping(TagSet:PCacheObj) _p_cache;

  MARK_OBJECT_ONLY;

  string _sprintf() {return "RXML.Type" + OBJ_COUNT;}
}

static class PCacheObj
{
  int tag_set_gen;
  Parser clone_parser;
  Parser free_parser;
}

TAny t_any = TAny();
//! A completely unspecified nonsequential type. Every type is a
//! subtype of this one.

static class TAny
{
  inherit Type;
  constant name = "*";
  string _sprintf() {return "RXML.t_any" + OBJ_COUNT;}
}

TNil t_nil = TNil();
//! A sequential type accepting only the value nil. This type is by
//! definition a subtype of every sequential type.

static class TNil
{
  inherit Type;
  constant name = "nil";
  constant sequential = 1;
  Nil empty_value = nil;

  void type_check (mixed val)
  {
    if (val != nil) parse_error ("A non-nil value is not accepted.\n");
  }

  mixed encode (mixed val)
  {
#ifdef MODULE_DEBUG
    type_check (val);
#endif
    return nil;
  }

  mixed decode (mixed val)
  {
#ifdef MODULE_DEBUG
    type_check (val);
#endif
    return nil;
  }

  int subtype_of (Type other) {return other->sequential || other == t_any;}

  string _sprintf() {return "RXML.t_nil" + OBJ_COUNT;}
}

TSame t_same = TSame();
//! A magic type used in Tag.content_type.

static class TSame
{
  inherit Type;
  constant name = "same";
  string _sprintf() {return "RXML.t_same" + OBJ_COUNT;}
}

TText t_text = TText();
//! The standard type for generic document text.

static class TText
{
  inherit Type;
  constant name = "text/plain";
  constant sequential = 1;
  constant empty_value = "";
  constant free_text = 1;
  constant encoding_type = "none";

  void type_check (mixed val)
  {
    if (!stringp (val)) parse_error ("The text value is not a string.\n");
  }

  string encode (mixed val, void|Type from)
  {
    if (mixed err = catch {val = (string) val;})
      parse_error ("Cannot convert value to text: " + describe_error (err));
    if (from && from->encoding_type != encoding_type)
      val = from->decode ([string] val);
    return [string] val;
  }

  string decode (mixed val)
  {
#ifdef MODULE_DEBUG
    type_check (val);
#endif
    return val;
  }

  string _sprintf() {return "RXML.t_text" + OBJ_COUNT;}
}

THtml t_xml = TXml();
//! The type for XML and similar markup.

static class TXml
{
  inherit TText;
  constant name = "text/xml";
  constant encoding_type = "xml";

  string encode (mixed val, void|Type from)
  {
    if (mixed err = catch {val = (string) val;})
      parse_error ("Cannot convert value to text: " + describe_error (err));
    if (!from) from = t_text;
    if (from->encoding_type != encoding_type)
      return replace (
	from->decode ([string] val),
	// FIXME: This ignores the invalid Unicode character blocks.
	({"&", "<", ">", "\"", "\'",
	  "\000", "\001", "\002", "\003", "\004", "\005", "\006", "\007",
	  "\010",                 "\013", "\014",         "\016", "\017",
	  "\020", "\021", "\022", "\023", "\024", "\025", "\026", "\027",
	  "\030", "\031", "\032", "\033", "\034", "\035", "\036", "\037",
	}),
	({"&amp;", "&lt;", "&gt;", /*"&quot;"*/ "&#34;", /*"&apos;"*/ "&#39;",
	  "&#0;",  "&#1;",  "&#2;",  "&#3;",  "&#4;",  "&#5;",  "&#6;",  "&#7;",
	  "&#8;",                    "&#11;", "&#12;",          "&#14;", "&#15;",
	  "&#16;", "&#17;", "&#18;", "&#19;", "&#20;", "&#21;", "&#22;", "&#23;",
	  "&#24;", "&#25;", "&#26;", "&#27;", "&#28;", "&#29;", "&#30;", "&#31;",
	}));
    return [string] val;
  }

  string decode (mixed val)
  {
#ifdef MODULE_DEBUG
    type_check (val);
#endif
    return charref_decode_parser->clone()->finish (val)->read();
  }

  string format_tag (string|Tag tag, void|mapping(string:string) args,
		     void|string content, void|int flags)
  //! Returns a formatted XML tag. The flags argument contains a flag
  //! field compatible with Tag.flags etc; the flags FLAG_PROC_INSTR,
  //! FLAG_COMPAT_PARSE, FLAG_EMPTY_ELEMENT and FLAG_RAW_ARGS are
  //! heeded when formatting the tag. If tag is an object, its flags
  //! field is used instead of the flags argument.
  {
    string tagname;
    if (objectp (tag)) tagname = tag->name, flags = tag->flags;
    else tagname = tag;

    if (flags & FLAG_PROC_INSTR)
      return "<?" + tagname + " " + content + "?>";

    string res = "<" + tagname;

    if (args)
      if (flags & FLAG_RAW_ARGS)
	foreach (indices (args), string arg)
	  res += " " + arg + "=\"" + replace (args[arg], "\"", "\"'\"'\"") + "\"";
      else
	foreach (indices (args), string arg)
	  res += " " + arg + "=" + Roxen->html_encode_tag_value (args[arg]);

    if (content)
      res += ">" + content + "</" + tagname + ">";
    else
      if (flags & FLAG_COMPAT_PARSE)
	if (flags & FLAG_EMPTY_ELEMENT) res += ">";
	else res += "></" + tagname + ">";
      else
	res += " />";

    return res;
  }

  string format_entity (string entity)
  {
    return "&" + entity + ";";
  }

  string _sprintf() {return "RXML.t_xml" + OBJ_COUNT;}
}

THtml t_html = THtml();
//! (Currently) identical to t_xml, but tags it as "text/html".

static class THtml
{
  inherit TXml;
  constant name = "text/html";
  string _sprintf() {return "RXML.t_html" + OBJ_COUNT;}
}


// P-code compilation and evaluation.

class VarRef
//! A helper for representing variable reference tokens.
{
  constant is_RXML_VarRef = 1;
  string scope, var;
  static void create (string _scope, string _var) {scope = _scope, var = _var;}
  int valid (Context ctx) {return ctx->exist_scope (scope);}
  mixed get (Context ctx) {return ctx->get_var (var, scope);}
  mixed set (Context ctx, mixed val) {return ctx->set_var (var, val, scope);}
  void delete (Context ctx) {ctx->delete_var (var, scope);}
  string name() {return scope + "." + var;}
  MARK_OBJECT;
  string _sprintf() {return "RXML.VarRef(" + scope + "." + var + ")" + OBJ_COUNT;}
}

class PCode
//! Holds p-code and evaluates it. P-code is the intermediate form
//! after parsing and before evaluation.
{
  constant is_RXML_PCode = 1;
  constant thrown_at_unwind = 1;

  array p_code = ({});

  int error_count;
  //! Number of RXML errors that occurred during evaluation. If this
  //! is nonzero, the value from eval() shouldn't be trusted.

  mixed eval (Context ctx)
  //! Evaluates the p-code in the given context.
  {
    // FIXME

    // Note: Remember to initialize Frame.content and Frame.result
    // when reusing frames.
  }

  function(Context:mixed) compile();
  //! Returns a compiled function for doing the evaluation. The
  //! function will receive a context to do the evaluation in.


  // Internals.

  void report_error (string msg)
  {
    // FIXME
  }

  PCode|Parser _parent;
  // The parent evaluator if this one is nested.

  MARK_OBJECT;

  string _sprintf() {return "RXML.PCode" + OBJ_COUNT;}
}


//! Some parser tools.

Nil nil = Nil();
//! An object representing the empty value. Works as initializer for
//! sequences, since nil + anything == anything + nil == anything. It
//! can cast itself to the empty value for the basic Pike types. It
//! also evaluates to false in a boolean context, but it's not equal
//! to 0.

static class Nil
{
  mixed `+ (mixed... vals) {return sizeof (vals) ? predef::`+ (@vals) : this_object();}
  mixed ``+ (mixed val) {return val;}
  int `!() {return 1;}
  string _sprintf() {return "RXML.nil";}
  mixed cast(string type)
  {
    switch(type)
    {
    case "int":
      return 0;
    case "float":
      return 0.0;
    case "string":
      return "";
    case "array":
      return ({});
    case "multiset":
      return (<>);
    case "mapping":
      return ([]);
    default:
      error ("Cannot cast RXML.nil to "+type+".\n");
    }
  }
};

Nil Void = nil;			// Compatibility.

class ScanStream
//! A helper class for the input and scanner stage in a parser. It's a
//! stream that takes unparsed strings and splits them into tokens
//! which are queued. Intended to be inherited in a Parser class.
{
  private Link head = Link();	// Last link is an empty eof marker.
  private Link tail = head;
  private int next_token = 0;
  private string end = "";
  private int fin = 0;

  array scan (string in, int finished);
  //! The scanner function. It gets an unparsed string and should
  //! return an array of tokens. If the second argument is nonzero,
  //! there won't be any more data later. If the second argument is
  //! zero, the last item in the returned array is handled as unparsed
  //! data that will be passed back to the scanner later. Tokens may
  //! be of any type. Use VarRef objects for variables.

  void feed (string in)
  //!
  {
#ifdef MODULE_DEBUG
    if (fin) fatal_error ("Cannot feed data to a finished stream.\n");
#endif
    array tokens = scan (end + in, 0);
    end = [string] tokens[-1];
    if (sizeof (tokens) > 1) {
      tail->data = tokens[..sizeof (tokens) - 2];
      tail = tail->next = Link();
    }
  }

  void finish (void|string in)
  //!
  {
    if (in || !fin && sizeof (end)) {
#ifdef MODULE_DEBUG
      if (in && fin) fatal_error ("Cannot feed data to a finished stream.\n");
#endif
      fin = 1;
      if (in) end += in;
      tail->data = scan (end, 1);
      tail = tail->next = Link();
    }
  }

  void reset()
  //!
  {
    head = Link();
    tail = head;
    next_token = 0;
    end = "";
    fin = 0;
  }

  mixed read()
  //! Returns the next token, or RXML.nil if there's no more data.
  {
    while (head->next)
      if (next_token >= sizeof (head->data)) {
	next_token = 0;
	head = head->next;
      }
      else return head->data[next_token++];
    return nil;
  }

  void unread (mixed... put_back)
  //! Puts back tokens and variable references at the beginning of the
  //! stream so that the leftmost argument will be read first.
  {
    int i = sizeof (put_back);
    while (i) head->data[--next_token] = put_back[--i];
    if (i) {
      Link l = Link();
      l->next = head, head = l;
      l->data = allocate (next_token = max (i - 32, 0)) + put_back[..--i];
    }
  }

  array read_all()
  //!
  {
    array data;
    if (next_token) {
      data = head->data[next_token..];
      head = head->next;
      next_token = 0;
    }
    else data = ({});
    while (head->next) {
      data += head->data;
      head = head->next;
    }
    return data;
  }

  int finished()
  //! Returns nonzero if the write end is finished.
  {
    return fin;
  }

  MARK_OBJECT;

  string _sprintf() {return "RXML.ScanStream" + OBJ_COUNT;}
}

private class Link
{
  array data;
  Link next;
}


// Caches and object tracking.

static int tag_set_count = 0;

mapping(int|string:TagSet) garb_local_tag_set_cache()
{
  call_out (garb_local_tag_set_cache, 30*60);
  return local_tag_set_cache = ([]);
}

mapping(int|string:TagSet) local_tag_set_cache = garb_local_tag_set_cache();

// Various internal kludges.

static object/*(Parser.HTML)*/ charref_decode_parser;

static void init_charref_decode_parser()
{
  // Pretty similar to PEnt..
  object/*(Parser.HTML)*/ p = Parser_HTML();
  p->lazy_entity_end (1);
  p->add_entities (Roxen->parser_charref_table);
  p->_set_entity_callback (
    lambda (object/*(Parser.HTML)*/ p) {
      string chref = p->tag_name();
      if (sizeof (chref) && chref[0] == '#')
	if ((<"#x", "#X">)[chref[..1]]) {
	  if (sscanf (chref, "%*2s%x%*c", int c) == 2)
	    return ({(string) ({c})});
	}
	else
	  if (sscanf (chref, "%*c%d%*c", int c) == 2)
	    return ({(string) ({c})});
      parse_error ("Cannot decode character entity reference %O.\n", p->current());
    });
  p->_set_tag_callback (
    lambda (object/*(Parser.HTML)*/ p) {
      parse_error ("Cannot convert XML value to text "
		   "since it contains a tag %O.\n", p->current());
    });
  charref_decode_parser = p;
}

static function(string,mixed...:void) _run_error = run_error;
static function(string,mixed...:void) _parse_error = parse_error;

// Argh!
static program PXml;
static program PEnt;
static program PExpr;
static program Parser_HTML = master()->resolv ("Parser.HTML");

void _fix_module_ref (string name, mixed val)
{
  mixed err = catch {
    switch (name) {
      case "PXml": PXml = [program] val; break;
      case "PEnt": PEnt = [program] val; break;
      case "PExpr": PExpr = [program] val; break;
      case "Roxen": Roxen = [object] val; init_charref_decode_parser(); break;
      case "empty_tag_set": empty_tag_set = [object(TagSet)] val; break;
      default: error ("Herk\n");
    }
  };
  if (err) werror (describe_backtrace (err));
}
