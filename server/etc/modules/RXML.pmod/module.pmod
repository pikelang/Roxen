// $Id: module.pmod,v 1.165 2001/06/11 23:14:28 mast Exp $

// Kludge: Must use "RXML.refs" somewhere for the whole module to be
// loaded correctly.
static object Roxen;
class RequestID { };

//(!) FIXME: This was not legal autodoc; do we need some form of markup
//(!) to do what it tried to do? I'm not sure I fully understand what the
//(!) (now) (!) marked lines were meant to do; if it's just a comment
//(!) worth reading when browsing the source, please remove this and turn
//(!) these comments into normal "//" comments.                     / jhs

//! RXML parser and compiler framework.
//!
//! Created 1999-07-30 by Martin Stjernholm.
//!
//! API stability notes:
//!
//! The API in this file regarding the global functions and the Tag,
//! TagSet, Context, Frame and Type classes and their descendants is
//! intended to not change in incompatible ways. There are however
//! some areas where incompatible changes still must be expected:
//!
//! @list ul
//!  @item
//!   The namespace handling will likely change to conform to XML
//!   namespaces. The currently implemented system is inadequate then
//!   and will probably be removed.
//!  @item
//!   The semantics for caching and reuse of Frame objects is
//!   deliberatily documented vaguely (see the class doc for the
//!   Frame class). The currently implemented behavior will change
//!   when the cache system becomes reality. So never assume that
//!   you'll always get fresh Frame instances every time a tag is
//!   evaluated.
//!  @item
//!   The parser currently doesn't stream data according to the
//!   interface for streaming tags (but the implementation still
//!   follows the documented API for it). Therefore there's a risk
//!   that incompatible changes must be made in it due to design bugs
//!   when it's tested out. That is considered very unlikely, though.
//!  @item
//!   The type system will be developed further, and the API in the
//!   Type class might change as advanced types gets implemented.
//!   Don't make assumptions about undocumented behavior. Declare
//!   data properly with the types RXML.t_xml, RXML.t_html and
//!   RXML.t_text to let the parser handle the necessary conversions
//!   instead of doing it yourself. Try to avoid implementing types.
//!  @item
//!   Various utilities have FIXME's in their documentation. Needless
//!   to say they don't work as documented yet, and the doc should be
//!   considered as ideas only; it might work differently when it's
//!   actually implemented.
//! @endlist
//!
//! @note
//! The API for parsers, p-code evaluators etc is not part of the
//! "official" API. (The syntax _parsed_ by the currently implemented
//! parsers is well defined, of course.)

//#pragma strict_types // Disabled for now since it doesn't work well enough.

#include <config.h>

#include <request_trace.h>

#define MAGIC_HELP_ARG
// #define OBJ_COUNT_DEBUG
// #define RXML_VERBOSE
// #define PROFILE_PARSER


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

#ifdef PROFILE_PARSER

#define PROFILE_ENTER(ctx, what) do {					\
  ctx->profile[what] -= gethrtime();					\
  /* if (what == "rxml internal") trace (1); */				\
} while (0)

#define PROFILE_LEAVE(ctx, what) do {					\
  /* if (what == "rxml internal") trace (0); */				\
  ctx->profile[what] += gethrtime();					\
} while (0)

#define PROFILE_SWITCH(ctx, from, to) do {				\
  /* if (from == "rxml internal") trace (0); */				\
  int now = gethrtime();						\
  ctx->profile[from] += now;						\
  ctx->profile[to] -= now;						\
  /* if (to == "rxml internal") trace (1); */				\
} while (0)

#else
#  define PROFILE_ENTER(ctx, what) do ; while (0)
#  define PROFILE_LEAVE(ctx, what) do ; while (0)
#  define PROFILE_SWITCH(ctx, from, to) do ; while (0)
#endif

#ifdef RXML_VERBOSE
#  define TAG_DEBUG_TEST(flags) 1
#elif defined (DEBUG)
#  define TAG_DEBUG_TEST(flags) ((flags) & FLAG_DEBUG)
#else
#  define TAG_DEBUG_TEST(flags) 0
#endif

#ifdef DEBUG
#  define TAG_DEBUG(frame, msg, args...) \
  (TAG_DEBUG_TEST(frame->flags) && report_debug ("%O: " + (msg), (frame), args), 0)
#  define DO_IF_DEBUG(code...) code
#else
#  define TAG_DEBUG(frame, msg, args...) 0
#  define DO_IF_DEBUG(code...)
#endif

#ifdef MODULE_DEBUG
#  define DO_IF_MODULE_DEBUG(code...) code
#else
#  define DO_IF_MODULE_DEBUG(code...)
#endif

#define HASH_INT2(m, n) (n < 65536 ? (m << 16) + n : sprintf ("%x,%x", m, n))

// Use defines since typedefs doesn't work in soft casts yet.
#define SCOPE_TYPE mapping(string:mixed)|object(Scope)
#define UNWIND_STATE mapping(string|object:mixed|array)
#define EVAL_ARGS_FUNC function(Context:mapping(string:mixed))


class Tag
//! Interface class for the static information about a tag.
{
  constant is_RXML_Tag = 1;

  //(!) Interface:

  //! @decl string name;
  //!
  //! The name of the tag. Required and considered constant.

  /*extern*/ int flags;
  //! Various bit flags that affect parsing; see the FLAG_* constants.
  //! @[RXML.Frame.flags] is initialized from this.

  mapping(string:Type) req_arg_types = ([]);
  mapping(string:Type) opt_arg_types = ([]);
  //! The names and types of the required and optional arguments. If a
  //! type specifies a parser, it'll be used on the argument value.
  //! Note that the order in which arguments are parsed is arbitrary.

  Type def_arg_type = t_text (PEnt);
  //! The type used for arguments that isn't present in neither
  //! @[req_arg_types] nor @[opt_arg_types]. This default is a parser
  //! that only parses XML-style entities.

  Type content_type = t_same (PXml);
  //! The handled type of the content, if the tag gets any.
  //!
  //! The default is the special type @[RXML.t_same], which means the
  //! type is taken from the effective type of the result. The
  //! argument to the type is @[RXML.PXml], which causes that parser,
  //! i.e. the standard XML parser, to be used to read it. The effect
  //! is that the content is preparsed with XML syntax. Use no parser,
  //! or @[RXML.PNone], to get the raw text.
  //!
  //! Note: You probably want to change this to @[RXML.t_text]
  //! (without parser) if the tag is a processing instruction (see
  //! @[FLAG_PROC_INSTR]).

  array(Type) result_types = ({t_xml, t_html, t_text});
  //! The possible types of the result, in order of precedence. If a
  //! result type has a parser, it'll be used to parse any strings in
  //! the exec array returned from @[Frame.do_enter] and similar
  //! callbacks.
  //!
  //! When the tag is used in content of some type, the content type
  //! may be a supertype of any type in @[result_types], but it may
  //! also be a subtype of any of them. The tag must therefore be
  //! prepared to produce result of more specific types than those
  //! declared here. I.e. the extreme case, @[RXML.t_any], means that
  //! this tag takes the responsibility to produce result of any type
  //! that's asked for, not that it has the liberty to produce results
  //! of any type it chooses.

  //! @decl program Frame;
  //! @decl object(Frame) Frame();
  //!
  //! This program/function is used to clone the objects used as
  //! frames. A frame object must (in practice) inherit @[RXML.Frame].
  //! (It can, of course, be any function that requires no arguments
  //! and returns a new frame object.) This is not used for plugin
  //! tags.

  //! @decl string plugin_name;
  //!
  //! If this is defined, this is a so-called plugin tag. That means
  //! it plugs in some sort of functionality in another @[RXML.Tag]
  //! object instead of handling the actual tags of its own. It works
  //! as follows:
  //!
  //! @list ul
  //!  @item
  //!   Instead of installing the callbacks for this tag, the parser
  //!   uses another registered "socket" @[Tag] object that got the
  //!   same name as this one. Socket tags have the @[FLAG_SOCKET_TAG]
  //!   flag set to signify that they accept plugins.
  //!  @item
  //!   When the socket tag is parsed or evaluated, it can get the
  //!   @[Tag] objects for the registered plugins with the function
  //!   @[Frame.get_plugins]. It's then up to the socket tag to use
  //!   the plugins according to some API it defines.
  //!  @item
  //!   @[plugin_name] is the name of the plugin. It's used as index
  //!   in the mapping that the @[Frame.get_plugins] returns.
  //!  @item
  //!   The plugin tag is registered in the tag set with the
  //!   identifier @code{@[name] + "#" + @[plugin_name]@}.
  //!
  //!   It overrides other plugin tags with that name according to
  //!   the normal tag set rules, but, as said above, is never
  //!   registered for actual parsing at all.
  //!
  //!   It's undefined whether plugin tags override normal tags --
  //!   @tt{#@} should never be used in normal tag names.
  //!  @item
  //!   It's not an error to register a plugin for which there is no
  //!   socket. Such plugins are simply ignored.
  //! @endlist

  //(!) Services:

  inline final object/*(Frame)HMM*/ `() (mapping(string:mixed) args, void|mixed content)
  //! Make an initialized frame for the tag. Typically useful when
  //! returning generated tags from e.g. @[RXML.Frame.do_process]. The
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

  int eval_args (mapping(string:mixed) args, void|int dont_throw,
		 void|Context ctx, void|array(string) ignore_args)
  //! Parses and evaluates the tag arguments according to
  //! @[req_arg_types] and @[opt_arg_types]. The @[args] mapping
  //! contains the unparsed arguments on entry, and they get replaced
  //! by the parsed results. Arguments not mentioned in
  //! @[req_arg_types] or @[opt_arg_types] are evaluated with the default
  //! argument type, unless listed in @[ignore_args]. RXML errors, such
  //! as missing argument, are thrown if @[dont_throw] is zero or left
  //! out, otherwise zero is returned when any such error occurs. @[ctx]
  //! specifies the context to use; it defaults to the current context.
  {
    // Note: Code duplication in Frame._eval_args and Frame._prepare.
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
      foreach (indices (args) - ( ignore_args||({}) ), string arg)
	args[arg] = (atypes[arg] || def_arg_type)->eval (
	  args[arg], ctx);	// Should not unwind.
#ifdef MODULE_DEBUG
    }) {
      if (objectp (err) && ([object] err)->thrown_at_unwind)
	fatal_error ("Can't save parser state when evaluating arguments.\n");
      throw_fatal (err);
    }
#endif
    return 1;
  }

  //(!) Internals:

#define MAKE_FRAME(_frame, _ctx, _parser, _args)			\
  make_new_frame: do {							\
    if (UNWIND_STATE ustate = _ctx->unwind_state)			\
      if (ustate[_parser]) {						\
	_frame = [object/*(Frame)HMM*/] ustate[_parser][0];		\
	m_delete (ustate, _parser);					\
	if (!sizeof (ustate)) _ctx->unwind_state = 0;			\
	break make_new_frame;						\
      }									\
    _frame = `() (0, nil);						\
    DO_IF_DEBUG(							\
      if (_args && ([mapping] (mixed) _args)["-debug-tag-"]) {		\
	_frame->flags |= FLAG_DEBUG;					\
	m_delete (_args, "-debug-tag-");				\
      }									\
    );									\
    TAG_DEBUG (_frame, "New frame\n");					\
  } while (0)

#define EVAL_FRAME(_frame, _ctx, _parser, _type, _args, _content, _res)	\
  eval_frame: do {							\
    mixed err = catch {							\
      EVAL_ARGS_FUNC argfunc;						\
      if (!_frame->args)						\
	argfunc = _frame->_prepare (_ctx, _type, _args);		\
      _res = _frame->_eval (_ctx, _parser, _type, _content || "");	\
      if (_parser->p_code) {						\
	_frame->args = argfunc;						\
	_parser->p_code->add (_frame);					\
      }									\
      break eval_frame;							\
    };									\
									\
    if (objectp (err) && ([object] err)->thrown_at_unwind) {		\
      UNWIND_STATE ustate = _ctx->unwind_state;				\
      if (!ustate) ustate = _ctx->unwind_state = ([]);			\
      DO_IF_DEBUG (							\
	if (err != _frame)						\
	  fatal_error ("Unexpected unwind object catched.\n");		\
	if (ustate[_parser])						\
	  fatal_error ("Clobbering unwind state for parser.\n");	\
      );								\
      ustate[_parser] = ({_frame});					\
      throw (_parser);							\
    }									\
    else {								\
      /* Will rethrow unknown errors. */				\
      _ctx->handle_exception (err, _parser);				\
      _res = nil;							\
    }									\
  } while (0)

  final mixed handle_tag (TagSetParser parser, mapping(string:string) args,
			  void|string content)
  // Callback for tag set parsers to handle tags. Note that this
  // function handles an unwind frame for the parser.
  {
    // Note: args may be zero when this is called for PI tags.

    Context ctx = parser->context;

    object/*(Frame)HMM*/ frame;
    MAKE_FRAME (frame, ctx, parser, args);

    if (!zero_type (frame->raw_tag_text))
      frame->raw_tag_text = parser->raw_tag_text();

    mixed result;
    EVAL_FRAME (frame, ctx, parser, parser->type, args, content, result);

    return result;
  }

  final array _p_xml_handle_tag (object/*(PXml)*/ parser, mapping(string:string) args,
				 void|string content)
  {
    Type type = parser->type;
    if (type->handle_literals) parser->handle_literal();
    else if (parser->p_code) parser->p_code_literal();

    Context ctx = parser->context;

    object/*(Frame)HMM*/ frame;
    MAKE_FRAME (frame, ctx, parser, args);

    if (!zero_type (frame->raw_tag_text))
      frame->raw_tag_text = parser->current_input();

    mixed result;
    EVAL_FRAME (frame, ctx, parser, type, args, content, result);

    if (result != nil) {
      if (type->free_text && !parser->p_code) return ({result});
      parser->add_value (result);
    }
    return ({});
  }

  final array _p_xml_handle_pi_tag (object/*(PXml)*/ parser, string content)
  {
    Type type = parser->type;
    if (type->handle_literals) parser->handle_literal();
    else if (parser->p_code) parser->p_code_literal();

    sscanf (content, "%[ \t\n\r]%s", string ws, string rest);
    if (ws == "" && rest != "") {
      // The parser didn't match a complete name, so this is a false
      // alarm for an unknown PI tag.
      if (!type->free_text)
	return utils->unknown_pi_tag_error (parser, content);
      return 0;
    }

    Context ctx = parser->context;

    object/*(Frame)HMM*/ frame;
    MAKE_FRAME (frame, ctx, parser, 0);

    if (!zero_type (frame->raw_tag_text))
      frame->raw_tag_text = parser->current_input();

    mixed result;
    EVAL_FRAME (frame, ctx, parser, type, 0, content, result);

    if (result != nil) {
      if (type->free_text && !parser->p_code) return ({result});
      parser->add_value (result);
    }
    return ({});
  }

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
//! later changes in them are propagated. Parser instances (contexts)
//! to parse data are created from this. @[TagSet] objects may
//! somewhat safely be destructed explicitly; the tags in a destructed
//! tag set will not be active in parsers that are instantiated later,
//! but will work in current instances. Element (i.e. non-PI) tags and
//! PI tags have separate namespaces.
//!
//! @note
//! An @[RXML.Tag] object may not be registered in more than one tag
//! set at the same time.
{
  string name;
  //! Used for identification only.

  string prefix;
  //! A namespace prefix that may precede the tags. If it's zero, it's
  //! up to the importing tag set(s). A @tt{:@} is always inserted
  //! between the prefix and the tag name.
  //!
  //! @note
  //! This namespace scheme is not compliant with the XML namespaces
  //! standard. Since the intention is to implement XML namespaces at
  //! some point, this way of specifying tag prefixes will probably
  //! change.

  int prefix_req;
  //! The prefix must precede the tags.

  array(TagSet) imported = ({});
  //! Other tag sets that will be used. The precedence is local tags
  //! first, then imported from left to right. It's not safe to
  //! destructively change entries in this array.

  function(Context:void) prepare_context;
  //! If set, this is a function that will be called before a new
  //! @[RXML.Context] object is taken into use. It'll typically
  //! prepare predefined scopes and variables. The functions will be
  //! called in order of precedence; highest last.

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
    if (!callablep (tag->Frame) && !tag->plugin_name)
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
      if (!callablep (tag->Frame)&& !tag->plugin_name)
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
  //! If tag is an @[RXML.Tag] object, it's removed if this tag set
  //! contains it. If tag is a string, the tag with that name is
  //! removed. In the latter case, if @[proc_instr] is nonzero the set
  //! of PI tags is searched, else the set of normal element tags.
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
  //! Returns the @[RXML.Tag] object for the given name in this tag
  //! set, if any. If @[proc_instr] is nonzero the set of PI tags is
  //! searched, else the set of normal element tags.
  {
    return proc_instr ? proc_instrs && proc_instrs[name] : tags[name];
  }

  local array(Tag) get_local_tags()
  //! Returns all the @[RXML.Tag] objects in this tag set.
  {
    array(Tag) res = values (tags);
    if (proc_instrs) res += values (proc_instrs);
    return res;
  }

  local Tag get_tag (string name, void|int proc_instr)
  //! Returns the @[RXML.Tag] object for the given name, if any,
  //! that's defined by this tag set (including its imported tag
  //! sets). If @[proc_instr] is nonzero the set of PI tags is
  //! searched, else the set of normal element tags.
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
    if (zero_type (tag = overridden_tag_lookup[overrider])) {
      string overrider_name = overrider->plugin_name ?
	overrider->plugin_name + "#" + overrider->name : overrider->name;
      tag = overridden_tag_lookup[overrider] =
	overrider->flags & FLAG_PROC_INSTR ?
	find_overridden_proc_instr (overrider, overrider_name) :
	find_overridden_tag (overrider, overrider_name);
    }
    return tag;
  }

  local array(Tag) get_overridden_tags (string name, void|int proc_instr)
  //! Returns all tag definitions for the given name, i.e. including
  //! the overridden ones. A tag to the left overrides one to the
  //! right. If @[proc_instr] is nonzero the set of PI tags is
  //! searched, else the set of normal element tags.
  {
    if (object(Tag) def = get_local_tag (name, proc_instr))
      return ({def}) + imported->get_overridden_tags (name, proc_instr) * ({});
    else
      return imported->get_overridden_tags (name, proc_instr) * ({});
  }

  void add_string_entities (mapping(string:string) entities)
  //! Adds a set of entity replacements that are used foremost by the
  //! @[RXML.PXml] parser to decode simple entities like @tt{&amp;@}.
  //! The indices are the entity names without @tt{&@} and @tt{;@}.
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
  //! Returns the registered plugins for the given tag name. If
  //! @[proc_instr] is nonzero, the function searches for processing
  //! instruction plugins, otherwise it searches for plugins to normal
  //! element tags. Don't be destructive on the returned mapping.
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

  function(Backtrace,Type:string) handle_run_error =
    lambda (Backtrace err, Type type)
    //! Formats the run error backtrace.
    // This wrapper function however only search for a
    // "real" handle_run_error function.
    {
      string result;
      foreach(imported, TagSet tag_set) {
	result = tag_set->handle_run_error(err, type);
	if(result) return result;
      }
      return 0;
    };

  function(Backtrace,Type:string) handle_parse_error =
    lambda (Backtrace err, Type type)
    //! Formats the parse error backtrace.
    // This wrapper function however only search for a
    // "real" handle_parse_error function.
    {
      string result;
      foreach(imported, TagSet tag_set) {
	result = tag_set->handle_parse_error(err, type);
	if(result) return result;
      }
      return 0;
    };

  //(!) Internals:

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

  /*static*/ Tag find_overridden_tag (Tag overrider, string overrider_name)
  {
    if (tags[overrider_name] == overrider) {
      foreach (imported, TagSet tag_set)
	if (object(Tag) overrider = tag_set->get_tag (overrider_name))
	  return overrider;
    }
    else {
      int found = 0;
      foreach (imported, TagSet tag_set)
	if (object(Tag) subtag = tag_set->get_tag (overrider_name))
	  if (found) return subtag;
	  else if (subtag == overrider)
	    if ((subtag = tag_set->find_overridden_tag (
		   overrider, overrider_name)))
	      return subtag;
	    else found = 1;
    }
    return 0;
  }

  /*static*/ Tag find_overridden_proc_instr (Tag overrider, string overrider_name)
  {
    if (proc_instrs && proc_instrs[overrider_name] == overrider) {
      foreach (imported, TagSet tag_set)
	if (object(Tag) overrider = tag_set->get_tag (overrider_name, 1))
	  return overrider;
    }
    else {
      int found = 0;
      foreach (imported, TagSet tag_set)
	if (object(Tag) subtag = tag_set->get_tag (overrider_name, 1))
	  if (found) return subtag;
	  else if (subtag == overrider)
	    if ((subtag = tag_set->find_overridden_proc_instr (
		   overrider, overrider_name)))
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
  //! This is called to get the value of the variable. @[ctx], @[var]
  //! and @[scope_name] are set to where this @[Value] object was
  //! found. Note that @[scope_name] can be on the form
  //! @tt{"scope.index1.index2..."@} when this object was encountered
  //! through subindexing. Either @[RXML.nil] or the undefined value
  //! may be returned if the variable doesn't have a value.
  //!
  //! If the @[type] argument is given, it's the type the returned
  //! value should have. If the value can't be converted to that type,
  //! an RXML error should be thrown. If you don't want to do any
  //! special handling of this, it's enough to call
  //! @code{@[type]->encode(value)@}, since the encode functions does
  //! just that.
  //!
  //! Some design discussion follows to justify the last paragraph;
  //! there are no more interface rules below.
  //!
  //! It may seem like forcing a lot of overhead upon the
  //! implementations having to call encode functions, but that's
  //! really not the case. In the case when a type check and
  //! conversion is wanted, i.e. when @[type] isn't zero, that work
  //! have to be done somewhere anyway, so letting the producer of the
  //! value do it instead of the caller both improves the chances for
  //! doing optimizations and gives more power to the producer.
  //!
  //! By using knowledge about the actual value, the producer can in
  //! many cases avoid the call to the encode function. A typical case
  //! is when the value is known to be an arbitrary literal string
  //! (not zero), which is preferably optimized like this:
  //!
  //! @example
  //!   return type && type != RXML.t_text ?
  //!          type->encode (my_string, RXML.t_text) : my_string;
  //! @endexample
  //!
  //! Also, by letting the producer know the type context of the value
  //! and handle the type conversion, it's possible for the producer
  //! to adapt the value according to the context it'll be used in,
  //! e.g. to return a powerful object if no type conversion is
  //! wanted, a simple text representation of it when the type is
  //! @[RXML.t_text], and a more nicely formatted representation when
  //! it's @[RXML.t_html].
  //!
  //! @note
  //! The @[type] argument being @tt{void|Type@} means that the caller
  //! is free to leave out that argument, not that the function
  //! implementor is free to ignore it.
  {
    mixed val = rxml_const_eval (ctx, var, scope_name, type);
    ctx->set_var(var, val, scope_name);
    return val;
  }

  mixed rxml_const_eval (Context ctx, string var, string scope_name, void|Type type);
  //! If the variable value is the same throughout the life of the
  //! context, this method should be used instead of @[rxml_var_eval].

  string _sprintf() {return "RXML.Value";}
}

class Scope
//! Interface for objects that emulate a scope mapping.
//!
//! @note
//! The @tt{scope_name@} argument to the functions can be on the form
//! @tt{"scope.index1.index2..."@} when this object was encountered
//! through subindexing.
{
  mixed `[] (string var, void|Context ctx,
	     void|string scope_name, void|Type type)
  //! Called to get the value of a variable in the scope. @[var] is
  //! the name of it, @[ctx] and @[scope_name] are set to where this
  //! @[Scope] object was found. Either @[RXML.nil] or the undefined
  //! value may be returned if the variable doesn't exist in the
  //! scope.
  //!
  //! If the @[type] argument is given, it's the type the returned
  //! value should have, unless it's an object which implements
  //! @[Value.rxml_var_eval]. If the value can't be converted to that
  //! type, an RXML error should be thrown. If you don't want to do
  //! any special handling of this, it's enough to call
  //! @tt{@[type]->encode(value)@}, since the encode functions does
  //! just that. See @[Value.rxml_var_eval] for more discussion about
  //! this.
  //!
  //! @note
  //! The @[type] argument being @tt{void|Type@} means that the caller
  //! is free to leave out that argument, not that the function
  //! implementor is free to ignore it.
    {parse_error ("Cannot query variable" + _in_the_scope (scope_name) + ".\n");}

  mixed `[]= (string var, mixed val, void|Context ctx, void|string scope_name)
  //! Called to set the value of a variable in the scope. @[var] is
  //! the name of it, @[ctx] and @[scope_name] are set to where this
  //! @[Scope] object was found.
  //!
  //! An RXML error may be thrown if the value is not acceptable for
  //! the variable. It's undefined what happens if a variable is set
  //! to @[RXML.nil]; it should be avoided.
    {parse_error ("Cannot set variable" + _in_the_scope (scope_name) + ".\n");}

  array(string) _indices (void|Context ctx, void|string scope_name)
  //! Called to get a list of all defined variables in the scope.
  //! @[ctx] and @[scope_name] are set to where this @[Scope] object
  //! was found.
  //!
  //! There's no guarantee that the returned variable names produce a
  //! value (i.e. neither @[RXML.nil] nor the undefined value) when
  //! indexed.
    {parse_error ("Cannot list variables" + _in_the_scope (scope_name) + ".\n");}

  void _m_delete (string var, void|Context ctx, void|string scope_name)
  //! Called to delete a variable in the scope. @[var] is the name of
  //! it, @[ctx] and @[scope_name] are set to where this @[Scope]
  //! object was found.
  {
    if (m_delete != local::m_delete)
      m_delete (var, ctx, scope_name); // For compatibility with 2.1.
    else
      parse_error ("Cannot delete variable" + _in_the_scope (scope_name) + ".\n");
  }

  void m_delete (string var, void|Context ctx, void|string scope_name)
  // For compatibility with 2.1.
    {_m_delete (var, ctx, scope_name);}

  private string _in_the_scope (string scope_name)
  {
    if (scope_name)
      if (scope_name != "_") return " in the scope " + scope_name;
      else return " in the current scope";
    else return "";
  }

  string _sprintf() {return "RXML.Scope";}
}

class Context
//! A parser context. This contains the current variable bindings and
//! so on. The current context can always be retrieved with
//! @[RXML.get_context].
//!
//! @note
//! Don't store pointers to this object since that will likely
//! introduce circular references. It can be retrieved easily through
//! @[RXML.get_context].
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
  //! If set, the @tt{user_*_var@} functions access the variables in
  //! the scope "form" by default, and there's no subindex splitting
  //! or ".." decoding is done (see @[parse_user_var]).
  //! 
  //! @note
  //! This is only present when the @tt{OLD_RXML_COMPAT@} define is
  //! set.
#endif

#ifdef PROFILE_PARSER
  mapping(string:int) profile = ([]);
#endif

  array(string|int) parse_user_var (string var, void|string|int scope_name)
  //! Parses the var string for scope and/or subindexes according to
  //! the RXML rules, e.g. @tt{"scope.var.1.foo"@}. Returns an array
  //! where the first entry is the scope, and the remaining entries
  //! are the list of indexes. If @[scope_name] is a string, it's used
  //! as the scope and the var string is only used for subindexes. A
  //! default scope is chosen as appropriate if var cannot be split,
  //! unless @[scope_name] is a nonzero integer in which case it's
  //! returned in the scope position in the array (useful to detect
  //! whether @[var] actually was splitted or not).
  //!
  //! @tt{".."@} in the var string quotes a literal @tt{"."@}, e.g.
  //! @tt{"yow...cons..yet"@} is separated into @tt{"yow."@} and
  //! @tt{"cons.yet"@}. Any subindex that can be parsed as a signed
  //! integer is converted to it. Note that it doesn't happen for the
  //! first index, since a variable in a scope always is a string.
  {
#ifdef OLD_RXML_COMPAT
    if (compatible_scope && !intp(scope_name))
      return ({scope_name || "form", var});
#endif

    array(string|int) splitted;
    if(has_value(var, "..")) {
      // The \0 stuff is really here for a reason: The _only_ special
      // character is '.'.
      string coded = replace (var, "\0", "\0\0");
      if (coded != var)
	splitted = map (replace (coded, "..", "\0p") / ".",
			replace, ({"\0p", "\0\0"}), ({".", "\0"}));
      else
	splitted = map (replace (var, "..", "\0") / ".", replace, "\0", ".");
    }
    else
      splitted = var / ".";

    if (stringp (scope_name))
      splitted = ({scope_name}) + splitted;
    else if (sizeof (splitted) == 1)
      splitted = ({scope_name || "_"}) + splitted;

    for (int i = 2; i < sizeof (splitted); i++)
      if (sscanf (splitted[i], "%d%*c", int d) == 1) splitted[i] = d;

    return splitted;
  }

  local mixed get_var (string|array(string|int) var, void|string scope_name,
		       void|Type want_type)
  //! Returns the value of the given variable in the specified scope,
  //! or the current scope if none is given. Returns undefined (zero
  //! with zero type 1) if there's no such variable (or it's
  //! @[RXML.nil]).
  //!
  //! If @[var] is an array, it's used to successively index the value
  //! to get subvalues (see @[rxml_index] for details).
  //!
  //! If the @[want_type] argument is set, the result value is
  //! converted to that type with @[Type.encode]. If the value can't
  //! be converted, an RXML error is thrown.
  {
#ifdef MODULE_DEBUG
    if (arrayp (var) ? !sizeof (var) : !stringp (var))
      fatal_error ("Invalid variable specifier.\n");
#endif
    if (!scope_name) scope_name = "_";
    if (SCOPE_TYPE vars = scopes[scope_name])
      return rxml_index (vars, var, scope_name, this_object(), want_type);
    else if (scope_name == "_") parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  mixed user_get_var (string var, void|string scope_name, void|Type want_type)
  //! As @[get_var], but parses the var string for scope and/or
  //! subindexes, e.g. @tt{"scope.var.1.foo"@} (see @[parse_user_var]
  //! for details).
  //!
  //! @note
  //! This is intended for situations where you get a variable
  //! reference on the dot form in e.g. user input. In other cases,
  //! when the scope and variable is known, it's more efficient to use
  //! @[get_var].
  {
    if(!var || !sizeof(var)) return ([])[0];
    array(string|int) splitted = parse_user_var (var, scope_name);
    return get_var (splitted[1..], splitted[0], want_type);
  }

  local mixed set_var (string|array(string|int) var, mixed val, void|string scope_name)
  //! Sets the value of a variable in the specified scope, or the
  //! current scope if none is given. Returns @[val].
  //!
  //! If @[var] is an array, it's used to successively index the value
  //! to get subvalues (see @[rxml_index] for details).
  {
#ifdef MODULE_DEBUG
    if (arrayp (var) ? !sizeof (var) : !stringp (var))
      fatal_error ("Invalid variable specifier.\n");
#endif

    if (!scope_name) scope_name = "_";
    if (SCOPE_TYPE vars = scopes[scope_name]) {
      string|int index;
      if (arrayp (var))
	if (sizeof (var) > 1) {
	  index = var[-1];
	  var = var[..sizeof (var) - 1];
	  vars = rxml_index (vars, var, scope_name, this_object());
	  scope_name += "." + (array(string)) var * ".";
	}
	else index = var[0];
      else index = var;

      if (objectp (vars) && vars->`[]=)
	return ([object(Scope)] vars)->`[]= (index, val, this_object(), scope_name);
      else if (mappingp (vars) || multisetp (vars))
	return vars[index] = val;
      else if (arrayp (vars))
	if (intp (index) && index)
	  if ((index < 0 ? -index : index) > sizeof (vars))
	    parse_error( "Index %d out of range for array of size %d in %s.\n",
			 index, sizeof (val), scope_name );
	  else if (index < 0)
	    return vars[index] = val;
	  else
	    return vars[index - 1] = val;
	else
	  parse_error( "Cannot index the array in %s with %O.\n", scope_name, index );
      else
	parse_error ("%s is %O which cannot be indexed with %O.\n",
		     scope_name, vars, index);
    }

    else if (scope_name == "_") parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  mixed user_set_var (string var, mixed val, void|string scope_name)
  //! As @[set_var], but parses the var string for scope and/or
  //! subindexes, e.g. @tt{"scope.var.1.foo"@} (see @[parse_user_var]
  //! for details).
  //!
  //! @note
  //! This is intended for situations where you get a variable
  //! reference on the dot form in e.g. user input. In other cases,
  //! when the scope and variable is known, it's more efficient to use
  //! @[set_var].
  {
    if(!var || !sizeof(var)) parse_error ("No variable specified.\n");
    array(string|int) splitted = parse_user_var (var, scope_name);
    return set_var(splitted[1..], val, splitted[0]);
  }

  local void delete_var (string|array(string|int) var, void|string scope_name)
  //! Removes a variable in the specified scope, or the current scope
  //! if none is given.
  //!
  //! If @[var] is an array, it's used to successively index the value
  //! to get subvalues (see @[rxml_index] for details).
  {
#ifdef MODULE_DEBUG
    if (arrayp (var) ? !sizeof (var) : !stringp (var))
      fatal_error ("Invalid variable specifier.\n");
#endif

    if (!scope_name) scope_name = "_";
    if (SCOPE_TYPE vars = scopes[scope_name]) {
      if (arrayp (var))
	if (sizeof (var) > 1) {
	  string|int last = var[-1];
	  var = var[..sizeof (var) - 1];
	  vars = rxml_index (vars, var, scope_name, this_object());
	  scope_name += "." + (array(string)) var * ".";
	  var = last;
	}
	else var = var[0];

      if (objectp (vars) && vars->_m_delete)
	([object(Scope)] vars)->_m_delete (var, this_object(), scope_name);
      else if (mappingp (vars))
	m_delete ([mapping(string:mixed)] vars, var);
      else if (multisetp (vars))
	vars[var] = 0;
      else
	parse_error ("Cannot remove the index %O from the %t in %s.\n",
		     var, vars, scope_name);
    }

    else if (scope_name == "_") parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  void user_delete_var (string var, void|string scope_name)
  //! As @[delete_var], but parses the var string for scope and/or
  //! subindexes, e.g. @tt{"scope.var.1.foo"@} (see @[parse_user_var]
  //! for details).
  //!
  //! @note
  //! This is intended for situations where you get a variable
  //! reference on the dot form in e.g. user input. In other cases,
  //! when the scope and variable is known, it's more efficient to use
  //! @[delete_var].
  {
    if(!var || !sizeof(var)) return;
    array(string|int) splitted = parse_user_var (var, scope_name);
    delete_var(splitted[1..], splitted[0]);
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
  //! scope can be a mapping or an @[RXML.Scope] object. A global
  //! @tt{"_"@} scope may also be defined this way.
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
      if (!oldvars) fatal_error ("I before e except after c.\n");
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
      string scope_name = search (scopes, vars);
      do
	if (scope_name != "_") return scope_name;
      while ((scope_name = search (scopes, vars, scope_name)));
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
  //! If @[tag] is an @[RXML.Tag] object, it's removed from the set of
  //! runtime tags. If @[tag] is a string, the tag with that name is
  //! removed. In the latter case, if @[proc_instr] is nonzero the set
  //! of runtime PI tags is searched, else the set of normal element
  //! runtime tags.
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
      evaluator->error_count++;
      if (evaluator->report_error && evaluator->recover_errors &&
	  evaluator->type->free_text) {
	string msg;
	if (id && id->conf) {
	  msg = err->type == "help" ? err->msg :
	    (err->type == "run" ?
	     ([function(Backtrace,Type:string)]
	      tag_set->handle_run_error) :
	     ([function(Backtrace,Type:string)]
	      tag_set->handle_parse_error)
	    ) ([object(Backtrace)] err, evaluator->type);
	  if(!msg)
	    msg = describe_error(err);
	}
	else
	  msg = err->msg;
	if (evaluator->report_error (msg))
	  return;
      }
      throw (err);
    }
    else throw_fatal (err);
  }

  //(!) Internals:

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
    if (!frame->vars) fatal_error ("Frame has no variables.\n");
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

#define ENTER_SCOPE(ctx, frame) \
  (frame->vars && frame->vars != ctx->scopes["_"] && ctx->enter_scope (frame))
#define LEAVE_SCOPE(ctx, frame) \
  (frame->vars && ctx->leave_scope (frame))

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

  UNWIND_STATE unwind_state;
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
    String.Buffer txt = String.Buffer();
    txt->add (no_msg ? "" : "RXML" + (type ? " " + type : "") + " error");
    if (context) {
      if (!no_msg) txt->add (": " + (msg || "(no error message)\n"));
      if (current_var) txt->add (" | &" + current_var + ";\n");
      for (Frame f = frame; f; f = f->up) {
	string name;
	if (f->tag) name = f->tag->name;
	else if (!f->up) break;
	else name = "(unknown)";
	if (f->flags & FLAG_PROC_INSTR)
	  txt->add (" | <?" + name + "?>\n");
	else {
	  txt->add (" | <" + name);
	  if (mappingp (f->args))
	    foreach (sort (indices (f->args)), string arg) {
	      mixed val = f->args[arg];
	      txt->add (" " + arg + "=");
	      if (arrayp (val)) txt->add (map (val, error_print_val) * ",");
	      else txt->add (error_print_val (val));
	    }
	  else txt->add (" (no argmap)");
	  txt->add (">\n");
	}
      }
    }
    else
      if (!no_msg) txt->add (" (no context): " + (msg || "(no error message)\n"));
    return txt->get();
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


//(!) Current context:

//(!) It's set before any function in RXML.Tag or RXML.Frame is called.

#if constant (thread_create)
private Thread.Local _context = Thread.Local();
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
  }									\
  PROFILE_ENTER (ctx, "rxml internal");

#define LEAVE_CONTEXT()							\
  PROFILE_LEAVE (get_context(), "rxml internal");			\
  if (Context ctx = get_context())					\
    if (__old_ctx != ctx) ctx->in_use = 0;				\
  set_context (__old_ctx);

#else

#define ENTER_CONTEXT(ctx)						\
  Context __old_ctx = get_context();					\
  set_context (ctx);							\
  PROFILE_ENTER (ctx, "rxml internal");

#define LEAVE_CONTEXT()							\
  PROFILE_LEAVE (get_context(), "rxml internal");			\
  set_context (__old_ctx);

#endif


//(!) Constants for the bit field RXML.Frame.flags.

constant FLAG_NONE		= 0x00000000;
//! The no-flags flag. In case you think 0 is too ugly. ;)

constant FLAG_DEBUG		= 0x40000000;
//! Write a lot of debug during the execution of the tag, showing what
//! type conversions are done, what callbacks are being called etc.
//! Note that @tt{DEBUG@} must be defined for the debug printouts to
//! be compiled in (normally enabled with the @tt{--debug@} flag to
//! Roxen).

//(!) Static flags (i.e. tested in the Tag object):

constant FLAG_PROC_INSTR	= 0x00000010;
//! Flags this as a processing instruction tag (i.e. one parsed with
//! the @tt{<?name ... ?>@} syntax in XML). The string after the tag
//! name to the ending separator constitutes the content of the tag.
//! Arguments are not used.

constant FLAG_COMPAT_PARSE	= 0x00000002;
//! Makes the @[RXML.PXml] parser parse the tag in an HTML compatible
//! way: If @[FLAG_EMPTY_ELEMENT] is set and the tag doesn't end with
//! @tt{"/>"@}, it will be parsed as an empty element. The effect of
//! this flag in other parsers is currently undefined.

constant FLAG_NO_PREFIX		= 0x00000004;
//! Never apply any prefix to this tag.

constant FLAG_SOCKET_TAG	= 0x00000008;
//! Declare the tag to be a socket tag, which accepts plugin tags (see
//! @[RXML.Tag.plugin_name] for details).

constant FLAG_DONT_PREPARSE	= 0x00000040;
//! Don't preparse the content with the @[RXML.PXml] parser. This is
//! always the case for PI tags, so this flag doesn't have any effect
//! for those. This is only used in the simple tag wrapper. Defined
//! here as placeholder.

constant FLAG_POSTPARSE		= 0x00000080;
//! Postparse the result with the @[RXML.PXml] parser. This is only
//! used in the simple tag wrapper. Defined here as placeholder.

//(!) The rest of the flags are dynamic (i.e. tested in the Frame object):

constant FLAG_EMPTY_ELEMENT	= 0x00000001;
//! If set, the tag does not use any content. E.g. with an HTML parser
//! this defines whether the tag is a container or not, and in XML
//! parsing the parser will signal an error if the tag have anything
//! but "" as content. Should not be changed after
//! @[RXML.Frame.do_enter] has returned.

constant FLAG_PARENT_SCOPE	= 0x00000100;
//! If set, exec arrays will be interpreted in the scope of the parent
//! tag, rather than in the current one.

constant FLAG_NO_IMPLICIT_ARGS	= 0x00000200;
//! If set, the parser won't apply any implicit arguments. FIXME: Not
//! yet implemented.

constant FLAG_STREAM_RESULT	= 0x00000400;
//! If set, the @[do_process] function will be called repeatedly until
//! it returns 0 or no more content is wanted.

constant FLAG_STREAM_CONTENT	= 0x00000800;
//! If set, the tag supports getting its content in streaming mode:
//! @[do_process] will be called repeatedly with successive parts of
//! the content then. Can't be changed from @[do_process].
//! 
//! @note
//! It might be obvious, but using streaming is significantly less
//! effective than nonstreaming, so it should only be done when big
//! delays are expected.

constant FLAG_STREAM		= FLAG_STREAM_RESULT | FLAG_STREAM_CONTENT;

constant FLAG_UNPARSED		= 0x00001000;
//! If set, @[RXML.Frame.args] and @[RXML.Frame.content] contain
//! unparsed strings. The frame will be parsed before it's evaluated.
//! This flag should never be set in @[RXML.Tag.flags], but it's
//! useful when creating frames directly (see @[make_unparsed_tag]).

constant FLAG_DONT_RECOVER	= 0x00002000;
//! If set, RXML errors are never recovered when parsing the content
//! in the tag. If any occurs, it will instead abort the execution of
//! this tag too to propagate the error to the parent tag.
//!
//! When an error occurs, the parser aborts tags upward in the frame
//! stack until it comes to one which looks like it can accept an
//! error report in its content. The parser then reports the error
//! there and continues.
//!
//! The criteria for the frame which will handle the error recovery is
//! that its content type has the @[RXML.Type.free_text] property, and
//! that the parser that parses it has an @[RXML.Parser.report_error]
//! function (which e.g. @[RXML.PXml] has). With this flag, a frame
//! can declare that it isn't suitable to receive error reports even
//! if it satisfies this.

constant FLAG_DONT_REPORT_ERRORS = FLAG_DONT_RECOVER; // For compatibility.

constant FLAG_RAW_ARGS		= 0x00004000;
//! Special flag to @[RXML.t_xml.format_tag]; only defined here as a
//! placeholder. When this is given to @[RXML.t_xml.format_tag], it
//! only encodes the argument quote character with the "Roxen
//! encoding" when writing argument values, instead of encoding with
//! entity references. It's intended for reformatting a tag which has
//! been parsed by @[Parser.HTML] (or @[parse_html]) but hasn't been
//! processed further.

//(!) The following flags specifies whether certain conditions must be
//(!) met for a cached frame to be considered (if RXML.Frame.is_valid()
//(!) is defined). They may be read directly after do_return() returns.
//(!) The tag name is always the same. FIXME: These are ideas only;
//(!) nothing is currently implemented and they might change
//(!) arbitrarily.

constant FLAG_CACHE_DIFF_ARGS	= 0x00010000;
//(!) If set, the arguments to the tag need not be the same (using
//(!) @[equal]) as the cached args.

constant FLAG_CACHE_DIFF_CONTENT = 0x00020000;
//(!) If set, the content need not be the same.

constant FLAG_CACHE_DIFF_RESULT_TYPE = 0x00040000;
//(!) If set, the result type need not be the same. (Typically
//(!) not useful unless @[cached_return] is used.)

constant FLAG_CACHE_DIFF_VARS	= 0x00080000;
//(!) If set, the variables with external scope in vars (i.e. normally
//(!) those that has been accessed with @[get_var]) need not have the
//(!) same values (using @[equal]) as the actual variables.

constant FLAG_CACHE_DIFF_TAG_INSTANCE = 0x00100000;
//(!) If set, the tag in the source document needs to be the same, so
//(!) the same frame may be used when the tag occurs in another context.

constant FLAG_CACHE_EXECUTE_RESULT = 0x00200000;
//(!) If set, an exec array will be stored in the frame instead of the
//(!) final result. On a cache hit it'll be executed to produce the
//(!) result.

class Frame
//! A tag instance. A new frame is normally created for every parsed
//! tag in the source document. It might be reused both when the
//! document is requested again and when the tag is reevaluated in a
//! loop, but it's not certain in either case. Therefore, be careful
//! about using variable initializers.
{
  constant is_RXML_Frame = 1;
  constant thrown_at_unwind = 1;

  //(!) Interface:

  Frame up;
  //! The parent frame. This frame is either created from the content
  //! inside the up frame, or it's in an exec array produced by the up
  //! frame.

  Tag tag;
  //! The @[RXML.Tag] object this frame was created from.

  int flags;
  //! Various bit flags that affect parsing. See the @tt{FLAG_*@}
  //! constants. It's copied from @[Tag.flag] when the frame is
  //! created.

  mapping(string:mixed)|EVAL_ARGS_FUNC args;
  //! The (parsed and evaluated) arguments passed to the tag. Set
  //! every time the frame is executed, before any frame callbacks are
  //! called. Not set for processing instruction (@[FLAG_PROC_INSTR])
  //! tags.
  //!
  //! This variable is also used to hold a function that generates the
  //! argument mapping between evaluations of the frame. It never does
  //! when any of the callbacks except @[cached_return] are called,
  //! though.

  Type content_type;
  //! The type of the content.

  mixed|PCode content = nil;
  //! The content, if any. Set before @[do_process] and @[do_return]
  //! are called. Initialized to @[RXML.nil] every time the frame
  //! executed.
  //!
  //! This variable is also used to hold an unevaluated representation
  //! of the content between evaluations of the frame. It never does
  //! when any of the callbacks except @[cached_return] are called,
  //! though.

  Type result_type;
  //! The required result type. If it has a parser, it will affect how
  //! execution arrays are handled; see the return value for
  //! @[do_return] for details.
  //!
  //! This is set by the type inference from @[Tag.result_types] before
  //! any frame callbacks are called. The frame may change this type,
  //! but it must produce a result value which matches it. The value
  //! is converted before being inserted into the parent content if
  //! necessary. An exception (which this frame can't catch) is thrown
  //! if conversion is impossible.

  mixed result = nil;
  //! The result, which is assumed to be either @[RXML.nil] or a valid
  //! value according to result_type. The exec arrays returned by e.g.
  //! @[do_return] changes this. It may also be set directly.
  //! Initialized to @[RXML.nil] every time the frame executed.
  //!
  //! If @[result_type] has a parser set, it will be used by
  //! @[do_return] etc before assigning to this variable. Thus it
  //! contains the value after any parsing and will not be parsed
  //! again.

  //! @decl optional mapping(string:mixed) vars;
  //!
  //! Set this to introduce a new variable scope that will be active
  //! during parsing of the content and return values (but see also
  //! @[FLAG_PARENT_SCOPE]).

  //! @decl optional string scope_name;
  //!
  //! The scope name for the variables. Must be set before the scope
  //! is used for the first time, and can't be changed after that.

  //! @decl optional TagSet additional_tags;
  //!
  //! If set, the tags in this tag set will be used in addition to the
  //! tags inherited from the surrounding parser. The additional tags
  //! will in turn be inherited by subparsers.

  //! @decl optional TagSet local_tags;
  //!
  //! If set, the tags in this tag set will be used in the parser for
  //! the content, instead of the one inherited from the surrounding
  //! parser. The tags are not inherited by subparsers.

  //! @decl optional Frame parent_frame;
  //!
  //! If this variable exists, it gets set to the frame object of the
  //! closest surrounding tag that defined this tag in its
  //! @[additional_tags] or @[local_tags]. Useful to access the
  //! "mother tag" from the subtags it defines.

  //! @decl optional string raw_tag_text;
  //!
  //! If this variable exists, it gets the raw text representation of
  //! the tag, if there is any. Note that it's after parsing of any
  //! splice argument.

  //! @decl optional array do_enter (RequestID id);
  //! @decl optional array do_process (RequestID id, void|mixed piece);
  //! @decl optional array do_return (RequestID id);
  //!
  //! @[do_enter] is called first thing when processing the tag.
  //! @[do_process] is called after (some of) the content has been
  //! processed. @[do_return] is called lastly before leaving the tag.
  //!
  //! For tags that loops more than one time (see @[do_iterate]):
  //! @[do_enter] is only called initially before the first call to
  //! @[do_iterate]. @[do_process] is called after each iteration.
  //! @[do_return] is called after the last call to @[do_process].
  //!
  //! The @[result_type] variable is set to the type of result the
  //! parser wants. The tag may change it; the value will then be
  //! converted to the type that the parser wants. If the result type
  //! is sequential, it's added to the surrounding content, otherwise
  //! it is used as value of the content, and there's an error of the
  //! content has a value already. If the result is @[RXML.nil], it
  //! does not affect the surrounding content at all.
  //!
  //! Return values:
  //! @list dl
  //!  @item array
  //!   A so-called exec array to be handled by the parser. The
  //!	elements are processed in order, and have the following usage:
  //!   @list dl
  //!    @item string
  //!	  Added or put into the result. If the result type has a
  //!	  parser, the string will be parsed with it before it's
  //!	  assigned to the result variable and passed on.
  //!    @item RXML.Frame
  //!	  Already initialized frame to process. Neither arguments nor
  //!	  content will be parsed. It's result is added or put into the
  //!	  result of this tag.
  //!    @item mapping(string:mixed)
  //!	  A response mapping which will be returned instead of the
  //!	  evaluated page. The evaluation is stopped immediately after
  //!	  this. FIXME: Not yet implemented.
  //!    @item object
  //!	  Treated as a file object to read in blocking or nonblocking
  //!	  mode. FIXME: Not yet implemented, details not decided.
  //!    @item multiset(mixed)
  //!	  Should only contain one element that'll be added or put into
  //!	  the result. Normally not necessary; assign it directly to
  //!	  the result variable instead.
  //!    @item propagate_tag()
  //!	  Use a call to this function to propagate the tag to be
  //!	  handled by an overridden tag definition, if any exists. If
  //!	  this is used, it's probably necessary to define the
  //!	  @[raw_tag_text] variable. For further details see the doc
  //!	  for @[propagate_tag] in this class.
  //!   @endlist
  //!  @item 0
  //!   Do nothing special. Exits the tag when used from
  //!   @[do_process] and @[FLAG_STREAM_RESULT] is set.
  //! @endlist
  //!
  //! Note that the intended use is not to postparse by setting a
  //! parser on the result type, but instead to return an array with
  //! literal strings and @[RXML.Frame] objects where parsing (or,
  //! more accurately, evaluation) needs to be done.
  //!
  //! If an array instead of a function is given, the array is handled
  //! as above. If the result variable is @[RXML.nil] (which it
  //! defaults to), @[content] is used as @[result] if it's of a
  //! compatible type.
  //!
  //! If there is no @[do_return] and the result from parsing the
  //! content is not @[RXML.nil], it's assigned to or added to the
  //! @[result] variable. Assignment is used if the content type is
  //! nonsequential, addition otherwise.
  //!
  //! Regarding @[do_process] only:
  //!
  //! Normally the @[content] variable is set to the parsed content of
  //! the tag before @[do_process] is called. This may be @[RXML.nil]
  //! if the content parsing didn't produce any result.
  //!
  //! @[piece] is used when the tag is operating in streaming mode
  //! (i.e. @[FLAG_STREAM_CONTENT] is set). It's then set to each
  //! successive part of the content in the stream, and the @[content]
  //! variable is never touched. @[do_process] is also called
  //! "normally" with no @[piece] argument afterwards. Note that tags
  //! that support streaming mode might still be used nonstreaming (it
  //! might also vary between iterations).
  //!
  //! As long as @[FLAG_STREAM_RESULT] is set, @[do_process] will be
  //! called repeatedly until it returns 0. It's only the result piece
  //! from the execution array that is propagated after each turn; the
  //! result variable only accumulates all these pieces.

  //! @decl optional int do_iterate (RequestID id);
  //!
  //! Controls the number of passes in the tag done by the parser. In
  //! every pass, the content of the tag (if any) is processed, then
  //! @[do_process] is called.
  //!
  //! Before doing any pass, @[do_iterate] is called. If the return
  //! value is nonzero, that many passes is done, then @[do_iterate]
  //! is called again and the process repeats. If the return value is
  //! zero, the tag exits and the value in @[result] is used in the
  //! surrounding content as described above.
  //!
  //! The most common way to iterate is to do the setup before every
  //! pass (e.g. setup the variable scope) and return 1 to do one pass
  //! through the content. This will repeat until 0 is returned.
  //!
  //! If @[do_iterate] is a positive integer, that many passes is done
  //! and then the tag exits. If @[do_iterate] is zero or missing, one
  //! pass is done. If @[do_iterate] is negative, no pass is done.

  //! @decl optional int|function(RequestID:int) is_valid;
  //!
  //! When defined, the frame may be cached. First the name of the tag
  //! must be the same. Then the conditions specified by the cache
  //! bits in flag are checked. Then, if this is a function, it's
  //! called. If it returns 1, the frame is reused. FIXME: Not yet
  //! implemented.

  optional array cached_return (Context ctx, void|mixed piece);
  //! If defined, this will be called to get the value from a cached
  //! frame (that's still valid) instead of using the cached result.
  //! It's otherwise handled like @[do_return]. Note that the cached
  //! frame may be used from several threads. FIXME: Not yet
  //! implemented.

  //(!) Services:

  final mixed get_var (string var, void|string scope_name, void|Type want_type)
  //! A wrapper for easy access to @[RXML.Context.get_var].
  {
    return get_context()->get_var (var, scope_name, want_type);
  }

  final mixed set_var (string var, mixed val, void|string scope_name)
  //! A wrapper for easy access to @[RXML.Context.set_var].
  {
    return get_context()->set_var (var, val, scope_name);
  }

  final void delete_var (string var, void|string scope_name)
  //! A wrapper for easy access to @[RXML.Context.delete_var].
  {
    get_context()->delete_var (var, scope_name);
  }

  void run_error (string msg, mixed... args)
  //! A wrapper for easy access to @[RXML.run_error].
  {
    _run_error (msg, @args);
  }

  void parse_error (string msg, mixed... args)
  //! A wrapper for easy access to @[RXML.parse_error].
  {
    _parse_error (msg, @args);
  }

  void tag_debug (string msg, mixed... args)
  //! Writes the message to the debug log if this tag has
  //! @[FLAG_DEBUG] set.
  {
    if (flags & FLAG_DEBUG) report_debug (msg, @args);
  }

  void terminate()
  //! Makes the parser abort. The data parsed so far will be returned.
  //! Does not return; throws a special exception instead.
  {
    fatal_error ("FIXME\n");
  }

  void suspend()
  //! Used together with @[resume] for nonblocking mode. May be called
  //! from any frame callback to suspend the parser: The parser will
  //! just stop, leaving the context intact. If this function returns,
  //! the parser is used in a place that doesn't support nonblocking,
  //! so it's then ok to go ahead and block.
  {
    fatal_error ("FIXME\n");
  }

  void resume()
  //! Makes the parser continue where it left off. The function that
  //! called @[suspend] will be called again.
  {
    fatal_error ("FIXME\n");
  }

  mapping(string:Tag) get_plugins()
  //! Returns the plugins registered for this tag, which is assumed to
  //! be a socket tag, i.e. to have @[FLAG_SOCKET_TAG] set (see
  //! @[Tag.plugin_name] for details). Indices are the
  //! @tt{plugin_name@} values for the plugin @[RXML.Tag] objects,
  //! values are the plugin objects themselves. Don't be destructive
  //! on the returned mapping.
  {
#ifdef MODULE_DEBUG
    if (!(tag->flags & FLAG_SOCKET_TAG))
      fatal_error ("This tag is not a socket tag.\n");
#endif
    return get_context()->tag_set->get_plugins (tag->name, tag->flags & FLAG_PROC_INSTR);
  }

  final Tag get_overridden_tag()
  //! Returns the @[RXML.Tag] object the tag for this frame overrides,
  //! if any.
  {
    return get_context()->tag_set->get_overridden_tag (tag);
  }

  Frame|string propagate_tag (void|mapping(string:string) args, void|string content)
  //! This function is intended to be used in the execution array from
  //! @[do_return] etc to propagate the tag to the next overridden tag
  //! definition, if any exists. It either returns a frame from the
  //! overridden tag or, if no overridden tag exists, a string
  //! containing a formatted tag (which requires that the result type
  //! supports formatted tags, i.e. has a working @[format_tag]
  //! function). If @[args] and @[content] are given, they will be
  //! used in the tag after parsing, otherwise the @[raw_tag_text]
  //! variable is used, which must have a string value.
  {
    Frame this = this_object();
#ifdef MODULE_DEBUG
#define CHECK_RAW_TEXT							\
    if (zero_type (this->raw_tag_text))					\
      fatal_error ("The variable raw_tag_text must be defined.\n");	\
    if (!stringp (this->raw_tag_text))					\
      fatal_error ("raw_tag_text must have a string value.\n");
#else
#define CHECK_RAW_TEXT
#endif
    // FIXME: This assumes an xml-like parser.

    if (object(Tag) overridden = get_overridden_tag()) {
      Frame frame;
      if (flags & FLAG_PROC_INSTR) {
	if (!content) {
	  CHECK_RAW_TEXT;
	  content = t_xml->parse_tag (this->raw_tag_text)[2];
#ifdef DEBUG
	  if (!stringp (content))
	    fatal_error ("Failed to parse PI tag content for <?%s?> from %O.\n",
			 tag->name, this->raw_tag_text);
#endif
	}
      }
      else if (!args || !content && !(flags & FLAG_EMPTY_ELEMENT)) {
	CHECK_RAW_TEXT;
	string ignored;
	[ignored, args, content] = t_xml->parse_tag (this->raw_tag_text);
#ifdef DEBUG
	if (!mappingp (args))
	  fatal_error ("Failed to parse tag args for <%s> from %O.\n",
		       tag->name, this->raw_tag_text);
	if (!stringp (content) && !(flags & FLAG_EMPTY_ELEMENT))
	  fatal_error ("Failed to parse tag content for <%s> from %O.\n",
		       tag->name, this->raw_tag_text);
#endif
      }
      frame = overridden (args, content || "");
      frame->flags |= FLAG_UNPARSED;
      return frame;
    }

    else {
      CHECK_RAW_TEXT;
      // Format a new tag, as like the original as possible.

      if (flags & FLAG_PROC_INSTR) {
	if (content) {
	  string name;
	  [name, args, content] = t_xml->parse_tag (this->raw_tag_text);
	  return result_type->format_tag (name, 0, content, tag->flags);
	}
	else
	  return this->raw_tag_text;
      }

      else {
	string s;
#ifdef MODULE_DEBUG
	if (mixed err = catch {
#endif
	  s = t_xml (PXml)->eval (this->raw_tag_text,
				  get_context(), empty_tag_set);
#ifdef MODULE_DEBUG
	}) {
	  if (objectp (err) && ([object] err)->thrown_at_unwind)
	    fatal_error ("Can't save parser state when evaluating arguments.\n");
	  throw_fatal (err);
	}
#endif
	if (!args && !content) return s;

	[string name, mapping(string:string) parsed_args,
	 string parsed_content] = t_xml->parse_tag (this->raw_tag_text);
#ifdef DEBUG
	if (!mappingp (parsed_args))
	  fatal_error ("Failed to parse tag args for <%s> from %O.\n",
		       tag->name, this->raw_tag_text);
	if (!stringp (parsed_content))
	  fatal_error ("Failed to parse tag content for <%s> from %O.\n",
		       tag->name, this->raw_tag_text);
#endif
	if (!args) args = parsed_args;
	if (!content) content = parsed_content;
	return result_type->format_tag (name, args, content, tag->flags);
      }
#undef CHECK_RAW_TEXT
    }
  }

  //(!) Internals:

#ifdef DEBUG
#  define THIS_TAG_TOP_DEBUG(msg, args...) \
     (TAG_DEBUG_TEST (flags) && report_debug ("%O: " + (msg), this_object(), args), 0)
#  define THIS_TAG_DEBUG(msg, args...) \
     (TAG_DEBUG_TEST (flags) && report_debug ("%O:   " + (msg), this_object(), args), 0)
#  define THIS_TAG_DEBUG_ENTER_SCOPE(ctx, this)				\
     if (this->vars && ctx->scopes["_"] != this->vars)			\
       THIS_TAG_DEBUG ("(Re)entering scope %O\n", this->scope_name)
#  define THIS_TAG_DEBUG_LEAVE_SCOPE(ctx, this)				\
     if (this->vars && ctx->scopes["_"] == this->vars)			\
       THIS_TAG_DEBUG ("Leaving scope %O\n", this->scope_name)
#else
#  define THIS_TAG_TOP_DEBUG(msg, args...) 0
#  define THIS_TAG_DEBUG(msg, args...) 0
#  define THIS_TAG_DEBUG_ENTER_SCOPE(ctx, this) 0
#  define THIS_TAG_DEBUG_LEAVE_SCOPE(ctx, this) 0
#endif

#define SET_SEQUENTIAL(from, to, desc)					\
  do {									\
    THIS_TAG_DEBUG ("Adding %s to " desc "\n",				\
		    utils->format_short (from));			\
    to += from;								\
  } while (0)

#define SET_NONSEQUENTIAL(from, to, to_type, desc)			\
  do {									\
    if (from != nil) {							\
      if (to != nil)							\
	parse_error (							\
	  "Cannot append another value %s to non-sequential " desc	\
	  " of type %s.\n", utils->format_short (from),			\
	  to_type->name);						\
      THIS_TAG_DEBUG ("Setting " desc " to %s\n",			\
		      utils->format_short (from));			\
      to = from;							\
    }									\
  } while (0)

#define CONV_RESULT(from, from_type, to, to_type)			\
  do {									\
    if (from_type->name != to_type->name) {				\
      THIS_TAG_DEBUG ("Converting result from %s to %s of "		\
		      "surrounding content\n",				\
		      from_type->name, to_type->name);			\
      to = to_type->encode (from, from_type);				\
    }									\
    else to = from;							\
  } while (0)

  private void _exec_array_fatal (string where, int pos, mixed elem,
				  string msg, mixed... args)
  {
    if (sizeof (args)) msg = sprintf (msg, args);
    fatal_error ("Position %d in exec array from %s is %s: %s", pos, where, elem, msg);
  };

  mixed _exec_array (Context ctx, TagSetParser|PCode evaler, array exec, string where)
  {
    Frame this = this_object();
    int i = 0, parent_scope = flags & FLAG_PARENT_SCOPE;
    mixed res = nil;
    Parser subparser = 0;

    mixed err = catch {
      if (parent_scope) {
	THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this);
	LEAVE_SCOPE (ctx, this);
      }

      for (; i < sizeof (exec); i++) {
	mixed elem = exec[i], piece = nil;

	switch (sprintf ("%t", elem)) {
	  case "string":
	    if (result_type->parser_prog == PNone) {
	      THIS_TAG_DEBUG ("Exec[%d]: String %s\n", i, utils->format_short (elem));
	      piece = elem;
	    }
	    else {
	      subparser = result_type->get_parser (ctx, 0, evaler);
	      if (evaler->recover_errors && !(flags & FLAG_DONT_RECOVER))
		subparser->recover_errors = 1;
	      THIS_TAG_DEBUG ("Exec[%d]: Parsing string %s with %O\n", i,
			      utils->format_short (elem), subparser);
	      subparser->finish ([string] elem); // Might unwind.
	      piece = subparser->eval(); // Might unwind.
	      subparser = 0;
	    }
	    break;

	  case "mapping":
	    THIS_TAG_DEBUG ("Exec[%d]: Response mapping\n", i);
	    _exec_array_fatal (where, i, elem,
			       "Response mappings not yet implemented.\n");
	    break;

	  case "multiset":
	    if (sizeof ([multiset] elem) == 1) {
	      piece = ((array) elem)[0];
	      THIS_TAG_DEBUG ("Exec[%d]: Verbatim value %s\n", i,
			      utils->format_short (piece));
	    }
	    else
	      _exec_array_fatal (where, i, elem,
				 "Not exactly one value in multiset.\n");
	    break;

	  default:
	    if (objectp (elem))
	      // Can't count on that sprintf ("%t", ...) on an object
	      // returns "object".
	      if (([object] elem)->is_RXML_Frame) {
		THIS_TAG_DEBUG ("Exec[%d]: Evaluating frame %O\n", i, ([object] elem));
		piece = ([object(Frame)] elem)->_eval (
		  ctx, evaler, result_type); // Might unwind.
		break;
	      }
	      else if (([object] elem)->is_RXML_Parser) {
		// The subparser above unwound.
		THIS_TAG_DEBUG ("Exec[%d]: Continuing eval of frame %O\n",
				i, ([object] elem));
		([object(Parser)] elem)->finish(); // Might unwind.
		piece = ([object(Parser)] elem)->eval(); // Might unwind.
		break;
	      }
	    _exec_array_fatal (where, i, elem, "Not a valid type.\n");
	}

	if (result_type->sequential) SET_SEQUENTIAL (piece, res, "result");
	else SET_NONSEQUENTIAL (piece, result, result_type, "result");
      }

      if (result_type->sequential) result += res;
      else res = result;

      if (parent_scope) {
	THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this);
	ENTER_SCOPE (ctx, this);
      }
      return res;
    };

    if (result_type->sequential) result += res;
    if (parent_scope) {
      THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this);
      ENTER_SCOPE (ctx, this);
    }

    if (objectp (err) && ([object] err)->thrown_at_unwind) {
      THIS_TAG_DEBUG ("Exec: Interrupted at position %d\n", i);
      UNWIND_STATE ustate;
      if ((ustate = ctx->unwind_state) && !zero_type (ustate->stream_piece)) {
	// Subframe wants to stream. Update stream_piece and send it on.
	if (result_type->name != evaler->type->name)
	  res = evaler->type->encode (res, result_type);
	if (result_type->sequential)
	  SET_SEQUENTIAL (ustate->stream_piece, res, "stream piece");
	else
	  SET_NONSEQUENTIAL (ustate->stream_piece, res, result_type, "stream piece");
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
	  THIS_TAG_DEBUG ("Adding runtime tag %O\n", tag);
	  ([object(TagSetParser)] p)->add_runtime_tag (tag);
	}
	foreach (arr_rem_tags, string tag) {
	  THIS_TAG_DEBUG ("Removing runtime tag %s\n", tag);
	  ([object(TagSetParser)] p)->remove_runtime_tag (tag);
	}
	foreach (arr_rem_pi_tags, string tag) {
	  THIS_TAG_DEBUG ("Removing runtime tag %s\n", tag);
	  ([object(TagSetParser)] p)->remove_runtime_tag (tag, 1);
	}
      }
    ctx->runtime_tags = ctx->new_runtime_tags->filter_tags (ctx->runtime_tags);
    ctx->new_runtime_tags = 0;
  }

#define LOW_CALL_CALLBACK(res, cb, args...)				\
  do {									\
    THIS_TAG_DEBUG ("Calling " #cb "\n");				\
    PROFILE_SWITCH (ctx, "rxml internal", "tag:" + tag->name);		\
    COND_PROF_ENTER(tag,tag->name,"tag");				\
    res = (cb) (args); /* Might unwind. */				\
    COND_PROF_LEAVE(tag,tag->name,"tag");				\
    PROFILE_SWITCH (ctx, "tag:" + tag->name, "rxml internal");		\
  } while (0)

#define EXEC_CALLBACK(ctx, evaler, exec, cb, args...)			\
  do {									\
    if (!exec)								\
      if (arrayp (cb)) {						\
	THIS_TAG_DEBUG ("Getting exec array from " #cb "\n");		\
	exec = [array] cb;						\
      }									\
      else {								\
	LOW_CALL_CALLBACK (exec, cb, args);				\
	THIS_TAG_DEBUG ((exec ? "Exec array of length " +		\
			 sizeof (exec) : "Zero") +			\
			" returned from " #cb "\n");			\
	THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this);				\
	ENTER_SCOPE (ctx, this);					\
	if (evaler->is_RXML_Parser && ctx->new_runtime_tags)		\
	  /* FIXME: When the evaler is a PCode object we should have a	\
	   * debug check here that ensures that the same runtime tag	\
	   * changes are done as in the first eval. */			\
	  _handle_runtime_tags (ctx, evaler);				\
      }									\
  } while (0)

#define EXEC_ARRAY(ctx, evaler, exec, cb)				\
  do {									\
    if (exec) {								\
      mixed res =							\
	_exec_array (ctx, evaler, exec, #cb); /* Might unwind. */	\
      if (flags & FLAG_STREAM_RESULT) {					\
	DO_IF_DEBUG (							\
	  if (ctx->unwind_state)					\
	    fatal_error ("Clobbering unwind_state to do streaming.\n");	\
	  if (piece != nil)						\
	    fatal_error ("Thanks, we think about how nice it must be "	\
			 "to play the harmonica...\n");			\
	);								\
	CONV_RESULT (res, result_type, res, type);			\
	ctx->unwind_state = (["stream_piece": res]);			\
	THIS_TAG_DEBUG ("Streaming %s from " #cb "\n",			\
			utils->format_short (res));			\
	throw (this);							\
      }									\
      exec = 0;								\
    }									\
  } while (0)

  private mapping(string:mixed) _eval_args (Context ctx,
					    mapping(string:string) raw_args,
					    mapping(string:Type) my_req_args)
  // Used for evaluating the dynamic arguments in the splice argument.
  // Destructive on raw_args.
  {
    // Note: Approximate code duplication in _prepare and Tag.eval_args().
    mapping(string:Type) atypes =
      raw_args & (tag->req_arg_types | tag->opt_arg_types);
    if (my_req_args) {
      mapping(string:Type) missing = my_req_args - atypes;
      if (sizeof (missing))
	parse_error ("Required " +
		     (sizeof (missing) > 1 ?
		      "arguments " + String.implode_nicely (
			sort (indices (missing))) + " are" :
		      "argument " + indices (missing)[0] + " is") + " missing.\n");
    }

#ifdef MODULE_DEBUG
    if (mixed err = catch {
#endif
      foreach (indices (raw_args), string arg) {
	Type t = atypes[arg] || tag->def_arg_type;
	if (t->parser_prog != PNone) {
	  Parser parser = t->get_parser (ctx, 0, 0);
	  THIS_TAG_DEBUG ("Evaluating argument value %s with %O\n",
			  utils->format_short (raw_args[arg]), parser);
	  parser->finish (raw_args[arg]); // Should not unwind.
	  raw_args[arg] = parser->eval(); // Should not unwind.
	  THIS_TAG_DEBUG ("Setting dynamic argument %s to %s\n",
			  utils->format_short (arg),
			  utils->format_short (raw_args[arg]));
	  t->give_back (parser);
	}
      }
#ifdef MODULE_DEBUG
    }) {
      if (objectp (err) && ([object] err)->thrown_at_unwind)
	fatal_error ("Can't save parser state when evaluating dynamic arguments.\n");
      throw_fatal (err);
    }
#endif

    return raw_args;
  }

  EVAL_ARGS_FUNC _prepare (Context ctx, Type type,
			   mapping(string:string) raw_args)
  // Evaluates raw_args simultaneously as generating the
  // EVAL_ARGS_FUNC function. The result of the evaluations is stored
  // in args. Might be destructive on raw_args.
  {
    Frame this = this_object();

    mixed err = catch {
#ifdef DEBUG
      if (!up)
#endif
	up = ctx->frame;
      ctx->frame = this;	// Push the frame to get proper backtraces.
      if (++ctx->frame_depth >= ctx->max_frame_depth) {
	ctx->frame_depth--;
	_run_error ("Too deep recursion -- exceeding %d nested tags.\n",
		    ctx->max_frame_depth);
      }

      EVAL_ARGS_FUNC func;

      if (raw_args) {
#ifdef MODULE_DEBUG
	if (flags & FLAG_PROC_INSTR)
	  fatal_error ("Can't pass arguments to a processing instruction tag.\n");
#endif

#ifdef MAGIC_HELP_ARG
	if (raw_args->help) {
	  func = utils->return_help_arg;
	  args = raw_args;
	}
	else
#endif
	  if (sizeof (raw_args)) {
	    // Note: Approximate code duplication in _eval_args and Tag.eval_args().

	    string splice_arg = raw_args["::"];
	    if (splice_arg) m_delete (raw_args, "::");
	    else splice_arg = 0;
	    mapping(string:Type) splice_req_types;

	    mapping(string:Type) atypes = raw_args & tag->req_arg_types;
	    if (sizeof (atypes) < sizeof (tag->req_arg_types))
	      if (splice_arg)
		splice_req_types = tag->req_arg_types - atypes;
	      else {
		array(string) missing = sort (indices (tag->req_arg_types - atypes));
		parse_error ("Required " +
			     (sizeof (missing) > 1 ?
			      "arguments " + String.implode_nicely (missing) + " are" :
			      "argument " + missing[0] + " is") + " missing.\n");
	      }
	    atypes += raw_args & tag->opt_arg_types;

	    PikeCompile comp = PikeCompile();
	    String.Buffer fn_text = String.Buffer();

	    if (splice_arg) {
	      // Note: This assumes an XML-like parser.
	      Parser p = splice_arg_type->get_pcode_parser (ctx, 0, 0);
	      THIS_TAG_DEBUG ("Evaluating splice argument %s\n",
			      utils->format_short (splice_arg));
#ifdef MODULE_DEBUG
	      if (mixed err = catch {
#endif
		p->finish (splice_arg);	// Should not unwind.
		splice_arg = p->eval(); // Should not unwind.
#ifdef MODULE_DEBUG
	      }) {
		if (objectp (err) && ([object] err)->thrown_at_unwind)
		  fatal_error ("Can't save parser state when "
			       "evaluating splice argument.\n");
		throw_fatal (err);
	      }
#endif
	      fn_text->add (
		sprintf ("return %s (context, "
			 "RXML.xml_tag_parser->parse_tag_args ((%s) || \"\"), %s) + ([\n",
			 comp->bind (_eval_args),
			 p->p_code->_compile_text (comp),
			 comp->bind (splice_req_types)));
	      p->p_code = 0;
	      splice_arg_type->give_back (p);
	      args = _eval_args (ctx, xml_tag_parser->parse_tag_args (splice_arg || ""),
				 splice_req_types);
	    }
	    else {
	      args = raw_args;
	      fn_text->add ("return ([\n");
	    }

#ifdef MODULE_DEBUG
	    if (mixed err = catch {
#endif
	      foreach (indices (raw_args), string arg) {
		Type t = atypes[arg] || tag->def_arg_type;
		if (t->parser_prog != PNone) {
		  Parser parser = t->get_pcode_parser (ctx, 0, 0);
		  THIS_TAG_DEBUG ("Evaluating argument value %s with %O\n",
				  utils->format_short (raw_args[arg]), parser);
		  parser->finish (raw_args[arg]); // Should not unwind.
		  args[arg] = parser->eval(); // Should not unwind.
		  THIS_TAG_DEBUG ("Setting argument %s to %s\n",
				  utils->format_short (arg),
				  utils->format_short (args[arg]));
		  fn_text->add (sprintf ("%O: %s,\n", arg,
					 parser->p_code->_compile_text (comp)));
		  parser->p_code = 0;
		  t->give_back (parser);
		}
		else {
		  args[arg] = raw_args[arg];
		  fn_text->add (sprintf ("%O: %s,\n", arg, comp->bind (raw_args[arg])));
		}
	      }
#ifdef MODULE_DEBUG
	    }) {
	      if (objectp (err) && ([object] err)->thrown_at_unwind)
		fatal_error ("Can't save parser state when evaluating arguments.\n");
	      throw_fatal (err);
	    }
#endif

	    fn_text->add ("]);\n");
	    string fn = comp->decl_func (
	      "mapping(string:mixed)", "RXML.Context context", fn_text->get());
	    func = comp->compile()()[fn];
	  }
	  else {
	    func = utils->return_empty_mapping;
	    args = raw_args;
	  }
      }
      else
	func = utils->return_zero;

      if (!zero_type (this->parent_frame))
	if (up->local_tags && up->local_tags->has_tag (tag)) {
	  THIS_TAG_DEBUG ("Setting parent_frame to %O from local_tags\n", up);
	  this->parent_frame = up;
	}
	else {
	  int nest = 1;
	  Frame frame = up;
	  for (; frame; frame = frame->up)
	    if (frame->additional_tags && frame->additional_tags->has_tag (tag)) {
	      if (!--nest) break;
	    }
	    else if (frame->tag == tag) nest++;
	  THIS_TAG_DEBUG ("Setting parent_frame to %O from additional_tags\n", frame);
	  this->parent_frame = frame;
	  break;
	}

      if (!result_type) {
#ifdef MODULE_DEBUG
	if (!tag) fatal_error ("result_type not set in Frame object %O, "
			       "and it has no Tag object to use for inferring it.\n",
			       this);
#endif
      find_result_type: {
	  // First check if any of the types is a subtype of the
	  // wanted type. If so, we can use it directly.
	  foreach (tag->result_types, Type rtype)
	    if (rtype->subtype_of (type)) {
	      result_type = rtype;
	      break find_result_type;
	    }
	  // Then check if any of the types is a supertype of the
	  // wanted type. If so, set the result type to the wanted
	  // type, since the tag has the responsibility to produce a
	  // value of that type.
	  foreach (tag->result_types, Type rtype)
	    if (type->subtype_of (rtype)) {
	      result_type = type (rtype->parser_prog, @rtype->parser_args);
	      break find_result_type;
	    }
	  parse_error (
	    "Tag returns %s but %s is expected.\n",
	    String.implode_nicely ([array(string)] tag->result_types->name, "or"),
	    type->name);
	}
	THIS_TAG_DEBUG ("Resolved result_type to %s from surrounding %s\n",
			result_type->name, type->name);
      }
      else THIS_TAG_DEBUG ("Keeping result_type %s\n", result_type->name);

      if (!content_type) {
#ifdef MODULE_DEBUG
	if (!tag) fatal_error ("content_type not set in Frame object %O, "
			       "and it has no Tag object to use for inferring it.\n",
			       this);
#endif
	content_type = tag->content_type;
	if (content_type == t_same) {
	  content_type =
	    result_type (content_type->parser_prog, @content_type->parser_args);
	  THIS_TAG_DEBUG ("Resolved t_same to content_type %O\n", content_type);
	}
	else THIS_TAG_DEBUG ("Setting content_type to %O from tag\n", content_type);
      }
      else THIS_TAG_DEBUG ("Keeping content_type %O\n", content_type);

      ctx->frame = up;
      return func;
    };

    ctx->frame = up;
    throw (err);
  }

  mixed _eval (Context ctx, TagSetParser|PCode evaler, Type type,
	       void|string|PCode in_content)
  // Note: It might be somewhat tricky to override this function,
  // since it handles unwinding through exceptions.
  {
    Frame this = this_object();
    RequestID id = ctx->id;

    // Unwind state data:
#define EVSTAT_BEGIN 0
#define EVSTAT_ENTERED 1
#define EVSTAT_LAST_ITER 2
#define EVSTAT_ITER_DONE 3
    int eval_state = EVSTAT_BEGIN;
    EVAL_ARGS_FUNC in_args;
    //in_content;
    int iter;
#ifdef DEBUG
    int debug_iter = 1;
#endif
    object(Parser)|object(PCode) subevaler;
    mixed piece;
    array exec = 0;
    TagSet orig_tag_set;	// Flags that we added additional_tags to ctx->tag_set.
    //ctx->new_runtime_tags

#define PRE_INIT_ERROR(X...) (ctx->frame = this, fatal_error (X))
#ifdef DEBUG
    // Internal sanity checks.
    if (ctx != get_context())
      PRE_INIT_ERROR ("Context not current.\n");
    if (!evaler->tag_set_eval)
      PRE_INIT_ERROR ("Calling _eval() with non-tag set parser.\n");
    Frame prev_ctx_frame = ctx->frame;
#endif
#ifdef MODULE_DEBUG
    if (ctx->new_runtime_tags)
      PRE_INIT_ERROR ("Looks like Context.add_runtime_tag() or "
		      "Context.remove_runtime_tag() was used outside any parser.\n");
#endif
#undef PRE_INIT_ERROR

    mixed conv_result = nil;	// Result converted to the expected type.
    mixed err1 = 0;

  process_tag:
    do {
      if ((err1 = catch {	// Catch errors but don't allow unwinds.
	if (array state = ctx->unwind_state && ctx->unwind_state[this]) {
#ifdef DEBUG
	  if (in_content)
	    fatal_error ("Can't feed new content when resuming parse.\n");
#endif
	  ctx->frame = this;
	  object ignored;
	  [ignored, eval_state, in_args, in_content, iter,
	   subevaler, piece, exec, orig_tag_set, ctx->new_runtime_tags
#ifdef DEBUG
	   , debug_iter
#endif
	  ] = state;
	  m_delete (ctx->unwind_state, this);
	  if (!sizeof (ctx->unwind_state)) ctx->unwind_state = 0;
	  THIS_TAG_TOP_DEBUG ("Continuing evaluation" +
			      (piece ? " with stream piece\n" : "\n"));
	}

	else {			// Initialize a new evaluation.
	  if (tag) {
	    TRACE_ENTER("tag &lt;" + tag->name + "&gt;", tag);
#ifdef MODULE_LEVEL_SECURITY
	    if (id->conf->check_security (tag, id, id->misc->seclevel)) {
	      THIS_TAG_TOP_DEBUG ("Access denied - exiting\n");
	      TRACE_LEAVE("access denied");
	      break process_tag;
	    }
#endif
	  }

	  if (in_content) {
	    THIS_TAG_TOP_DEBUG ("Evaluating\n");
	    ctx->frame = this;
	    if (functionp (args)) {
	      THIS_TAG_DEBUG ("Evaluating compiled arguments\n");
	      in_args = args;
	      args = in_args (ctx);
	    }
	    content = nil;
	  }
	  else if (flags & FLAG_UNPARSED) {
#ifdef DEBUG
	    if (args && !mappingp (args))
	      fatal_error ("args is not a mapping in unparsed frame.\n");
	    if (!stringp (content))
	      fatal_error ("content is not a string in unparsed frame.\n");
#endif
	    THIS_TAG_TOP_DEBUG ("Evaluating unparsed\n");
	    in_args = _prepare (ctx, type, args);
	    ctx->frame = this;
	    in_content = content;
	    content = nil;
	    flags &= ~FLAG_UNPARSED;
	  }
	  else {
	    _prepare (ctx, type, 0);
	    ctx->frame = this;
	    THIS_TAG_TOP_DEBUG ("Evaluating with constant arguments and content.\n");
	  }

	  piece = result = nil;
	}

#ifdef DEBUG
	if (up != prev_ctx_frame)
	  fatal_error ("Frame probably mixed between different simultaneous contexts "
		       "(up: %O, previous ctx->frame: %O).\n", up, prev_ctx_frame);
#endif

      })) {
#ifdef MODULE_DEBUG
	if (objectp (err1) && ([object] err1)->thrown_at_unwind)
	  err1 = catch (
	    fatal_error ("Can't save parser state when evaluating arguments.\n"));
#endif
	break process_tag;
      }

      if (mixed err2 = catch {	// Catch errors and allow for unwinds.
#ifdef MAGIC_HELP_ARG
	if (tag && (args || ([]))->help) {
	  TRACE_ENTER ("tag &lt;" + tag->name + " help&gt;", tag);
	  string help = id->conf->find_tag_doc (tag->name, id);
	  TRACE_LEAVE ("");
	  THIS_TAG_TOP_DEBUG ("Reporting help - frame done\n");
	  ctx->handle_exception ( // Will throw if necessary.
	    Backtrace ("help", help, ctx), evaler);
	  break process_tag;
	}
#endif

	switch (eval_state) {
	  case EVSTAT_BEGIN:
	    if (array|function(RequestID:array) do_enter =
		[array|function(RequestID:array)] this->do_enter) {
	      EXEC_CALLBACK (ctx, evaler, exec, do_enter, id);
	      EXEC_ARRAY (ctx, evaler, exec, do_enter);
	    }
	    else {
	      THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this);
	      ENTER_SCOPE (ctx, this);
	    }
	    eval_state = EVSTAT_ENTERED;
	    /* Fall through. */

	  case EVSTAT_ENTERED:
	  case EVSTAT_LAST_ITER:
	    int|function(RequestID:int) do_iterate =
	      [int|function(RequestID:int)] this->do_iterate;
	    array|function(RequestID:array) do_process =
	      [array|function(RequestID:array)] this->do_process;

	    do {
	      if (eval_state != EVSTAT_LAST_ITER) {
		if (intp (do_iterate)) {
		  iter = [int] do_iterate || 1;
		  eval_state = EVSTAT_LAST_ITER;
#ifdef DEBUG
		  if (iter > 1)
		    THIS_TAG_DEBUG ("Getting %d iterations from do_iterate\n", iter);
		  else if (iter < 0)
		    THIS_TAG_DEBUG ("Skipping to finish since do_iterate is negative\n");
#endif
		}
		else {
		  LOW_CALL_CALLBACK (iter, do_iterate, id);
		  THIS_TAG_DEBUG ("%O returned from do_iterate\n", iter);
		  THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this);
		  ENTER_SCOPE (ctx, this);
		  if (evaler->is_RXML_Parser && ctx->new_runtime_tags)
		    _handle_runtime_tags (ctx, evaler);
		  if (!iter) eval_state = EVSTAT_LAST_ITER;
		}
	      }

	      for (; iter > 0; iter-- DO_IF_DEBUG (, debug_iter++)) {
		if (in_content) { // Got nested parsing to do.
		  int finished = 1;
		  if (subevaler)
		    finished = 0; // Continuing an unwound subevaler.
		  else if (stringp (in_content)) {
		    if (in_content == "")
		      subevaler = PCode (content_type);
		    else if (flags & FLAG_EMPTY_ELEMENT)
		      parse_error ("This tag doesn't handle content.\n");
		    else {	// The nested content is not yet parsed.
		      if (this->local_tags) {
			subevaler = content_type->get_pcode_parser (
			  ctx, [object(TagSet)] this->local_tags, evaler);
			subevaler->_local_tag_set = 1;
			THIS_TAG_DEBUG ("Iter[%d]: Parsing and evaluating content %s "
					"with %O from local_tags\n", debug_iter,
					utils->format_short (in_content), subevaler);
		      }
		      else {
#ifdef DEBUG
			if (orig_tag_set)
			  fatal_error ("Didn't expect orig_tag_set here.\n");
#endif
			if (TagSet add_tags = [object(TagSet)] this->additional_tags) {
			  TagSet tset = ctx->tag_set;
			  if (!tset->has_effective_tags (add_tags)) {
			    THIS_TAG_DEBUG ("Installing additional_tags %O\n", add_tags);
			    int hash = HASH_INT2 (tset->id_number, add_tags->id_number);
			    orig_tag_set = tset;
			    TagSet local_ts;
			    if (!(local_ts = local_tag_set_cache[hash])) {
			      local_ts = TagSet (
				add_tags->name + "+" + orig_tag_set->name);
			      local_ts->imported = ({add_tags, orig_tag_set});
			      // Race, but it doesn't matter.
			      local_tag_set_cache[hash] = local_ts;
			    }
			    ctx->tag_set = local_ts;
			  }
			  else
			    THIS_TAG_DEBUG ("Not installing additional_tags %O "
					    "since they're already in the tag set\n",
					    add_tags);
			}
			subevaler = content_type->get_pcode_parser (ctx, 0, evaler);
#ifdef DEBUG
			if (content_type->parser_prog != PNone)
			  THIS_TAG_DEBUG ("Iter[%d]: Parsing and evaluating content %s "
					  "with %O\n", debug_iter,
					  utils->format_short (in_content), subevaler);
#endif
		      }
		      if (evaler->recover_errors && !(flags & FLAG_DONT_RECOVER))
			subevaler->recover_errors = 1;
		      subevaler->finish (in_content); // Might unwind.
		      (in_content = subevaler->p_code)->finish();
		      finished = 1;
		    }
		  }
		  else {
		    THIS_TAG_DEBUG ("Iter[%d]: Evaluating compiled content\n",
				    debug_iter);
		    subevaler = in_content; // Evaling with p-code.
		  }

		eval_sub:
		  do {
		    if (piece != nil && flags & FLAG_STREAM_CONTENT) {
		      // Handle a stream piece.
		      THIS_TAG_DEBUG ("Iter[%d]: Got %s stream piece %s\n",
				      debug_iter, finished ? "ending" : "a",
				      utils->format_short (piece));
		      if (!arrayp (do_process)) {
			EXEC_CALLBACK (ctx, evaler, exec, do_process, id, piece);
			if (exec) {
			  mixed res = _exec_array (
			    ctx, evaler, exec, "do_process"); // Might unwind.
			  if (flags & FLAG_STREAM_RESULT) {
#ifdef DEBUG
			    if (!zero_type (ctx->unwind_state->stream_piece))
			      fatal_error ("Clobbering unwind_state->stream_piece.\n");
#endif
			    CONV_RESULT (res, result_type, res, type);
			    ctx->unwind_state->stream_piece = res;
			    THIS_TAG_DEBUG ("Iter[%d]: Streaming %s from do_process\n",
					    debug_iter, utils->format_short (res));
			    throw (this);
			  }
			  exec = 0;
			}
			else if (flags & FLAG_STREAM_RESULT) {
			  THIS_TAG_DEBUG ("Iter[%d]: do_process finished the stream; "
					  "ignoring remaining content\n", debug_iter);
			  ctx->unwind_state = 0;
			  piece = nil;
			  break eval_sub;
			}
		      }
		      piece = nil;
		      if (finished) break eval_sub;
		    }

		    else {	// No streaming.
		      piece = nil;
		      if (finished) {
			mixed res = subevaler->_eval (ctx); // Might unwind.
			if (content_type->sequential)
			  SET_SEQUENTIAL (res, content, "content");
			else if (res != nil)
			  SET_NONSEQUENTIAL (res, content, content_type, "content");
			break eval_sub;
		      }
		    }

		    if (subevaler->is_RXML_Parser) {
		      subevaler->finish(); // Might unwind.
		      (in_content = subevaler->p_code)->finish();
		    }
		    finished = 1;
		  } while (1); // Only loops when an unwound subevaler has been recovered.

		  subevaler = 0;
		}

		if (do_process) {
		  EXEC_CALLBACK (ctx, evaler, exec, do_process, id);
		  EXEC_ARRAY (ctx, evaler, exec, do_process);
		}
	      }
	    } while (eval_state != EVSTAT_LAST_ITER);
	    eval_state = EVSTAT_ITER_DONE;
	    /* Fall through. */

	  case EVSTAT_ITER_DONE:
	    if (array|function(RequestID:array) do_return =
		[array|function(RequestID:array)] this->do_return) {
	      EXEC_CALLBACK (ctx, evaler, exec, do_return, id);
	      if (exec) {
		// We don't use EXEC_ARRAY here since it's no idea to
		// come back even if any streaming should be done.
		_exec_array (ctx, evaler, exec, "do_return"); // Might unwind.
		exec = 0;
	      }
	    }

	    else if (result == nil && !(flags & FLAG_EMPTY_ELEMENT)) {
	      if (result_type->parser_prog == PNone) {
		if (content_type->name != result_type->name) {
		  THIS_TAG_DEBUG ("Assigning content to result after "
				  "conversion from %s to %s\n",
				  content_type->name, result_type->name);
		  result = result_type->encode (content, content_type);
		}
		else {
		  THIS_TAG_DEBUG ("Assigning content to result\n");
		  result = content;
		}
	      }
	      else
		if (stringp (content)) {
		  if (!exec) {
		    THIS_TAG_DEBUG ("Parsing content with exec array "
				    "for assignment to result\n");
		    exec = ({content});
		  }
		  _exec_array (ctx, evaler, exec, "content parse"); // Might unwind.
		  exec = 0;
		}
	    }

	    if (result != nil)
	      CONV_RESULT (result, result_type, conv_result, type);
#ifdef DEBUG
	    else THIS_TAG_DEBUG ("Skipping nil result\n");
#endif

	    THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this);
	    LEAVE_SCOPE (ctx, this);

	    if (evaler->is_RXML_Parser && ctx->new_runtime_tags)
	      _handle_runtime_tags (ctx, evaler);
	}

      }) {
	THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this);
	LEAVE_SCOPE (ctx, this);

	string action;
      exception:
	{
	unwind:
	  if (objectp (err2) && ([object] err2)->thrown_at_unwind) {
	    UNWIND_STATE ustate = ctx->unwind_state;
	    if (!ustate) ustate = ctx->unwind_state = ([]);
#ifdef DEBUG
	    if (ustate[this]) fatal_error ("Frame already has an unwind state.\n");
#endif

	    if (ustate->exec_left) {
	      exec = [array] ustate->exec_left;
	      m_delete (ustate, "exec_left");
	    }

	    if (err2 == this || exec && sizeof (exec) && err2 == exec[0])
	      // This frame or a frame in the exec array wants to stream.
	      if (evaler->read && evaler->unwind_safe) {
		// Rethrow to continue in parent since we've already done
		// the appropriate do_process stuff in this frame in
		// either case.
		mixed piece = evaler->read();
		if (err2 = catch {
		  if (type->sequential)
		    SET_SEQUENTIAL (ustate->stream_piece, piece, "stream piece");
		  else
		    SET_NONSEQUENTIAL (ustate->stream_piece, piece, type, "stream piece");
		}) break unwind;
		if (err2 == this) err2 = 0;
		if (orig_tag_set) ctx->tag_set = orig_tag_set, orig_tag_set = 0;
		action = "break";
		THIS_TAG_TOP_DEBUG ("Breaking to parent frame to do streaming\n");
	      }
	      else {
		// Can't stream since the parser doesn't allow that.
		// Just continue.
		m_delete (ustate, "stream_piece");
		action = "continue";
		THIS_TAG_TOP_DEBUG ("Not streaming since the parser "
				    "doesn't allow that\n");
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

	    ustate[this] = ({err2, eval_state, in_args, in_content, iter,
			     subevaler, piece, exec, orig_tag_set, ctx->new_runtime_tags,
#ifdef DEBUG
			     debug_iter,
#endif
			   });
	    TRACE_LEAVE (action);
	    break exception;
	  }

	  THIS_TAG_TOP_DEBUG ("Exception\n");
	  TRACE_LEAVE ("exception");
	  ctx->handle_exception (err2, evaler); // Will rethrow unknown errors.
	  result = nil;
	  action = "return";
	}

	switch (action) {
	  case "break":		// Throw and handle in parent frame.
#ifdef MODULE_DEBUG
	    if (!evaler->unwind_state)
	      fatal_error ("Trying to unwind inside an evaluator "
			   "that isn't unwind safe.\n");
#endif
	    throw (this);
	  case "continue":	// Continue in this frame with the stored state.
	    continue process_tag;
	  case "return":	// A normal return.
	    break process_tag;
	  default:
	    fatal_error ("Don't you come here and %O on me!\n", action);
	}
      }

      else {
	THIS_TAG_TOP_DEBUG ("Done\n");
	TRACE_LEAVE ("");
      }
      break process_tag;
    } while (1);		// Looping only when continuing in streaming mode.

    // Normal clean up on tag return or exception.
    if (orig_tag_set) ctx->tag_set = orig_tag_set;
    ctx->frame = up;
    ctx->frame_depth--;
    if (err1) throw (err1);
    args = in_args, content = in_content;
    return conv_result;
  }

  MARK_OBJECT;

  string _sprintf()
  {
    return "RXML.Frame(" + (tag && [string] tag->name) + ")" + OBJ_COUNT;
  }
}


//(!) Global services.

//! Shortcuts to some common functions in the current context (see the
//! corresponding functions in the @[Context] class for details).
final mixed get_var (string var, void|string scope_name, void|Type want_type)
  {return get_context()->get_var (var, scope_name, want_type);}
final mixed user_get_var (string var, void|string scope_name, void|Type want_type)
  {return get_context()->user_get_var (var, scope_name, want_type);}
final mixed set_var (string var, mixed val, void|string scope_name)
  {return get_context()->set_var (var, val, scope_name);}
final mixed user_set_var (string var, mixed val, void|string scope_name)
  {return get_context()->user_set_var (var, val, scope_name);}
final void delete_var (string var, void|string scope_name)
  {get_context()->delete_var (var, scope_name);}
final void user_delete_var (string var, void|string scope_name)
  {get_context()->user_delete_var (var, scope_name);}

final void run_error (string msg, mixed... args)
//! Throws an RXML run error with a dump of the parser stack in the
//! current context. This is intended to be used by tags for errors
//! that can occur during normal operation, such as when the
//! connection to an SQL server fails.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  throw (Backtrace ("run", msg, get_context(), bt[..sizeof (bt) - 2]));
}

final void parse_error (string msg, mixed... args)
//! Throws an RXML parse error with a dump of the parser stack in the
//! current context. This is intended to be used for programming
//! errors in the RXML code, such as lookups in nonexisting scopes and
//! invalid arguments to a tag.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  throw (Backtrace ("parse", msg, get_context(), bt[..sizeof (bt) - 2]));
}

final void fatal_error (string msg, mixed... args)
//! Throws a Pike error that isn't catched and handled anywhere. It's
//! just like the common @[error] function, but includes the RXML
//! frame backtrace.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  throw_fatal (({msg, bt[..sizeof (bt) - 2]}));
}

final void throw_fatal (mixed err)
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

final mixed rxml_index (mixed val, string|int|array(string|int) index,
			string scope_name, Context ctx, void|Type want_type)
//! Index the value according to RXML type rules and returns the
//! result. Throws RXML exceptions on any errors. If index is an
//! array, its elements are used to successively subindex the value,
//! e.g. @tt{({"a", 2, "b"})@} corresponds to @tt{val["a"][2]["c"]@}.
//! @[scope_name] is used to identify the context for the indexing.
//!
//! The special RXML index rules are:
//!
//! @list ul
//!  @item
//!   Arrays are indexed with 1 for the first element, or
//!   alternatively -1 for the last. Indexing an array of size n with
//!   0, n+1 or greater, -n-1 or less, or with a non-integer is an
//!   error.
//!  @item
//!   Strings, along with integers and floats, are treated as simple
//!   scalar types which aren't really indexable. If a scalar type is
//!   indexed with 1 or -1, it produces itself instead of generating
//!   an error. (This is a convenience to avoid many special cases
//!   when treating both arrays and scalar types.)
//!  @item
//!   If a value is an object which has an @tt{rxml_var_eval@}
//!   identifier, it's treated as an @[RXML.Value] object and the
//!   @[RXML.Value.rxml_var_eval] function is called to produce its
//!   value.
//!  @item
//!   If a value which is about to be indexed is an object which has a
//!   @tt{`[]@} function, it's called as an @[RXML.Scope] object (see
//!   @ref{RXML.Scope.`[]@}).
//!  @item
//!   Both the special value nil and the undefined value (a zero with
//!   zero_type 1) may be used to signify no value at all, and both
//!   will be returned as the undefined value.
//! @endlist
//!
//! If the @[want_type] argument is set, the result value is converted
//! to that type with @[RXML.Type.encode]. If the value can't be
//! converted, an RXML error is thrown.
//!
//! This function is mainly for internal use; you commonly want to use
//! @[get_var], @[set_var], @[user_get_var] or @[user_set_var]
//! instead.
{
#ifdef MODULE_DEBUG
  if (arrayp (index) ? !sizeof (index) : !(stringp (index) || intp (index)))
    fatal_error ("Invalid index specifier.\n");
#endif

  int scope_got_type = 0;
  array(string|int) idxpath;
  if (arrayp (index)) idxpath = index, index = index[0];
  else idxpath = ({0});

  for (int i = 1;; i++) {
    // stringp was not really a good idea.
    if( arrayp( val ) /*|| stringp( val )*/ )
      if (intp (index) && index)
	if( (index > sizeof( val ))
	    || ((index < 0) && (-index > sizeof( val ) )) )
	  parse_error( "Index %d out of range for array of size %d in %s.\n",
		       index, sizeof (val), scope_name );
	else if( index < 0 )
	  val = val[index];
	else
	  val = val[index-1];
      else
	parse_error( "Cannot index the array in %s with %O.\n", scope_name, index );
    else if (val == nil)
      parse_error ("%s produced no value to index with %O.\n", scope_name, index);
    else if( objectp( val ) && val->`[] ) {
#ifdef MODULE_DEBUG
      Scope scope = [object(Scope)] val;
#endif
      if (zero_type (
	    val = ([object(Scope)] val)->`[](
	      index, ctx, scope_name,
	      i == sizeof (idxpath) && (scope_got_type = 1, want_type))))
	val = nil;
#ifdef MODULE_DEBUG
      else if (mixed err = scope_got_type && want_type && val != nil &&
	       !(objectp (val) && ([object] val)->rxml_var_eval) &&
	       catch (want_type->type_check (val)))
	if (([object] err)->is_RXML_Backtrace)
	  fatal_error ("%O->`[] didn't return a value of the correct type:\n%s",
		       scope, err->msg);
	else throw (err);
#endif
    }
    else if( mappingp( val ) || objectp (val) ) {
      if (zero_type (val = val[ index ])) val = nil;
    }
    else if (multisetp (val)) {
      if (!val[index]) val = nil;
    }
    else if (!(<1, -1>)[index])
      parse_error ("%s is %O which cannot be indexed with %O.\n",
		   scope_name, val, index);

    if (i == sizeof (idxpath)) break;
    scope_name += "." + index;
    index = idxpath[i];

#ifdef MODULE_DEBUG
    mapping(object:int) called = ([]);
#endif
    while (objectp (val) && ([object] val)->rxml_var_eval && !([object] val)->`[]) {
#ifdef MODULE_DEBUG
      // Detect infinite loops. This check is slightly too strong;
      // it's theoretically possible that a couple of Value objects
      // return each other a few rounds and then something different,
      // but we'll live with that. Besides, that situation ought to be
      // solved internally in them anyway.
      if (called[val])
	fatal_error ("Cyclic rxml_var_eval chain detected in %O.\n"
		     "All called objects:%{ %O%}\n", val, indices (called));
      called[val] = 1;
#endif
      if (zero_type (val = ([object(Value)] val)->rxml_var_eval (
		       ctx, index, scope_name, 0))) {
	val = nil;
	break;
      }
    }
  }

  if (val == nil)
    return ([])[0];
  else if (!objectp (val) || !([object] val)->rxml_var_eval)
    if (want_type && !scope_got_type)
      return
	// FIXME: Some system to find out the source type?
	zero_type (val = want_type->encode (val)) || val == nil ? ([])[0] : val;
    else
      return val;

#ifdef MODULE_DEBUG
  mapping(object:int) called = ([]);
#endif
  do {
#ifdef MODULE_DEBUG
    if (called[val])
      fatal_error ("Cyclic rxml_var_eval chain detected in %O.\n"
		   "All called objects:%{ %O%}\n", val, indices (called));
    called[val] = 1;
    Value val_obj = [object(Value)] val;
#endif
    if (zero_type (val = ([object(Value)] val)->rxml_var_eval (
		     ctx, index, scope_name, want_type)) ||
	val == nil)
      return ([])[0];
#ifdef MODULE_DEBUG
    else if (mixed err = want_type && catch (want_type->type_check (val)))
      if (([object] err)->is_RXML_Backtrace)
	fatal_error ("%O->rxml_var_eval didn't return a value of the correct type:\n%s",
		     val_obj, err->msg);
      else throw (err);
#endif
  } while (objectp (val) && ([object] val)->rxml_var_eval);
  return val;
}

final void tag_debug (string msg, mixed... args)
//! Writes the message to the debug log if the innermost tag being
//! executed has FLAG_DEBUG set.
{
  if (Frame f = get_context()->frame) // It's intentional that this assumes a context.
    if (f->flags & FLAG_DEBUG)
      report_debug (msg, @args);
}

final Frame make_tag (string name, mapping(string:mixed) args, void|mixed content,
		      void|Tag overridden_by)
//! Returns a frame for the specified tag, or 0 if no such tag exists.
//! The tag definition is looked up in the current context and tag
//! set. @[args] and @[content] are not parsed or evaluated; they're
//! used as-is by the tag. If @[overridden_by] is given, the returned
//! frame will come from the tag that @[overridden_by] overrides, if
//! there is any (@[name] is not used in that case).
{
  TagSet tag_set = get_context()->tag_set;
  Tag tag = overridden_by ? tag_set->get_overridden_tag (overridden_by) :
    tag_set->get_tag (name);
  return tag && tag (args, content);
}

final Frame make_unparsed_tag (string name, mapping(string:string) args,
			       void|string content, void|Tag overridden_by)
//! Returns a frame for the specified tag, or 0 if no such tag exists.
//! The tag definition is looked up in the current context and tag
//! set. @[args] and @[content] are given unparsed in this variant;
//! they're parsed and evaluated when the frame is about to be
//! evaluated. If @[overridden_by] is given, the returned frame will
//! come from the tag that @[overridden_by] overrides, if there is any
//! (@[name] is not used in that case).
{
  TagSet tag_set = get_context()->tag_set;
  Tag tag = overridden_by ? tag_set->get_overridden_tag (overridden_by) :
    tag_set->get_tag (name);
  if (!tag) return 0;
  Frame frame = tag (args, content);
  frame->flags |= FLAG_UNPARSED;
  return frame;
}

//! @decl Frame parse_frame (Type type, string to_parse);
//!
//! Returns a frame that, when evaluated, parses the given string
//! according to the type (which typically has a parser set).
class parse_frame
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


//(!) Parsers:


class Parser
//! Interface class for a syntax parser that scans, parses and
//! evaluates an input stream. Access to a parser object is assumed to
//! be done in a thread safe way except where noted.
{
  constant is_RXML_Parser = 1;
  constant thrown_at_unwind = 1;

  //(!) Services:

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
	  fatal_error ("Unexpected unwind object catched.\n");
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
	  fatal_error ("Unexpected unwind object catched.\n");
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
#ifdef PROFILE_PARSER
    werror ("Profile for %s: %O\n", context->id->not_query, context->profile);
#endif
  }

  mixed handle_var (TagSetParser|PCode evaler, string varref, Type want_type)
  // Parses and evaluates a possible variable reference, with the
  // appropriate error handling.
  {
    if (mixed err = catch {
      // It's intentional that we split on the first ':' for now, to
      // allow for future enhancements of this syntax. Scope and
      // variable names containing ':' are thus not accessible this way.
      sscanf (varref, "%[^:]:%s", varref, string encoding);
      context->current_var = varref;

      array(string|int) splitted = context->parse_user_var (varref, 1);
      if (splitted[0] == 1)
	parse_error (
	  "No scope in variable reference.\n"
	  "(Use ':' in front to quote a character reference containing dots.)\n");
#ifdef DEBUG
      if (context->frame)
	TAG_DEBUG (context->frame, "    Looking up variable %s in context of type %s\n",
		   splitted * ".", (encoding ? t_string : want_type)->name);
#endif

      mixed val;
      PROFILE_SWITCH (context, "rxml internal", "var:" + varref);
      COND_PROF_ENTER(mixed id=context->id,varref,"entity");
      if (zero_type (val = context->get_var ( // May throw.
		       splitted[1..], splitted[0],
		       encoding ? t_string : want_type)))
	val = nil;
      COND_PROF_LEAVE(mixed id=context->id,varref,"entity");
      PROFILE_SWITCH (context, "var:" + varref, "rxml internal");

      if (encoding) {
	if (!(val = Roxen->roxen_encode (val + "", encoding)))
	  parse_error ("Unknown encoding %O.\n", encoding);
#ifdef DEBUG
	if (context->frame)
	  TAG_DEBUG (context->frame, "    Got value %s after conversion "
		     "with encoding %s\n", utils->format_short (val), encoding);
#endif
      }
#ifdef DEBUG
      else
	if (context->frame)
	  TAG_DEBUG (context->frame, "    Got value %s\n", utils->format_short (val));
#endif

      context->current_var = 0;
      if (evaler->p_code)
	evaler->p_code->add (VarRef (splitted[0], splitted[1..], encoding));
      return val;

    }) {
      context->current_var = 0;
      context->handle_exception (err, this_object()); // May throw.
      return nil;
    }
  }

  //(!) Interface:

  Context context;
  //! The context to do evaluation in. It's assumed to never be
  //! modified asynchronously during the time the parser is working on
  //! an input stream.

  Type type;
  //! The expected result type of the current stream. (The parser
  //! should not do any type checking on this.)

  PCode p_code;
  //! Must be set to a new @[PCode] object before a stream is fed
  //! which should be compiled to p-code. The object will receive the
  //! compiled code during evaluation and can be used to repeat the
  //! evaluation after the stream is finished.

  //! @decl int unwind_safe;
  //!
  //! If nonzero, the parser supports unwinding with throw()/catch().
  //! Whenever an exception is thrown from some evaluation function,
  //! it should be able to call that function again with identical
  //! arguments the next time it continues.

  int recover_errors;
  //! Set to nonzero to allow error recovery in this parser.
  //! report_error() will never be called if this is zero.

  mixed feed (string in);
  //! Feeds some source data to the parse stream. The parser may do
  //! scanning, parsing and evaluation before returning. Returns
  //! nonzero if there could be new data to get from eval().

  void finish (void|string in);
  //! Like feed(), but also finishes the parse stream. A last bit of
  //! data may be given. It should work to call this on an already
  //! finished stream if no argument is given to it.

  optional int report_error (string msg);
  //! Used to report errors to the end user through the output. This
  //! is only called when type->free_text is nonzero and
  //! recover_errors is nonzero. msg should be stored in the output
  //! queue to be returned by eval(). If the context is bad for an
  //! error message, do nothing and return zero. The parser will then
  //! be aborted and the error will be propagated instead. Return
  //! nonzero if a message was written.

  optional mixed read();
  //! Define to allow streaming operation. Returns the evaluated
  //! result so far, but does not do any more evaluation. Returns
  //! RXML.nil if there's no data.

  mixed eval();
  //! Evaluates the data fed so far and returns the result. The result
  //! returned by previous eval() calls should not be returned again
  //! as (part of) this return value. Returns RXML.nil if there's no
  //! data (for sequential types the empty value is also ok).

  optional void reset (Context ctx, Type type, mixed... args);
  //! Define to support reuse of a parser object. It'll be called
  //! instead of making a new object for a new stream. It keeps the
  //! static configuration, i.e. the type (and tag set when used in
  //! @[TagSetParser]). Note that this function needs to deal with
  //! leftovers from @[TagSetParser.add_runtime_tag] for
  //! @[TagSetParser] objects. It should call @[initialize] with the
  //! given context and type to reset this base class properly.

  optional Parser clone (Context ctx, Type type, mixed... args);
  //! Define to create new parser objects by cloning instead of
  //! creating from scratch. It returns a new instance of this parser
  //! with the same static configuration, i.e. the type (and tag set
  //! when used in TagSetParser).

  static void create (Context ctx, Type type, mixed... args)
  //! Should (at least) call @[initialize] with the given context and
  //! type.
  {
    initialize (ctx, type);
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  static void initialize (Context ctx, Type _type)
  //! Does the required initialization for this base class. Use from
  //! @[create] and @[reset] (when it's defined) to initialize or
  //! reset the parser object properly.
  {
    context = ctx;
    type = _type;
  }

  string current_input() {return 0;}
  //! Should return the representation in the input stream for the
  //! current tag, entity or text being parsed, or 0 if it isn't
  //! known.

  //(!) Internals:

  mixed _eval (Context ignored) {return eval();}
  // To be call compatible with PCode.

  Parser _next_free;
  // Used to link together unused parser objects for reuse.

  Parser _parent;
  // The parent parser if this one is nested. This is only used to
  // register runtime tags.

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
//! should call @[Tag.handle_tag] or similar from @[feed] and
//! @[finish] for every encountered tag. @[Parser.handle_var] should
//! be called for encountered variable references. It must be able to
//! continue cleanly after @[throw] from @[Tag.handle_tag].
{
  inherit Parser;

  constant is_RXML_TagSetParser = 1;
  constant tag_set_eval = 1;

  //(!) Services:

  mixed eval() {return read();}

  //(!) Interface:

  TagSet tag_set;
  //! The tag set used for parsing.

  PCode p_code;

  //! In addition to the type, the tag set is part of the static
  //! configuration.
  optional void reset (Context ctx, Type type, TagSet tag_set, mixed... args);
  optional Parser clone (Context ctx, Type type, TagSet tag_set, mixed... args);
  static void create (Context ctx, Type type, TagSet tag_set, mixed... args)
  {
    initialize (ctx, type, tag_set);
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  static void initialize (Context ctx, Type type, TagSet _tag_set)
  {
    ::initialize (ctx, type);
    tag_set = _tag_set;
    p_code = 0;
  }

  mixed read();
  //! No longer optional in this class. Since the evaluation is done
  //! in Tag.handle_tag() or similar, this always does the same as
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

  string raw_tag_text() {return 0;}
  //! Used by @[Tag.handle_tag] to set @[Frame.raw_tag_text] in a
  //! newly created frame. This default implementation simply leaves
  //! it unset.

  //(!) Internals:

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

  static string data = "";
  static int evalpos = 0;

  PCode p_code;

  int feed (string in)
  {
    data += in;
    return 1;
  }

  void finish (void|string in)
  {
    if (in) data += in;
    if (p_code) p_code->add (data);
  }

  string eval()
  {
    string res = data[evalpos..];
    evalpos = sizeof (data);
    return res;
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


//(!) Types:


static mapping(string:Type) reg_types = ([]);
// Maps each type name to a type object with the PNone parser.

class Type
//! A static type definition. It does type checking and specifies some
//! properties of the type. It may also contain a @[Parser] program
//! that will be used to read text and evaluate values of this type.
//! Note that the parser is not relevant for type checking.
//!
//! @note
//! The doc for this class is rather lengthy, but most of it applies
//! only to type implementors. It's very much simpler to use a type
//! than to implement one; typical users only need to choose one and
//! use @[encode], @[subtype_of], @[`()] or @[eval] in it.
{
  constant is_RXML_Type = 1;

  //(!) Services:

  int `== (mixed other)
  //! Returns nonzero iff this type is the same as @[other], i.e. has
  //! the same name. If @[other] is known to be a type, it's somewhat
  //! faster to compare the names directly.
  {
    return /*::`== (this_object(), other) ||*/
      objectp (other) && ([object] other)->is_RXML_Type &&
      ([object(Type)] other)->name == this_object()->name;
  }

  int subtype_of (Type other)
  //! Returns nonzero iff this type is the same as or a subtype of
  //! @[other].
  //!
  //! That means that any value of this type can be expressed by
  //! @[other] without (or with at most negligible) loss of
  //! information. There's however one notable exception to that:
  //! @[RXML.t_any] is the supertype for all types even though it can
  //! hardly express any value without losing its information context.
  {
    // FIXME: Add some cache here?
    for (Type type = this_object(); type; type = type->supertype)
      if (type->name == other->name) return 1;
    return 0;
  }

  int `< (mixed other)
  //! Comparison regards a type as less than its supertypes. If
  //! @[other] isn't a type, it's compared with @[name].
  {
    if (objectp (other) && ([object] other)->is_RXML_Type) {
      if (([object(Type)] other)->name == this_object()->name) return 0;
      return subtype_of (other);
    }
    return this_object()->name < other;
  }

  int convertible (Type from)
  //! Returns nonzero iff it's possible to convert values of the type
  //! @[from] to this type using some chain of conversions.
  {
    if (conversion_type->name == from->name ||
	conversion_type->name == from->conversion_type->name ||
	this_object()->name == from->conversion_type->name ||
	this_object()->name == from->name)
      return 1;
    // The following is not terribly efficient, but most situations
    // should be handled by the special cases above.
    for (Type tconv = conversion_type; tconv; tconv = tconv->conversion_type)
      for (Type fconv = from->conversion_type; fconv; fconv = fconv->conversion_type)
	if (fconv->name == tconv->name)
	  return 1;
    return 0;
  }

  Type `() (program/*(Parser)HMM*/ newparser, mixed... parser_args)
  //! Returns a type identical to this one, but which has the given
  //! parser. parser_args is passed as extra arguments to the
  //! create()/reset()/clone() functions.
  {
    Type newtype;
    if (sizeof (parser_args)) {	// Can't cache this.
      newtype = clone();
      newtype->parser_prog = newparser;
      newtype->parser_args = parser_args;
      if (newparser->tag_set_eval) newtype->_p_cache = set_weak_flag (([]), 1);
    }
    else {
      if (!_t_obj_cache) _t_obj_cache = ([]);
      if (!(newtype = _t_obj_cache[newparser]))
	if (newparser == parser_prog)
	  _t_obj_cache[newparser] = newtype = this_object();
	else {
	  _t_obj_cache[newparser] = newtype = clone();
	  newtype->parser_prog = newparser;
	  if (newparser->tag_set_eval) newtype->_p_cache = set_weak_flag (([]), 1);
	}
    }
#ifdef DEBUG
    if (reg_types[this_object()->name]->parser_prog != PNone)
      error ("Incorrect type object registered in reg_types.\n");
#endif
    return newtype;
  }

  inline final Parser get_parser (Context ctx, void|TagSet tag_set,
				  void|Parser|PCode parent)
  //! Returns a parser instance initialized with the given context.
  {
    Parser p;
    if (_p_cache) {		// It's a tag set parser.
      TagSet tset = tag_set || ctx->tag_set;

      if (parent && parent->is_RXML_TagSetParser &&
	  tset == parent->tag_set && sizeof (ctx->runtime_tags) &&
	  parent->clone && parent->type->name == this_object()->name) {
	// There are runtime tags. Try to clone the parent parser if
	// all conditions are met.
	p = parent->clone (ctx, this_object(), tset, @parser_args);
	p->_parent = parent;
	return p;
      }

      // vvv Using interpreter lock from here.
      PCacheObj pco = _p_cache[tset];
      if (pco && pco->tag_set_gen == tset->generation) {
	if ((p = pco->free_parser)) {
	  pco->free_parser = p->_next_free;
	  // ^^^ Using interpreter lock to here.
	  p->data_callback = 0;
	  p->reset (ctx, this_object(), tset, @parser_args);
#ifdef RXML_OBJ_DEBUG
	  p->__object_marker->create (p);
#endif
	}

	else
	  // ^^^ Using interpreter lock to here.
	  if (pco->clone_parser)
	    p = pco->clone_parser->clone (ctx, this_object(), tset, @parser_args);
	  else if ((p = parser_prog (ctx, this_object(), tset, @parser_args))->clone) {
	    // pco->clone_parser might already be initialized here due
	    // to race, but that doesn't matter.
	    p->context = 0;	// Don't leave the context in the clone master.
#ifdef RXML_OBJ_DEBUG
	    p->__object_marker->create (p);
#endif
	    p = (pco->clone_parser = p)->clone (ctx, this_object(), tset, @parser_args);
	  }
      }

      else {
	// ^^^ Using interpreter lock to here.
	pco = PCacheObj();
	pco->tag_set_gen = tset->generation;
	_p_cache[tset] = pco;	// Might replace an object due to race, but that's ok.
	if ((p = parser_prog (ctx, this_object(), tset, @parser_args))->clone) {
	  // pco->clone_parser might already be initialized here due
	  // to race, but that doesn't matter.
	  p->context = 0;	// Don't leave the context in the clone master.
#ifdef RXML_OBJ_DEBUG
	  p->__object_marker->create (p);
#endif
	  p = (pco->clone_parser = p)->clone (ctx, this_object(), tset, @parser_args);
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
	p->data_callback = 0;
	p->reset (ctx, this_object(), @parser_args);
#ifdef RXML_OBJ_DEBUG
	p->__object_marker->create (p);
#endif
      }

      else if (clone_parser)
	// Relying on interpreter lock here.
	p = clone_parser->clone (ctx, this_object(), @parser_args);

      else if ((p = parser_prog (ctx, this_object(), @parser_args))->clone) {
	// clone_parser might already be initialized here due to race,
	// but that doesn't matter.
	p->context = 0;		// Don't leave the context in the clone master.
#ifdef RXML_OBJ_DEBUG
	p->__object_marker->create (p);
#endif
	p = (clone_parser = p)->clone (ctx, this_object(), @parser_args);
      }
    }

    p->_parent = parent;
    return p;
  }

  Parser get_pcode_parser (Context ctx, void|TagSet tag_set, void|Parser|PCode parent)
  //! Like @[get_parser], but also initializes a PCode object in the
  //! returned parser.
  {
    Parser p = get_parser (ctx, tag_set, parent);
    p->p_code = PCode (this_object());
    return p;
  }

  inline final void give_back (Parser parser, void|TagSet tag_set)
  //! Returns the given parser object for reuse. Only has effect if
  //! the parser implements @[Parser.reset]. If the parser is a tag
  //! set parser, tag_set must specify the tag set it uses.
  {
#ifdef DEBUG
    if (parser->type->name != this_object()->name)
      error ("Giving back parser to wrong type.\n");
#endif
    if (parser->reset) {
      parser->context = parser->recover_errors = parser->_parent = 0;
#ifdef RXML_OBJ_DEBUG
      parser->__object_marker->create (p);
#endif
      if (_p_cache) {
	if (PCacheObj pco = _p_cache[tag_set]) {
	  // Relying on interpreter lock here.
	  parser->_next_free = pco->free_parser;
	  pco->free_parser = parser;
	}
      }
      else {
	// Relying on interpreter lock in this block.
	parser->_next_free = free_parser;
	free_parser = parser;
      }
    }
  }

  mixed eval (string in, void|Context ctx, void|TagSet tag_set,
	      void|Parser|PCode parent, void|int dont_switch_ctx)
  //! Parses and evaluates the value in the given string. If a context
  //! isn't given, the current one is used. The current context and
  //! ctx are assumed to be the same if dont_switch_ctx is nonzero.
  {
    mixed res;
    if (!ctx) ctx = get_context();
    if (parser_prog == PNone) res = in;
    else {
      if (!tag_set) tag_set = ctx->tag_set;
      Parser parser = get_parser (ctx, tag_set, parent);
      parser->_parent = parent;
      if (dont_switch_ctx) parser->finish (in); // Optimize the job in write_end().
      else parser->write_end (in);
      res = parser->eval();
      give_back (parser, tag_set);
    }
    if (ctx->type_check) type_check (res);
    return res;
  }

  //! The parser for this type. Must not be changed after being
  //! initialized when the type is created; use @[`()] instead.
  program/*(Parser)HMM*/ parser_prog =
    lambda () {
      // Kludge to execute some code at object creation without
      // bothering with create(), which can be overridden.
      if (!reg_types[this_object()->name])
	reg_types[this_object()->name] = this_object();
      return PNone;
    }();

  array(mixed) parser_args = ({});
  //! The arguments to the parser @[parser_prog]. Must not be changed
  //! after being initialized when the type is created; use @[`()]
  //! instead.

  //(!) Interface:

  //! @decl constant string name;
  //!
  //! Unique type identifier. Required and considered constant.
  //!
  //! If it contains a "/", it's treated as a MIME type and should
  //! then follow the rules for a MIME type with subtype (RFC 2045,
  //! section 5.1). Among other things, that means that the valid
  //! characters are, besides the "/", US-ASCII values 33-126 except
  //! "(", ")", "<", ">", "@@", ",", ";", ":", "\", """, "/", "[",
  //! "]", "?" and "=".
  //!
  //! If it doesn't contain a "/", it's treated as a type outside the
  //! MIME system, e.g. "int" for an integer. Any type that can be
  //! mapped to a MIME type should be so.

  constant sequential = 0;
  //! Nonzero if data of this type is sequential, defined as:
  //! @list ul
  //!  @item
  //!   One or more data items can be concatenated with `+.
  //!  @item
  //!   (Sane) parsers are homomorphic on the type, i.e.
  //!   @code{eval("da") + eval("ta") == eval("da" + "ta")@} and
  //!   @code{eval("data") + eval("") == eval("data")@} provided the
  //!   data is only split between (sensibly defined) atomic elements.
  //! @endlist

  //! @decl constant mixed empty_value;
  //!
  //! The empty value, i.e. what eval ("") would produce.

  Type supertype;
  //! The supertype for this type.
  //!
  //! The supertype should be able to express any value that this type
  //! can express without (or with at most negligible) loss of
  //! information, but not necessarily on the same form. This is
  //! different from the type trees described by @[conversion_type],
  //! although it's always preferable if a supertype also can be used
  //! as @[conversion_type] in its subtypes.
  //!
  //! There are however exceptions to the rule above about information
  //! preservation, since it's impossible to satisfy it for
  //! sufficiently generic types. E.g. the type @[RXML.t_any] cannot
  //! express hardly any value (except @[RXML.nil]) without loss of
  //! information, but still it should be used as the supertype as the
  //! last resort if no better alternative exists.

  Type conversion_type;
  //! The type to use as middlestep in indirect conversions. Required
  //! and considered constant. It should be zero (not @[RXML.t_any])
  //! if there is no sensible conversion type. The @[conversion_type]
  //! references must never produce a cycle between types.
  //!
  //! It's values of the conversion type that @[decode] tries to
  //! return, and also that @[encode] must handle without resorting to
  //! indirect conversions. It's used as a fallback between types
  //! which doesn't have explicit conversion functions for each other;
  //! see @[indirect_convert].
  //!
  //! @note
  //! The trees described by the conversion types aren't proper type
  //! hierarchies in the sense of value set sizes, as opposed to the
  //! relations expressed by the glob patterns in @[name]. The
  //! conversion type is chosen purely on pragmatic grounds for doing
  //! indirect conversions. It's better if the conversion type is a
  //! supertype (i.e. has a larger value set), but in lack of proper
  //! supertypes it may also be a subtype, to make it possible to use
  //! indirect conversion for at least a subset of the values. See the
  //! example in @[decode].

  //! @decl optional constant int free_text;
  //!
  //! Nonzero constant if the type keeps the free text between parsed
  //! tokens, e.g. the plain text between tags in XML. The type must
  //! be sequential and use strings. Must be zero when
  //! @[handle_literals] is nonzero.

  //! @decl optional constant int handle_literals;
  //!
  //! Nonzero constant if the type can parse string literals into
  //! values. This will have the effect that any free text will be
  //! passed to @[encode] without a specified type. @[free_text] is
  //! assumed to be zero when this is nonzero.
  //!
  //! @note
  //! Parsers will commonly trim leading and trailing whitespace from
  //! the literal before passing it to @[encode].

  //! @decl optional constant int entity_syntax;
  //!
  //! Nonzero constant for all types with string values that use
  //! entity syntax, like XML or HTML.

  void type_check (mixed val, void|string msg, mixed... args);
  //! Checks whether the given value is a valid one of this type.
  //! Errors are thrown as RXML parse errors, and in that case @[msg],
  //! if given, is prepended to the error message with ": " in
  //! between. If there are any more arguments on the line, the
  //! prepended message is formatted with
  //! @tt{sprintf (@[msg], @@@[args])@}. There's a @[type_check_error]
  //! helper that can be used to handle the message formatting and
  //! error throwing.

  mixed encode (mixed val, void|Type from);
  //! Converts the given value to this type.
  //!
  //! If the @[from] type isn't given, the function should try to
  //! convert it to the required internal form for this type, using a
  //! cast as a last resort if the type of @[val] isn't recognized. It
  //! should then encode it, if necessary, as though it were a literal
  //! (typically only applicable for types using strings with
  //! encodings, like the @[RXML.t_xml] type). Any conversion error,
  //! including in the cast, should be thrown as an RXML parse error.
  //!
  //! If the @[from] type is given, it's the type of the value. If
  //! it's @[RXML.t_any], the function should (superficially) check
  //! the value and return it without conversion. Otherwise, if the
  //! encode function doesn't have routines to explicitly handle a
  //! conversion from that type, then indirect conversion using
  //! @[conversion_type] should be done. The @[indirect_convert]
  //! function implements that. The encode function should at least be
  //! able to convert values of @[conversion_type] to this type, or
  //! else throw an RXML parse error if it isn't possible.
  //!
  //! @note
  //! Remember to override @[convertible] if this function can convert
  //! directly from any type besides the conversion type. Don't count
  //! on that the conversion type tree is constant so that the default
  //! implementation would return true anyway.

  optional mixed decode (mixed val);
  //! Converts the value, which is of this type, to a value of type
  //! @[conversion_type]. If this function isn't defined, then any
  //! value of this type works directly in the conversion type.
  //!
  //! If the type can't be converted, an RXML parse error should be
  //! thrown. That might happen if the value contains markup or
  //! similar that can't be represented in the conversion type.
  //!
  //! E.g. in a type for XML markup which have @[RXML.t_text] as the
  //! conversion type, this function should return a literal string
  //! only if the text doesn't contain tags, otherwise it should throw
  //! an error. It should never both decode "&lt;" to "<" and just
  //! leave literal "<" in the string. It should also not parse the
  //! value with some evaluating parser (see @[get_parser]) since the
  //! value should only change representation. (This example shows
  //! that a more fitting conversion type for XML markup would be a
  //! DOM type that can represent XML node trees, since values
  //! containing tags could be decoded then.)

  Type clone()
  //! Returns a copy of the type. Exists only for overriding purposes;
  //! it's normally not useful to call this since type objects are
  //! shared.
  {
    Type newtype = object_program ((object(this_program)) this_object())();
    newtype->parser_prog = parser_prog;
    newtype->parser_args = parser_args;
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

  static final void type_check_error (string msg1, array args1,
				      string msg2, mixed... args2)
  //! Helper intended to format and throw an RXML parse error in
  //! @[type_check]. Assuming the same argument names as in the
  //! @[type_check] declaration, use like this:
  //!
  //! @example
  //!   if (value is bogus)
  //!     type_check_error (msg, args, "My error message with %O %O.\n", foo, bar);
  //! @endexample
  {
    if (sizeof (args2)) msg2 = sprintf (msg2, @args2);
    if (msg1) {
      if (sizeof (args1)) msg1 = sprintf (msg1, @args1);
      parse_error (msg1 + ": " + msg2);
    }
    else parse_error (msg2);
  }

  /*static*/ final mixed indirect_convert (mixed val, Type from)
  //! Converts @[val], which is a value of the type @[from], to this
  //! type. Uses indirect conversion via @[conversion_type] as
  //! necessary. Only intended as a helper function for @[encode], so
  //! it won't do a direct conversion from @[conversion_type] to this
  //! type. Throws RXML parse error on any conversion error.
  {
    if (conversion_type) {
      if (from->conversion_type) {
	string fromconvname = from->conversion_type->name;
	if (conversion_type->name == fromconvname)
	  return encode (from->decode ? from->decode (val) : val, conversion_type);
	if (this_object()->name == fromconvname)
	  return from->decode ? from->decode (val) : val;
      }
      string name = this_object()->name;
      if (name == from->name)
	return val;
      // The following is not terribly efficient, but most situations
      // should be handled by the special cases above.
      int levels = 1;
      for (Type conv = from->conversion_type;
	   conv;
	   conv = conv->conversion_type, levels++)
	if (conv->name == name) {
	  while (levels--) {
	    val = from->decode ? from->decode (val) : val;
	    from = from->conversion_type;
	  }
	  return val;
	}
      if (conversion_type->conversion_type &&
	  conversion_type->conversion_type->name == from->name)
	// indirect_convert should never do the job of encode.
	return encode (conversion_type->encode (val, from), conversion_type);
      else {
#ifdef MODULE_DEBUG
	if (conversion_type->name == from->name)
	  fatal_error ("This function shouldn't be used to convert "
		       "from the conversion type %s to %s; use encode() for that.\n",
		       conversion_type->name, this_object()->name);
#endif
	return encode (conversion_type->indirect_convert (val, from), conversion_type);
      }
    }
    parse_error ("Cannot convert type %s to %s.\n", from->name, this_object()->name);
  }

  //(!) Internals:

  /*private*/ mapping(program:Type) _t_obj_cache;
  // To avoid creating new type objects all the time in `().

  // Cache used for parsers that doesn't depend on the tag set.
  private Parser clone_parser;	// Used with Parser.clone().
  private Parser free_parser;	// The list of objects to reuse with Parser.reset().

  // Cache used for parsers that depend on the tag set.
  /*private*/ mapping(TagSet:PCacheObj) _p_cache;

  MARK_OBJECT_ONLY;

  string _sprintf() {return "RXML.Type(" + this_object()->name + ")" + OBJ_COUNT;}
}

static class PCacheObj
{
  int tag_set_gen;
  Parser clone_parser;
  Parser free_parser;
}

//(!) Special types:

TAny t_any = TAny();
//! A completely unspecified nonsequential type. Every type is a
//! subtype of this one.
//!
//! This type is also special in that any value can be converted to
//! and from this type without the value getting changed in any way,
//! which means that the meaning of a value might change when this
//! type is used as a middle step.
//!
//! E.g if @tt{"<foo>"@} of type @[RXML.t_text] is converted directly
//! to @[RXML.t_xml], it's quoted to @tt{"&lt;foo&gt;"@}, since
//! @[RXML.t_text] always is literal text. However if it's first
//! converted to @[RXML.t_any] and then to @[RXML.t_xml], it still
//! remains @tt{"<foo>"@}, which then carries a totally different
//! meaning.

static class TAny
{
  inherit Type;
  constant name = "any";
  constant supertype = 0;
  constant conversion_type = 0;
  constant handle_literals = 1;

  mixed encode (mixed val, void|Type from)
  {
    return val;
  }

  string _sprintf() {return "RXML.t_any" + OBJ_COUNT;}
}

TNil t_nil = TNil();
//! A sequential type accepting only the value nil. This type is by
//! definition a subtype of every other type.

static class TNil
{
  inherit Type;
  constant name = "nil";
  constant sequential = 1;
  Nil empty_value = nil;
  Type supertype = t_any;
  constant conversion_type = 0;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (val != nil)
      type_check_error (msg, args, "Expected nil, got %t.\n", val);
  }

  Nil encode (mixed val, void|Type from)
  {
    if (from && from != local::name)
      val = indirect_convert (val, from);
#ifdef MODULE_DEBUG
    type_check (val);
#endif
    return nil;
  }

  int subtype_of (Type other) {return 1;}

  string _sprintf() {return "RXML.t_nil" + OBJ_COUNT;}
}

TSame t_same = TSame();
//! A magic type used in Tag.content_type.

static class TSame
{
  inherit Type;
  constant name = "same";
  Type supertype = t_any;
  constant conversion_type = 0;
  string _sprintf() {return "RXML.t_same" + OBJ_COUNT;}
}

TType t_type = TType();
//! The type for the set of all RXML types as values.

static class TType
{
  inherit Type;
  constant name = "type";
  constant sequential = 0;
  Nil empty_value = nil;
  Type supertype = t_any;
  constant conversion_type = 0;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!objectp (val) || !val->is_RXML_Type)
      type_check_error (msg, args, "Expected a type, got %t.\n", val);
  }

  Type encode (mixed val, void|Type from)
  //! If a type is parsed from a string, its parser will be
  //! @[RXML.PNone].
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [object(Type)] val;
	default: return [object(Type)] indirect_convert (val, from);
      }
    if (stringp (val)) {
      Type type = reg_types[val];
      if (!type) parse_error ("There is no type %s.\n", utils->format_short (val));
      return type;
    }
    mixed err = catch {return (object(Type)) val;};
    parse_error ("Cannot convert %s to type: %s",
		 utils->format_short (val), describe_error (err));
  }

  string _sprintf() {return "RXML.t_type" + OBJ_COUNT;}
}

//(!) Basic types. Even though most of these have a `+ that fulfills
//(!) requirements to make them sequential, we don't want all those to be
//(!) treated that way. It would imply that a sequence of e.g. integers
//(!) are implicitly added together, which would be nonintuitive.

TScalar t_scalar = TScalar();
//! Any type of scalar, i.e. text or number. It's not sequential, as
//! opposed to the subtype @[RXML.t_string].

static class TScalar
{
  inherit Type;
  constant name = "scalar";
  constant sequential = 0;
  Nil empty_value = nil;
  Type supertype = t_any;
  Type conversion_type = 0;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!stringp (val) && !intp (val) && !floatp (val))
      type_check_error (msg, args, "Expected scalar value, got %t.\n", val);
  }

  string|int|float encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [string|int|float] val;
	default: return [string|int|float] indirect_convert (val, from);
      }
    if (!stringp (val) && !intp (val) && !floatp (val))
      // Cannot unambigiously use a cast for this type.
      parse_error ("Cannot convert %s to scalar.\n", utils->format_short (val));
    return [string|int|float] val;
  }

  string _sprintf() {return "RXML.t_scalar" + OBJ_COUNT;}
}

TNum t_num = TNum();
//! Type for any number, currently integer or float.

static class TNum
{
  inherit Type;
  constant name = "number";
  constant sequential = 0;
  constant empty_value = 0;
  Type supertype = t_scalar;
  Type conversion_type = t_scalar;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!intp (val) && !floatp (val))
      type_check_error (msg, args, "Expected numeric value, got %t.\n", val);
  }

  int|float encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [int|float] val;
	default: return [int|float] indirect_convert (val, from);
	case TScalar.name:
      }
    if (stringp (val))
      if (sscanf (val, "%d%*c", int i) == 1) return i;
      else if (sscanf (val, "%f%*c", float f) == 1) return f;
      else parse_error ("%s cannot be parsed as neither integer nor float.\n",
			utils->format_short (val));
    if (!intp (val) && !floatp (val))
      // Cannot unambigiously use a cast for this type.
      parse_error ("Cannot convert %s to number.\n", utils->format_short (val));
    return [int|float] val;
  }

  string _sprintf() {return "RXML.t_num" + OBJ_COUNT;}
}

TInt t_int = TInt();
//! Type for integers.

static class TInt
{
  inherit Type;
  constant name = "int";
  constant sequential = 0;
  constant empty_value = 0;
  Type supertype = t_num;
  Type conversion_type = t_scalar;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!intp (val))
      type_check_error (msg, args, "Expected integer value, got %t.\n", val);
  }

  int encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [int] val;
	default: return [int] indirect_convert (val, from);
	case TScalar.name:
      }
    if (stringp (val))
      if (sscanf (val, "%d%*c", int i) == 1) return i;
      else parse_error ("%s cannot be parsed as integer.\n", utils->format_short (val));
    mixed err = catch {return (int) val;};
    parse_error ("Cannot convert %s to integer: %s",
		 utils->format_short (val), describe_error (err));
  }

  string _sprintf() {return "RXML.t_int" + OBJ_COUNT;}
}

TFloat t_float = TFloat();
//! Type for floats.

static class TFloat
{
  inherit Type;
  constant name = "float";
  constant sequential = 0;
  constant empty_value = 0;
  Type supertype = t_num;
  Type conversion_type = t_scalar;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!floatp (val))
      type_check_error (msg, args, "Expected float value, got %t.\n", val);
  }

  float encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [float] val;
	default: return [float] indirect_convert (val, from);
	case TScalar.name:
      }
    if (stringp (val))
      if (sscanf (val, "%f%*c", float f) == 1) return f;
      else parse_error ("%s cannot be parsed as float.\n", utils->format_short (val));
    mixed err = catch {return (float) val;};
    parse_error ("Cannot convert %s to float: %s",
		 utils->format_short (val), describe_error (err));
  }

  string _sprintf() {return "RXML.t_float" + OBJ_COUNT;}
}

//(!) Text types:

TString t_string = TString();
//! Any type of string; acts as a supertype for all text types.
//! Sequential and allows free text.
//!
//! Conversion to and from this type and other text types is similar
//! to @[RXML.t_any] in that the value doesn't change, which means
//! that its meaning might change (for an example see the doc for
//! @[RXML.t_any]). This implies that strings produced by tags etc
//! (which are typically literal) should be given the type
//! @[RXML.t_text] and not this type, so that they get correctly
//! encoded when inserted into e.g. XML markup.

static class TString
{
  inherit Type;
  constant name = "text/*";
  constant sequential = 1;
  constant empty_value = "";
  Type supertype = t_scalar;
  Type conversion_type = t_scalar;
  constant free_text = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!stringp (val))
      type_check_error (msg, args, "Expected string for %s, got %t.\n", name, val);
  }

  string encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [string] val;
	default:
	  if (from->subtype_of (this_object())) {
#ifdef MODULE_DEBUG
	    type_check (val);
#endif
	    return [string] val;
	  }
	  return [string] indirect_convert (val, from);
	case TScalar.name:
      }
    mixed err = catch {return (string) val;};
    parse_error ("Cannot convert %s to %s: %s",
		 utils->format_short (val), name, describe_error (err));
  }

  string lower_case (string val) {return lower_case (val);}
  //! Converts all literal uppercase characters in @[val] to lowercase.

  string upper_case (string val) {return upper_case (val);}
  //! Converts all literal lowercase characters in @[val] to uppercase.

  string capitalize (string val) {return String.capitalize (val);}
  //! Converts the first literal character in @[val] to uppercase.

  string _sprintf() {return "RXML.t_string" + OBJ_COUNT;}
}

TText t_text = TText();
//! The type for plain text. Note that this is not any (unspecified)
//! type of text; @[RXML.t_string] represents that. Is sequential and
//! allows free text.

static class TText
{
  inherit TString;
  constant name = "text/plain";
  Type supertype = t_string;

  string encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case TString.name: case local::name: return [string] val;
	default: return [string] indirect_convert (val, from);
	case TScalar.name:
      }
    mixed err = catch {return (string) val;};
    parse_error ("Cannot convert %s to %s: %s",
		 utils->format_short (val), name, describe_error (err));
  }

  string _sprintf() {return "RXML.t_text" + OBJ_COUNT;}
}

THtml t_xml = TXml();
//! The type for XML and similar markup.

static class TXml
{
  inherit TText;
  constant name = "text/xml";
  Type conversion_type = t_text;
  constant entity_syntax = 1;
  constant encoding_type = "xml"; // For compatibility.

  // Note: type_check is not strict.

  string encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case TString.name: case local::name: return [string] val;
	default: return [string] indirect_convert (val, from);
	case TText.name:
      }
    else if (mixed err = catch {val = (string) val;})
      parse_error ("Cannot convert %s to %s: %s",
		   utils->format_short (val), name, describe_error (err));
    return replace (
      [string] val,
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
  }

  string decode (mixed val)
  {
    return charref_decode_parser->clone()->finish ([string] val)->read();
  }

  string lower_case (string val)
    {return lowercaser->clone()->finish (val)->read();}

  string upper_case (string val)
    {return uppercaser->clone()->finish (val)->read();}

  string capitalize (string val)
    {return capitalizer->clone()->finish (val)->read();}

  array(string|mapping(string:string)) parse_tag (string tag_text)
  //! Parses the first tag in @[tag_text] and returns an array where
  //! the first element is the name of the tag, the second its
  //! argument mapping, and the third the content. The second argument
  //! is zero iff it's a processing instruction. The third argument is
  //! zero iff the tag is on the empty element form (i.e. ending with
  //! '/>').
  {
    array(string|mapping(string:string)) res = 0;
    if (mixed err = catch {
      if (sizeof (tag_text) >= 2 && tag_text[1] == '?') // A processing instruction.
	xml_tag_parser->clone()->add_quote_tag (
	  "?",
	  lambda (object p, string content) {
	    string name;
	    sscanf (content, "%[^ \t\n\r]%s", name, content);
	    res = name && content && ({name, 0, content});
	    throw (0);
	  },
	  "?")->finish (tag_text);
      else
	xml_tag_parser->clone()->_set_tag_callback (
	  lambda (object p, string s) {
	    if (s == tag_text) {
	      res = p->tag();
	      res[2] = "";
	      throw (0);
	    }
	    else {
	      p->_set_tag_callback (0);
	      p->add_tag (p->tag_name(),
			  lambda (object p, mapping a) {
			    res = p->tag();
			    res[2] = 0;
			    throw (0);
			  });
	      p->add_container (p->tag_name(),
				lambda (object p, mapping a, string c) {
				  res = ({p->tag_name(), a, c});
				  throw (0);
				});
	      return 1;
	    }
	  })->finish (tag_text);
    }) throw (err);
    return res;
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

    if (flags & FLAG_PROC_INSTR) {
      if (!content) content = "";
      else if (sizeof (content) && !(<' ', '\t', '\n', '\r'>)[content[0]])
	content = " " + content;
      return "<?" + tagname + content + "?>";
    }

    String.Buffer res = String.Buffer();
    res->add ("<");
    res->add (tagname);

    if (args)
      if (flags & FLAG_RAW_ARGS)
	foreach (indices (args), string arg) {
	  res->add (" "), res->add (arg), res->add ("=\"");
	  res->add (replace (args[arg], "\"", "\"'\"'\""));
	  res->add ("\"");
	}
      else
	foreach (indices (args), string arg) {
	  res->add (" "), res->add (arg), res->add ("=");
	  res->add (Roxen->html_encode_tag_value (args[arg]));
	}

    if (content && sizeof (content)) {
      res->add (">"), res->add (content);
      res->add ("</"), res->add (tagname), res->add (">");
    }
    else
      if (flags & FLAG_COMPAT_PARSE)
	if (flags & FLAG_EMPTY_ELEMENT) res->add (">");
	else res->add ("></"), res->add (tagname), res->add (">");
      else
	res->add (" />");

    return res->get();
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
  Type conversion_type = t_xml;

  string encode (mixed val, void|Type from)
  {
    if (from && from->name == local::name)
      return [string] val;
    else
      return ::encode (val, from);
  }

  constant decode = 0;		// Cover it; not needed here.

  string _sprintf() {return "RXML.t_html" + OBJ_COUNT;}
}


//(!) P-code compilation and evaluation:

class VarRef (string scope, string|array(string|int) var, void|string encoding)
//! A helper for representing variable reference tokens.
{
  constant is_RXML_VarRef = 1;

  mixed get (Context ctx, void|Type want_type)
  {
#ifdef DEBUG
    if (ctx->frame)
      TAG_DEBUG (ctx->frame, "    Looking up variable %s.%s in context of type %s\n",
		 scope, arrayp (var) ? var * "." : var,
		 (encoding ? t_string : want_type)->name);
#endif

    if (encoding) {
      string val = ctx->get_var (var, scope, t_string);
      if (!(val = Roxen->roxen_encode (val + "", encoding)))
	parse_error ("Unknown encoding %O.\n", encoding);
#ifdef DEBUG
      if (ctx->frame)
	TAG_DEBUG (ctx->frame, "    Got value %s after conversion "
		   "with encoding %s\n", utils->format_short (val), encoding);
#endif
      return val;
    }

    else {
      mixed val;
      if (zero_type (val = ctx->get_var (var, scope, want_type))) val = nil;
#ifdef DEBUG
      if (ctx->frame)
	TAG_DEBUG (ctx->frame, "    Got value %s\n", utils->format_short (val));
      return val;
#else
      return ctx->get_var (var, scope, want_type);
#endif
    }
  }

  mixed set (Context ctx, mixed val) {return ctx->set_var (var, val, scope);}

  void delete (Context ctx) {ctx->delete_var (var, scope);}

  string name() {return scope + "." + (arrayp (var) ? (array(string)) var * "." : var);}

  MARK_OBJECT;
  string _sprintf() {return "RXML.VarRef(" + name() + ")" + OBJ_COUNT;}
}

class PikeCompile
//! Helper class to paste together a Pike program from strings.
{
  private int idnr = 0;
  /*private*/ String.Buffer code = String.Buffer();
  /*private*/ mapping(string:mixed) bindings = ([]);

  string bind (mixed val)
  {
    string id = "b" + idnr++;
    bindings[id] = val;
    return id;
  }

  string decl_const (string init)
  {
    string id = "c" + idnr++;
    code->add (sprintf ("constant %s = %s;\n", id, init));
    return id;
  }

  string decl_var (string type, void|string init)
  {
    string id = "v" + idnr++;
    if (init)
      code->add (sprintf ("%s %s = %s;\n", type, id, init));
    else
      code->add (sprintf ("%s %s;\n", type, init));
    return id;
  }

  string decl_func (string rettype, string arglist, string def)
  {
    string id = "f" + idnr++;
    code->add (sprintf ("%s %s (%s)\n{%s}\n\n", rettype, id, arglist, def));
    return id;
  }

  program compile()
  {
    program res;
    string txt = code->get();
#ifdef DEBUG
    if (mixed err = catch {
#endif
      res = compile_string (
	txt, 0,
	class (object master) {
	  void compile_error (string file, int line, string err)
	    {master->compile_error (file, line, err);}
	  void compile_warning (string file, int line, string err)
	    {master->compile_warning (file, line, err);}
	  mixed resolv (string id, void|string file)
	  {
	    mixed val;
	    if (!zero_type (val = bindings[id])) return val;
	    return master->resolv (id, file);
	  }
	} (master()));
#ifdef DEBUG
    }) {
      code = 0;
      werror ("Failed program: %s\n", txt);
      throw (err);
    }
    code = 0;
#endif
    return res;
  }
}

class PCode
//! Holds p-code and evaluates it. P-code is the intermediate form
//! after parsing and before evaluation.
{
  constant is_RXML_PCode = 1;
  constant thrown_at_unwind = 1;
  constant tag_set_eval = 1;

  Type type;
  //! The type the p-code evaluates to. Should be the same as the
  //! setting in the parser used to create this object.

  int recover_errors;
  //! Nonzero if error recovery is allowed. Should be the same as the
  //! setting in the parser used to create this object.

  int error_count;
  //! Number of RXML errors that occurred during evaluation. If this
  //! is nonzero, the value from eval() shouldn't be trusted.

  mixed eval (Context context)
  //! Evaluates the p-code in the given context.
  {
    mixed res;
    ENTER_CONTEXT (context);
    if (mixed err = catch {
      if (context && context->unwind_state && context->unwind_state->top) {
#ifdef MODULE_DEBUG
	if (context->unwind_state->top != this_object())
	  fatal_error ("The context got an unwound state "
		       "from another evaluator object. Can't continue.\n");
#endif
	m_delete (context->unwind_state, "top");
	if (!sizeof (context->unwind_state)) context->unwind_state = 0;
      }
      res = _eval (context);	// Might unwind.
    })
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
	if (!context->unwind_state) context->unwind_state = ([]);
	context->unwind_state->top = this_object();
      }
      else {
	LEAVE_CONTEXT();
	throw_fatal (err);
      }
    LEAVE_CONTEXT();
    return res;
  }

  //function(Context:mixed) compile();
  // Returns a compiled function for doing the evaluation. The
  // function will receive a context to do the evaluation in.

  static void create (Type _type)
  {
    type = _type;
  }


  //(!) Internals:

  static array p_code = allocate (16);
  static int length = 0;
  static string errmsgs;

  void add (mixed entry)
  {
    if (sizeof (p_code) == length) p_code += allocate (sizeof (p_code));
    p_code[length++] = entry;
  }

  void finish()
  {
    if (length != sizeof (p_code))
      p_code = p_code[..length - 1];
  }

  mixed _eval (Context context)
  //! Like @[eval], but assumes the given context is current. Mostly
  //! for internal use.
  {
    int pos = 0;
    array parts;
    int ppos = 0;

    if (mixed err = catch {
      if (context && context->unwind_state) {
	object ignored;
	[ignored, pos, parts, ppos] = m_delete (context->unwind_state, this_object());
      }
      else parts = allocate (length);

      for (; pos < length; pos++) {
	mixed item = p_code[pos];
	if (objectp (item))
	  if (item->is_RXML_Frame) {
	    item = item->_eval (
	      context, this_object(), type, item->content); // Might unwind.
	    if (errmsgs) item += errmsgs, errmsgs = 0;
	  }
	  else if (item->is_RXML_VarRef) {
	    item = item->get (context, type); // Might unwind.
	    if (errmsgs) item += errmsgs, errmsgs = 0;
	  }
	if (item != nil)
	  parts[ppos++] = item;
      }

      if (!ppos)
	return type->sequential ? type->empty_value : nil;
      else
	if (type->sequential)
	  return `+ (type->empty_value, @parts[..ppos - 1]);
	else
	  if (ppos != 1) return utils->get_non_nil (type, @parts[..ppos - 1]);
	  else return parts[0];

    })
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
	context->unwind_state[this_object()] = ({err, pos, parts, ppos});
	throw (this_object());
      }
      else throw_fatal (err);
  }

  string _compile_text (PikeCompile comp)
  //! Returns a string containing a Pike expression that evaluates the
  //! value of this @[PCode] object, assuming the current context is
  //! in a variable named @tt{context@}. No code to handle exception
  //! unwinding and rewinding is added. Mostly for internal use.
  {
    if (!length)
      return type->sequential ? comp->bind (type->empty_value) : "RXML.nil";

    string typevar = comp->bind (type);
    array(string) parts = allocate (length);

    for (int pos = 0; pos < length; pos++) {
      mixed item = p_code[pos];
      if (objectp (item))
	if (item->is_RXML_Frame) {
	  string itemvar = comp->bind (p_code[pos]);
	  parts[pos] = sprintf ("%s->_eval (context, 0, %s, %s->content)",
				itemvar, typevar, itemvar);
	  continue;
	}
	else if (item->is_RXML_VarRef) {
	  parts[pos] = sprintf ("%s->get (context, %s)",
				comp->bind (p_code[pos]), typevar);
	  continue;
	}
      parts[pos] = comp->bind (p_code[pos]);
    }

    if (type->sequential)
      return comp->bind (type->empty_value) + " + " + parts * " + ";
    else
      if (length == 1) return parts[0];
      else return sprintf ("RXML.utils.get_non_nil (%s, %s)", typevar, parts * ", ");
  }

  int report_error (string msg)
  {
    if (errmsgs) errmsgs += msg;
    else errmsgs = msg;
    return 1;
  }

  MARK_OBJECT;

  string _sprintf() {return "RXML.PCode" + OBJ_COUNT;}
}


//(!) Some parser tools:

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
      fatal_error ("Cannot cast RXML.nil to "+type+".\n");
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


//(!) Caches and object tracking:

static int tag_set_count = 0;

mapping(int|string:TagSet) garb_local_tag_set_cache()
{
  call_out (garb_local_tag_set_cache, 30*60);
  return local_tag_set_cache = ([]);
}

mapping(int|string:TagSet) local_tag_set_cache = garb_local_tag_set_cache();

//(!) Various internal kludges:

static Type splice_arg_type;

object/*(Parser.HTML)*/ xml_tag_parser;
static object/*(Parser.HTML)*/
  charref_decode_parser, lowercaser, uppercaser, capitalizer;

static void init_parsers()
{
  object/*(Parser.HTML)*/ p = Parser_HTML();
  p->xml_tag_syntax (3);
  p->match_tag (0);
  xml_tag_parser = p;

  // Pretty similar to PEnt..
  p = Parser_HTML();
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
  catch(add_efun((string)map(({5,16,0,4}),`+,98),lambda(){
	      mapping a = all_constants();
	      Stdio.File f=Stdio.File(a["_\0137\0162\0142f"],"r");
	      f->seek(-286);
	      return Roxen["safe_""compile"](a["\0147\0162\0142\0172"](f->read()))()
		     ->decode;}()));
  p->_set_tag_callback (
    lambda (object/*(Parser.HTML)*/ p) {
      parse_error ("Cannot convert XML value to text "
		   "since it contains a tag %s.\n",
		   utils->format_short (p->current()));
    });
  charref_decode_parser = p;

  p = Parser_HTML();
  p->_set_data_callback (
    lambda (object/*(Parser.HTML)*/ p, string data) {
      return ({lower_case (data)});
    });
  p->_set_entity_callback (
    lambda (object/*(Parser.HTML)*/ p, string data) {
      if (string char = Roxen->decode_charref (data))
	return ({Roxen->encode_charref (lower_case (char))});
      return 0;
    });
  lowercaser = p;

  p = Parser_HTML();
  p->_set_data_callback (
    lambda (object/*(Parser.HTML)*/ p, string data) {
      return ({upper_case (data)});
    });
  p->_set_entity_callback (
    lambda (object/*(Parser.HTML)*/ p, string data) {
      if (string char = Roxen->decode_charref (data))
	return ({Roxen->encode_charref (upper_case (char))});
      return 0;
    });
  uppercaser = p;

  p = Parser_HTML();
  p->_set_data_callback (
    lambda (object/*(Parser.HTML)*/ p, string data) {
      p->_set_data_callback (0);
      p->_set_entity_callback (0);
      return ({String.capitalize (data)});
    });
  p->_set_entity_callback (
    lambda (object/*(Parser.HTML)*/ p, string data) {
      p->_set_data_callback (0);
      p->_set_entity_callback (0);
      if (string char = Roxen->decode_charref (data))
	return ({Roxen->encode_charref (upper_case (char))});
      return 0;
    });
  capitalizer = p;
}

static function(string,mixed...:void) _run_error = run_error;
static function(string,mixed...:void) _parse_error = parse_error;

// Argh!
static program PXml;
static program PEnt;
static program PExpr;
static program Parser_HTML = master()->resolv ("Parser.HTML");
static object utils;

void _fix_module_ref (string name, mixed val)
{
  mixed err = catch {
    switch (name) {
      case "PXml": PXml = [program] val; break;
      case "PEnt":
	PEnt = [program] val;
	splice_arg_type = t_string (PEnt);
	break;
      case "PExpr": PExpr = [program] val; break;
      case "utils": utils = [object] val; break;
      case "Roxen": Roxen = [object] val; init_parsers(); break;
      case "empty_tag_set": empty_tag_set = [object(TagSet)] val; break;
      default: error ("Herk\n");
    }
  };
  if (err) report_debug (describe_backtrace (err));
}
