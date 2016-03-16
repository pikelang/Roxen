// RXML parser and compiler framework.
//
// Created 1999-07-30 by Martin Stjernholm.
//
// $Id$

// Kludge: Must use "RXML.refs" somewhere for the whole module to be
// loaded correctly.
protected object Roxen;
protected object roxen;

//! API stability notes:
//!
//! The API in this file regarding the global functions and the Tag,
//! TagSet, Context, Frame and Type classes and their descendants is
//! intended to not change in incompatible ways. There are however
//! some areas where incompatible changes still must be expected:
//!
//! @ul
//!  @item
//!   The namespace handling will likely change to conform to XML
//!   namespaces. The currently implemented system is inadequate then
//!   and will probably be removed.
//!  @item
//!   The RXML parser module currently doesn't stream data according
//!   to the interface for streaming tags (but the implementation
//!   still follows the documented API for it). Therefore there's a
//!   risk that incompatible changes must be made in it due to design
//!   bugs when it's tested out. That is considered very unlikely,
//!   though.
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
//! @endul
//!
//! @note
//! The API for parsers, p-code evaluators etc is not part of the
//! "official" API. (The syntax _parsed_ by the currently implemented
//! parsers is well defined, of course.)

//#pragma strict_types // Disabled for now since it doesn't work well enough.

#define MAGIC_HELP_ARG
// #define OBJ_COUNT_DEBUG
// #define RXML_OBJ_DEBUG
// #define RXML_VERBOSE
// #define RXML_REQUEST_VERBOSE
// #define RXML_COMPILE_DEBUG
// #define RXML_ENCODE_DEBUG
// #define TYPE_OBJ_DEBUG
// #define PARSER_OBJ_DEBUG
// #define FRAME_DEPTH_DEBUG
// #define RXML_PCODE_DEBUG
// #define RXML_PCODE_UPDATE_DEBUG
// #define RXML_PCODE_COMPACT_DEBUG
// #define TAGSET_GENERATION_DEBUG

#include <config.h>
#include <module.h>
#include <request_trace.h>


#ifdef RXML_OBJ_DEBUG
#  define MARK_OBJECT \
     mapping|object __object_marker = RoxenDebug.ObjectMarker (this_object())
#  define MARK_OBJECT_ONLY \
     mapping|object __object_marker = RoxenDebug.ObjectMarker (0)
#  define DO_IF_RXML_OBJ_DEBUG(X...) X
#else
#  define MARK_OBJECT ;
#  define MARK_OBJECT_ONLY ;
#  define DO_IF_RXML_OBJ_DEBUG(X...)
#endif

#ifdef OBJ_COUNT_DEBUG
// This debug mode gives every object a unique number in the
// _sprintf() string.
#  ifndef RXML_OBJ_DEBUG
#    undef MARK_OBJECT
#    undef MARK_OBJECT_ONLY
#    define MARK_OBJECT \
       mapping|object __object_marker = (["count": ++all_constants()->_obj_count])
#    define MARK_OBJECT_ONLY \
       mapping|object __object_marker = (["count": ++all_constants()->_obj_count])
#  endif
#  define OBJ_COUNT (__object_marker ? "[" + __object_marker->count + "]" : "")
#else
#  define OBJ_COUNT ""
#endif

#ifdef DEBUG
#  define TAG_DEBUG(frame, msg, args...)				\
  (TAG_DEBUG_TEST (frame && frame->flags & FLAG_DEBUG) &&		\
   report_debug ("%O: " + (msg), (frame), args), 0)
#else
#  define TAG_DEBUG(frame, msg, args...) 0
#endif

#ifdef FRAME_DEPTH_DEBUG
#  define FRAME_DEPTH_MSG(msg...) report_debug (msg)
#else
#  define FRAME_DEPTH_MSG(msg...)
#endif

#ifdef RXML_PCODE_UPDATE_DEBUG
#  define PCODE_UPDATE_MSG(msg...) report_debug (msg)
#else
#  define PCODE_UPDATE_MSG(msg...)
#endif

#define _LITERAL(X) #X
#define LITERAL(X) _LITERAL (X)

#define HASH_INT2(m, n) (n < 65536 ? (m << 16) + n : sprintf ("%x,%x", m, n))

#undef RXML_CONTEXT
#define RXML_CONTEXT (_cur_rxml_context->get())
#define SET_RXML_CONTEXT(ctx) (_cur_rxml_context->set (ctx))

// Use defines since typedefs doesn't work in soft casts yet.
#define SCOPE_TYPE mapping(string:mixed)|object(Scope)
#define UNWIND_STATE mapping(string|object:mixed|array)
#define EVAL_ARGS_FUNC function(Context,Parser|PCode:mapping(string:mixed))|string

// Tell Pike.count_memory this is global.
constant pike_cycle_depth = 0;


// Internal caches and object tracking
//
// This must be first so that it happens early in __INIT.

protected int tag_set_count = 0;

protected mapping(RoxenModule|Configuration:
		  mapping(string:TagSet|int)) all_tag_sets = ([]);
// Maps all tag sets to their TagSet objects. The top mapping is
// indexed with the owner of the tag set, or 0 for global tag sets.
// The inner mappings (which always are weak) are indexed by the tag
// set names.
//
// For tag sets that have been removed, the value is their generation
// number, so that a new tag set with that name will continue the
// generation sequence. We use the fact that a weak mapping won't
// remove items that aren't refcounted (and strings).

protected Thread.Mutex all_tag_sets_mutex = Thread.Mutex();

#define LOOKUP_TAG_SET(owner, name) ((all_tag_sets[owner] || ([]))[name])

// Assumes all_tag_sets_mutex is locked.
#define SET_TAG_SET(owner, name, value) do {				\
  mapping(string:TagSet|int) map =					\
    all_tag_sets[owner] ||						\
    (all_tag_sets[owner] = set_weak_flag (([]), 1));			\
  map[name] = (value);							\
} while (0)

protected mapping(string:program/*(Parser)*/) reg_parsers = ([]);
// Maps each parser name to the parser program.

protected mapping(string:Type) reg_types = ([]);
// Maps each type name to a type object with the PNone parser.

protected mapping(mixed:string) reverse_constants = set_weak_flag (([]), 1);


// Interface classes

class Tag
//! Interface class for the static information about a tag.
{
  constant is_RXML_Tag = 1;
  constant is_RXML_encodable = 1;
  constant is_RXML_p_code_frame = 1;
  constant is_RXML_p_code_entry = 1;

  // Interface:

  //! @decl string name;
  //!
  //! The name of the tag. Required and considered constant.

  TagSet tagset;
  //! The tag set that this tag belongs to, if any.

  //! @decl int flags;
  //!
  //! Various bit flags that affect parsing; see the FLAG_* constants.
  //! @[RXML.Frame.flags] is initialized from this.

  mapping(string:Type) req_arg_types = ([]);
  mapping(string:Type) opt_arg_types = ([]);
  //! The names and types of the required and optional arguments. If a
  //! type specifies a parser, it'll be used on the argument value.
  //! Note that the order in which arguments are parsed is arbitrary.
  //!
  //! If an argument got a nonsequential type, it takes exactly one
  //! value. More than one value trigs a parse error. If no value is
  //! given (e.g. the attribute value is just an empty string) then a
  //! parse error is trigged if the argument is required, otherwise
  //! the argument is considered missing altogether.
  //!
  //! For instance, if you have @expr{@[opt_arg_types] = (["foo":
  //! RXML.t_int(RXML.PEnt)])@} then @expr{<my-tag foo=""/>@} is the
  //! same as @expr{<my-tag/>@} since the attribute value @expr{""@}
  //! contains no integer.
  //!
  //! The above does not apply to sequential types, since they always
  //! can be assigned an empty value.

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

  array(Type) result_types = ({t_string, t_any_text});
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
  //!
  //! The types in this list are first searched in order for a type
  //! that is a subtype of the actual type. If none is found, the list
  //! is searched through a second time for a type that is a supertype
  //! of the actual type.
  //!
  //! The default value inherited from this class defines the tag to
  //! produce any string result (and thereby accept any string
  //! content, due to @[RXML.t_same] in @[content_type]). If the type
  //! is @tt{text/*@} (@[RXML.t_any_text]) or some subtype, the tag
  //! operates on text, which means all whitespace is significant. If
  //! the type is @tt{string@} or some supertype, the tag operates on
  //! the @tt{string@} type (@[RXML.t_string]) which ignores
  //! whitespace between tokens (the tag doesn't need to do any
  //! special treatment of this).

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
  //! @ul
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
  //!   identifier @expr{@[name] + "#" + @[plugin_name]@}.
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
  //! @endul

  // Services:

  final object/*(Frame)HMM*/ `() (mapping(string:mixed) args, void|mixed content)
  //! Make an initialized frame for the tag. Typically useful when
  //! returning generated tags from e.g. @[RXML.Frame.do_process]. The
  //! argument values and the content are normally not parsed.
  {
    object/*(Frame)HMM*/ frame =
      ([function(:object/*(Frame)HMM*/)] this_object()->Frame)();
    frame->tag = this_object();
    frame->flags = this_object()->flags;
    frame->args = args;
    frame->content = zero_type (content) ? nil : content;
#ifdef RXML_OBJ_DEBUG
    frame->__object_marker->create (frame);
#endif
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
    // Note: Approximate code duplication in _eval_splice_args and
    // Frame._prepare.
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
    if (!ctx) ctx = RXML_CONTEXT;
#ifdef MODULE_DEBUG
    if (mixed err = catch {
#endif
	if (ignore_args)
	  foreach (indices (args) - ignore_args, string arg) {
	    Type t = atypes[arg] || def_arg_type;
	    mixed v = t->eval_opt (args[arg], ctx); // Should not unwind.
	    if (v == nil)
	      set_nil_arg (args, arg, t, req_arg_types, ctx->id);
	    else
	      args[arg] = v;
	  }
	else
	  foreach (args; string arg; mixed val) {
	    Type t = atypes[arg] || def_arg_type;
	    mixed v = t->eval_opt (val, ctx); // Should not unwind.
	    if (v == nil)
	      set_nil_arg (args, arg, t, req_arg_types, ctx->id);
	    else
	      args[arg] = v;
	  }
#ifdef MODULE_DEBUG
    }) {
      if (objectp (err) && ([object] err)->thrown_at_unwind)
	fatal_error ("Can't save parser state when evaluating arguments.\n");
      throw_fatal (err);
    }
#endif
    return 1;
  }

  // Internals:

  // We assume these objects always are globally referenced.
  constant pike_cycle_depth = 0;

#define MAKE_FRAME(_frame, _ctx, _parser, _args, _content)		\
  make_new_frame: do {							\
    if (UNWIND_STATE ustate = _ctx->unwind_state)			\
      if (ustate[_parser]) {						\
	_frame = [object/*(Frame)HMM*/] ustate[_parser][0];		\
	m_delete (ustate, _parser);					\
	if (!sizeof (ustate)) _ctx->unwind_state = 0;			\
	break make_new_frame;						\
      }									\
    _frame =								\
      ([function(:object/*(Frame)HMM*/)] this_object()->Frame)();	\
    _frame->tag = this_object();					\
    _frame->flags = this_object()->flags|FLAG_UNPARSED;			\
    _frame->args = _args;						\
    _frame->content = _content || "";					\
    DO_IF_RXML_OBJ_DEBUG (_frame->__object_marker->create (_frame));	\
    DO_IF_DEBUG(							\
      if (_args && ([mapping] (mixed) _args)["_debug_"]) {		\
	_frame->flags |= FLAG_DEBUG;					\
	m_delete (_args, "_debug_");					\
      }									\
    );									\
  } while (0)

#define EVAL_FRAME(_frame, _ctx, _parser, _type, _res)			\
  do {									\
    EVAL_ARGS_FUNC argfunc = 0;						\
    int orig_state_updated = _ctx->state_updated;			\
    if (mixed err = catch {						\
      _res = _frame->_eval (_ctx, _parser, _type);			\
      if (PCode p_code = _parser->p_code)				\
	p_code->add_frame (_ctx, _frame, _res, 1);			\
    })									\
      if (objectp (err) && ([object] err)->thrown_at_unwind) {		\
	UNWIND_STATE ustate = _ctx->unwind_state;			\
	if (!ustate) ustate = _ctx->unwind_state = ([]);		\
	DO_IF_DEBUG (							\
	  if (err != _frame)						\
	    fatal_error ("Unexpected unwind object catched.\n");	\
	  if (ustate[_parser])						\
	    fatal_error ("Clobbering unwind state for parser.\n");	\
	);								\
	ustate[_parser] = ({_frame});					\
	throw (_parser);						\
      }									\
      else {								\
	if (PCode p_code = _parser->p_code) {				\
	  PCODE_UPDATE_MSG (						\
	    "%O (frame %O): Restoring p-code update count "		\
	    "from %d to %d since the frame is stored unevaluated "	\
	    "due to exception.\n",					\
	    _ctx, _frame, _ctx->state_updated, orig_state_updated);	\
	  _ctx->state_updated = orig_state_updated;			\
	  p_code->add_frame (_ctx, _frame, PCode, 1);			\
	}								\
	ctx->handle_exception (						\
	  err, _parser); /* Will rethrow unknown errors. */		\
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
    MAKE_FRAME (frame, ctx, parser, args, content);
    if (object_variablep(frame, "raw_tag_text"))
      frame->raw_tag_text = parser->raw_tag_text();
    mixed result;
    EVAL_FRAME (frame, ctx, parser, parser->type, result);
    return result;
  }

  final array _p_xml_handle_tag (object/*(PXml)*/ parser, mapping(string:string) args,
				 void|string content)
  {
    Type type = parser->type;
    parser->drain_output();
    Context ctx = parser->context;
    object/*(Frame)HMM*/ frame;
    MAKE_FRAME (frame, ctx, parser, args, content);
    if (object_variablep (frame, "raw_tag_text"))
      frame->raw_tag_text = parser->current_input();
    mixed result;
    EVAL_FRAME (frame, ctx, parser, type, result);
    if (result != nil && result != empty) parser->add_value (result);
    return ({});
  }

  final array _p_xml_handle_pi_tag (object/*(PXml)*/ parser, string content)
  {
    Type type = parser->type;
    parser->drain_output();

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
    MAKE_FRAME (frame, ctx, parser, 0, content);
    if (object_variablep (frame, "raw_tag_text"))
      frame->raw_tag_text = parser->current_input();
    mixed result;
    EVAL_FRAME (frame, ctx, parser, type, result);
    if (result != nil && result != empty) parser->add_value (result);
    return ({});
  }

  mapping(string:mixed) _eval_splice_args (Context ctx,
					   mapping(string:string) raw_args,
					   mapping(string:Type) my_req_args)
  // Used from Frame._prepare for evaluating the dynamic arguments in
  // the splice argument. Destructive on raw_args.
  {
    // Note: Approximate code duplication in eval_args and Frame._prepare.
    mapping(string:Type) atypes =
      raw_args & (req_arg_types | opt_arg_types);
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
      foreach (raw_args; string arg; string val) {
	Type t = atypes[arg] || def_arg_type;
	if (t->parser_prog != PNone) {
	  Parser parser = t->get_parser (ctx, ctx->tag_set, 0);
	  TAG_DEBUG (RXML_CONTEXT->frame,
		     "Evaluating argument value %s with %O\n",
		     format_short (val), parser);

	  parser->finish (val); // Should not unwind.
	  mixed v = parser->eval(); // Should not unwind.
	  t->give_back (parser, ctx->tag_set);

	  if (v == nil)
	    set_nil_arg (raw_args, arg, t, req_arg_types, ctx->id);
	  else
	    raw_args[arg] = v;

	  TAG_DEBUG (RXML_CONTEXT->frame,
		     "Setting dynamic argument %s to %s\n",
		     format_short (arg), format_short (val));
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

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (void|int flag)
  {
    return flag == 'O' &&
      ((function_name (object_program (this)) || "RXML.Tag") +
       "(" + [string] this->name +
       (this->plugin_name ? "#" + [string] this->plugin_name : "") +
       ([int] this->flags & FLAG_PROC_INSTR ? " [PI]" : "") + ")" +
       OBJ_COUNT);
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
  constant is_RXML_TagSet = 1;

  RoxenModule|Configuration owner;
  //! The owner of this tag set, or zero if the tag set is globally
  //! shared. The owner is typically the Roxen module that created the
  //! tag set, but it can also be the @[Configuration] object for some
  //! special tag sets that don't belong to any module.

  string name;
  //! Unique identification string among all with the same @[owner].
  //! It may also be zero, in which case the tag set is nameless.
  //! Nameless tag sets cannot be encoded by @[RXML.p_code_to_string],
  //! with the exception when they only contain imported tag sets.
  //!
  //! If set, the name must be stable across server restarts since
  //! it's used to identify tag sets in dumped p-code. The name may
  //! contain the characters "!", "#", "(", ")", ",", "-", ".", "/",
  //! ":", ";", "<", "=", ">", "?", "@@", "_", and any alphanumeric
  //! character.
  //!
  //! @note
  //! The module tag set for Roxen parser modules has the name "", so
  //! you should not use that if you create more tag sets in such a
  //! module.

  //! @decl string prefix;
  //!
  //! A namespace prefix that may precede the tags. If it's zero, it's
  //! up to the importing tag set(s). A @tt{:@} is always inserted
  //! between the prefix and the tag name.
  //!
  //! @note
  //! This namespace scheme is not compliant with the XML namespaces
  //! standard. Since the intention is to implement XML namespaces at
  //! some point, this way of specifying tag prefixes will probably
  //! change.

  //! @decl int prefix_req;
  //!
  //! The prefix must precede the tags.

  array(TagSet) imported = ({});
  //! Other tag sets that will be used. The precedence is local tags
  //! first, then imported from left to right. It's not safe to
  //! destructively change entries in this array.
  //!
  //! @note
  //! The return value from @[get_hash] depends on the exact order in
  //! this array. So even if the order isn't important for tag
  //! overriding it should not be random in any way, or else
  //! @[get_hash] won't return stable values. That would in turn make
  //! decoding with @[RXML.string_to_p_code] fail almost always.

  function(Context:void) prepare_context;
  //! If set, this is a function that will be called before a new
  //! @[RXML.Context] object is taken into use. It'll typically
  //! prepare predefined scopes and variables. The callbacks in
  //! imported tag sets will be called in order of precedence; highest
  //! last.

  //! @decl function(Context:void) eval_finish;
  //! If set, this will be called just before an evaluation of the
  //! given @[RXML.Context] finishes. The callbacks in imported tag
  //! sets will be called in order of precedence; highest last.

  int generation = 1;
  //! A number that is increased every time something changes in this
  //! object or in some tag set it imports.

  int id_number;
  //! Unique number identifying this tag set.

  protected void create (RoxenModule|Configuration owner_, string name_,
			 void|array(Tag) _tags)
  //! @[owner_] and @[name_] initializes @[owner] and @[name],
  //! respectively. They are used to identify the tag set and its tags
  //! when p-code is created and stored on disk.
  //!
  //! @[owner_] is the object that "owns" this tag set and is
  //! typically the @[RoxenModule] object that created it. It can also
  //! be a @[Configuration] object or zero; see @[owner] for more
  //! details.
  //!
  //! @[name_] identifies the tag set uniquely among those owned by
  //! @[owner_]. Note that the empty string is already used for the
  //! main tag set in Roxen tag modules. See @[name]
  //!
  //! @example
  //! A tag set for local or additional tags within an RXML tag in a
  //! Roxen tag module is typically created like this:
  //!
  //! @code
  //!   RXML.TagSet internal =
  //!     RXML.TagSet(this_module(), "my-tag",
  //!   	      ({MySubTag1(), MySubTag2(), ...}));
  //! @endcode
  //!
  //! "my-tag" is the name of the tag that contains the subtags. It's
  //! typically a good idea to use the name of that tag, since it
  //! always is stable enough and unique within the tag set.
  //!
  //! Note that creating a tag set at runtime when a @[Frame] is
  //! created doesn't work with p-code generation. If you think you
  //! need to do that then you should probably take a look at
  //! @[Frame.parent_frame] instead.
  {
    if (RXML_CONTEXT &&
	(!RXML_CONTEXT->id ||
	 !RXML_CONTEXT->id->misc->disable_tag_set_creation_warning)) {
      report_debug (
	"Warning: Tag set %O in %O created during RXML evaluation.\n"
	"This doesn't work with p-code generation and should be avoided.\n",
	name_, owner_);
#ifdef MODULE_DEBUG
      array bt = backtrace();
      report_debug (describe_backtrace (bt/*[sizeof (bt) - 6..]*/));
#endif
    }

    // Note: Some code duplication wrt CompositeTagSet.create.
    id_number = ++tag_set_count;
    if (name_) {
      Thread.MutexKey key = all_tag_sets_mutex->lock (2);
      // Allow recursive locking since we don't touch any other
      // locks in here.
      set_name (owner_, name_);
      key = 0;
    }
    else owner = owner_;
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
    tag->tagset = this_object();
#ifdef RXML_OBJ_DEBUG
    // The object marker might not have gotten the proper name from
    // Tag._sprintf so try to give it a better string now.
    tag->__object_marker->create (tag);
#endif
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
      tag->tagset = this_object();
#ifdef RXML_OBJ_DEBUG
      // The object marker might not have gotten the proper name from
      // Tag._sprintf so try to give it a better string now.
      tag->__object_marker->create (tag);
#endif
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

  void clear()
  //! Removes all registered tags, processing instructions and string
  //! entities.
  {
    tags = ([]), proc_instrs = 0;
    clear_string_entities();	// Calls changed().
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

  local string get_hash()
  //! Returns a hash string built from all the tags and imported tag
  //! sets. It's suitable for use in persistent data to detect whether
  //! the tag set has changed in any way that would cause different
  //! tags to be parsed, or if they would be bound to different tag
  //! definitions.
  //!
  //! @note
  //! In the nonpersistent case it's much more efficient to use
  //! @[generation] to track changes in the tag set.
  {
    if (!hash)
      hash = Crypto.MD5.hash (encode_value_canonic (get_hash_data()));
    return hash;
  }

  local void add_tag_set_dependency (TagSet tset)
  //! Makes this tag set depend on @[tset], so that any change in it
  //! invalidates this tag set and affects the hash returned by
  //! @[get_hash].
  //!
  //! This kind of dependency normally exists on the imported tag
  //! sets, but this function lets you add a dependency without
  //! getting the tags imported. It's typically useful to get proper
  //! dependencies on tag sets that contain local or runtime tags.
  {
    dep_tag_sets[tset] = 1;
    tset->do_notify (changed);
    changed();
  }

  local void remove_tag_set_dependency (TagSet tset)
  //! Removes a dependency added by @[add_tag_set_dependency].
  {
    dep_tag_sets[tset] = 0;
    tset->dont_notify (changed);
  }

  local int has_effective_tags (TagSet tset)
  //! This one deserves some explanation.
  {
    return tset == top_tag_set && !got_local_tags;
  }

  local mixed `->= (string var, mixed val)
  {
    switch (var) {
      case "owner": {
	Thread.MutexKey key = all_tag_sets_mutex->lock (2);
	// Allow recursive locking since we don't touch any other
	// locks in here.
	if (name) SET_TAG_SET (owner, name, generation);
	set_name (val, name);
	break;
      }
      case "name": {
	Thread.MutexKey key = all_tag_sets_mutex->lock (2);
	// Allow recursive locking since we don't touch any other
	// locks in here.
	if (name) SET_TAG_SET (owner, name, generation);
	set_name (owner, val);
	break;
      }
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

  final Context new_context (void|RequestID id)
  //! Creates and initializes a new context for use with a parser or
  //! @[RXML.PCode] object based on this tag set. @[id] is put into
  //! the context if given. Normally you'd rather use @[get_parser] or
  //! @[RXML.PCode.new_context] instead of this function.
  {
    Context ctx = Context (this_object(), id);
    call_prepare_funs (ctx);
    return ctx;
  }

  final Parser get_parser (Type top_level_type, void|RequestID id, void|int make_p_code)
  //! Creates a new context for parsing content of the specified type,
  //! and returns the parser object for it. @[id] is put into the
  //! context. The parser will collect an @[RXML.PCode] object if
  //! @[make_p_code] is nonzero.
  {
    // Soft cast due to circular forward reference.
    // Will hopefully be resolved with the next generation compiler.
    return [object(Parser)](mixed)
      new_context (id)->new_parser (top_level_type, make_p_code);
  }

  final Parser `() (Type top_level_type, void|RequestID id, void|int make_p_code)
  //! For compatibility. Use @[get_parser] instead.
  {
    return get_parser (top_level_type, id, make_p_code);
  }

  void changed()
  //! Should be called whenever something is changed. Done
  //! automatically most of the time, however.
  {
#ifdef TAGSET_GENERATION_DEBUG
    werror ("%O update, generation %d -> %d\n", this_object(),
	    generation, generation + 1);
#endif
    generation++;
    prepare_funs = 0;
    overridden_tag_lookup = 0;
    plugins = pi_plugins = 0;
    hash = 0;
    (notify_funcs -= ({0}))();
    set_weak_flag (notify_funcs, 1);
    got_local_tags = sizeof (tags) || (proc_instrs && sizeof (proc_instrs));
#ifdef TAGSET_GENERATION_DEBUG
    werror ("%O update done, generation %d -> %d\n", this_object(),
	    generation - 1, generation);
#endif
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

  // Internals:

  // We assume these objects always are globally referenced.
  constant pike_cycle_depth = 0;

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

  array(TagSet) tag_set_components()
  // If this is a composite tag set importing exactly two other tag
  // sets and nothing else, those two are returned. Used by the codec
  // to encode tag sets produced by GET_COMPOSITE_TAG_SET.
  {
    return !sizeof (tags) && !proc_instrs && !string_entities &&
      sizeof (imported) == 2 && imported;
  }

  protected void destroy()
  {
    catch (changed());
    if (name && global::this) SET_TAG_SET (owner, name, generation);
  }

  protected void set_name (Configuration new_owner, string new_name)
  // Note: Assumes all_tag_sets_mutex is locked already.
  {
    if (new_name) {
      object(TagSet)|int old_tag_set = LOOKUP_TAG_SET (owner, name);
      if (objectp (old_tag_set)) {
	// It'd be nice if we could warn about duplicate tag sets with
	// the same name here, but unfortunately that doesn't work
	// well enough: Local tag sets from old module instances might
	// still be around with references from cached frames in stale
	// p-code.
	old_tag_set = old_tag_set->generation;
      }
      if (generation <= old_tag_set) generation = old_tag_set;
      owner = new_owner;
      name = new_name;
      SET_TAG_SET (owner, name, this_object());
    }
    else {
      owner = new_owner;
      name = 0;
    }
  }

  protected mapping(string:Tag) tags = ([]), proc_instrs;
  // Static since we want to track changes in these.

  protected mapping(string:string) string_entities;
  // Used by e.g. PXml to hold normal entities that should be replaced
  // during parsing.

  protected TagSet top_tag_set;
  // The imported tag set with the highest priority.

  protected int got_local_tags;
  // Nonzero if there are local element tags or PI tags.

  protected array(function(:void)) notify_funcs = ({});
  // Weak (when nonempty).

  protected array(function(Context:void)) prepare_funs;

  protected multiset(TagSet) dep_tag_sets = set_weak_flag ((<>), 1);

  /*protected*/ array(function(Context:void)) get_prepare_funs()
  {
    if (prepare_funs) return prepare_funs;
    array(function(Context:void)) funs = ({});
    for (int i = sizeof (imported) - 1; i >= 0; i--)
      funs += imported[i]->get_prepare_funs();
    if (prepare_context) funs += ({prepare_context});
    // We don't cache in prepare_funs; do that only at the top level.
    return funs;
  }

  final void call_prepare_funs (Context ctx)
  {
    if (!prepare_funs) prepare_funs = get_prepare_funs();
    (prepare_funs -= ({0})) (ctx);
  }

  protected array(function(Context:void)) eval_finish_funs;

  /*protected*/ array(function(Context:void)) get_eval_finish_funs()
  {
    if (eval_finish_funs) return eval_finish_funs;
    array(function(Context:void)) funs = ({});
    for (int i = sizeof (imported) - 1; i >= 0; i--)
      funs += imported[i]->get_eval_finish_funs();
    if (this->eval_finish) funs += ({this->eval_finish});
    // We don't cache in eval_finish_funs; do that only at the top level.
    return funs;
  }

  void call_eval_finish_funs (Context ctx)
  {
    if (!eval_finish_funs) eval_finish_funs = get_eval_finish_funs();
    (eval_finish_funs -= ({0})) (ctx);
  }

  protected mapping(Tag:Tag) overridden_tag_lookup;

  /*protected*/ Tag find_overridden_tag (Tag overrider, string overrider_name)
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

  /*protected*/ Tag find_overridden_proc_instr (Tag overrider,
						string overrider_name)
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

  protected mapping(string:mapping(string:Tag)) plugins, pi_plugins;

  /*protected*/ void low_get_plugins (string prefix, mapping(string:Tag) res)
  {
    for (int i = sizeof (imported) - 1; i >= 0; i--)
      imported[i]->low_get_plugins (prefix, res);
    foreach (tags; string name; Tag tag)
      if (has_prefix (name, prefix))
	if (tag->plugin_name) res[[string] tag->plugin_name] = tag;
    // We don't cache in plugins; do that only at the top level.
  }

  /*protected*/ void low_get_pi_plugins (string prefix, mapping(string:Tag) res)
  {
    for (int i = sizeof (imported) - 1; i >= 0; i--)
      imported[i]->low_get_pi_plugins (prefix, res);
    if (proc_instrs)
      foreach (proc_instrs; string name; Tag tag)
	if (name[..sizeof (prefix) - 1] == prefix)
	  if (tag->plugin_name) res[[string] tag->plugin_name] = tag;
    // We don't cache in pi_plugins; do that only at the top level.
  }

  protected string hash;

  /*protected*/ array get_hash_data()
  {
    return ({
      this_object()->prefix,
      this_object()->prefix_req,
      mkmultiset (indices (tags)),
      proc_instrs && mkmultiset (indices (proc_instrs)),
      string_entities,
    }) + imported->get_hash_data() +
      ({0}) + (indices (dep_tag_sets) - ({0}))->get_hash_data();
  }

  /*protected*/ string tag_set_component_names()
  {
    return name || sizeof (imported) && imported->tag_set_component_names() * "+";
  }

  string _sprintf (void|int flag)
  {
    if (flag != 'O') return 0;
    return (function_name (object_program (this)) || "RXML.TagSet") +
      "(" +
      // No, the owner isn't written unambiguously; we try to be brief here.
      (string) (owner && (owner->is_module ?
			  owner->module_local_id() :
			  owner->name)) +
      "," + tag_set_component_names() + ")" + OBJ_COUNT;
    //return "RXML.TagSet(" + id_number + ")" + OBJ_COUNT;
  }

  //! @ignore
  MARK_OBJECT_ONLY;
  //! @endignore
}

TagSet empty_tag_set;
//! The empty tag set.

TagSet shared_tag_set (RoxenModule|Configuration owner, string name, void|array(Tag) tags)
//! If a tag set with the given owner and name exists, it's returned.
//! Otherwise a new tag set is created with them. @[tags] is passed
//! along to its @[RXML.TagSet.create] function in that case. Note
//! that @[owner] may be zero to get a tag set that is global.
{
  Thread.MutexKey key = all_tag_sets_mutex->lock();
  if (TagSet tag_set = LOOKUP_TAG_SET (owner, name))
    if (objectp (tag_set))
      return tag_set;
  return TagSet (owner, name, tags);
}

protected class CompositeTagSet
{
  inherit TagSet;

  protected void create (TagSet... tag_sets)
  {
    // Note: Some code duplication wrt TagSet.create.
    id_number = ++tag_set_count;
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
    // Make sure TagSet::`-> gets called.
    this->imported = tag_sets;
  }

  string _sprintf (void|int flag)
  {
    if (flag != 'O') return 0;
    return "RXML.CompositeTagSet(" + tag_set_component_names() + ")" +
      OBJ_COUNT;
    //return "RXML.TagSet(" + id_number + ")" + OBJ_COUNT;
  }
}

protected mapping(int|string:CompositeTagSet) garb_composite_tag_set_cache()
{
  call_out (garb_composite_tag_set_cache, 30*60);
  return composite_tag_set_cache = ([]);
}

protected mapping(int|string:CompositeTagSet) composite_tag_set_cache =
  garb_composite_tag_set_cache();

#define GET_COMPOSITE_TAG_SET(a, b, res) do {				\
  int|string hash = HASH_INT2 (b->id_number, a->id_number);		\
  if (!(res = composite_tag_set_cache[hash]))				\
    /* Race, but it doesn't matter. */					\
    res = composite_tag_set_cache[hash] = CompositeTagSet (a, b);	\
} while (0)


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
  //! If an object with an @[rmxl_var_eval] function is returned, then
  //! that function is called in turn to produce the real value. As a
  //! special case, if @[rxml_var_eval] returns this object, the
  //! object itself is used as value.
  //!
  //! If the @[type] argument is given, it's the type the returned
  //! value should have. If the value can't be converted to that type,
  //! an RXML error should be thrown. If you don't want to do any
  //! special handling of this, it's enough to call
  //! @expr{@[type]->encode(value)@}, since the encode functions does
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
  //! @code
  //!   return type && type != RXML.t_text ?
  //!          type->encode (my_string, RXML.t_text) : my_string;
  //! @endcode
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
    mixed val = rxml_const_eval (ctx, var, scope_name);
    // We replace the variable object with the evaluated value when
    // rxml_const_eval is used. However, we hide
    // ctx->misc->recorded_changes so that the setting isn't cached.
    // That since rxml_const_eval should work for values that only are
    // constant in the current request. Note that we can still
    // overcache the returned result; it's up to the user to avoid
    // that with suitable cache tags.
    array rec_chgs = ctx->misc->recorded_changes;
    ctx->misc->recorded_changes = 0;
    ctx->set_var(var, val, scope_name);
    ctx->misc->recorded_changes = rec_chgs;
    return type ? type->encode (val) : val;
  }

  mixed rxml_const_eval (Context ctx, string var, string scope_name);
  //! If the variable value is the same throughout the life of the
  //! context, this method can be used instead of @[rxml_var_eval] to
  //! only get a call the first time the value is evaluated.
  //!
  //! Note that this doesn't provide any control over the type
  //! conversion; this function should return a raw unquoted value,
  //! which will always be encoded with the current type when it's
  //! used.

  optional string format_rxml_backtrace_frame (
    Context ctx, string var, string scope_name);
  //! Define this to control how the variable reference is formatted
  //! in RXML backtraces. The returned string should be one line,
  //! without a trailing newline. It should not contain the " | "
  //! prefix.
  //!
  //! The empty string may be returned to suppress the backtrace frame
  //! altogether. That might be useful for some types of internally
  //! used variables, but it should be used only if there are very
  //! good reasons; the backtrace easily just becomes confusing
  //! instead.

  string _sprintf (void|int flag)
  {
    return flag == 'O' &&
      ((function_name (object_program (this)) || "RXML.Value") + "()");
  }
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

  void _m_delete (string var, void|Context ctx,
		  void|string scope_name, void|int from_m_delete)
  //! Called to delete a variable in the scope. @[var] is the name of
  //! it, @[ctx] and @[scope_name] are set to where this @[Scope]
  //! object was found. @[from_m_delete] is an internal kludge for 2.1
  //! compatibility; it should never be given a value.
  {
    if (!from_m_delete)
      m_delete (var, ctx, scope_name); // For compatibility with 2.1.
    else
      parse_error ("Cannot delete variable" + _in_the_scope (scope_name) + ".\n");
  }

  void m_delete (string var, void|Context ctx, void|string scope_name)
  // For compatibility with 2.1.
    {_m_delete (var, ctx, scope_name, 1);}

  optional Scope clone();
  //! Define this to allow cloning of the scope object. A scope object
  //! with the same state as this one should be returned. Any future
  //! variable changes in either object shouldn't affect the variables
  //! in the other one. If a scope implements read-only access it's ok
  //! to return the same object.

  optional string format_rxml_backtrace_frame (
    Context ctx, string var, string scope_name);
  //! Define this to control how the variable reference is formatted
  //! in RXML backtraces. The returned string should be one line,
  //! without a trailing newline. It should not contain the " | "
  //! prefix.
  //!
  //! The empty string may be returned to suppress the backtrace frame
  //! altogether. That might be useful for some types of internally
  //! used variables, but it should be used only if there are very
  //! good reasons; the backtrace easily just becomes confusing
  //! instead.

  private string _in_the_scope (string scope_name)
  {
    if (scope_name)
      if (scope_name != "_") return " in the scope " + scope_name;
      else return " in the current scope";
    else return "";
  }

  string _sprintf (void|int flag)
  {
    return flag == 'O' &&
      ((function_name (object_program (this)) || "RXML.Scope") + "()");
  }
}

mapping(string:mixed) scope_to_mapping (SCOPE_TYPE scope,
					void|Context ctx,
					void|string scope_name)
//! Converts an RXML scope (in the form of a mapping or an object) to
//! a mapping. If @[scope] is a mapping, a shallow copy is returned.
//! If @[scope] is an object, every variable in it is queried to
//! produce the mapping. An error is thrown if the scope can't be
//! listed.
//!
//! The optional @[ctx] and @[scope_name] are passed on to the
//! @[RXML.Scope] object functions.
{
  if (mappingp (scope))
    return scope + ([]);

  mapping(string:mixed) res = ([]);
  foreach (scope->_indices (ctx, scope_name), string var) {
    mixed val = scope->`[] (var, ctx, scope_name);
    if (!zero_type (val) && val != nil) res[var] = val;
  }
  return res;
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
  //! Current evaluation recursion depth. This might be more than the
  //! number of frames in the @[frame] linked chain.

  constant max_frame_depth = 100;
  //! Maximum allowed evaluation recursion depth.

  RequestID id;
  //!

  mapping(mixed:mixed) misc = ([]);
  //! Various context info, typically internal stuff that shouldn't be
  //! directly accessible by the user in some scope. This is typically
  //! the same mapping as @tt{id->misc->defines@}. To avoid accidental
  //! namespace conflicts in this mapping, it's suggested that the
  //! module/tag program or object is used as index in it.
  //!
  //! Note however that the indices and values in this mapping
  //! sometimes might need to be encoded by @[RXML.p_code_to_string],
  //! so use some object to which it can properly encode references
  //! (preferably @[RXML.Tag], @[RXML.TagSet], and Roxen module
  //! objects).

  int type_check;
  // Whether to do type checking. FIXME: Not fully implemented.

  int error_count;
  //! Number of RXML errors that has occurred. If this is nonzero, the
  //! result of the evaluation shouldn't be trusted, but it might be
  //! wise to return it to the user anyway, as it can contain error
  //! reports (see @[Parser.recover_errors] and @[FLAG_DONT_RECOVER]
  //! for further details about error reporting).

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

  void state_update()
  //! Should be called whenever the persistent state changes. For tag
  //! implementors that means whenever the value that
  //! @[RXML.Frame.save] would return changes.
  {
    PCODE_UPDATE_MSG ("%O: P-code update to %d by request from %s",
		      this_object(), state_updated + 1,
		      describe_backtrace (backtrace()[<1..<1]));
    state_updated++;
  }

  array(string|int) parse_user_var (string var, void|string|int scope_name)
  //! Parses the var string for scope and/or subindexes according to
  //! the RXML rules, e.g. @tt{"scope.var.1.foo"@}. Returns an array
  //! where the first entry is the scope, and the remaining entries
  //! are the list of indexes. If @[scope_name] is a string, it's used
  //! as the scope and the var string is only used for subindexes. A
  //! default scope is chosen as appropriate if var cannot be split,
  //! unless @[scope_name] is a nonzero integer in which case it's
  //! returned in the scope position in the array (useful to detect
  //! whether @[var] actually was split or not).
  //!
  //! @tt{".."@} in the var string quotes a literal @tt{"."@}, e.g.
  //! @tt{"yow...cons..yet"@} is separated into @tt{"yow."@} and
  //! @tt{"cons.yet"@}. Any subindex that can be parsed as a signed
  //! integer is converted to it. Note that it doesn't happen for the
  //! first index, since a variable name in a scope always is a string.
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
  //! current scope if none is given. If @[val] is @[RXML.nil] then
  //! the variable is removed instead (see @[delete_var]). Returns
  //! @[val].
  //!
  //! If @[var] is an array, it's used to successively index the value
  //! to get subvalues (see @[rxml_index] for details).
  {
    if (val == nil) {
      delete_var (var, scope_name);
      return nil;
    }

#ifdef MODULE_DEBUG
    if (arrayp (var) ? !sizeof (var) : !stringp (var))
      fatal_error ("Invalid variable specifier.\n");
#endif

    if (!scope_name) scope_name = "_";
    if (SCOPE_TYPE vars = scopes[scope_name]) {
      string|int index;

    record_change: {
	if (arrayp (var))
	  if (sizeof (var) > 1) {
	    if (array rec_chgs = misc->recorded_changes)
	      if (rec_chgs[-1][encode_value_canonic (({scope_name}))])
		// The scope is added in the same entry. Since we
		// can't do subindexing reliably in it we have to add
		// another entry to ensure correct sequence. C.f.
		// delete_var and VariableChange.add.
		misc->recorded_changes +=
		  ({([encode_value_canonic (({scope_name}) + var): val])});
	      else
		rec_chgs[-1][encode_value_canonic (({scope_name}) + var)] = val;

	    array(string|int) path = var[..sizeof (var) - 2];
	    vars = rxml_index (vars, path, scope_name, this_object());
	    scope_name += "." + (array(string)) path * ".";
	    index = var[-1];
	    break record_change;
	  }
	  else
	    index = var[0];
	else
	  index = var;

	if (array rec_chgs = misc->recorded_changes)
	  if (SCOPE_TYPE scope = rec_chgs[-1][encode_value_canonic (({scope_name}))])
	    // The scope is added in the same entry so we modify it
	    // with the new variable setting. This is done not only as
	    // an optimization but also to ensure that VariableChange
	    // doesn't try to set the variable before the scope is
	    // installed. C.f. delete_var and VariableChange.add.
	    scope[index] = val;
	  else
	    rec_chgs[-1][encode_value_canonic (({scope_name, index}))] = val;
      }

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
	  parse_error( "Cannot index the array in %s with %s.\n",
		       scope_name, format_short (index) );
      else
	parse_error ("%s is %s which cannot be indexed with %s.\n",
		     scope_name, format_short (vars), format_short (index));
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

    record_change: {
	if (arrayp (var))
	  if (sizeof (var) > 1) {
	    if (array rec_chgs = misc->recorded_changes)
	      if (rec_chgs[-1][encode_value_canonic (({scope_name}))])
		// The scope is added in the same entry. Since we
		// can't do subindexing reliably in it we have to add
		// another entry to ensure correct sequence. C.f.
		// set_var and VariableChange.add.
		misc->recorded_changes +=
		  ({([encode_value_canonic (({scope_name}) + var): nil])});
	      else
		rec_chgs[-1][encode_value_canonic (({scope_name}) + var)] = nil;

	    array(string|int) path = var[..sizeof (var) - 2];
	    vars = rxml_index (vars, path, scope_name, this_object());
	    scope_name += "." + (array(string)) path * ".";
	    var = var[-1];
	    break record_change;
	  }
	  else
	    var = var[0];

	if (array rec_chgs = misc->recorded_changes)
	  if (SCOPE_TYPE scope = rec_chgs[-1][encode_value_canonic (({scope_name}))])
	    // The scope is added in the same entry so we modify it to
	    // delete the variable. This is done not only as an
	    // optimization but also to ensure that VariableChange
	    // doesn't try to set the variable before the scope is
	    // installed. C.f. set_var and VariableChange.add.
	    m_delete (scope, var);
	  else
	    rec_chgs[-1][encode_value_canonic (({scope_name, var}))] = nil;
      }

      if (objectp (vars) && vars->_m_delete)
	([object(Scope)] vars)->_m_delete (var, this_object(), scope_name);
      else if (mappingp (vars))
	m_delete ([mapping(string:mixed)] vars, var);
      else if (multisetp (vars))
	vars[var] = 0;
      else
	parse_error ("Cannot remove the index %s from the %t in %s.\n",
		     format_short (var), vars, scope_name);
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

  array(string) list_var (void|string scope_name, void|int check_nil)
  //! Returns the names of all variables in the specified scope, or
  //! the current scope if none is given.
  //!
  //! Variables with the value @[RXML.nil] or @[UNDEFINED] should not
  //! occur (since those values by definition indicates that the
  //! variable doesn't exist). This function doesn't check for this by
  //! default, but that can be enabled with the @[check_nil] flag.
  {
    if (SCOPE_TYPE vars = scopes[scope_name || "_"]) {
      array(string) res;
      if (objectp (vars))
	res = ([object(Scope)] vars)->_indices (this_object(),
						scope_name || "_");
      else
	res = indices ([mapping(string:mixed)] vars);
      if (check_nil)
	res = filter (res, lambda (string var) {
			     mixed val = vars[var];
			     if (objectp (val) && ([object] val)->rxml_var_eval)
			       val = ([object(Value)] val)->rxml_var_eval (
				 this, var, scope_name, 0);
			     return val != nil && !zero_type (val);
			   });
      return res;
    }
    else if ((<0, "_">)[scope_name]) parse_error ("No current scope.\n");
    else parse_error ("Unknown scope %O.\n", scope_name);
  }

  array(string) list_scopes (void|int list_hidden)
  //! Returns the names of all defined scopes. If @[list_hidden] is
  //! nonzero then internal scopes are also returned.
  {
    if (list_hidden)
      return indices (scopes) - ({"_"});
    else
      return indices (scopes) - ({"_", "_internal_"});
  }

  int exist_scope (void|string scope_name)
  //!
  {
    return !!scopes[scope_name || "_"];
  }

#define CLEANUP_VAR_CHG_SCOPE(var_chg, scope_name) do {			\
    foreach (var_chg; mixed encoded_var;)				\
      if (stringp (encoded_var)) {					\
	mixed var = decode_value (encoded_var);				\
	if (arrayp (var) && var[0] == scope_name)			\
	  m_delete (var_chg, encoded_var);				\
      }									\
  } while (0)

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

    if (array rec_chgs = misc->recorded_changes) {
      CLEANUP_VAR_CHG_SCOPE (rec_chgs[-1], scope_name);
      rec_chgs[-1][encode_value_canonic (({scope_name}))] =
	mappingp (vars) ? vars + ([]) : vars;
    }
  }

  void extend_scope (string scope_name, SCOPE_TYPE vars)
  //! If there is a scope with the name @[scope_name] at the global
  //! level then it is extended with @[vars]. If there is no such
  //! scope then @[vars] becomes a global scope with the name
  //! @[scope_name] (without copying it).
  //!
  //! @note
  //! The contents of @[vars] is currently transferred over to the
  //! existing scope object, if there is any. That's usually not an
  //! issue if the scopes are mappings, but can be if @[vars] is an
  //! @[RXML.Scope] object, or the existing scope is such an object
  //! that doesn't handle assignments.
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
      if (objectp (vars))
	foreach (([object(Scope)] vars)->_indices (this_object(),
						   scope_name || "_"),
		 string var)
	  set_var(var, vars[var], scope_name);
      else
	foreach (vars; string var; mixed val)
	  set_var(var, val, scope_name);
    }

    else {
      scopes[scope_name] = vars;

      if (array rec_chgs = misc->recorded_changes) {
	CLEANUP_VAR_CHG_SCOPE (rec_chgs[-1], scope_name);
	rec_chgs[-1][encode_value_canonic (({scope_name}))] =
	  mappingp (vars) ? vars + ([]) : vars;
      }
    }
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

    if (array rec_chgs = misc->recorded_changes) {
      CLEANUP_VAR_CHG_SCOPE (rec_chgs[-1], scope_name);
      rec_chgs[-1][encode_value_canonic (({scope_name}))] = 0;
    }
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

  SCOPE_TYPE get_scope (string scope_name)
  //! Returns the scope mapping/object for the given scope.
  {
    return scopes[scope_name];
  }

  void set_misc (mixed index, mixed value)
  //! Sets an index:value pair in @[misc]. The given index is removed
  //! from @[misc] if @[value] is @[RXML.nil].
  //!
  //! This function also records the setting if p-code is being result
  //! compiled, so that the setting is remade when the cached p-code
  //! result is reevaluated (see @[RXML.FLAG_DONT_CACHE_RESULT]). It
  //! should therefore be used whenever a tag that doesn't use
  //! @[RXML.FLAG_DONT_CACHE_RESULT] sets a value in @[misc] to be
  //! used by some other tag or variable later in the evaluation. In
  //! other situations it's perfectly all right to access @[misc]
  //! directly.
  //!
  //! @note
  //! Neither @[index] nor @[value] is copied when stored in the
  //! cache. That means that you probably don't want to change them
  //! destructively, or else those changes can have propagated
  //! "backwards" when the cached p-code is used. Sometimes that
  //! propagation can be a useful feature, though.
  //!
  //! @note
  //! Use @[set_id_misc] or @[set_root_id_misc] instead of this if you
  //! want to access the stored value after the RXML evaluation has
  //! finished. There is compatibility code that tries to keep
  //! @tt{id->misc->defines@} around for a while afterwards, but it's
  //! not recommended to depend on it since there are circumstances
  //! when the mapping will get overridden.
  //!
  //! @note
  //! For compatibility reasons, changes of the _ok flag
  //! (@tt{@[misc][" _ok"]@}) are detected and saved automatically.
  //! Thus it is not necessary to call @[set_misc] to change it. This
  //! is a special case and does not apply to any other entry in
  //! @[misc].
  {
    if (value == nil) m_delete (misc, index);
    else misc[index] = value;
    if (array rec_chgs = misc->recorded_changes) {
      if (stringp (index)) index = encode_value_canonic (index);
      rec_chgs[-1][index] = value;
    }
  }

  void set_id_misc (mixed index, mixed value)
  //! Like @[set_misc], but sets a value in @[id->misc], which is
  //! useful if the value should be used by other code after the rxml
  //! evaluation.
  {
    if (value == nil) m_delete (id->misc, index);
    else id->misc[index] = value;
    if (array rec_chgs = misc->recorded_changes)
      rec_chgs[-1][encode_value_canonic (({1, index}))] = value;
  }

  void set_root_id_misc (mixed index, mixed value)
  //! Like @[set_id_misc], but sets a value in @[id->root_id->misc]
  //! instead. The difference is that the setting then is visible
  //! throughout the outermost request when the setting is made in an
  //! internal subrequest, e.g. through @[Configuration.try_get_file].
  {
    if (value == nil) m_delete (id->root_id->misc, index);
    else id->root_id->misc[index] = value;
    if (array rec_chgs = misc->recorded_changes)
      rec_chgs[-1][encode_value_canonic (({2, index}))] = value;
  }

  void add_p_code_callback (function|string callback, mixed... args)
  //! If result p-code is collected then a call to @[callback] with
  //! the given arguments is added to it, so that it will be called
  //! when the result p-code is reevaluated.
  //!
  //! If @[callback] is a string then it's taken to be the name of a
  //! function to call in the current @[id] object. The string can
  //! also contain "->" to build index chains. E.g. the string
  //! "misc->foo->bar" will cause a call to @[id]->misc->foo->bar()
  //! when the result p-code is evaluated.
  {
    if (misc->recorded_changes)
      // See PCode.low_process_recorded_changes for details.
      misc->recorded_changes += ({callback, args, ([])});
  }

  protected int last_internal_var_id = 0;

  string alloc_internal_var()
  //! Allocates and returns a unique variable name in the special
  //! scope "_internal_", creating that scope if necessary. After this
  //! it's safe to use that variable for internal purposes in tags
  //! with the normal variable functions. No other variables in the
  //! "_internal_" scope should be accessed.
  //!
  //! @note
  //! The "_internal_" scope is currently hidden by default by
  //! @[list_scope] but otherwise there are no access restrictions on
  //! it. Therefore an end user can get at the variables in that scope
  //! directly. On the other hand there's no guarantee that that will
  //! remain possible in the future, so no end user RXML code should
  //! use the "_internal_" scope.
  {
    if (!scopes->_internal_) add_scope ("_internal_", ([]));
    return (string) ++last_internal_var_id;
  }

  void signal_var_change (string var, void|string scope_name, void|mixed val)
  //! Call this when the variable @[var] in the specified scope has
  //! changed in some other way than by calling a function in this
  //! class. If necessary, this will register the variable and its
  //! current value in generated p-code (see @[set_misc] for further
  //! details). The current scope is used if @[scope_name] is left
  //! out. The caller can provide a overriding value which is needed when
  //! modifying e.g. the outgoing headers via extra_heads.
  {
    if (array rec_chgs = misc->recorded_changes) {
      if (!scope_name) scope_name = "_";
      rec_chgs[-1][encode_value_canonic (({scope_name, var}))] =
	zero_type (val) ? scopes[scope_name][var] : val;
    }
  }

  void add_runtime_tag (Tag tag)
  //! Adds a tag that will exist from this point forward in the
  //! current context only.
  {
#ifdef MODULE_DEBUG
    if (tag->plugin_name)
      fatal_error ("Cannot handle plugin tags added at runtime.\n");
#endif
    if (!new_runtime_tags) new_runtime_tags = NewRuntimeTags();
    if (array rec_chgs = misc->recorded_changes)
      rec_chgs[-1][encode_value_canonic (({0, tag->flags & FLAG_PROC_INSTR ?
					  "?" + tag->name : tag->name}))] = tag;
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
    if (objectp (tag)) {
      proc_instr = tag->flags & FLAG_PROC_INSTR;
      tag = tag->name;
    }
    if (array rec_chgs = misc->recorded_changes)
      rec_chgs[-1][encode_value_canonic (({0, proc_instr ? "?" + tag : tag}))] = 0;
    new_runtime_tags->remove_tag (tag, proc_instr);
  }

  multiset(Tag) get_runtime_tags()
  //! Returns all currently active runtime tags.
  {
    mapping(string:Tag) tags = runtime_tags;
    if (new_runtime_tags) tags = new_runtime_tags->filter_tags (tags);
    return mkmultiset (values (tags));
  }

  int incomplete_eval()
  //! Returns true if the last evaluation isn't complete, i.e. when
  //! this context is unwound due to use of streaming/nonblocking
  //! operation.
  {
    return unwind_state && unwind_state->reason == "streaming";
  }

  void handle_exception (mixed err, PCode|Parser evaluator, void|PCode p_code_error)
  //! This function gets any exception that is catched during
  //! evaluation. evaluator is the object that catched the error. If
  //! p_code_error is set, a CompiledError object will be added to it
  //! if the error was reported.
  {
    error_count++;

    if (objectp (err)) {
      if (err->is_RXML_break_eval) {
	if (err->action == "continue") {
	  TAG_DEBUG (RXML_CONTEXT->frame, "Continuing after RXML break exception\n");
	  return;
	}
	Context ctx = RXML_CONTEXT;
	if (ctx->frame) {
	  if (stringp (err->target) ? err->target == ctx->frame->scope_name :
	      err->target == ctx->frame)
	    err->action = "continue";
	}
	else
	  if (err->target) {
	    ctx->frame = err->cur_frame;
	    err = catch (parse_error ("There is no surrounding frame %s.\n",
				      stringp (err->target) ?
				      sprintf ("with scope %O", err->target) :
				      sprintf ("%O", err->target)));
	    ctx->frame = 0;
	    handle_exception (err, evaluator, p_code_error);
	  }
	TAG_DEBUG (RXML_CONTEXT->frame, "Rethrowing RXML break exception\n");
	throw (err);
      }

      else if (err->is_RXML_Backtrace) {
	if (evaluator->report_error && evaluator->recover_errors &&
	    evaluator->type->free_text) {
	  string msg;
	  if (tag_set && id && id->conf) {
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
	  if (evaluator->report_error (msg)) {
	    if (p_code_error) {
	      CompiledError comp_err = CompiledError (err);
	      p_code_error->add (RXML_CONTEXT, comp_err, comp_err);
	    }

	    if (!id || !id->conf || id->conf->compat_level() >= 5.0)
	      misc[" _ok"] = 0;

	    TAG_DEBUG (RXML_CONTEXT->frame,
		       "RXML exception %O reported - continuing\n", err);
	    return;
	  }
	}
	TAG_DEBUG (RXML_CONTEXT->frame,
		   "Rethrowing RXML exception %O\n", err);
	throw (err);
      }
    }

    throw_fatal (err);
  }

  final array(mixed|PCode) eval_and_compile (Type type, string to_parse,
					     void|int stale_safe,
					     void|TagSet tag_set_override)
  //! Parses and evaluates @[to_parse] with @[type] in this context.
  //! At the same time, p-code is collected for later reevaluation. An
  //! array is returned which contains the result in the first element
  //! and the generated @[RXML.PCode] object in the second. If
  //! @[stale_safe] is nonzero, the p-code object will be an instance
  //! of @[RXML.RenewablePCode] instead, which never fails due to
  //! being stale. The tag set defaults to @[tag_set], but it may be
  //! overridden with @[tag_set_override].
  {
    int orig_make_p_code = make_p_code, orig_state_updated = state_updated;
    int orig_top_frame_flags = frame && frame->flags;
    PCODE_UPDATE_MSG ("%O: Saved p-code update count %d before eval_and_compile\n",
		      this_object(), orig_state_updated);
    if (!tag_set_override) tag_set_override = tag_set;
    make_p_code = 1;
    Parser parser = type->get_parser (
      this_object(), tag_set_override, 0,
      stale_safe ?
      RenewablePCode (type, this_object(), tag_set) :
      PCode (type, this_object(), tag_set));

    mixed res;
    PCode p_code;
    mixed err = catch {
      parser->write_end (to_parse);
      res = parser->eval();
      p_code = parser->p_code;
      p_code->finish();
    };

    type->give_back (parser, tag_set_override);
    PCODE_UPDATE_MSG ("%O: Restoring p-code update count from %d to %d "
		      "after eval_and_compile\n",
		      this_object(), state_updated, orig_state_updated);
    make_p_code = orig_make_p_code, state_updated = orig_state_updated;
    if (frame)
      // The subevaluation might change the cache result control
      // flags, but they should be ignored since it's not the same
      // cache. These flags are set but never cleared, so we only need
      // to clear those that are cleared in orig_top_frame_flags.
      frame->flags &= orig_top_frame_flags |
	~(FLAG_DONT_CACHE_RESULT|FLAG_MAY_CACHE_RESULT);

    if (err) throw (err);
    return ({res, p_code});
  }

  // Internals:

  final Parser new_parser (Type top_level_type, void|int _make_p_code)
  // Returns a new parser object to start parsing with this context.
  // Normally TagSet.`() should be used instead of this.
  {
#ifdef MODULE_DEBUG
    if (in_use || frame) fatal_error ("Context already in use.\n");
#endif
    return top_level_type->get_parser (this_object(), tag_set, 0,
				       make_p_code = _make_p_code);
  }

#ifdef DEBUG
  private int eval_finished = 0;
#endif

  final void eval_finish (void|int dont_set_eval_status)
  // Called at the end of the evaluation in this context.
  {
    FRAME_DEPTH_MSG ("%*s%O eval_finish\n", frame_depth, "", this_object());
    if (!dont_set_eval_status) id->eval_status["rxmlsrc"] = 1;
    if (!frame_depth) {
#ifdef DEBUG
      if (eval_finished) fatal_error ("Context already finished.\n");
      eval_finished = 1;
#endif
      if (tag_set) tag_set->call_eval_finish_funs (this_object());
    }
  }

  mapping(string:SCOPE_TYPE) scopes = ([]);
  // The variable mappings for every currently visible scope. A
  // special entry "_" points to the current local scope.

  mapping(Frame:array(SCOPE_TYPE)) hidden = ([]);
  // The currently hidden scopes. The indices are frame objects which
  // introduce scopes. The values are tuples of the current scope and
  // the named scope they hide.

  void enter_scope (Frame|CacheStaticFrame frame, SCOPE_TYPE vars)
  {
    // Note that vars is zero when called from
    // CacheStaticFrame.EnterScope.get.
#ifdef DEBUG
    if (!vars && !frame->is_RXML_CacheStaticFrame)
      fatal_error ("Got no scope mapping.\n");
#endif

    array rec_chgs = misc->recorded_changes;
    if (rec_chgs)
      CLEANUP_VAR_CHG_SCOPE (rec_chgs[-1], "_");

    if (string scope_name = [string] frame->scope_name) {
      if (!hidden[frame])
	hidden[frame] = ({scopes["_"], scopes[scope_name]});
      scopes["_"] = scopes[scope_name] = vars;

      if (rec_chgs) {
	CLEANUP_VAR_CHG_SCOPE (rec_chgs[-1], scope_name);
	rec_chgs[-1][encode_value_canonic (({scope_name}))] =
	  rec_chgs[-1][encode_value_canonic (({"_"}))] =
	  mappingp (vars) ? vars + ([]) : vars;
      }
    }

    else {
      if (!hidden[frame])
	hidden[frame] = ({scopes["_"], 0});
      scopes["_"] = vars;

      if (rec_chgs)
	rec_chgs[-1][encode_value_canonic (({"_"}))] =
	  mappingp (vars) ? vars + ([]) : vars;
    }
  }

  void leave_scope (Frame|CacheStaticFrame frame)
  {
    if (array(SCOPE_TYPE) back = hidden[frame]) {
      if (array rec_chgs = misc->recorded_changes) {
	CLEANUP_VAR_CHG_SCOPE (rec_chgs[-1], "_");
	if (string scope_name = frame->scope_name)
	  CLEANUP_VAR_CHG_SCOPE (rec_chgs[-1], scope_name);
      }
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

#define ENTER_SCOPE(ctx, frame)						\
  (frame->vars &&							\
   (!ctx->hidden[frame] || frame->vars != ctx->scopes["_"]) &&		\
   ctx->enter_scope (frame, frame->vars))
#define LEAVE_SCOPE(ctx, frame) \
  (frame->vars && ctx->leave_scope (frame))

  mapping(string:Tag) runtime_tags = ([]);
  // The active runtime tags. PI tags are stored in the same mapping
  // with their names prefixed by '?'.

  void direct_add_runtime_tag (string name, Tag tag)
  {
    if (array rec_chgs = misc->recorded_changes)
      rec_chgs[-1][encode_value_canonic (({0, name}))] = tag;
    runtime_tags[name] = tag;
  }

  void direct_remove_runtime_tag (string name)
  {
    if (array rec_chgs = misc->recorded_changes)
      rec_chgs[-1][encode_value_canonic (({0, name}))] = 0;
    m_delete (runtime_tags, name);
  }

  NewRuntimeTags new_runtime_tags;
  // Used to record the result of any add_runtime_tag() and
  // remove_runtime_tag() calls since the last time the parsers ran.

  int make_p_code;
  // Nonzero if the parsers should compile along with the evaluation.

  int state_updated;
  // Nonzero if the persistent state of the evaluated rxml has
  // changed. Never negative.

  PCode evaled_p_code;
  // The p-code object of the innermost frame that collects evaled
  // content (i.e. got FLAG_GET_EVALED_CONTENT set).

  protected void create (void|TagSet _tag_set, void|RequestID _id)
  // Normally TagSet.`() should be used instead of this.
  {
    tag_set = _tag_set || empty_tag_set;
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
  // "reason": string (The reason why the state is unwound. Can
  //    currently be "streaming".)

  mapping id_defines;
  // Ugly kludge: The old id->misc->defines is stored here if it's
  // overridden by the misc mapping above. See
  // rxml_tag_set->prepare_context.

  //! @ignore
  MARK_OBJECT_ONLY;
  //! @endignore

  string _sprintf (int flag)
  {
    return flag == 'O' &&
      ((function_name (object_program (this)) || "RXML.Context") +
       "()" + OBJ_COUNT);
  }

#ifdef MODULE_DEBUG
#if constant (thread_create)
  Thread.Thread in_use;
#else
  int in_use;
#endif
#endif
}

/*protected*/ class CacheStaticFrame (string scope_name)
// This class is used when tracking local scopes in frames that have
// been optimized away by FLAG_IS_CACHE_STATIC. It contains the scope
// name and is used as the key for Context.enter_scope and
// Context.leave_scope.
//
// Can't be protected since encode_value must be able to index it.
{
  constant is_RXML_CacheStaticFrame = 1;
  constant is_RXML_encodable = 1;

  string _encode() {return scope_name;}
  void _decode (string data) {scope_name = data;}

  class EnterScope()
  {
    constant is_RXML_encodable = 1;
    constant is_RXML_p_code_entry = 1;
    constant is_csf_enter_scope = 1;
    constant p_code_no_result = 1;
    mixed get (Context ctx)
      {RXML_CONTEXT->enter_scope (CacheStaticFrame::this, 0); return nil;}
    CacheStaticFrame frame()
      {return CacheStaticFrame::this;}
    mixed _encode() {}
    void _decode (mixed v) {}
    protected string _sprintf (int flag)
    {
      return flag == 'O' &&
	sprintf ("CSF.EnterScope(%O)",
		 CacheStaticFrame::this && CacheStaticFrame::scope_name);
    }
  }

  class LeaveScope()
  {
    constant is_RXML_encodable = 1;
    constant is_RXML_p_code_entry = 1;
    constant is_csf_leave_scope = 1;
    constant p_code_no_result = 1;
    mixed get (Context ctx)
      {RXML_CONTEXT->leave_scope (CacheStaticFrame::this); return nil;}
    CacheStaticFrame frame()
      {return CacheStaticFrame::this;}
    mixed _encode() {}
    void _decode (mixed v) {}
    protected string _sprintf (int flag)
    {
      return flag == 'O' &&
	sprintf ("CSF.LeaveScope(%O)",
		 CacheStaticFrame::this && CacheStaticFrame::scope_name);
    }
  }

  protected string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("RXML.CacheStaticFrame(%O)", scope_name);
  }
}

protected class NewRuntimeTags
// Tool class used to track runtime tags in Context.
{
  protected mapping(string:Tag) add_tags;
  protected mapping(string:int|string) remove_tags;

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

protected class BreakEval (Frame|string target)
// Used in frame break exceptions.
{
  constant is_RXML_BreakEval = 1;
  string action = "break";
  Frame cur_frame = RXML_CONTEXT->frame;
}

class Backtrace
//! The object used to throw RXML errors.
{
  constant is_generic_error = 1;
  constant is_RXML_Backtrace = 1;

  string type;			// Currently "run" or "parse".
  string msg;
  Context context;
  array(Frame) frames;
  array(mapping(string:mixed)) args;
  string current_var;
  array backtrace;

  protected void create (void|string _type, void|string _msg,
			 void|Context _context, void|array _backtrace)
  {
    type = _type;
    msg = _msg;
    if (context = _context || RXML_CONTEXT) {
      frames = allocate (context->frame_depth);
      args = allocate (context->frame_depth);
      Frame frame = context->frame;
      int i = 0;
      for (; frame; i++, frame = frame->up) {
	if (i >= sizeof (frames)) {
	  frames += allocate (sizeof (frames) + 1);
	  args += allocate (sizeof (args) + 1);
	}
	frames[i] = frame;
	args[i] = frame->args;
      }
      frames = frames[..i - 1];
      args = args[..i - 1];
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
    function(string...:void) add = txt->add;
    if (!no_msg) add ("RXML", type ? " " + type : "", " error");
    if (context) {
      if (!no_msg) add (": ", msg || "(no error message)\n");
      if (current_var && current_var != "") add (" | ", current_var, "\n");
      for (int i = 0; i < sizeof (frames); i++) {
	Frame f = frames[i];
	string name;
	if (f->format_rxml_backtrace_frame) {
	  string res = f->format_rxml_backtrace_frame();
	  if (res != "") add (" | ", res, "\n");
	}
	else {
	  if (f->tag) name = f->tag->name;
	  //else if (!f->up) break;
	  else name = "(unknown)";
	  if (f->flags & FLAG_PROC_INSTR)
	    add (" | <?", name, "?>\n");
	  else {
	    add (" | <", name);
	    mapping(string:mixed) argmap = args[i];
	    if (mappingp (argmap))
	      foreach (sort (indices (argmap)), string arg) {
		mixed val = argmap[arg];
		add (" ", arg, "=");
		if (arrayp (val)) add (map (val, error_print_val) * ",");
		else add (error_print_val (val));
	      }
	    else add (" (no argmap)");
	    add (">\n");
	  }
	}
      }
    }
    else
      if (!no_msg) add (" (no context): ", msg || "(no error message)\n");
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

  mixed `[]= (int i, mixed val)
  {
    if (i == 0 && stringp (val)) {
      // Try to handle additional info being set in the error message.
      // This is very icky. The exception interface could be better.. :P
      string oldmsg = describe_rxml_backtrace();
      if (has_prefix (val, oldmsg))
	msg += val[sizeof (oldmsg)..];
      else if (has_suffix (val, oldmsg))
	msg = val[..sizeof (val) - sizeof (oldmsg) - 1] + msg;
      else
	msg = val;
      return val;
    }
    error ("Cannot set index %O to %O.\n", i, val);
  }

  string _sprintf (void|int flag)
  {
    return flag == 'O' && sprintf ("RXML.Backtrace(%s: %O)", type || "", msg);
  }
}

protected void nil_for_nonseq_error (RequestID id, Type type,
				     void|string msg, mixed... args)
{
  if (!id || !id->conf || id->conf->compat_level() >= 5.0) {
    if (sizeof (args)) msg = sprintf (msg, @args);
    parse_error ("No value given for nonsequential type %s%s.\n",
		 type->name, msg || "");
  }
}

protected void set_nil_arg (mapping(string:mixed) args, string arg,
			    Type type, mapping(string:Type) req_args,
			    RequestID id)
// Helper to do the work to assign nil to an attribute value.
{
  if (type->sequential)
    args[arg] = type->copy_empty_value();
  else if (req_args[arg]) {
    nil_for_nonseq_error (id, type, " in attribute %s", format_short (arg));
    args[arg] = nil;		// < 5.0 compat.
  }
  else
    // If an optional attribute has a nonsequential type and the value
    // is missing after parsing then let's treat it as if the
    // attribute was never given, since that's more useful than
    // complaining. It's not strictly 4.5-compatible (which would be
    // to assign nil just like above), but that incompatibility is not
    // expected to cause problems.
    m_delete (args, arg);
}


// Current context:

final void set_context (Context ctx) {SET_RXML_CONTEXT (ctx);}

final Context get_context() {return [object(Context)] RXML_CONTEXT;}
//! Returns the current @[RXML.Context] object, which contains all the
//! evaluation context info. It's updated before any function in
//! @[RXML.Tag] or @[RXML.Frame] is called.
//!
//! @note
//! A slightly faster way to access it is through the @[RXML_CONTEXT]
//! macro in @tt{module.h@}.

#if defined (MODULE_DEBUG) && constant (thread_create)

// Got races in this debug check, but looks like we have to live with that. :/

#define ENTER_CONTEXT(ctx)						\
  Context __old_ctx = RXML_CONTEXT;					\
  SET_RXML_CONTEXT (ctx);						\
  if (ctx) {								\
    if (ctx->in_use && ctx->in_use != this_thread())			\
      fatal_error ("Attempt to use context asynchronously.\n");		\
    ctx->in_use = this_thread();					\
  }

#define LEAVE_CONTEXT()							\
  if (Context ctx = RXML_CONTEXT)					\
    if (__old_ctx != ctx) ctx->in_use = 0;				\
  SET_RXML_CONTEXT (__old_ctx);

#else

#define ENTER_CONTEXT(ctx)						\
  Context __old_ctx = RXML_CONTEXT;					\
  SET_RXML_CONTEXT (ctx);

#define LEAVE_CONTEXT()							\
  SET_RXML_CONTEXT (__old_ctx);

#endif


// Constants for the bit field RXML.Frame.flags.

constant FLAG_NONE		= 0x00000000;
//! The no-flags flag. In case you think 0 is too ugly. ;)

constant FLAG_DEBUG		= 0x40000000;
//! Write a lot of debug during the execution of the tag, showing what
//! type conversions are done, what callbacks are being called etc.
//! Note that @tt{DEBUG@} must be defined for the debug printouts to
//! be compiled in (normally enabled with the @tt{--debug@} flag to
//! Roxen).

// Flags tested in the Tag object:

constant FLAG_EMPTY_ELEMENT	= 0x00000001;
//! If set, the tag does not use any content. E.g. with an HTML parser
//! this defines whether the tag is a container or not, and in XML
//! parsing the parser will signal an error if the tag have anything
//! but "" as content. Should not be changed after
//! @[RXML.Frame.do_enter] has returned.
//!
//! This flag may be changed in @[do_enter] to turn enable the error
//! check if the tag contains content.

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

constant FLAG_IS_CACHE_STATIC	= 0x00000200;
//! If this flag is set, the tag may be cached even when its content
//! contains uncachable parts. It's done by merging the result p-code
//! for the content of the tag and any variable assignments directly
//! into the result p-code for the surrounding content.
//!
//! This optimization flag may only be set for tags that meet these
//! conditions:
//!
//! @ul
//! @item
//!   The content is propagated to the result without any
//!   transformations, except that it's repeated zero or more times.
//!   This implies that the content and result types must be the same
//!   except for the parser.
//! @item
//!   The @tt{do_*@} callbacks have no other side effects than
//!   deciding the number of content iterations, setting variables, or
//!   introducing a tag scope, and this work does not depend in any
//!   way on the actual content.
//! @item
//!   Neither @[FLAG_GET_EVALED_CONTENT] nor @[FLAG_DONT_CACHE_RESULT]
//!   may be set. (Note however that the parser might internally set
//!   @[FLAG_DONT_CACHE_RESULT] for @[RXML.Frame] objects.
//!   @[FLAG_IS_CACHE_STATIC] overrides it in that case.)
//! @endul
//!
//! @note
//! Setting this flag on tags already in use might have insidious
//! compatiblity effects. Consider this case:
//!
//! @example
//! <cache>
//!   <registered-user>
//!   	<nocache>Your name is &registered-user.name;</nocache>
//!   </registered-user>
//! </cache>
//!
//! The tag @tt{<registered-user>@} is a custom tag that ignores its
//! content whenever the user isn't registered. When it doesn't have
//! this flag set, the nested @tt{<nocache>@} tag causes it to stay
//! unevaluated in the surrounding cache, and the test of the user is
//! therefore kept dynamic. If it on the other hand has set
//! @[FLAG_IS_CACHE_STATIC], that test is cached and the cache entry
//! will either contain the @tt{<nocache>@} block and a cached
//! assignment to @tt{&registered-user.name;@}, or none of the content
//! inside @tt{<registered-user>@}.
//!
//! If the parameters of the surrounding cache doesn't take that into
//! account then the same cache entry might be used both for
//! registered and unregistered users, something that didn't happen
//! before the @[FLAG_IS_CACHE_STATIC] flag was set.

// Flags tested in the Frame object:

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

constant FLAG_CONTENT_VAL_REQ	= 0x00200000;
//! Set this if the content must produce a value.
//!
//! This is only relevant if the content type is nonsequential:
//! Normally the parser checks that at most one tag or variable entity
//! in the content produces a value (i.e. not @[RXML.nil]), since
//! values for nonsequential types cannot be concatenated. It does
//! however not by default check that exactly one value is produced,
//! so the content might be @[RXML.nil]. This flag adds that check, so
//! the tag can assume that the content never gets set to @[RXML.nil].
//!
//! The above is not applicable for sequential types since they always
//! have a value (the empty value, at least) even if there is no
//! content.
//!
//! @note
//! The reason no value is allowed for nonsequential types by default
//! is because the content often is simply propagated to the result,
//! and we want to allow another sibling tag to produce a value for
//! the surrounding tag.

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

constant FLAG_COMPILE_INPUT	= 0x00008000;
//! The arguments and the content of the frame is always compiled to
//! p-code if this is set. Otherwise it's only done if the surrounding
//! content is, or if the frame iterates more than once.

constant FLAG_COMPILE_RESULT	= 0x00010000;
//! Any evaluation done in the exec arrays that the frame callbacks
//! returns is also compiled to p-code, and the exec array is
//! destructively changed to contain the p-code. This affects strings
//! if the result type has a parser.

constant FLAG_GET_RAW_CONTENT	= 0x00020000;
//! Puts the unparsed content of the tag into the
//! @[RXML.Frame.content] variable when @[RXML.Frame.do_enter] is
//! called. It's only available when the tag is actually evaluated
//! from source, however (as opposed to @[RXML.Frame.raw_tag_text]); a
//! cached frame won't receive it, but it will otoh contain the state
//! from an earlier evaluation from source (see @[RXML.Frame.save] and
//! @[RXML.Frame.restore]).

constant FLAG_GET_EVALED_CONTENT = 0x00040000;
//! When the content is evaluated, the frame will receive the result
//! of the evaluation as p-code in @[RXML.Frame.evaled_content], with
//! the exception of any nested tags which got
//! @[FLAG_DONT_CACHE_RESULT] set.

constant FLAG_DONT_CACHE_RESULT	= 0x00080000;
//! Keep this frame unevaluated in the p-code produced for a
//! surrounding frame with @[FLAG_GET_EVALED_CONTENT]. That implies
//! that all other surrounding frames (that aren't cache static; see
//! @[FLAG_IS_CACHE_STATIC]) also remain unevaluated, and this flag is
//! therefore automatically propagated by the parser into surrounding
//! frames. The flag is tested after the first evaluation of the frame
//! has finished.
//!
//! Since the flag is propagated, it might be set for frames which
//! have @[FLAG_IS_CACHE_STATIC] set. That's necessary for correct
//! propagation, but @[FLAG_IS_CACHE_STATIC] always overrides it for
//! the frame itself.

constant FLAG_MAY_CACHE_RESULT	= 0x00100000;
//! Mostly for internal use to flag that the result may be cached.
//! It's not enough to check the absence of @[FLAG_DONT_CACHE_RESULT]
//! for this: If the content of a frame isn't evaluated at all, we
//! don't know whether it might contain @[FLAG_DONT_CACHE_RESULT]
//! frames or not. Thus it's required that @[FLAG_DONT_CACHE_RESULT]
//! is cleared and this flag is set for the result of a frame to be
//! cached instead of the frame itself.
//!
//! This flag may be set explicitly to improve caching of tags that
//! unconditionally ignore their content.

constant FLAG_CUSTOM_TRACE	= 0x00000100;
//! Normally the parser runs TRACE_ENTER and TRACE_LEAVE for every tag
//! for the sake of the request trace. This flag disables that, so
//! that the tag can have its own custom TRACE_* calls.

// constant FLAG_PARENT_SCOPE	= 0x00000100;
//
// If set, exec arrays will be interpreted in the scope of the parent
// tag, rather than in the current one.
//
// This feature proved unnecessary and no longer exists.

// constant FLAG_NO_IMPLICIT_ARGS = 0x00000200;
// 
// If set, the parser won't apply any implicit arguments.
//
// Not implemented since there has been no need for it. The only
// implicit argument is "help" (see also MAGIC_HELP_ARG), and there
// probably won't be any more.

class Frame
//! A tag instance. A new frame is normally created for every parsed
//! tag in the source document. It might be reused both when the
//! document is requested again and when the tag is reevaluated in a
//! loop, but it's not certain in either case (see also @[save] and
//! @[restore]). Therefore, be careful about using variable
//! initializers.
{
  constant is_RXML_Frame = 1;
  constant is_RXML_encodable = 1;
  constant is_RXML_p_code_frame = 1;
  constant is_RXML_p_code_entry = 1;
  constant thrown_at_unwind = 1;

  // Interface:

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
  //!
  //! @note
  //! This variable may be set in the @tt{do_*@} callbacks, but it's
  //! assumed to be static, i.e. its value should not depend on any
  //! information that's known only at runtime. Practically that means
  //! that the value is assumed to never change if the frame is reused
  //! by p-code.

  mapping(string:mixed)|EVAL_ARGS_FUNC args;
  //! A mapping with the (parsed and evaluated) arguments passed to
  //! the tag. Set every time the frame is executed, before any frame
  //! callbacks are called (unless the frame was made with the
  //! finished args mapping directly, e.g. by @[RXML.make_tag]). Not
  //! set for processing instruction (@[FLAG_PROC_INSTR]) tags.

  Type content_type;
  //! The type of the content. It may be changed in @[do_enter] to
  //! affect how the content will be parsed.
  //!
  //! @note
  //! This variable is assumed to be static in the sense that its
  //! value does not depend on any information that's known only at
  //! runtime. Practically that means that the value is assumed to
  //! never change if the frame is compiled into p-code.
  //!
  //! Note that the assumption can't always be guaranteed. E.g. if the
  //! content type can be set by an @[RXML.Type] argument to the tag,
  //! it's always possible that it's set through a splice argument
  //! that might change at run time. Since that seems only like a
  //! theoretical situation, and since solving it would incur a
  //! runtime cost, it's been left as a "known issue" for the time
  //! being.

  mixed content;
  //! The content, if any. Set before @[do_process] and @[do_return]
  //! are called. Initialized to @[RXML.nil] every time the frame
  //! executed (unless the frame was made with the finished content
  //! directly, e.g. by @[RXML.make_tag]).
  //!
  //! Even if @[content_type] is nonsequential, this value might be
  //! @[RXML.nil], indicating the lack of any value at all. The parser
  //! can be forced to check that a value is produced by setting
  //! @[FLAG_CONTENT_VAL_REQ].

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
  //!
  //! @note
  //! This variable is assumed to be static; see the note for
  //! @[content_type] for further details.

  mixed result;
  //! The result, which is assumed to be either @[RXML.nil] or a valid
  //! value according to result_type. The exec arrays returned by e.g.
  //! @[do_return] changes this. It may also be set directly.
  //! Initialized to @[RXML.nil] every time the frame executed.
  //!
  //! If @[result_type] has a parser set, it will be used by
  //! @[do_return] etc before assigning to this variable. Thus it
  //! contains the value after any parsing and will not be parsed
  //! again.

  //! @decl optional mapping(string:mixed)|object(Scope) vars;
  //!
  //! Set this to introduce a new variable scope that will be active
  //! during parsing of the content and return values.
  //!
  //! @note
  //! A frame may destructively change or replace its own @[vars]
  //! mapping to make changes in its scope. Changes from any other
  //! place should go through @[RXML.Context.set_var] (or its
  //! alternatives @[RXML.Context.user_set_var], @[RXML.set_var],
  //! @[set_var] etc) so that the change is recorded properly in
  //! caches etc.

  //! @decl optional string scope_name;
  //!
  //! The scope name for the variables. Must be set before the scope
  //! is used for the first time, and can't be changed after that.

  //! @decl optional TagSet additional_tags;
  //!
  //! If set, the tags in this tag set will be used in addition to the
  //! tags inherited from the surrounding parser. The additional tags
  //! will in turn be inherited by subparsers.
  //!
  //! @note
  //! This variable may be set in the @[do_enter] callback, but it's
  //! assumed to be static, i.e. its value should not depend on any
  //! information that's known only at runtime. Practically that means
  //! that the value is assumed to never change if the frame is reused
  //! by p-code.

  //! @decl optional TagSet local_tags;
  //!
  //! If set, the tags in this tag set will be used in the parser for
  //! the content, instead of the one inherited from the surrounding
  //! parser. The tags are not inherited by subparsers.
  //!
  //! @note
  //! This variable is assumed to be static; see the note for
  //! @[additional_tags] for further details.

  //! @decl optional Frame parent_frame;
  //!
  //! If this variable exists, it gets set to the frame object of the
  //! closest surrounding tag that defined this tag in its
  //! @[additional_tags] or @[local_tags]. Useful to access the
  //! "mother tag" from the subtags it defines.
  //!
  //! @note
  //! If the parent tag is cache static, this will not be set when the
  //! parent frame is optimized away. If that is a problem then either
  //! make this tag cache static too, or don't make the parent tag
  //! cache static.

  //! @decl optional string raw_tag_text;
  //!
  //! If this variable exists, it gets the raw text representation of
  //! the tag, if there is any. Note that it's after the parsing of
  //! any splice argument.
  //!
  //! @note
  //! This variable is assumed to be static, i.e. its value doesn't
  //! depend on any information that's known only at runtime.

  //! @decl optional object check_security_object;
  //!
  //! If this is defined, it specifies an object to use for the module
  //! level security check. The default is to use @[tag] if it's set,
  //! else this object.
  //!
  //! Setting this is useful for short lived tags and tagless frames
  //! since the security system caches references to these objects,
  //! which otherwise would cause them to be lying around until the
  //! next gc round.
  //!
  //! @note
  //! This is used only if the define MODULE_LEVEL_SECURITY exists.

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
  //! @returns
  //! Return values:
  //! @mixed
  //!  @type array
  //!   A so-called exec array to be handled by the parser. The
  //!	elements are processed in order, and have the following usage:
  //!   @mixed
  //!    @type string
  //!	  Added or put into the result. If the result type has a
  //!	  parser, the string will be parsed with it before it's
  //!	  assigned to the result variable and passed on.
  //!    @type RXML.Frame
  //!	  Already initialized frame to process. Its result is added
  //!	  or put into the result of this tag. The functions
  //!	  @[RXML.make_tag], @[RXML.make_unparsed_tag] are useful to
  //!	  create frames.
  //!	 @type RXML.PCode
  //!	  A p-code object to evaluate. It's not necessary that the
  //!	  type it evaluates to is the same as @[result_type]; it will
  //!	  be converted if it isn't.
  //!	 @type function(RequestID:mixed)
  //!	  Run the function and add its return value to the result.
  //!	  It's assumed to be a valid value of @[result_type].
  //!    @type object
  //!	  Treated as a file object to read in blocking or nonblocking
  //!	  mode. FIXME: Not yet implemented, details not decided.
  //!    @type multiset(mixed)
  //!	  Should only contain one element that'll be added or put into
  //!	  the result. Normally not necessary; assign it directly to
  //!	  the result variable instead.
  //!    @type propagate_tag
  //!	  Use a call to this function to propagate the tag to be
  //!	  handled by an overridden tag definition, if any exists. If
  //!	  this is used, it's probably necessary to define the
  //!	  @[raw_tag_text] variable. For further details see the doc
  //!	  for @[propagate_tag] in this class.
  //!	 @type RXML.nil
  //!	  Ignored.
  //!   @endmixed
  //!  @type int(0..0)
  //!   Do nothing special. Exits the tag when used from
  //!   @[do_process] and @[FLAG_STREAM_RESULT] is set.
  //! @endmixed
  //!
  //! @note
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

  optional mixed save();
  //! If defined, this will be called after the frame has been
  //! evaluated (i.e. after @[do_return]) for the first time, if the
  //! frame state is to be preserved in p-code. The returned value,
  //! aka the persistent state of the frame, will be passed to
  //! @[restore] when the frame is reinstantiated from the p-code.
  //!
  //! The function usually saves the frame specific data that should
  //! be cached. It need not save the values of the standard variables
  //! @[flags], @[args], @[content], @[content_type], @[result_type]
  //! and @[raw_tag_text] (if present). Note that when this function
  //! is called, @[args] and @[content] are set to the function and
  //! p-code, respectively, used for reevaluation of those values.
  //!
  //! If the persistent state changes in a later reevaluation of the
  //! frame, it should call @[RXML.Context.state_update] to trig
  //! another save of the frame state.
  //!
  //! If this returns zero then @[restore] won't be called.

  optional void restore (mixed saved);
  //! Should be defined when @[save] is. It takes the value produced
  //! by @[save] and restores that frame state. The values of the
  //! standard variables are already restored to the same values they
  //! had at the call to @[save].
  //!
  //! @note
  //! A frame might be reevaluated without a prior call to this
  //! function, if it's the same frame object since the call to
  //! @[save].
  //!
  //! @note
  //! This function is used to decode dumped p-code that's read from
  //! disk. @[saved] might therefore be of an incompatible format
  //! produced by an earlier version of @[save]. It's not necessary
  //! that @[restore] handles this, but if it doesn't it must produce
  //! some kind of exception so that the decoding of the p-code fails.
  //! It must never restore an invalid state which might cause errors
  //! or invalid results in later calls to the @tt{do_*@} functions.

  //! @decl PCode evaled_content;
  //!
  //! Must exist if @[FLAG_GET_EVALED_CONTENT] is set. It will be set
  //! to a p-code object containing the (mostly) evaluated content (in
  //! each iteration). This variable is not automatically saved and
  //! restored (see @[save] and @[restore]).

  optional void exec_array_state_update();
  //! If this is defined, it is called whenever p-code or frames are
  //! evaluated in an exec array (as returned by any of the
  //! @tt{do_*@} functions), and that evaluation causes their
  //! persistent state to change.
  //!
  //! Its typical use is to contain a call to
  //! @expr{RXML_CONTEXT->state_update@} to propagate the state update
  //! event if the exec array is part of the persistent state of this
  //! frame.
  //!
  //! @seealso
  //! @[do_enter], @[do_process], @[do_return], @[Context.state_update]

  optional string format_rxml_backtrace_frame();
  //! Define this to control how the frame is formatted in RXML
  //! backtraces. The returned string should be one line, without a
  //! trailing newline. It should not contain the " | " prefix.
  //!
  //! The empty string may be returned to suppress the backtrace frame
  //! altogether. That might be useful for some types of internally
  //! used frames, but it should be used only if there are very good
  //! reasons; the backtrace easily just becomes confusing instead.

  // Services:

  final mixed get_var (string|array(string|int) var, void|string scope_name,
		       void|Type want_type)
  //! A wrapper for easy access to @[RXML.Context.get_var].
  {
    return RXML_CONTEXT->get_var (var, scope_name, want_type);
  }

  final mixed set_var (string|array(string|int) var, mixed val, void|string scope_name)
  //! A wrapper for easy access to @[RXML.Context.set_var].
  {
    return RXML_CONTEXT->set_var (var, val, scope_name);
  }

  final void delete_var (string|array(string|int) var, void|string scope_name)
  //! A wrapper for easy access to @[RXML.Context.delete_var].
  {
    RXML_CONTEXT->delete_var (var, scope_name);
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
    if (TAG_DEBUG_TEST (flags & FLAG_DEBUG)) report_debug (msg, @args);
  }

  void break_frame (void|Frame|string frame_or_scope)
  //! Makes the parser break the evaluation up to the specified frame,
  //! or to the top level if no frame is given. If @[frame_or_scope]
  //! is a frame object higher up in the stack then the evaluation up
  //! to and including that frame will be broken, and then continue.
  //! If @[frame_or_scope] is a string then the closest frame higher
  //! up in the stack with a scope of that name will be broken. It's
  //! an error if @[frame_or_scope] is nonzero and doesn't match a
  //! frame in the stack. Does not return; throws a special exception
  //! instead.
  //!
  //! @note
  //! It's not well defined how much of the earlier evaluated data
  //! will be in the final result. Since none of the broken tags are
  //! executed on the partial data after the break, it won't be
  //! returned. This means that typically none of the earlier data is
  //! returned. However if streaming is in use then data in earlier
  //! returned pieces is not affected, of course.
  {
    throw (BreakEval (frame_or_scope));
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
    return RXML_CONTEXT->tag_set->get_plugins (tag->name, tag->flags & FLAG_PROC_INSTR);
  }

  final Tag get_overridden_tag()
  //! Returns the @[RXML.Tag] object the tag for this frame overrides,
  //! if any.
  {
    return RXML_CONTEXT->tag_set->get_overridden_tag (tag);
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
#ifdef MODULE_DEBUG
#define CHECK_RAW_TEXT							\
    if (!object_variablep (this, "raw_tag_text"))			\
      fatal_error ("The variable raw_tag_text must be defined.\n");	\
    if (!stringp (this_object()->raw_tag_text))				\
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
	  content = t_xml->parse_tag (this_object()->raw_tag_text)[2];
#ifdef DEBUG
	  if (!stringp (content))
	    fatal_error ("Failed to parse PI tag content for <?%s?> from %O.\n",
			 tag->name, this_object()->raw_tag_text);
#endif
	}
      }
      else if (!args || !content && !(flags & FLAG_EMPTY_ELEMENT)) {
	CHECK_RAW_TEXT;
	string ignored;
	[ignored, args, content] = t_xml->parse_tag (this_object()->raw_tag_text);
#ifdef DEBUG
	if (!mappingp (args))
	  fatal_error ("Failed to parse tag args for <%s> from %O.\n",
		       tag->name, this_object()->raw_tag_text);
	if (!stringp (content) && !(flags & FLAG_EMPTY_ELEMENT))
	  fatal_error ("Failed to parse tag content for <%s> from %O.\n",
		       tag->name, this_object()->raw_tag_text);
#endif
      }
      frame = overridden (args, content || "");
      frame->flags |= FLAG_UNPARSED;
      return frame;
    }

    else {
      CHECK_RAW_TEXT;
      // Format a new tag, as close to the original as possible.

      if (flags & FLAG_PROC_INSTR) {
	if (content) {
	  string name;
	  [name, args, content] = t_xml->parse_tag (this_object()->raw_tag_text);
	  return result_type->format_tag (name, 0, content, tag->flags);
	}
	else
	  return this_object()->raw_tag_text;
      }

      else {
	string s;
	if (!args || !content && !(flags & FLAG_EMPTY_ELEMENT)) {
#ifdef MODULE_DEBUG
	  if (mixed err = catch {
#endif
	    s = t_xml (PXml)->eval (this_object()->raw_tag_text,
				    RXML_CONTEXT, empty_tag_set);
#ifdef MODULE_DEBUG
	  }) {
	    if (objectp (err) && ([object] err)->thrown_at_unwind)
	      fatal_error ("Can't save parser state when evaluating arguments.\n");
	    throw_fatal (err);
	  }
#endif
	  if (!args && !content) return s;
	}
	else s = this_object()->raw_tag_text;

	[string name, mapping(string:string) parsed_args,
	 string parsed_content] = t_xml->parse_tag (this_object()->raw_tag_text);
#ifdef DEBUG
	if (!mappingp (parsed_args))
	  fatal_error ("Failed to parse tag args for <%s> from %O.\n",
		       tag->name, this_object()->raw_tag_text);
	if (!stringp (parsed_content))
	  fatal_error ("Failed to parse tag content for <%s> from %O.\n",
		       tag->name, this_object()->raw_tag_text);
#endif
	if (!args) args = parsed_args;
	if (!content && !(flags & FLAG_EMPTY_ELEMENT)) content = parsed_content;
	return result_type->format_tag (name, args, content, tag->flags);
      }
#undef CHECK_RAW_TEXT
    }
  }

  // Internals:

#ifdef DEBUG
#  define THIS_TAG_TOP_DEBUG(msg, args...)				\
     (TAG_DEBUG_TEST (flags & FLAG_DEBUG) &&				\
      report_debug ("%O: " + (msg), this_object(), args), 0)
#  define THIS_TAG_DEBUG(msg, args...)					\
     (TAG_DEBUG_TEST (flags & FLAG_DEBUG) &&				\
      report_debug ("%O:   " + (msg), this_object(), args), 0)
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
    THIS_TAG_DEBUG ("Adding %s to " desc "\n", format_short (from));	\
    /* Keep only one ref to to to allow destructive change. */		\
    to = to + (to = 0, from);						\
  } while (0)

#define SET_NONNIL_NONSEQUENTIAL(from, to, to_type, desc)		\
  do {									\
    if (to != nil)							\
      parse_error (							\
	"Cannot append another value %s to nonsequential " desc		\
	" of type %s.\n", format_short (from), to_type->name);		\
    THIS_TAG_DEBUG ("Setting " desc " to %s\n", format_short (from));	\
    to = from;								\
  } while (0)

#define SET_NONSEQUENTIAL(from, to, to_type, desc)			\
  do {									\
    if (from != nil)							\
      SET_NONNIL_NONSEQUENTIAL (from, to, to_type, desc);		\
  } while (0)

#define CONVERT_VALUE(from, from_type, to, to_type, desc)		\
  do {									\
    if (from_type->name != to_type->name) {				\
      THIS_TAG_DEBUG (desc, from_type->name, to_type->name);		\
      to = to_type->encode (from, from_type);				\
    }									\
    else to = from;							\
  } while (0)

#define CONV_RESULT(from, from_type, to, to_type) \
  CONVERT_VALUE(from, from_type, to, to_type, \
		"Converting result from %s to %s of surrounding content\n")

  private void _exec_array_fatal (string where, int pos, mixed elem,
				  string msg, mixed... args)
  {
    if (sizeof (args)) msg = sprintf (msg, args);
    fatal_error ("Position %d in exec array from %s is %s: %s",
		 pos, where, format_short (elem), msg);
  };

  mixed _exec_array (Context ctx, TagSetParser|PCode evaler, array exec, string where)
  {
    int i = 0;
    mixed res = nil;
    Parser subparser = 0;
    int orig_make_p_code = ctx->make_p_code;
    int orig_state_updated = ctx->state_updated;
    PCode orig_evaled_p_code = ctx->evaled_p_code;
    ctx->evaled_p_code = 0;

    mixed err = catch {
      for (; i < sizeof (exec); i++) {
	mixed elem = exec[i], piece = nil;

	switch (sprintf ("%t", elem)) {
	  case "string":
	    if (result_type->parser_prog == PNone) {
	      THIS_TAG_DEBUG ("Exec[%d]: String %s\n", i, format_short (elem));
	      piece = elem;
	    }
	    else {
	      {
		PCode p_code = 0;
		if (TagSet local_tags = this_object()->local_tags) {
		  if ((ctx->make_p_code = flags & FLAG_COMPILE_RESULT)) {
		    p_code = RenewablePCode (result_type, ctx, local_tags);
		    p_code->source = [string] elem;
		  }
		  subparser = result_type->get_parser (ctx, local_tags, evaler, p_code);
		  subparser->_local_tag_set = 1;
		  THIS_TAG_DEBUG ("Exec[%d]: Parsing%s string %s with %O "
				  "from local_tags\n", i,
				  p_code ? " and compiling" : "",
				  format_short (elem), subparser);
		}
		else {
		  if ((ctx->make_p_code = flags & FLAG_COMPILE_RESULT)) {
		    p_code = RenewablePCode (result_type, ctx, ctx->tag_set);
		    p_code->source = [string] elem;
		  }
		  subparser = result_type->get_parser (
		    ctx, ctx->tag_set, evaler, p_code);
		  THIS_TAG_DEBUG ("Exec[%d]: Parsing%s string %s with %O\n", i,
				  p_code ? " and compiling" : "",
				  format_short (elem), subparser);
		}
		if (evaler->recover_errors && !(flags & FLAG_DONT_RECOVER)) {
		  subparser->recover_errors = 1;
		  if (p_code) p_code->recover_errors = 1;
		}
	      }
	      subparser->finish ([string] elem); // Might unwind.
	      piece = subparser->eval(); // Might unwind.
	      if (PCode p_code = subparser->p_code) {
		// Could perhaps collect adjacent PCode objects here.
		p_code->finish();
		exec[i] = p_code;
	      }
	      result_type->give_back (subparser, ctx->tag_set);
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
	      THIS_TAG_DEBUG ("Exec[%d]: Verbatim value %s\n", i, format_short (piece));
	    }
	    else
	      _exec_array_fatal (where, i, elem,
				 "Not exactly one value in multiset.\n");
	    break;

	  default:
	    if (objectp (elem)) {
	      // Can't count on that sprintf ("%t", ...) on an object
	      // returns "object".
	      if (([object] elem)->is_RXML_Frame) {
		if (orig_make_p_code)
		  // FIXME: Should p-code this if FLAG_COMPILE_RESULT
		  // is set, but then we have to solve the thread
		  // safety and staleness check issues.
		  ctx->make_p_code = 0;
		THIS_TAG_DEBUG ("Exec[%d]: Evaluating frame %O\n", i, elem);
		piece = ([object(Frame)] elem)->_eval (
		  ctx, evaler, result_type); // Might unwind.
		([object(Frame)] elem)->up = 0;	// Break potential cyclic reference.
		break;
	      }
	      else if (([object] elem)->is_RXML_PCode) {
		THIS_TAG_DEBUG ("Exec[%d]: Evaluating p-code %O\n", i, elem);
		piece = ([object(PCode)] elem)->_eval (ctx, 0);
		CONVERT_VALUE (piece, ([object(PCode)] elem)->type,
			       piece, result_type,
			       "Converting p-code result from %s "
			       "to tag result type %s\n");
		break;
	      }
	      else if (([object] elem)->is_RXML_Parser) {
		// The subparser above unwound.
		THIS_TAG_DEBUG ("Exec[%d]: Continuing eval of frame %O\n", i, elem);
		([object(Parser)] elem)->finish(); // Might unwind.
		piece = ([object(Parser)] elem)->eval(); // Might unwind.
		break;
	      }
	      else if (elem == nil)
		break;
	    }
	    else if (functionp (elem)) {
	      THIS_TAG_DEBUG ("Exec[%d]: Calling function %O\n", i, elem);
	      piece = ([function(RequestID:mixed)] elem) (ctx->id); // Might unwind.
	      break;
	    }
	    _exec_array_fatal (where, i, elem, "Not a valid type.\n");
	}

	if (result_type->sequential) SET_SEQUENTIAL (piece, res, "result");
	else SET_NONSEQUENTIAL (piece, result, result_type, "result");
      }

      if (result_type->sequential) result = result + (result = 0, res);
      else res = result;

      ctx->make_p_code = orig_make_p_code;
      ctx->evaled_p_code = orig_evaled_p_code;

      if (ctx->state_updated != orig_state_updated) {
	PCODE_UPDATE_MSG ("%O (frame %O): Restoring p-code update count "
			  "from %d to %d after evaluating exec array.\n",
			  ctx, this, ctx->state_updated, orig_state_updated);
	ctx->state_updated = orig_state_updated;
	if (exec_array_state_update) {
	  PCODE_UPDATE_MSG ("Calling %O->exec_array_state_update.\n", this);
	  exec_array_state_update();
	}
      }

      return res;
    };

    if (result_type->sequential) result = result + (result = 0, res);

    ctx->make_p_code = orig_make_p_code;
    ctx->evaled_p_code = orig_evaled_p_code;

    if (ctx->state_updated != orig_state_updated) {
      PCODE_UPDATE_MSG ("%O (frame %O): Restoring p-code update count "
			"from %d to %d after evaluating exec array.\n",
			ctx, this, ctx->state_updated, orig_state_updated);
      ctx->state_updated = orig_state_updated;
      if (exec_array_state_update) {
	PCODE_UPDATE_MSG ("Calling %O->exec_array_state_update.\n", this);
	exec_array_state_update();
      }
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
    }
    throw (err);
  }

  private void _handle_runtime_tags (Context ctx, TagSetParser|PCode evaler)
  {
    if (evaler->is_RXML_Parser) {
      array(Tag) arr_add_tags = ctx->new_runtime_tags->added_tags();
      array(string) arr_rem_tags = ctx->new_runtime_tags->removed_tags();
      array(string) arr_rem_pi_tags = ctx->new_runtime_tags->removed_pi_tags();
      for (Parser p = evaler; p; p = p->_parent)
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
    }
    // FIXME: When the evaler is a PCode object we should have a debug
    // check here that ensures that the same runtime tag changes are
    // done as in the first eval.
    ctx->runtime_tags = ctx->new_runtime_tags->filter_tags (ctx->runtime_tags);
    ctx->new_runtime_tags = 0;
  }

#define LOW_CALL_CALLBACK(res, cb, args...)				\
  do {									\
    THIS_TAG_DEBUG ("Calling " #cb "\n");				\
    COND_PROF_ENTER(tag,tag->name,"tag");				\
    res = (cb) (args); /* Might unwind. */				\
    COND_PROF_LEAVE(tag,tag->name,"tag");				\
  } while (0)

#define TAG_ENTER_SCOPE(ctx, csf)					\
  do {									\
    if (SCOPE_TYPE vars = this_object()->vars) {			\
      if (!csf && flags & FLAG_IS_CACHE_STATIC && ctx->evaled_p_code) {	\
	csf = CacheStaticFrame (this_object()->scope_name);		\
	ctx->misc->recorded_changes += ({csf->EnterScope(), ([])});	\
      }									\
      ENTER_SCOPE (ctx, this_object());					\
    }									\
  } while (0)

#define TAG_LEAVE_SCOPE(ctx, csf)					\
  do {									\
    if (SCOPE_TYPE vars = this_object()->vars) {			\
      LEAVE_SCOPE (ctx, this_object());					\
      /* csf is usually set, but might not be in the cleanup after	\
       * exceptions. */							\
      if (flags & FLAG_IS_CACHE_STATIC && csf && ctx->evaled_p_code)	\
	ctx->misc->recorded_changes += ({csf->LeaveScope(), ([])});	\
    }									\
  } while (0)

#define EXEC_CALLBACK(ctx, csf, evaler, exec, cb, args...)		\
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
	THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this_object());		\
	TAG_ENTER_SCOPE (ctx, csf);					\
	if (ctx->new_runtime_tags)					\
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
	ctx->unwind_state = (["stream_piece": res,			\
			      "reason": "streaming"]);			\
	THIS_TAG_DEBUG ("Streaming %s from " #cb "\n",			\
			format_short (res));				\
	throw (this_object());						\
      }									\
      exec = 0;								\
    }									\
  } while (0)

  EVAL_ARGS_FUNC|string _prepare (Context ctx, Type type,
				  mapping(string:string) raw_args,
				  PikeCompile comp)
  // Evaluates raw_args simultaneously as generating the
  // EVAL_ARGS_FUNC function. The result of the evaluations is stored
  // in args. Might be destructive on raw_args. No evaluation of
  // raw_args is done if tag isn't set.
  {
      if (ctx->frame_depth >= Context.max_frame_depth)
	_run_error ("Too deep recursion -- exceeding %d nested tags.\n",
		    Context.max_frame_depth);

      mapping(string:mixed) cooked_args;
      EVAL_ARGS_FUNC|string func;

      if (raw_args) {
#ifdef MODULE_DEBUG
	if (flags & FLAG_PROC_INSTR)
	  fatal_error ("Can't pass arguments to a processing instruction tag.\n");
#endif

#ifdef MAGIC_HELP_ARG
	if (raw_args->help) {
	  func = utils->return_help_arg;
	  cooked_args = raw_args;
	}
	else
#endif
	  if (sizeof (raw_args) || tag && sizeof (tag->req_arg_types)) {
	    // Note: Approximate code duplication in Tag.eval_args and
	    // Tag._eval_splice_args.

	    string splice_arg = raw_args["::"];
	    if (splice_arg) m_delete (raw_args, "::");
	    else splice_arg = 0;
	    mapping(string:Type) splice_req_types;

	    mapping(string:Type) atypes;
	    if (tag) {
	      atypes = raw_args & tag->req_arg_types;
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
	    }
	    else
	      atypes = ([]);

	    String.Buffer fn_text;
	    function(string...:void) fn_text_add;
	    PCode sub_p_code = 0;
	    if (comp) {
	      fn_text_add = (fn_text = String.Buffer())->add;
	      // The zero assignment is to avoid unused variable
	      // warnings in pike > 7.6.
	      fn_text_add ("mixed tmp = 0;\n");
	      sub_p_code = PCode (0, 0);
	    }

	    if (splice_arg) {
	      // Note: This assumes an XML-like parser.
	      if (comp)
		sub_p_code->create (splice_arg_type, ctx, ctx->tag_set, 0, comp);
	      Parser parser = splice_arg_type->get_parser (ctx, ctx->tag_set, 0,
							   sub_p_code);
	      THIS_TAG_DEBUG ("Evaluating splice argument %s\n",
			      format_short (splice_arg));
#ifdef MODULE_DEBUG
	      if (mixed err = catch {
#endif
		parser->finish (splice_arg); // Should not unwind.
		splice_arg = parser->eval(); // Should not unwind.
#ifdef MODULE_DEBUG
	      }) {
		if (objectp (err) && ([object] err)->thrown_at_unwind)
		  fatal_error ("Can't save parser state when "
			       "evaluating splice argument.\n");
		throw_fatal (err);
	      }
#endif
	      if (comp) {
		if (tag)
		  fn_text_add (
		    "mapping(string:mixed) args = ",
		    comp->bind (tag->_eval_splice_args), "(ctx,",
		    comp->bind (xml_tag_parser->parse_tag_args), "((",
		    sub_p_code->compile_text (comp), ")||\"\"),",
		    comp->bind (splice_req_types), ");\n");
		else
		  fn_text_add (
		    "mapping(string:mixed) args = ",
		    comp->bind (xml_tag_parser->parse_tag_args), "((",
		    sub_p_code->compile_text (comp), ")||\"\");\n");
	      }

	      splice_arg_type->give_back (parser, ctx->tag_set);
	      if (tag)
		cooked_args = tag->_eval_splice_args (
		  ctx, xml_tag_parser->parse_tag_args (splice_arg || ""),
		  splice_req_types);
	      else
		cooked_args = xml_tag_parser->parse_tag_args (splice_arg || "");
	    }

	    else {
	      cooked_args = ([]);
	      if (comp) fn_text_add ("mapping(string:mixed) args = ([]);\n");
	    }

#ifdef MODULE_DEBUG
	    if (mixed err = catch {
#endif

	      TagSet ctx_tag_set = ctx->tag_set;
	      Type default_type = tag ? tag->def_arg_type : t_any_text (PNone);
	      if (comp) {
		string req_args_var = comp->bind (tag->req_arg_types);
		foreach (raw_args; string arg; string val) {
		  Type t = atypes[arg] || default_type;
		  if (t->parser_prog != PNone) {
		    sub_p_code->create (t, ctx, ctx_tag_set, 0, comp);
		    Parser parser = t->get_parser (ctx, ctx_tag_set, 0, sub_p_code);
		    THIS_TAG_DEBUG ("Evaluating and compiling "
				    "argument value %s with %O\n",
				    format_short (val), parser);
		    parser->finish (val); // Should not unwind.
		    mixed v = parser->eval(); // Should not unwind.
		    t->give_back (parser, ctx_tag_set);

		    if ((v != nil) && t->type_check) t->type_check(v);
		    // FIXME: Add type-checking to the compiled code as well.

		    if (t->sequential)
		      fn_text_add (sprintf ("args[%O] = %s;\n", arg,
					    sub_p_code->compile_text (comp)));
		    else
		      fn_text_add (
			"tmp=", sub_p_code->compile_text (comp), ";\n",
			sprintf ("if (tmp == RXML.nil)"
				 " set_nil_arg(args,%O,%s,%s,ctx->id);\n"
				 "else args[%O] = tmp;\n",
				 arg, comp->bind (t), req_args_var, arg));

		    if (v == nil)
		      set_nil_arg (cooked_args, arg, t,
				   tag->req_arg_types, ctx->id);
		    else
		      cooked_args[arg] = v;

		    THIS_TAG_DEBUG ("Setting argument %s to %s\n",
				    format_short (arg),
				    format_short (cooked_args[arg]));
		  }

		  else {
		    cooked_args[arg] = val;
		    fn_text_add (sprintf ("args[%O] = %s;\n",
					  arg, comp->bind (val)));
		  }
		}
	      }

	      else
		foreach (raw_args; string arg; string val) {
		  Type t = atypes[arg] || default_type;
		  if (t->parser_prog != PNone) {
		    Parser parser = t->get_parser (ctx, ctx_tag_set, 0, 0);
		    THIS_TAG_DEBUG ("Evaluating argument value %s with %O\n",
				    format_short (val), parser);
		    parser->finish (val); // Should not unwind.
		    mixed v = parser->eval(); // Should not unwind.
		    t->give_back (parser, ctx_tag_set);

		    if (v == nil)
		      set_nil_arg (cooked_args, arg, t,
				   tag->req_arg_types, ctx->id);
		    else
		      cooked_args[arg] = v;

		    THIS_TAG_DEBUG ("Setting argument %s to %s\n",
				    format_short (arg),
				    format_short (cooked_args[arg]));
		  }

		  else
		    cooked_args[arg] = val;
		}

#ifdef MODULE_DEBUG
	    }) {
	      if (objectp (err) && ([object] err)->thrown_at_unwind)
		fatal_error ("Can't save parser state when evaluating arguments.\n");
	      throw_fatal (err);
	    }
#endif

	    if (comp) {
	      fn_text_add ("return args;\n");
	      func = comp->add_func (
		"mapping(string:mixed)", "object ctx, object evaler", fn_text->get());
	    }
	  }
	  else {
	    func = utils->return_empty_mapping;
	    cooked_args = raw_args;
	  }
      }
      else
	func = utils->return_zero;

      if (!result_type) {
#ifdef MODULE_DEBUG
	if (!tag) fatal_error ("result_type not set in Frame object %O, "
			       "and it has no Tag object to use for inferring it.\n",
			       this_object());
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
			       this_object());
#endif
	content_type = tag->content_type;
	if (content_type == t_same) {
	  content_type =
	    result_type (content_type->parser_prog, @content_type->parser_args);
	  THIS_TAG_DEBUG ("Resolved t_same to content_type %s\n",
			  content_type->name);
	}
	else THIS_TAG_DEBUG ("Setting content_type to %s from tag\n",
			     content_type->name);
      }
      else THIS_TAG_DEBUG ("Keeping content_type %s\n", content_type->name);

      if (raw_args)
	args = cooked_args;

      return func;
  }

#ifdef DEBUG
  Thread.Thread using_thread;
#endif

  //! Frame cleanup callback.
  //!
  //! Overload this function with code to cleanup
  //! any state that shouldn't be kept for the next
  //! use of the frame.
  //!
  //! This function is called after @[do_return()],
  //! and also during exception processing.
  static void cleanup() {}

  mixed _eval (Context ctx, TagSetParser|PCode evaler, Type type)
  // Note: It might be somewhat tricky to override this function,
  // since it handles unwinding and rewinding.
  {
    RequestID id = ctx->id;
    PikeCompile comp;

    // Unwind state data:
#define EVSTAT_NONE 0
#define EVSTAT_BEGIN 1
#define EVSTAT_ENTERED 2
#define EVSTAT_LAST_ITER 3
#define EVSTAT_ITER_DONE 4
    int eval_state = EVSTAT_NONE;
    mapping(string:mixed)|EVAL_ARGS_FUNC in_args = 0;
    string|PCode in_content = 0;
    int iter;
#ifdef DEBUG
    int debug_iter = 1;
#endif
    object(Parser)|object(PCode) subevaler;
    mixed piece;
    array exec = 0;
    TagSet orig_tag_set; // Flags that additional_tags has been added to ctx->tag_set.
    //ctx->new_runtime_tags
    int orig_make_p_code;
    CacheStaticFrame csf;
    //ctx->evaled_p_code;

#define PRE_INIT_ERROR(X...) (ctx->frame = this_object(), fatal_error (X))
#ifdef DEBUG
    // Internal sanity checks.
    if (using_thread)
      PRE_INIT_ERROR ("Frame already in use by thread %O, this is thread %O.\n",
		      using_thread, this_thread());
    using_thread = this_thread();
    if (ctx != RXML_CONTEXT)
      PRE_INIT_ERROR ("Context not current.\n");
    if (id && ctx->misc != ctx->id->misc->defines)
      PRE_INIT_ERROR ("ctx->misc != ctx->id->misc->defines\n"
		      "%O != %O\n",
		      ctx->misc, ctx->id->misc->defines);
    if (!evaler->tag_set_eval)
      PRE_INIT_ERROR ("Calling _eval() with non-tag set parser.\n");
    if (up)
      PRE_INIT_ERROR ("Up frame already set. Frame reused in different context?\n");
#endif
#ifdef MODULE_DEBUG
    if (ctx->new_runtime_tags)
      PRE_INIT_ERROR ("Looks like Context.add_runtime_tag() or "
		      "Context.remove_runtime_tag() was used outside any parser.\n");
#endif

    up = ctx->frame;
#ifdef DEBUG
    if (up && up->using_thread != this_thread())
      PRE_INIT_ERROR ("Parent frame in use by thread %O, this is thread %O.\n",
		      up->using_thread, this_thread());
#endif
    ctx->frame = this_object();
    ctx->frame_depth++;
    FRAME_DEPTH_MSG ("%*s%O frame_depth increase line %d\n",
		     ctx->frame_depth, "", this_object(), __LINE__);

#undef PRE_INIT_ERROR

  process_tag:
    while (1) {			// Looping only when continuing in streaming mode.
      if (mixed err = catch {
	mixed orig_args = args;

	if (array state = ctx->unwind_state && ctx->unwind_state[this_object()]) {
	  object ignored;
	  [ignored, eval_state, in_args, in_content, iter,
	   subevaler, piece, exec, orig_tag_set,
	   ctx->new_runtime_tags, orig_make_p_code, csf, ctx->evaled_p_code
#ifdef DEBUG
	   , debug_iter
#endif
	  ] = state;
	  m_delete (ctx->unwind_state, this_object());
	  if (!sizeof (ctx->unwind_state)) ctx->unwind_state = 0;
	  ctx->make_p_code = orig_make_p_code;
	  THIS_TAG_TOP_DEBUG ("Continuing evaluation" +
			      (piece ? " with stream piece\n" : "\n"));
	}

	else {			// Initialize a new evaluation.
	  if (!(flags & FLAG_CUSTOM_TRACE))
	    TRACE_ENTER(tag ? "tag <" + tag->name + ">" : "tagless frame",
			tag || this_object());
#ifdef MODULE_LEVEL_SECURITY
	  if (object sec_obj =
	      this_object()->check_security_object || tag || this_object())
	    if (id->conf->check_security (sec_obj, id, id->misc->seclevel)) {
	      if (flags & FLAG_CUSTOM_TRACE)
		TRACE_ENTER(tag ? "tag <" + tag->name + ">" : "tagless frame",
			    tag || this_object());
	      THIS_TAG_TOP_DEBUG ("Access denied - exiting\n");
	      TRACE_LEAVE("access denied");
	      return result = nil;
	    }
#endif

	  orig_make_p_code = ctx->make_p_code;

	  if (functionp (args)) {
	    THIS_TAG_TOP_DEBUG ("Evaluating with compiled arguments\n");
	    args = (in_args = [EVAL_ARGS_FUNC] args) (ctx, evaler);
	    in_content = content;
	    if (!in_content || in_content == "") flags |= FLAG_MAY_CACHE_RESULT;
	    content = nil;
	  }

	  else if (flags & FLAG_UNPARSED) {
#ifdef DEBUG
	    if (!(flags & FLAG_PROC_INSTR) && !mappingp (args))
	      fatal_error ("args is not a mapping in unparsed frame: %O\n", args);
	    if (content && !stringp (content))
	      fatal_error ("content is not a string in unparsed frame: %O.\n", content);
#endif

	  eval_only: {
	    eval_and_compile:
	      if (ctx->make_p_code) {
		if (evaler->is_RXML_PCode) {
		  if (!(comp = evaler->p_code_comp)) {
		    comp = evaler->p_code_comp = PikeCompile();
		    THIS_TAG_TOP_DEBUG (
		      "%s", "Evaluating and compiling unparsed"
		      DO_IF_DEBUG (+ sprintf (" (with new %O in %O)\n",
					      comp, evaler)));
		  }
		  else
		    THIS_TAG_TOP_DEBUG (
		      "%s", "Evaluating and compiling unparsed"
		      DO_IF_DEBUG (+ sprintf (" (with old %O in %O)\n",
					      comp, evaler)));
		}

		else {
		  if (!evaler->p_code) {
		    // This can happen if a context with make_p_code
		    // set is used in a nested parse without
		    // compilation. Just clear it and continue
		    // (orig_make_p_code will restore it afterwards.
		    ctx->make_p_code = 0;
		    break eval_and_compile;
		  }

		  else
		    if (!(comp = evaler->p_code->p_code_comp)) {
		      comp = evaler->p_code->p_code_comp = PikeCompile();
		      THIS_TAG_TOP_DEBUG (
			"%s", "Evaluating and compiling unparsed"
			DO_IF_DEBUG (+ sprintf (" (with new %O in %O in %O)\n",
						comp, evaler->p_code, evaler)));
		    }
		    else
		      THIS_TAG_TOP_DEBUG (
			"%s", "Evaluating and compiling unparsed"
			DO_IF_DEBUG (+ sprintf (" (with old %O in %O in %O)\n",
						comp, evaler->p_code, evaler)));
		}

		in_args = _prepare (ctx, type, args && args + ([]), comp);
		ctx->state_updated++;
		PCODE_UPDATE_MSG ("%O (frame %O): P-code update to %d "
				  "since args have been compiled.\n",
				  ctx, this_object(), ctx->state_updated);
		break eval_only;
	      }

	      THIS_TAG_TOP_DEBUG ("Evaluating unparsed\n");
	      in_args = args;
	      _prepare (ctx, type, args && args + ([]), 0);
	      if (args == in_args) in_args = 0;
	    }

	    in_content = content;
	    if (!in_content || in_content == "") flags |= FLAG_MAY_CACHE_RESULT;
	  }

	  else {
	    THIS_TAG_TOP_DEBUG ("Evaluating with constant arguments and content\n");
	    _prepare (ctx, type, 0, 0);
	  }

	  result = piece = nil;
	  eval_state = EVSTAT_BEGIN;
	}

	if (!mappingp (args) && !(flags & FLAG_PROC_INSTR))
	  error ("args is not a mapping: %O (orig: %O, flags: %x)\n",
		 args, orig_args, flags);
	orig_args = 0;

	if (!zero_type (this_object()->parent_frame))
	  // Note: This could be done in _prepare, but then we'd have
	  // to fix some sort of frame addressing when saving the
	  // frame state.
	  if (up->local_tags && up->local_tags->has_tag (tag)) {
	    THIS_TAG_DEBUG ("Setting parent_frame to %O from local_tags\n", up);
	    this_object()->parent_frame = up;
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
	    this_object()->parent_frame = frame;
	  }

#ifdef MAGIC_HELP_ARG
	if ((args || ([]))->help) {
	  TRACE_ENTER(tag ? "tag <" + tag->name + " help>" : "tagless frame",
		      tag || this_object());
	  string help = id->conf->find_tag_doc (tag->name, id);
	  TRACE_LEAVE ("");
	  THIS_TAG_TOP_DEBUG ("Reporting help - frame done\n");
	  throw (Backtrace ("help", help, ctx));
	}
#endif

	switch (eval_state) {
	  case EVSTAT_BEGIN:
	    if (array|function(RequestID:array) do_enter =
		[array|function(RequestID:array)] this_object()->do_enter) {
	      EXEC_CALLBACK (ctx, csf, evaler, exec, do_enter, id);
	      EXEC_ARRAY (ctx, evaler, exec, do_enter);
	    }
	    else {
	      THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this_object());
	      TAG_ENTER_SCOPE (ctx, csf);
	    }
	    if (flags & FLAG_UNPARSED) content = nil;
	    eval_state = EVSTAT_ENTERED;

	    if (TagSet add_tags = [object(TagSet)] this_object()->additional_tags) {
	      TagSet tset = ctx->tag_set;
	      if (!tset->has_effective_tags (add_tags)) {
		THIS_TAG_DEBUG ("Installing additional_tags %O\n", add_tags);
		orig_tag_set = tset;
		TagSet comp_ts;
		GET_COMPOSITE_TAG_SET (add_tags, tset, comp_ts);
		ctx->tag_set = comp_ts;
	      }
	      else
		THIS_TAG_DEBUG ("Not installing additional_tags %O "
				"since they're already in the tag set\n", add_tags);
	    }
	    // Fall through.

	  case EVSTAT_ENTERED:
	  case EVSTAT_LAST_ITER:
	    int|function(RequestID:int) do_iterate =
	      [int|function(RequestID:int)] this_object()->do_iterate;
	    array|function(RequestID:array) do_process =
	      [array|function(RequestID:array)] this_object()->do_process;
	    int finished = 0;

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
		  THIS_TAG_DEBUG_ENTER_SCOPE (ctx, this_object());
		  TAG_ENTER_SCOPE (ctx, csf);
		  if (ctx->new_runtime_tags)
		    _handle_runtime_tags (ctx, evaler);
		  if (iter <= 0) eval_state = EVSTAT_LAST_ITER;
		}
	      }

#ifdef MODULE_DEBUG
	      if (flags & FLAG_IS_CACHE_STATIC && flags & FLAG_GET_EVALED_CONTENT)
		fatal_error ("FLAG_IS_CACHE_STATIC cannot be set when "
			     "FLAG_GET_EVALED_CONTENT is.\n");
#endif

	      if (ctx->evaled_p_code)
		// Record any variable changes from do_enter or do_iterate.
		ctx->evaled_p_code->add (ctx, nil, nil);

	      for (; iter > 0; iter-- DO_IF_DEBUG (, debug_iter++)) {
	      eval_content: {
		  PCode orig_evaled_p_code = ctx->evaled_p_code;
		  PCode unevaled_content = 0;
		  finished++;

		  if (subevaler)
		    finished = 0; // Continuing an unwound subevaler.

		  else if (!in_content || in_content == "") {
		    if (flags & FLAG_GET_EVALED_CONTENT) {
		      this_object()->evaled_content =
			PCode (content_type, ctx, 0, 0,
			       evaler->p_code_comp ||
			       evaler->p_code && evaler->p_code->p_code_comp);
		      this_object()->evaled_content->finish();
		    }

		    // No content to handle.
		    if (flags & FLAG_UNPARSED) {
		      if (content_type->sequential) {
			THIS_TAG_DEBUG ("Setting content to empty value: %s\n",
					format_short (
					  content_type->empty_value));
			content = content_type->copy_empty_value();
		      }
		      else if (flags & FLAG_CONTENT_VAL_REQ)
			parse_error ("Missing value for nonsequential "
				     "content of type %s.\n",
				     content_type->name);
		    }
		    break eval_content;
		  }

		  else {
		    if (!(flags & FLAG_IS_CACHE_STATIC)) {
		      if (orig_evaled_p_code)
			// Make sure that any variable changes that were
			// added during collection of the previous p-code
			// are added to it instead of the new one (if any).
			orig_evaled_p_code->add (ctx, nil, nil);
		      ctx->evaled_p_code = 0;
		    }

		    if (stringp (in_content)) {
		      if (flags & FLAG_EMPTY_ELEMENT)
			parse_error ("This tag doesn't handle content.\n");

		      else {	// The nested content is not yet parsed.
			if (finished > 1)
			  // Looped once. Always compile since it's
			  // likely we'll loop again.
			  ctx->make_p_code = 1;
			if (TagSet local_tags =
			    [object(TagSet)] this_object()->local_tags) {
			  if (flags & FLAG_GET_EVALED_CONTENT)
			    // Do not pass on a PikeCompile object here since
			    // the result p-code will typically have a
			    // different lifespan than the content p-code.
			    this_object()->evaled_content = ctx->evaled_p_code =
			      PCode (content_type, ctx, local_tags, 1);

			  PCode p_code = unevaled_content =
			    ctx->make_p_code &&
			    PCode (content_type, ctx, local_tags, 0,
				   ctx->evaled_p_code ? ctx->evaled_p_code->p_code_comp :
				   evaler->p_code_comp ||
				   evaler->p_code && evaler->p_code->p_code_comp);
			  // Must use the same PikeCompile object for both
			  // content and result collection since
			  // FLAG_DONT_CACHE_RESULT frames in the result p-code
			  // will resolve to the same compiled args function.

			  if (PCode evaled_p_code = ctx->evaled_p_code)
			    if (p_code) p_code->p_code = evaled_p_code;
			    else p_code = evaled_p_code;

			  subevaler = content_type->get_parser (
			    ctx, local_tags, evaler, p_code);
			  subevaler->_local_tag_set = 1;

			  THIS_TAG_DEBUG ("Iter[%d]: Parsing%s%s content %s "
					  "with %O from local_tags\n", debug_iter,
					  ctx->make_p_code ? " and compiling" : "",
					  ctx->evaled_p_code ?
					  " and result compiling" : "",
					  format_short (in_content), subevaler);
			}

			else {
			  if (flags & FLAG_GET_EVALED_CONTENT)
			    // Do not pass on a PikeCompile object here since
			    // the result p-code will typically have a
			    // different lifespan than the content p-code.
			    this_object()->evaled_content = ctx->evaled_p_code =
			      PCode (content_type, ctx, ctx->tag_set, 1);

			  PCode p_code = unevaled_content =
			    ctx->make_p_code &&
			    PCode (content_type, ctx, ctx->tag_set, 0,
				   ctx->evaled_p_code ? ctx->evaled_p_code->p_code_comp :
				   evaler->p_code_comp ||
				   evaler->p_code && evaler->p_code->p_code_comp);
			  // Must use the same PikeCompile object for both
			  // content and result collection since
			  // FLAG_DONT_CACHE_RESULT frames in the result p-code
			  // will resolve to the same compiled args function.

			  if (PCode evaled_p_code = ctx->evaled_p_code)
			    if (p_code) p_code->p_code = evaled_p_code;
			    else p_code = evaled_p_code;

			  subevaler = content_type->get_parser (
			    ctx, ctx->tag_set, evaler, p_code);

			  THIS_TAG_DEBUG ("Iter[%d]: Parsing%s%s content %s "
					  "with %O%s\n", debug_iter,
					  ctx->make_p_code ? " and compiling" : "",
					  ctx->evaled_p_code ?
					  " and result compiling" : "",
					  format_short (in_content), subevaler,
					  this_object()->additional_tags ?
					  " from additional_tags" : "");
			}

			if (evaler->recover_errors && !(flags & FLAG_DONT_RECOVER)) {
			  subevaler->recover_errors = 1;
			  if (unevaled_content)
			    unevaled_content->recover_errors = 1;
			  if (flags & FLAG_GET_EVALED_CONTENT)
			    this_object()->evaled_content->recover_errors = 1;
			}

			subevaler->finish (in_content); // Might unwind.
			finished = 1;
		      }
		    }

		    else {
		      subevaler = in_content;

		      if (flags & FLAG_GET_EVALED_CONTENT) {
			// Do not pass on a PikeCompile object here since
			// the result p-code will typically have a
			// different lifespan than the content p-code.
			PCode p_code =
			  this_object()->evaled_content = ctx->evaled_p_code =
			  PCode (content_type, ctx, subevaler->tag_set, 1);
			if (subevaler->recover_errors)
			  p_code->recover_errors = 1;
		      }

		      THIS_TAG_DEBUG ("Iter[%d]: Evaluating%s with compiled content\n",
				      debug_iter,
				      ctx->evaled_p_code ? " and result compiling" : "");
		    }
		  }

		eval_sub:
		  do {
		    if (piece != nil && flags & FLAG_STREAM_CONTENT) {
		      // Handle a stream piece.
		      THIS_TAG_DEBUG ("Iter[%d]: Got %s stream piece %s\n",
				      debug_iter, finished ? "ending" : "a",
				      format_short (piece));

		      if (!arrayp (do_process)) {
			EXEC_CALLBACK (ctx, csf, evaler, exec, do_process, id, piece);

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
			    ctx->unwind_state->reason = "streaming";
			    THIS_TAG_DEBUG ("Iter[%d]: Streaming %s from do_process\n",
					    debug_iter, format_short (res));
			    throw (this_object());
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
			mixed res = subevaler->_eval (
			  ctx,
			  flags & (FLAG_GET_EVALED_CONTENT|FLAG_IS_CACHE_STATIC) &&
			  ctx->evaled_p_code); // Might unwind.

			if (res == nil) {
			  if (content_type->sequential) {
			    THIS_TAG_DEBUG (
			      "Setting content to empty value: %s\n",
			      format_short (content_type->empty_value));
			    content = content_type->copy_empty_value();
			  }
			  else if (flags & FLAG_CONTENT_VAL_REQ)
			    parse_error ("Missing value for nonsequential "
					 "content of type %s.\n",
					 content_type->name);
			}
			else {
			  if (content_type->sequential)
			    SET_SEQUENTIAL (res, content, "content");
			  else
			    SET_NONNIL_NONSEQUENTIAL (res, content,
						      content_type, "content");
			}

			break eval_sub;
		      }
		    }

		    subevaler->finish(); // Might unwind.
		    finished = 1;
		  } while (1); // Only loops when an unwound subevaler has been recovered.

		  if (flags & FLAG_GET_EVALED_CONTENT)
		    this_object()->evaled_content->finish();
		  if (unevaled_content) {
		    unevaled_content->finish();

		    if (PikeCompile _p_code_comp =
			unevaled_content->p_code_comp)
		      // This will clean up delayed_resolve_places in
		      // the PikeCompile object, which may otherwise
		      // contain references to things that have a
		      // back-reference to this PCode object,
		      // generating garbage due to a reference cycle.
		      _p_code_comp->compile();

		    in_content = unevaled_content;
		    ctx->state_updated++;
		    PCODE_UPDATE_MSG ("%O (frame %O): P-code update to %d "
				      "since content has been compiled.\n",
				      ctx, this_object(), ctx->state_updated);
		    ctx->make_p_code = orig_make_p_code; // Reset before do_return.
		  }
		  flags |= FLAG_MAY_CACHE_RESULT;

		  ctx->evaled_p_code = orig_evaled_p_code;
		  subevaler = 0;
		}

		if (do_process) {
		  EXEC_CALLBACK (ctx, csf, evaler, exec, do_process, id);
		  EXEC_ARRAY (ctx, evaler, exec, do_process);
		}
	      }
	    } while (eval_state != EVSTAT_LAST_ITER);
	    eval_state = EVSTAT_ITER_DONE;
	    // Fall through.

	  case EVSTAT_ITER_DONE:
	    if (array|function(RequestID,void|PCode:array) do_return =
		[array|function(RequestID,void|PCode:array)] this_object()->do_return) {
	      EXEC_CALLBACK (ctx, csf, evaler, exec, do_return, id,
			     objectp (in_content) && in_content);
	      if (exec) {
		// We don't use EXEC_ARRAY here since there's no idea
		// to come back even if any streaming should be done.
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
	}

	mixed conv_result = nil; // Result converted to the expected type.
	if (result != nil)
	  CONV_RESULT (result, result_type, conv_result, type);
#ifdef DEBUG
	else THIS_TAG_DEBUG ("Skipping nil result\n");
#endif
#ifdef MODULE_DEBUG
	if (flags & FLAG_IS_CACHE_STATIC &&
	    content_type->name != result_type->name)
	  fatal_error ("Frame got FLAG_IS_CACHE_STATIC set, "
		       "but the content (%s) and result (%s) types differ.\n",
		       content_type->name, result_type->name);
#endif

	THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this_object());
	TAG_LEAVE_SCOPE (ctx, csf);

	if (ctx->new_runtime_tags)
	  _handle_runtime_tags (ctx, evaler);

#define CLEANUP do {							\
	  DO_IF_DEBUG (							\
	    if (id && ctx->misc != id->misc->defines)			\
	      fatal_error ("ctx->misc != ctx->id->misc->defines\n"	\
			   "%O != %O\n",				\
			   ctx->misc, ctx->id->misc->defines);		\
	  );								\
	  if (mixed err = catch { cleanup(); }) {			\
	    master()->handle_error(err);				\
	  }								\
	  if (in_args) {						\
	    args = in_args;						\
	    if (stringp (in_args))					\
	      comp->delayed_resolve (this_object(), "args");		\
	  }								\
	  if (in_content) content = in_content;				\
	  ctx->make_p_code = orig_make_p_code;				\
	  if (orig_tag_set) ctx->tag_set = orig_tag_set;		\
	  if (up)							\
	    if (int f = flags & (FLAG_DONT_CACHE_RESULT|FLAG_MAY_CACHE_RESULT)) \
	      up->flags |= f;						\
	  ctx->frame = up;						\
	  FRAME_DEPTH_MSG ("%*s%O frame_depth decrease line %d\n",	\
			   ctx->frame_depth, "", this_object(),		\
			   __LINE__);					\
	  ctx->frame_depth--;						\
	  DO_IF_DEBUG (using_thread = 0);				\
	} while (0)
	
	CLEANUP;
	
	THIS_TAG_TOP_DEBUG ("Done%s\n",
			    flags & FLAG_DONT_CACHE_RESULT ?
			    " (don't cache result)" :
			    !(flags & FLAG_MAY_CACHE_RESULT) ?
			    " (don't cache result for now)" : "");
	if (!(flags & FLAG_CUSTOM_TRACE))
	  TRACE_LEAVE ("");
	return conv_result;

      }) {			// Exception handling.
	THIS_TAG_DEBUG_LEAVE_SCOPE (ctx, this_object());
	TAG_LEAVE_SCOPE (ctx, csf);

      unwind:
	if (objectp (err) && ([object] err)->thrown_at_unwind)
#ifdef MODULE_DEBUG
	  if (eval_state == EVSTAT_NONE)
	    fatal_error ("Can't save parser state when evaluating arguments.\n");
	  else
#endif
	  {
	    string action;
	    UNWIND_STATE ustate = ctx->unwind_state;
	    if (!ustate) ustate = ctx->unwind_state = ([]);
#ifdef DEBUG
	    if (ustate[this_object()])
	      fatal_error ("Frame already has an unwind state.\n");
#endif

	    if (ustate->exec_left) {
	      exec = [array] ustate->exec_left;
	      m_delete (ustate, "exec_left");
	    }

	    if (err == this_object() || exec && sizeof (exec) && err == exec[0])
	      // This frame or a frame in the exec array wants to stream.
	      if (evaler->read && evaler->unwind_safe) {
		// Rethrow to continue in parent since we've already done
		// the appropriate do_process stuff in this frame in
		// either case.
		mixed piece = evaler->read();
		if (err = catch {
		  if (type->sequential)
		    SET_SEQUENTIAL (ustate->stream_piece, piece, "stream piece");
		  else
		    SET_NONSEQUENTIAL (ustate->stream_piece, piece, type, "stream piece");
		}) break unwind;
		if (err == this_object()) err = 0;
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
	      THIS_TAG_TOP_DEBUG ("Continuing with stream piece.\n");
	    }
	    else {
	      action = "break";	// Some other reason - back up to the top.
	      THIS_TAG_TOP_DEBUG ("Interrupted\n");
	    }

	    ustate[this_object()] = ({err, eval_state, in_args, in_content, iter,
				      subevaler, piece, exec, orig_tag_set,
				      ctx->new_runtime_tags, orig_make_p_code,
				      csf, ctx->evaled_p_code,
#ifdef DEBUG
				      debug_iter,
#endif
				    });
	    TRACE_LEAVE (action);

	    switch (action) {
	      case "break":	// Throw and handle in parent frame.
#ifdef MODULE_DEBUG
		if (!evaler->unwind_state)
		  fatal_error ("Trying to unwind inside an evaluator "
			       "that isn't unwind safe.\n");
#endif
		throw (this_object());
	      case "continue": // Continue in this frame with the stored state.
		continue process_tag;
	    }
	    fatal_error ("Should not get here.\n");
	  }

	THIS_TAG_TOP_DEBUG ("Exception%s\n",
			    flags & FLAG_DONT_CACHE_RESULT ?
			    " (don't cache result)" :
			    !(flags & FLAG_MAY_CACHE_RESULT) ?
			    " (don't cache result for now)" : "");
	TRACE_LEAVE ("exception");
	err = catch (throw_fatal (err));
	CLEANUP;
	result = nil;
	throw (err);
      }
      fatal_error ("Should not get here.\n");
    }
    fatal_error ("Should not get here.\n");
  }

  array _save()
  {
    THIS_TAG_TOP_DEBUG ("Saving persistent state\n");
    // Note: Caller assumes element zero is the args value in case
    // it's a delay resolved function, i.e. a string.
    return ({copy_value (args), copy_value (content), flags,
	     content_type, result_type,
	     this_object()->raw_tag_text,
	     this_object()->save && this_object()->save()});
  }

  void _restore (array saved)
  {
    [args, content, flags, content_type, result_type,
     string raw_tag_text, mixed user_saved] = saved;
    if (raw_tag_text) this_object()->raw_tag_text = raw_tag_text;
    if (user_saved) restore (user_saved);
  }

  Frame _clone_empty()
  {
    Frame new = object_program (this_object())();
    new->flags = flags;
    new->tag = tag;
    return new;
  }

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (void|int flag)
  {
    return flag == 'O' &&
      ((function_name (object_program (this)) || "RXML.Frame") +
       "(" + (tag && [string] tag->name) + ")" + OBJ_COUNT);
  }
}


// Global services.

//! Shortcuts to some common functions in the current context (see the
//! corresponding functions in the @[Context] class for details).
final mixed get_var (string|array(string|int) var, void|string scope_name,
		     void|Type want_type)
  {return RXML_CONTEXT->get_var (var, scope_name, want_type);}
final mixed user_get_var (string var, void|string scope_name, void|Type want_type)
  {return RXML_CONTEXT->user_get_var (var, scope_name, want_type);}
final mixed set_var (string|array(string|int) var, mixed val, void|string scope_name)
  {return RXML_CONTEXT->set_var (var, val, scope_name);}
final mixed user_set_var (string var, mixed val, void|string scope_name)
  {return RXML_CONTEXT->user_set_var (var, val, scope_name);}
final void delete_var (string|array(string|int) var, void|string scope_name)
  {RXML_CONTEXT->delete_var (var, scope_name);}
final void user_delete_var (string var, void|string scope_name)
  {RXML_CONTEXT->user_delete_var (var, scope_name);}

final void run_error (string msg, mixed... args)
//! Throws an RXML run error with a dump of the parser stack in the
//! current context. This is intended to be used by tags for errors
//! that can occur during normal operation, such as when the
//! connection to an SQL server fails.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  TAG_DEBUG (RXML_CONTEXT && RXML_CONTEXT->frame, "Throwing run error: %s", msg);
  throw (Backtrace ("run", msg, RXML_CONTEXT, bt[..sizeof (bt) - 2]));
}

final void parse_error (string msg, mixed... args)
//! Throws an RXML parse error with a dump of the parser stack in the
//! current context. This is intended to be used for programming
//! errors in the RXML code, such as lookups in nonexisting scopes and
//! invalid arguments to a tag.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  TAG_DEBUG (RXML_CONTEXT && RXML_CONTEXT->frame, "Throwing parse error: %s", msg);
  throw (Backtrace ("parse", msg, RXML_CONTEXT, bt[..sizeof (bt) - 2]));
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

final void throw_fatal (mixed err, void|string current_var)
//! Mainly used internally to throw an error that includes the RXML
//! frame backtrace.
{
  if (objectp (err) && err->is_RXML_Backtrace) {
    if (!err->current_var) err->current_var = current_var;
  }
  else if (arrayp (err) && sizeof (err) == 2 ||
	   objectp (err) && err->is_generic_error) {
    string msg;
    if (catch (msg = err[0])) throw (err);
    if (stringp (msg) && !has_value (msg, "\nRXML frame backtrace:\n")) {
      Backtrace rxml_bt = Backtrace();
      rxml_bt->current_var = current_var;
      string descr = rxml_bt->describe_rxml_backtrace (1);
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
//! @ul
//!  @item
//!   Arrays are indexed with 1 for the first element, or
//!   alternatively -1 for the last. Indexing an array of size n with
//!   0, n+1 or greater, -n-1 or less, or with a noninteger is an
//!   error.
//!  @item
//!   Strings, along with integers and floats, are treated as simple
//!   scalar types which aren't really indexable. If a scalar type is
//!   indexed with 1 or -1, it produces itself instead of generating
//!   an error. (This is a convenience to avoid many special cases
//!   when treating both arrays and scalar types.)
//!  @item
//!   @[RXML.nil] and the undefined value is also treated as a scalar
//!   type wrt indexing, i.e. it produces itself if indexed with 1 or
//!   -1.
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
//! @endul
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

  object val_obj;
  if (mixed err = catch {
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
	  parse_error( "Cannot index the array in %s with %s.\n",
		       scope_name, format_short (index) );
      else if (val == nil) {
	if (!(<1, -1>)[index])
	  parse_error ("%s produced no value to index with %s.\n",
		       scope_name, format_short (index));
      }
      else if( objectp( val ) && val->`[] ) {
	val_obj = val;
	if (zero_type (
	      val = ([object(Scope)] val)->`[](
		index, ctx, scope_name,
		i == sizeof (idxpath) && (scope_got_type = 1, want_type))))
	  val = nil;
#ifdef MODULE_DEBUG
	else if (mixed err = scope_got_type && want_type && val != nil &&
		 !(objectp (val) && ([object] val)->rxml_var_eval) &&
		 catch (want_type->type_check (val)))
	  if (objectp (err) && ([object] err)->is_RXML_Backtrace)
	    fatal_error ("%O->`[] didn't return a value of the correct type:\n%s",
			 val_obj, err->msg);
	  else throw (err);
#endif
	val_obj = 0;
      }
      else if( mappingp( val ) || objectp (val) ) {
	if (zero_type (val = val[ index ])) val = nil;
      }
      else if (multisetp (val)) {
	if (!val[index]) val = nil;
      }
      else if (!(<1, -1>)[index])
	parse_error ("%s is %s which cannot be indexed with %s.\n",
		     scope_name, format_short (val), format_short (index));

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
	  fatal_error ("Cyclic rxml_var_eval chain detected in %s.\n"
		       "All called objects:%{ %O%}\n",
		       format_short (val), indices (called));
	called[val] = 1;
#endif
	val_obj = val;
	if (zero_type (val = ([object(Value)] val)->rxml_var_eval (
			 ctx, index, scope_name, 0))) {
	  val = nil;
	  val_obj = 0;
	  break;
	}
	else if (val == val_obj)
	  break;
	val_obj = 0;
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
	fatal_error ("Cyclic rxml_var_eval chain detected in %s.\n"
		     "All called objects:%{ %O%}\n",
		     format_short (val), indices (called));
      called[val] = 1;
#endif
      val_obj = val;
      if (zero_type (val = ([object(Value)] val)->rxml_var_eval (
		       ctx, index, scope_name, want_type)) ||
	  val == nil)
	return ([])[0];
      else if (val == val_obj)
	return val;
#ifdef MODULE_DEBUG
      else if (mixed err = want_type && catch (want_type->type_check (val)))
	if (objectp (err) && ([object] err)->is_RXML_Backtrace)
	  fatal_error ("%O->rxml_var_eval didn't return a value of the correct type:\n%s",
		       val_obj, err->msg);
	else throw (err);
#endif
    } while (objectp (val) && ([object] val)->rxml_var_eval);
    return val;

  }) {
    string current_var;
    if (val_obj && val_obj->format_rxml_backtrace_frame)
      if (mixed err2 = catch {
	  current_var = val_obj->format_rxml_backtrace_frame (ctx, index, scope_name);
	})
	master()->handle_error (err2);
    throw_fatal (err, current_var);
  }
}

final void tag_debug (string msg, mixed... args)
//! Writes the message to the debug log if the innermost tag being
//! executed has FLAG_DEBUG set.
{
  if (Frame f = RXML_CONTEXT->frame) // It's intentional that this assumes a context.
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
  TagSet tag_set = RXML_CONTEXT->tag_set;
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
  TagSet tag_set = RXML_CONTEXT->tag_set;
  Tag tag = overridden_by ? tag_set->get_overridden_tag (overridden_by) :
    tag_set->get_tag (name);
  if (!tag) return 0;
  Frame frame = tag (args, content || "");
  frame->flags |= FLAG_UNPARSED;
  return frame;
}

//! Returns a frame that, when evaluated, parses the given string
//! according to the type (which typically has a parser set).
//!
//! @note
//! In an exec array it's more efficient to return the string directly
//! and set the appropriate parser on the result type.
final class parse_frame
{
  inherit Frame;
  int flags = FLAG_UNPARSED|FLAG_PROC_INSTR; // Make it a PI so we avoid the argmap.

  //!
  protected void create (Type type, string to_parse)
  {
    if (type) {			// Might be created from decode or _clone_empty.
      content_type = type, result_type = type (PNone);
      content = to_parse;
    }
  }

  array _encode()
  {
    return ({content_type, content});
  }

  void _decode (array data)
  {
    [content_type, content] = data;
    result_type = content_type (PNone);
  }

  string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("RXML.parse_frame(%O)", content_type);
  }
}


// Parsers:


class Parser
//! Interface class for a syntax parser that scans, parses and
//! evaluates an input stream. Access to a parser object is assumed to
//! be done in a thread safe way except where noted.
//!
//! The parser program should be registered with
//! @[RXML.register_parser] at initialization (e.g. in a
//! @tt{create(}@} function in the module) to enable p-code encoding
//! with it.
//!
//! write() and write_end() are the functions to use from outside
//! the parser system, not feed() or finish().
{
  constant is_RXML_Parser = 1;
  constant thrown_at_unwind = 1;

  // Services:

  function(Parser:void) data_callback;
  //! A function to be called when data is likely to be available from
  //! eval(). It's always called when the source stream closes.

  int write (string in)
  //! Writes some source data to the parser. Returns nonzero if there
  //! might be data available in eval().
  {
    //werror ("%O write %s\n", this_object(), format_short (in));
    int res;
    ENTER_CONTEXT (context);
  eval:
    if (mixed err = catch {
      if (context && context->unwind_state && context->unwind_state->top) {
#ifdef MODULE_DEBUG
	if (context->unwind_state->top != this_object())
	  fatal_error ("The context got an unwound state from another parser. "
		       "Can't rewind.\n");
#endif
	m_delete (context->unwind_state, "top");
	m_delete (context->unwind_state, "reason");
	if (!sizeof (context->unwind_state)) context->unwind_state = 0;
      }
      if (feed (in)) res = 1; // Might unwind.
      if (res && data_callback) data_callback (this_object());
    }) {
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
#ifdef DEBUG
	if (err != this_object())
	  err = catch (fatal_error ("Unexpected unwind object catched.\n"));
#endif
	if (!context->unwind_state) context->unwind_state = ([]);
	context->unwind_state->top = err;
	break eval;
      }
      if (p_code && p_code->p_code_comp)
	// Fix all delayed resolves in any ongoing p-code compilation.
	p_code->p_code_comp->compile();
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
    //werror ("%O write_end %s\n", this_object(), format_short (in));
    ENTER_CONTEXT (context);
  eval:
    if (mixed err = catch {
      if (context && context->unwind_state && context->unwind_state->top) {
#ifdef MODULE_DEBUG
	if (context->unwind_state->top != this_object())
	  fatal_error ("The context got an unwound state from another parser. "
		       "Can't rewind.\n");
#endif
	m_delete (context->unwind_state, "top");
	m_delete (context->unwind_state, "reason");
	if (!sizeof (context->unwind_state)) context->unwind_state = 0;
      }
      finish (in); // Might unwind.
      if (data_callback) data_callback (this_object());
    }) {
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
#ifdef DEBUG
	if (err != this_object())
	  err = catch (fatal_error ("Unexpected unwind object catched.\n"));
#endif
	if (!context->unwind_state) context->unwind_state = ([]);
	context->unwind_state->top = err;
	break eval;
      }
      if (p_code && p_code->p_code_comp)
	// Fix all delayed resolves in any ongoing p-code compilation.
	p_code->p_code_comp->compile();
      LEAVE_CONTEXT();
      throw_fatal (err);
    }
    LEAVE_CONTEXT();
  }

  mixed handle_var (string varref, Type want_type)
  // Parses and evaluates a possible variable reference, with the
  // appropriate error handling.
  {
    // Note: VarRef.get more or less duplicates this; this is never
    // called from p-code.

    string encoding;
    array(string|int) splitted;
    mixed val;

    // It's intentional that we split on the first ':' for now, to
    // allow for future enhancements of this syntax. Scope and
    // variable names containing ':' are thus not accessible this way.
    sscanf (varref, "%[^:]:%s", varref, encoding);
    context->frame_depth++;
    FRAME_DEPTH_MSG ("%*s%O frame_depth increase line %d\n",
		     context->frame_depth, "", varref, __LINE__);

    splitted = context->parse_user_var (varref, 1);
    if (splitted[0] == 1) {
      Backtrace err =
	catch (parse_error ("No scope in variable reference.\n"
			    "(Use ':' in front to quote a "
			    "character reference containing dots.)\n"));
      err->current_var = "&" + varref + ";";
      context->handle_exception (err, this_object(), p_code);
      val = nil;
    }

    else {
      if (mixed err = catch {
#ifdef DEBUG
	if (TAG_DEBUG_TEST (context->frame))
	  TAG_DEBUG (context->frame, "    Looking up variable %s in context of type %s\n",
		     splitted * ".", (encoding ? t_any_text : want_type)->name);
#endif

	COND_PROF_ENTER(mixed id=context->id,varref,"entity");
	if (zero_type (val = context->get_var ( // May throw.
			 splitted[1..], splitted[0],
			 encoding ? t_any_text : want_type)))
	  val = nil;
	COND_PROF_LEAVE(mixed id=context->id,varref,"entity");

	if (encoding) {
	  if (!(val = Roxen->roxen_encode (val + "", encoding)))
	    parse_error ("Unknown encoding %O.\n", encoding);
#ifdef DEBUG
	  if (TAG_DEBUG_TEST (context->frame))
	    TAG_DEBUG (context->frame, "    Got value %s after conversion "
		       "with encoding %s\n", format_short (val), encoding);
#endif
	  if (want_type->empty_value != "")
	    val = want_type->encode (val, t_any_text);
	}
#ifdef DEBUG
	else
	  if (TAG_DEBUG_TEST (context->frame))
	    TAG_DEBUG (context->frame, "    Got value %s\n", format_short (val));
#endif

      }) {
	string current_var;
	if (objectp (err) && err->is_RXML_Backtrace)
	  if (err->current_var) current_var = err->current_var;
	  else current_var = err->current_var = "&" + varref + ";";
	else current_var = "&" + varref + ";";
	if ((err = catch {
	  context->handle_exception (err, this_object()); // May throw.
	})) {
	  VarRef varref = VarRef (splitted[0], splitted[1..], encoding, want_type);
	  if (p_code) p_code->add (context, varref, varref);
	  FRAME_DEPTH_MSG ("%*s%O frame_depth increase line %d\n",
			   context->frame_depth, "", varref, __LINE__);
	  context->frame_depth--;
	  throw_fatal (err, current_var);
	}
	val = nil;
      }

      if (p_code)
	p_code->add (context,
		     VarRef (splitted[0], splitted[1..], encoding, want_type), val);
    }
    FRAME_DEPTH_MSG ("%*s%O frame_depth increase line %d\n",
		     context->frame_depth, "", varref, __LINE__);
    context->frame_depth--;
    return val;
  }

  // Interface:

  //! @decl constant string name;
  //!
  //! Unique parser name. Required and considered constant.
  //!
  //! The name may contain the characters @tt{[0-9a-zA-Z_.-]@}.

  Context context;
  //! The context to do evaluation in. It's assumed to never be
  //! modified asynchronously during the time the parser is working on
  //! an input stream.

  Type type;
  //! The expected result type of the current stream. (The parser
  //! should not do any type checking on this.)

  PCode p_code;
  //! Must be set to a new @[PCode] object before a stream is fed
  //! which should be compiled to p-code. The object can be used to
  //! repeat the evaluation after the stream is finished.

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
  //! is only called when @[type->free_text] is nonzero and
  //! @[recover_errors] is nonzero. @[msg] should be stored in the
  //! output queue to be returned by @[eval]. If the context is bad
  //! for an error message, do nothing and return zero. The parser
  //! will then be aborted and the error will be propagated instead.
  //! Return nonzero if a message was written.

  optional mixed read();
  //! Define to allow streaming operation. Returns the evaluated
  //! result so far, but does not do any more evaluation. Returns
  //! @[RXML.nil] if there's no data.

  mixed eval (void|int eval_piece);
  //! Evaluates the data fed so far and returns the result. The result
  //! returned by previous @[eval] calls should not be returned again
  //! as (part of) this return value. Returns @[RXML.nil] if there's
  //! no data (for sequential types the empty value is also ok). If
  //! @[eval_piece] is nonzero, the evaluation may break prematurely
  //! due to streaming/nonblocking operation.
  //! @[context->incomplete_eval] will return nonzero in that case.
  //!
  //! @note
  //! The implementation must call @[context->eval_finish] after all
  //! other evaluation is done and the input stream is finished.

  optional void reset (Context ctx, Type type, PCode p_code, mixed... args);
  //! Define to support reuse of a parser object. It'll be called
  //! instead of making a new object for a new stream. It keeps the
  //! static configuration, i.e. the type (and tag set when used in
  //! @[TagSetParser]). Note that this function needs to deal with
  //! leftovers from @[TagSetParser.add_runtime_tag] for
  //! @[TagSetParser] objects. It should call @[initialize] with the
  //! given context and type to reset this base class properly.

  optional Parser clone (Context ctx, Type type, PCode p_code, mixed... args);
  //! Define to create new parser objects by cloning instead of
  //! creating from scratch. It returns a new instance of this parser
  //! with the same static configuration, i.e. the type (and tag set
  //! when used in TagSetParser).

  protected void create (Context ctx, Type type, PCode p_code, mixed... args)
  //! Should (at least) call @[initialize] with the given context and
  //! type.
  {
    initialize (ctx, type, p_code);
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  protected void initialize (Context ctx, Type _type, PCode _p_code)
  //! Does the required initialization for this base class. Use from
  //! @[create] and @[reset] (when it's defined) to initialize or
  //! reset the parser object properly.
  {
    context = ctx;
    type = _type;
    p_code = _p_code;
  }

  string current_input() {return 0;}
  //! Should return the representation in the input stream for the
  //! current tag, entity or text being parsed, or 0 if it isn't
  //! known.

  // Internals:

  // We assume these objects always are globally referenced.
  constant pike_cycle_depth = 0;

  mixed _eval (Context ignored, PCode more_p_code)
  // To be call compatible with PCode.
  {
#ifdef DEBUG
    if (more_p_code)
      // Since parsers can do evaluation already in feed() and
      // finish(), we can't add an extra p-code object here to compile
      // to. But allow it if it's already in the p-code chain.
      check_p_code: {
	for (PCode p = p_code; p; p = p->p_code)
	  if (more_p_code == p) break check_p_code;
	error ("New PCode object registered too late in parser.\n");
      }
#endif
    return eval();
  }

  constant p_code_comp = 0;
  // To ensure that this identifier is free; other code might do
  // evaler->p_code_comp, where evaler is either a Parser or a PCode.

  Parser _next_free;
  // Used to link together unused parser objects for reuse.

  Parser _parent;
  // The parent parser if this one is nested. This is only used to
  // register runtime tags.

  int _local_tag_set;
  // The local tag set, if any. It's actually used only in
  // TagSetParser, but defined here so that no special cases are
  // needed when assigning the value.

  //! @ignore
  MARK_OBJECT_ONLY;
  //! @endignore

  string _sprintf (void|int flag)
  {
    return flag == 'O' &&
      sprintf ("%s(%O)%s",
	       function_name (object_program (this)) || "RXML.Parser",
	       type, OBJ_COUNT);
  }
}

void register_parser (program/*(Parser)*/ parser_prog)
{
#ifdef DEBUG
  if (!stringp (parser_prog->name))
    error ("Parser %s lacks name.\n", Program.defined (parser_prog));
#endif
  if (zero_type (reg_parsers[parser_prog->name]))
    reg_parsers[parser_prog->name] = parser_prog;
  else if (reg_parsers[parser_prog->name] != parser_prog)
    error ("Cannot register duplicate parser %O.\n"
	   "Old parser program is %s,\n"
	   "New parser program is %s.\n", parser_prog->name,
	   Program.defined (reg_parsers[parser_prog->name]),
	   Program.defined (parser_prog));
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

  // Services:

  mixed eval (void|int eval_piece)
  {
    mixed res = read();
    if (!eval_piece)
      while (context->incomplete_eval()) {
	write_end();
	res = add_to_value (type, res, read());
      }
    return res;
  }

  // Interface:

  TagSet tag_set;
  //! The tag set used for parsing.

  //! In addition to the type, the tag set is part of the static
  //! configuration.
  optional void reset (Context ctx, Type type, PCode p_code,
		       TagSet tag_set, mixed... args);
  optional Parser clone (Context ctx, Type type, PCode p_code,
			 TagSet tag_set, mixed... args);
  protected void create (Context ctx, Type type, PCode p_code,
			 TagSet tag_set, mixed... args)
  {
    initialize (ctx, type, p_code, tag_set);
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  protected void initialize (Context ctx, Type type, PCode p_code,
			     TagSet _tag_set)
  {
    ::initialize (ctx, type, p_code);
    tag_set = _tag_set;
  }

  mixed read();
  //! No longer optional in this class. Since the evaluation is done
  //! in @[Tag.handle_tag] or similar, this always does the same as
  //! eval().
  //!
  //! @note
  //! The implementation must call @[context->eval_finish] after all
  //! other evaluation is done and the input stream is finished.

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

  // Internals:

  string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("RXML.TagSetParser(%O,%O)%s", type, tag_set, OBJ_COUNT);
  }
}


class PNone
//! The identity parser. It only returns its input.
{
  protected inherit String.Buffer;
  inherit Parser;

  constant name = "none";

  int feed (string in)
  {
    add (in);
    return 1;
  }

  void finish (void|string in)
  {
    if (in) add (in);
    if (p_code) {
      string data = get();
      p_code->add (context, data, data);
      add (data);
    }
  }

  string eval()
  {
    return get();
  }

  void reset (Context ctx, Type type, PCode p_code)
  {
    initialize (ctx, type, p_code);
    get();
  }

  protected void create (Context ctx, Type type, PCode p_code)
  {
    initialize (ctx, type, p_code);
#ifdef RXML_OBJ_DEBUG
    __object_marker->create (this_object());
#endif
  }

  string _sprintf (int flag)
  {
    return flag == 'O' && ("RXML.PNone()" + OBJ_COUNT);
  }
}


mixed simple_parse (string in, void|program parser)
//! A convenience function to parse a string with no type info, no tag
//! set, and no variable references. The parser defaults to PExpr.
{
  // FIXME: Recycle contexts?
  return t_any (parser || PExpr)->eval (in, Context (empty_tag_set));
}


// Types:


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

  // Services:

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

#ifdef TYPE_OBJ_DEBUG
#  define TDEBUG_MSG(X...) (report_debug (X))
#else
#  define TDEBUG_MSG(X...) 0
#endif

  Type `() (program/*(Parser)HMM*/ newparser, mixed... parser_args)
  //! Returns a type identical to this one, but which has the given
  //! parser. parser_args is passed as extra arguments to the
  //! create()/reset()/clone() functions.
  {
    TDEBUG_MSG ("%O(%s%{, %O%})", this_object(), newparser->name, parser_args);
    Type newtype;
    if (sizeof (parser_args)) {	// Can't cache this.
      newtype = clone();
      newtype->parser_prog = newparser;
      newtype->parser_args = parser_args;
      if (newparser->tag_set_eval) newtype->_p_cache = set_weak_flag (([]), 1);
      TDEBUG_MSG (" got args, can't cache\n");
    }
    else {
      if (!_t_obj_cache) _t_obj_cache = ([]);
      if (!(newtype = _t_obj_cache[newparser]))
	if (newparser == parser_prog) {
	  _t_obj_cache[newparser] = newtype = this_object();
	  TDEBUG_MSG (" caching and returning this object\n");
	}
	else {
	  _t_obj_cache[newparser] = newtype = clone();
	  newtype->parser_prog = newparser;
	  if (newparser->tag_set_eval) newtype->_p_cache = set_weak_flag (([]), 1);
	  TDEBUG_MSG (" returning cloned type %O\n", newtype);
	}
      else
	TDEBUG_MSG (" returning %O from cache\n", newtype);
    }
#ifdef DEBUG
    if (reg_types[this_object()->name]->parser_prog != PNone)
      error ("Incorrect type object registered in reg_types.\n");
#endif
    return newtype;
  }

#ifdef PARSER_OBJ_DEBUG
#  define PDEBUG_MSG(X...) \
  (report_debug ("%O->get_parser(): ", this_object()), report_debug (X))
#else
#  define PDEBUG_MSG(X...) 0
#endif

  inline final Parser get_parser (Context ctx, void|TagSet tag_set,
				  void|Parser|PCode parent, void|int|PCode make_p_code)
  //! Returns a parser instance initialized with the given context. If
  //! @[make_p_code] is nonzero, the parser will be initialized with a
  //! @[PCode] object so that it compiles during evaluation. If
  //! @[make_p_code] is a @[PCode] object, it's reset and used
  //! directly, otherwise a new object is created.
  {
    PCode p_code = 0;
    if (make_p_code)
      p_code = objectp (make_p_code) ? make_p_code : PCode (this_object(), ctx, tag_set);

    Parser p;
    if (_p_cache) {		// It's a tag set parser.
#ifdef DEBUG
      if (!tag_set) error ("Tag set not given for tag set parser.\n");
#endif

      if (parent && parent->is_RXML_TagSetParser &&
	  tag_set == parent->tag_set && sizeof (ctx->runtime_tags) &&
	  parent->clone && parent->type->name == this_object()->name) {
	// There are runtime tags. Try to clone the parent parser if
	// all conditions are met.
	p = parent->clone (ctx, this_object(), p_code, tag_set, @parser_args);
	p->_parent = parent;
	PDEBUG_MSG ("Cloned parent parser with runtime tags to %O\n", p);
	return p;
      }

      // vvv Using interpreter lock from here.
      PCacheObj pco = _p_cache[tag_set];
      if (pco && pco->tag_set_gen == tag_set->generation) {
	if ((p = pco->free_parser)) {
	  pco->free_parser = p->_next_free;
	  // ^^^ Using interpreter lock to here.
	  p->data_callback = 0;
	  p->reset (ctx, this_object(), p_code, tag_set, @parser_args);
#ifdef RXML_OBJ_DEBUG
	  p->__object_marker->create (p);
#endif
	  PDEBUG_MSG ("Reuse of free tag set parser %O\n", p);
	}

	else
	  // ^^^ Using interpreter lock to here.
	  if (pco->clone_parser) {
	    p = pco->clone_parser->clone (
	      ctx, this_object(), p_code, tag_set, @parser_args);
	    PDEBUG_MSG ("Cloned tag set parser to %O\n", p);
	  }
	  else if ((p = parser_prog (
		      ctx, this_object(), p_code, tag_set, @parser_args))->clone) {
	    // pco->clone_parser might already be initialized here due
	    // to race, but that doesn't matter.
	    p->context = p->p_code = 0; // Don't leave this stuff in the clone master.
#ifdef RXML_OBJ_DEBUG
	    p->__object_marker->create (p);
#endif
	    PDEBUG_MSG ("Made tag set clone parser (1) %O\n", p);
	    p = (pco->clone_parser = p)->clone (
	      ctx, this_object(), p_code, tag_set, @parser_args);
	    PDEBUG_MSG ("Cloned it to %O\n", p);
	  }
      }

      else {
	// ^^^ Using interpreter lock to here.
	pco = PCacheObj();
	pco->tag_set_gen = tag_set->generation;
	_p_cache[tag_set] = pco; // Might replace an object due to race, but that's ok.
	if ((p = parser_prog (
	       ctx, this_object(), p_code, tag_set, @parser_args))->clone) {
	  // pco->clone_parser might already be initialized here due
	  // to race, but that doesn't matter.
	  p->context = p->p_code = 0; // Don't leave this stuff in the clone master.
#ifdef RXML_OBJ_DEBUG
	  p->__object_marker->create (p);
#endif
	  PDEBUG_MSG ("Made tag set clone parser (2) %O\n", p);
	  p = (pco->clone_parser = p)->clone (
	    ctx, this_object(), p_code, tag_set, @parser_args);
	  PDEBUG_MSG ("Cloned it to %O\n", p);
	}
      }

      if (ctx->tag_set == tag_set && p->add_runtime_tag && sizeof (ctx->runtime_tags)) {
	PDEBUG_MSG ("Adding %d runtime tags to %O\n", sizeof (ctx->runtime_tags), p);
	foreach (ctx->runtime_tags;; Tag tag)
	  p->add_runtime_tag (tag);
      }
    }

    else {
      if ((p = free_parser)) {
	// Relying on interpreter lock here.
	free_parser = p->_next_free;
	p->data_callback = 0;
	p->reset (ctx, this_object(), p_code, @parser_args);
#ifdef RXML_OBJ_DEBUG
	p->__object_marker->create (p);
#endif
	PDEBUG_MSG ("Reuse of free parser %O\n", p);
      }

      else if (clone_parser) {
	// Relying on interpreter lock here.
	p = clone_parser->clone (ctx, this_object(), p_code, @parser_args);
	PDEBUG_MSG ("Cloned parser to %O\n", p);
      }

      else if ((p = parser_prog (ctx, this_object(), p_code, @parser_args))->clone) {
	// clone_parser might already be initialized here due to race,
	// but that doesn't matter.
	  p->context = p->p_code = 0; // Don't leave this stuff in the clone master.
#ifdef RXML_OBJ_DEBUG
	p->__object_marker->create (p);
#endif
	PDEBUG_MSG ("Made clone parser %O\n", p);
	p = (clone_parser = p)->clone (ctx, this_object(), p_code, @parser_args);
	PDEBUG_MSG ("Cloned it to %O\n", p);
      }
    }

    if (parent && parent->is_RXML_Parser) p->_parent = parent;
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
      parser->context = parser->p_code = parser->recover_errors = parser->_parent = 0;
#ifdef RXML_OBJ_DEBUG
      parser->__object_marker->create (parser);
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
      PDEBUG_MSG ("Parser given back and stored: %O\n", parser);
    }
    else
      PDEBUG_MSG ("Ignored nonresettable parser given back: %O\n", parser);
  }

  mixed eval (string in, void|Context ctx, void|TagSet tag_set,
	      void|Parser|PCode parent, void|int dont_switch_ctx)
  //! Parses and evaluates the value in the given string. If a context
  //! isn't given, the current one is used. The current context and
  //! @[ctx] are assumed to be the same if @[dont_switch_ctx] is
  //! nonzero.
  {
    mixed res = eval_opt (in, ctx, tag_set, parent, dont_switch_ctx);
    // FOO
    if (res == nil) {
      if (sequential)
	res = this->copy_empty_value();
      else
	nil_for_nonseq_error (ctx->id, this);
    }
    return res;
  }

  mixed eval_opt (string in, void|Context ctx, void|TagSet tag_set,
		  void|Parser|PCode parent, void|int dont_switch_ctx)
  //! Like @[eval], but doesn't check for missing value for
  //! nonsequential types. @[RXML.nil] is returned instead in such
  //! cases.
  {
    mixed res;
    if (!ctx) ctx = RXML_CONTEXT;
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
      if (!reg_types[this->name])
	reg_types[this->name] = this;
      return PNone;
    }();

  array(mixed) parser_args = ({});
  //! The arguments to the parser @[parser_prog]. Must not be changed
  //! after being initialized when the type is created; use @[`()]
  //! instead.

  // Interface:

  //! @decl constant string name;
  //!
  //! Unique type identifier. Required and considered constant. This
  //! is the name used to select the type from the RXML level and as
  //! display name in error messages etc.
  //!
  //! If it contains a "/", it's treated as a MIME type and should
  //! then follow the rules for a MIME type with subtype (RFC 2045,
  //! section 5.1). Among other things, that means that the valid
  //! characters are, besides the "/", US-ASCII values 33-126 except
  //! "(", ")", "<", ">", "@@", ",", ";", ":", "\", """, "/", "[",
  //! "]", "?" and "=".
  //!
  //! If it doesn't contain a "/", it's treated as a type outside the
  //! MIME system, e.g. "int" for an integer. In this case the name
  //! should follow the Pike type syntax.
  //!
  //! Any type that can be mapped to a MIME type should be so.

  //! @decl constant string type_name;
  //!
  //! Used as the type name for debug printouts in the default
  //! @[_sprintf].

  constant sequential = 0;
  //! Nonzero if data of this type is sequential, defined as:
  //! @ul
  //!  @item
  //!   One or more data items can be concatenated with `+.
  //!  @item
  //!   (Sane) parsers are homomorphic on the type, i.e.
  //!   @expr{eval("da") + eval("ta") == eval("da" + "ta")@} and
  //!   @expr{eval("data") + eval("") == eval("data")@} provided the
  //!   data is only split between (sensibly defined) atomic elements.
  //! @endul

  //! @decl optional constant mixed empty_value;
  //!
  //! The empty value, i.e. what eval ("") would produce. Must be
  //! defined for every sequential type.

  mixed copy_empty_value();
  //! Returns an instance of @[empty_value] such that provided it's
  //! possible to modify it destructively, such modifications don't
  //! affect @[empty_value].

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
  //! express any value without loss of information, but still it
  //! should be used as the supertype as the last resort if no better
  //! alternative exists.

  Type conversion_type;
  //! The type to use as middlestep in indirect conversions. Required
  //! and considered constant. It should be zero (not @[RXML.t_any])
  //! if there is no sensible conversion type. The @[conversion_type]
  //! references must never produce a cycle between types.
  //!
  //! @[decode] tries to return values of the conversion type, and
  //! @[encode] must handle such values without resorting to indirect
  //! conversions. The conversion type is used as a fallback between
  //! types which doesn't have explicit conversion functions for each
  //! other; see @[indirect_convert].
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
  //! FIXME: This is how parsers use the type.
  //!
  //! Nonzero constant if the type keeps the free text between parsed
  //! tokens, e.g. the plain text between tags in XML. The type must
  //! be sequential and use strings. Must be zero when
  //! @[handle_literals] is nonzero.

  //! @decl optional constant int handle_literals;
  //!
  //! FIXME: This is how parsers use the type.
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
  //! FIXME: This is how parsers use the type.
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

  protected final void type_check_error (string msg1, array args1,
					 string msg2, mixed... args2)
  //! Helper intended to format and throw an RXML parse error in
  //! @[type_check]. Assuming the same argument names as in the
  //! @[type_check] declaration, use like this:
  //!
  //! @code
  //!   if (value is bogus)
  //!     type_check_error (msg, args, "My error message with %O %O.\n", foo, bar);
  //! @endcode
  {
    if (sizeof (args2)) msg2 = sprintf (msg2, @args2);
    if (msg1) {
      if (sizeof (args1)) msg1 = sprintf (msg1, @args1);
      parse_error (msg1 + ": " + msg2);
    }
    else parse_error (msg2);
  }

  /*protected*/ final mixed indirect_convert (mixed val, Type from)
  //! Converts @[val], which is a value of the type @[from], to this
  //! type. Uses indirect conversion via @[conversion_type] as
  //! necessary. Only intended as a helper function for @[encode], so
  //! it won't do a direct conversion from @[conversion_type] to this
  //! type. Throws RXML parse error on any conversion error.
  {
    Type convtype = conversion_type || this_object();

    if (from->conversion_type &&
	convtype->name == from->conversion_type->name) {
      if (from->decode) val = from->decode (val);
      return convtype == this_object() ? val : encode (val, conversion_type);
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

    if (conversion_type)
      if (convtype->conversion_type &&
	  convtype->conversion_type->name == from->name)
	// indirect_convert should never do the job of encode.
	return encode (convtype->encode (val, from), convtype);
      else {
#ifdef MODULE_DEBUG
	if (convtype->name == from->name)
	  fatal_error ("This function shouldn't be used to convert "
		       "from the conversion type %s to %s; use encode() for that.\n",
		       convtype->name, this_object()->name);
#endif
	return encode (convtype->indirect_convert (val, from), convtype);
      }

    parse_error ("Cannot convert type %s to %s.\n", from->name, this_object()->name);
  }

  // Internals:

  // We assume these objects always are globally referenced.
  constant pike_cycle_depth = 0;

  /*private*/ mapping(program:Type) _t_obj_cache;
  // To avoid creating new type objects all the time in `().

  // Cache used for parsers that doesn't depend on the tag set.
  private Parser clone_parser;	// Used with Parser.clone().
  private Parser free_parser;	// The list of objects to reuse with Parser.reset().

  // Cache used for parsers that depend on the tag set.
  /*private*/ mapping(TagSet:PCacheObj) _p_cache;

  //! @ignore
  MARK_OBJECT_ONLY;
  //! @endignore

  protected string _sprintf (int flag)
  {
    switch (flag) {
      case 'O':
	return ((this->type_name || "RXML.Type") +
		"(" + this->name + ", " +
		(parser_prog && parser_prog->name) + ")" + OBJ_COUNT);
      case 's':
	// Convenient to get nice type names in error messages etc.
	return this->name;
    }
  }
}

protected class PCacheObj
{
  int tag_set_gen;
  Parser clone_parser;
  Parser free_parser;
}

// Special types:

TAny t_any = TAny();
//! A completely unspecified nonsequential type. Every type is a
//! subtype of this one.
//!
//! This type is also special in that any value can be converted to
//! and from this type without the value getting changed in any way
//! (provided it's representable in the target type), which means that
//! the meaning of a value might change when this type is used as a
//! middle step.
//!
//! E.g if @tt{"<foo>"@} of type @[RXML.t_text] is converted directly
//! to @[RXML.t_xml], it's quoted to @tt{"&lt;foo&gt;"@}, since
//! @[RXML.t_text] always is literal text. However if it's first
//! converted to @[RXML.t_any] and then to @[RXML.t_xml], it still
//! remains @tt{"<foo>"@}, which then carries a totally different
//! meaning.

class TAny
{
  inherit Type;
  constant name = "any";
  constant type_name = "RXML.t_any";
  Type supertype = 0;
  Type conversion_type = 0;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (val == nil)
      type_check_error (msg, args, "Expected value, got RXML.nil.\n");
  }

  mixed encode (mixed val, void|Type from)
  {
    if (val == nil) parse_error ("Expected value, got RXML.nil.\n");
    return val;
  }
}

TBottom t_bottom = TBottom();
//! A sequential type accepting no values. This type is by definition
//! a subtype of every other type except @[RXML.t_nil].
//!
//! Supertype: @[RXML.t_any]

protected class TBottom
{
  inherit Type;
  constant name = "bottom";
  constant type_name = "RXML.t_bottom";
  Type supertype = t_any;
  Type conversion_type = 0;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    type_check_error (msg, args, "This type does not accept any value.\n");
  }

  Nil encode (mixed val, void|Type from)
  {
    type_check (val);
  }

  int subtype_of (Type other)
  {
    return other->name != "nil";
  }
}

TIgnore t_ignore = TIgnore();
//! A special variant of @[RXML.t_any] that accepts any value but
//! ignores it. That way it can accept any value or combination of
//! values, even free text. Since it ignores all values, it is at the
//! same time a subtype of all types.
//!
//! The result of parsing with this type is officially always
//! @[RXML.nil], but it can currently produce other values due to
//! implementation details. It is basically useless except for the
//! @tt{<nooutput>@} tag.
//!
//! Supertype: @[RXML.t_any]

protected class TIgnore
{
  inherit TAny;
  constant name = "ignore";
  constant type_name = "RXML.t_ignore";
  constant sequential = 1;
  mixed empty_value = nil;
  mixed copy_empty_value() {return nil;}
  Type supertype = t_any;
  Type conversion_type = 0;
  constant free_text = 1;
  constant handle_literals = 0;

  void type_check (mixed val, void|string msg, mixed... args) {}

  TNil encode (mixed val, void|Type from) {return nil;}

  int subtype_of (Type other) {return 1;}
}

TNil t_nil = TNil();
//! Type version of @[RXML.nil], i.e. the type that signifies no value
//! at all (not even the empty value of some type). This type is a
//! subtype of every other type since all the RXML evaluation
//! functions can return no value (i.e. @[RXML.nil]) regardless of the
//! expected type.
//!
//! Supertype: @[RXML.t_any]

protected class TNil
{
  inherit Type;
  constant name = "nil";
  constant type_name = "RXML.t_nil";
  Type supertype = t_any;
  Type conversion_type = 0;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    type_check_error (msg, args, "This type can not be used for storage.\n");
  }

  Nil encode (mixed val, void|Type from)
  {
    type_check (val);
  }

  int subtype_of (Type other) {return 1;}
}

TSame t_same = TSame();
//! A magic type used only in @[Tag.content_type].

protected class TSame
{
  inherit Type;
  constant name = "same";
  constant type_name = "RXML.t_same";
  Type supertype = t_any_seq;
  Type conversion_type = 0;
}

TArray t_array = TArray();
//! An array (with any content). This is like @[RXML.t_any] except
//! that it's sequential and values are always arrays. This is useful
//! to collect several results to an array (whereas using
//! @[RXML.t_any] would raise a "Cannot append another value ..."
//! error if more than one result is given).
//!
//! The @[RXML.t_array] type is special in that it is the only type
//! where values both can be concatenated together and become array
//! elements. E.g. if we have @expr{a = ({1,2})@} and @expr{b =
//! ({"a"})@} then @expr{a + b@} could become either
//! @expr{({1,2,"a"})@} or @expr{({({1,2}),({"a"})})@}. Other
//! sequential types, e.g. @[RXML.t_string] and @[RXML.t_mapping], can
//! only be concatenated (to form a new string or mapping), and
//! nonsequential types like @[RXML.t_int] can never be concatenated.
//!
//! In accordance with the behavior mandated for sequential types,
//! this type opts to concatenate if there is an ambiguity, which is
//! when @expr{@[RXML.t_array]->encode@} is given an array value and
//! no type. If an array should be handled as a single element then
//! specify @[RXML.t_any] as the @expr{from@} type.
//!
//! Supertype: @[RXML.t_any]

//!
//! @seealso
//!   @[t_array]
class TArray
{
  inherit TAny;
  constant name = "array";
  constant type_name = "RXML.t_array";
  constant sequential = 1;
  constant empty_value = ({});
  mixed copy_empty_value() {return ({});}
  Type supertype = t_any;

  constant container_type = 1;
  //! Recognition constant for types for generic data containers, i.e.
  //! arrays and mappings.

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!arrayp (val) && val != empty)
      type_check_error (msg, args, "Expected array, got %t.\n", val);
  }

  array encode (mixed val, void|Type from)
  {
    if (from) {
      if (from->name == local::name) {
	type_check (val);
	return val == empty ? empty_value : val;
      }

      // If we have a different @[from] type then we always create a
      // single element array. This is what enables this type to be a
      // sequential variant of RXML.t_any.

      if (val == empty)
	// Ugly special case to avoid getting RXML.empty in arrays.
	// From a type theoretical perspective it's arguably more
	// correct to keep RXML.empty, but it just gets overly
	// complicated in practice to handle a quirky object instead
	// of a zero (which afterall has essentially the same meaning
	// on the pike level).
	return ({0});
      else {
	if (val == nil) parse_error ("Cannot convert RXML.nil to array.\n");
	return ({val});
      }
    }

    if (arrayp (val))
      return val;
    else if (val == empty || val == nil)
      return empty_value;
    else {
      if (val == nil) parse_error ("Cannot convert RXML.nil to array.\n");
      return ({val});
    }
  }
}

TArray t_any_seq = t_array;
//! A completely unspecified sequential type, i.e. a sequential
//! variant of @[RXML.t_any]. This is currently an alias for
//! @[RXML.t_array].
//!
//! All "ordinary" types with a nonempty set of values are subtypes of
//! this (except @[RXML.t_array] itself).

TMapping t_mapping = TMapping();
//! A mapping.
//!
//! This type is sequential, so more pairs can be added to a single
//! mapping. If there are duplicate indices then later values override
//! earlier.
//!
//! Supertype: @[RXML.t_any_seq]

//!
//! @seealso
//!   @[t_mapping]
class TMapping
{
  inherit TAny;
  constant name = "mapping";
  constant type_name = "RXML.t_mapping";
  constant sequential = 1;
  constant empty_value = ([]);
  mixed copy_empty_value() {return ([]);}
  Type supertype = t_any_seq;

  constant container_type = 1;
  //! Recognition constant for types for generic data containers, i.e.
  //! arrays and mappings.

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (mappingp (val) || (objectp (val) && val->`[])) {
      // Ok.
    }
    else if (val != empty)
      type_check_error (msg, args, "Expected a mapping, got %t.\n", val);
  }

  mapping encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); break;
	case local::name: return [mapping] val;
	default: return [mapping] indirect_convert (val, from); // FIXME: ?
      }
    mixed err = catch {return (mapping) val;};
    parse_error ("Cannot convert %s to mapping: %s",
		 format_short (val), describe_error (err));
  }
}

TType t_type = TType();
//! A type with the set of all RXML types as values.
//!
//! Supertype: @[RXML.t_any_seq]

//!
//! @seealso
//!   @[t_type]
protected class TType
{
  inherit Type;
  constant name = "type";
  constant type_name = "RXML.t_type";
  constant sequential = 0;
  Type supertype = t_any_seq;
  Type conversion_type = 0;
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
      if (!type) parse_error ("There is no type %s.\n", format_short (val));
      return type;
    }
    mixed err = catch {return (object(Type)) val;};
    parse_error ("Cannot convert %s to type: %s",
		 format_short (val), describe_error (err));
  }
}

TParser t_parser = TParser();
//! A type with the set of all RXML parser programs as values.
//!
//! Supertype: @[RXML.t_any_seq]

//!
//! @seealso
//!   @[t_parser]
protected class TParser
{
  inherit Type;
  constant name = "parser";
  constant type_name = "RXML.t_parser";
  constant sequential = 0;
  Type supertype = t_any_seq;
  Type conversion_type = 0;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!programp (val) || !val->is_RXML_Parser)
      type_check_error (msg, args, "Expected a parser program, got %t.\n", val);
  }

  program/*(Parser)*/ encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [program/*(Parser)*/] val;
	default: return [program/*(Parser)*/] indirect_convert (val, from);
      }
    if (stringp (val)) {
      program/*(Parser)*/ parser_prog = reg_parsers[val];
      if (!parser_prog) parse_error ("There is no parser %s.\n", format_short (val));
      return parser_prog;
    }
    mixed err = catch {return (program/*(Parser)*/) val;};
    parse_error ("Cannot convert %s to parser: %s",
		 format_short (val), describe_error (err));
  }
}

// Basic types. Even though most of these have a `+ that fulfills
// requirements to make them sequential, we don't want all those to be
// treated that way. It would imply that a sequence of e.g. integers
// are implicitly added together, which would be nonintuitive.

TScalar t_scalar = TScalar();
//! Any type of scalar, i.e. text or number. It's not sequential, as
//! opposed to the subtype @[RXML.t_any_text].
//!
//! Supertype: @[RXML.t_any_seq]

//!
//! @seealso
//!   @[t_scalar]
class TScalar
{
  inherit Type;
  constant name = "scalar";
  constant type_name = "RXML.t_scalar";
  constant sequential = 0;
  Type supertype = t_any_seq;
  Type conversion_type = 0;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!stringp (val) && !intp (val) && !floatp (val) && val != empty)
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
      parse_error ("Cannot convert %s to scalar.\n", format_short (val));
    return [string|int|float] val;
  }
}

TNum t_num = TNum();
//! Type for any number, currently integer or float.
//!
//! Supertype: @[RXML.t_scalar]

//!
//! @seealso
//!   @[t_num]
class TNum
{
  inherit Type;
  constant name = "number";
  constant type_name = "RXML.t_num";
  constant sequential = 0;
  constant empty_value = 0;
  mixed copy_empty_value() {return 0;}
  Type supertype = t_scalar;
  Type conversion_type = t_scalar;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!intp (val) && !floatp (val) && val != empty)
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
			format_short (val));
    if (!intp (val) && !floatp (val))
      // Cannot unambigiously use a cast for this type.
      parse_error ("Cannot convert %s to number.\n", format_short (val));
    return [int|float] val;
  }
}

TInt t_int = TInt();
//! Type for integers.
//!
//! Supertype: @[RXML.t_num]

//!
//! @seealso
//!   @[t_int]
class TInt
{
  inherit Type;
  constant name = "int";
  constant type_name = "RXML.t_int";
  constant sequential = 0;
  constant empty_value = 0;
  mixed copy_empty_value() {return 0;}
  Type supertype = t_num;
  Type conversion_type = t_scalar;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!intp (val) && val != empty)
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
      else parse_error ("%s cannot be parsed as integer.\n", format_short (val));
    mixed err = catch {return (int) val;};
    parse_error ("Cannot convert %s to integer: %s",
		 format_short (val), describe_error (err));
  }
}

TFloat t_float = TFloat();
//! Type for floats.
//!
//! Supertype: @[RXML.t_num]

//!
//! @seealso
//!   @[t_float]
class TFloat
{
  inherit Type;
  constant name = "float";
  constant type_name = "RXML.t_float";
  constant sequential = 0;
  constant empty_value = 0;
  mixed copy_empty_value() {return 0;}
  Type supertype = t_num;
  Type conversion_type = t_scalar;
  constant handle_literals = 1;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!floatp (val) && val != empty)
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
      else parse_error ("%s cannot be parsed as float.\n", format_short (val));
    mixed err = catch {return (float) val;};
    parse_error ("Cannot convert %s to float: %s",
		 format_short (val), describe_error (err));
  }
}

TString t_string = TString();
//! Type for strings. As opposed to @[RXML.t_any_text], this doesn't
//! allow free text, only literals, and as opposed to @[RXML.t_scalar]
//! it is sequential. That makes it useful in places where you want to
//! collect strings without attention to comments and surrounding
//! whitespace.
//!
//! Supertype: @[RXML.t_scalar]
//!
//! Conversion to and from this type works just like
//! @[RXML.t_any_text]; see the note for that type for further
//! details.
//!
//! @note
//! The whitespace handling implemented by this type is a bit
//! inadequate and doesn't conform to e.g. the XML whitespace
//! normalization rules.

//!
//! @seealso
//!   @[t_string]
class TString
{
  inherit Type;
  constant name = "string";
  constant type_name = "RXML.t_string";
  constant sequential = 1;
  constant empty_value = "";
  mixed copy_empty_value() {return "";}
  Type supertype = t_scalar;
  Type conversion_type = t_scalar;
  constant handle_literals = 1;

  constant string_type = 1;
  //! Recognition constant for all string based types, i.e.
  //! @[RXML.t_string], @[RXML.t_any_text], and all their subtypes.

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!stringp (val) && val != empty) {
      if (name == "string")
	type_check_error (msg, args, "Expected string, got %t.\n", val);
      else
	type_check_error (msg, args,
			  "Expected string for %s, got %t.\n", name, val);
    }
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
		 format_short (val), name, describe_error (err));
  }

  string lower_case (string val) {return val?predef::lower_case (val):val;}
  //! Converts all literal uppercase characters in @[val] to lowercase.

  string upper_case (string val) {return val?predef::upper_case (val):val;}
  //! Converts all literal lowercase characters in @[val] to uppercase.

  string capitalize (string val) {return val?String.capitalize (val):val;}
  //! Converts the first literal character in @[val] to uppercase.
}

// FIXME: Add an "xml" type that strips whitespace and comments and
// allows unknown xml tags.

RXML.Type type_for_value (mixed val)
//! Returns the type that fits the given value, or zero if none is
//! found.
//!
//! The most basic type that fits the value is returned. In particular
//! that means @[RXML.t_string] is returned for strings, not
//! @[RXML.t_any_text] or some other text type.
{
  switch (sprintf ("%t", val)) {
    case "int": return t_int;
    case "float": return t_float;
    case "string": return t_string;
    case "array": return t_array;
    case "mapping": return t_mapping;
    case "object":
      if (val == nil) return t_nil;
      if (val == empty) return t_any;
      if (val->`[]) return t_mapping;
      // Fall through.
    default:
      return 0;
  }
}

// Text types:

TAnyText t_any_text = TAnyText();
//! Any type of text, i.e. the supertype for all text types. It's
//! sequential and allows free text.
//!
//! Supertype: @[RXML.t_scalar]
//!
//! @note
//! Conversion to and from this type and other text types is similar
//! to @[RXML.t_any] in that the value doesn't change, which means
//! that its meaning might change (for an example see the doc for
//! @[RXML.t_any]). This implies that strings produced by tags etc
//! (which are typically literal) should be given the type
//! @[RXML.t_text] and not this type, so that they get correctly
//! encoded when inserted into e.g. XML markup.
//!
//! Otoh, tags that treat their content as text should usually use
//! this type rather than @[RXML.t_text]. The effect is that if a
//! (typed) xml value is inserted in the content then it will be
//! interpreted directly as text without trying to decode charrefs etc
//! in it (which is usually what is expected when the value isn't
//! literal). If @[RXML.t_text] was used instead, it might throw
//! errors at that point if the xml value contains tags.

//!
//! @seealso
//!   @[t_any_text]
class TAnyText
{
  inherit TString;
  constant name = "text/*";
  constant type_name = "RXML.t_any_text";
  constant sequential = 1;
  Type supertype = t_scalar;
  Type conversion_type = t_scalar;
  constant free_text = 1;
  constant handle_literals = 0;
}

TText t_text = TText();
//! The type for plain text. Note that this is not any (unspecified)
//! type of text; @[RXML.t_any_text] represents that. Is sequential
//! and allows free text.

//!
//! @seealso
//!   @[t_text]
class TText
{
  inherit TAnyText;
  constant name = "text/plain";
  constant type_name = "RXML.t_text";
  Type supertype = t_any_text;

  string encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case TString.name: case TAnyText.name: case local::name: return [string] val;
	default: return [string] indirect_convert (val, from);
	case TScalar.name:
      }
    mixed err = catch {return (string) val;};
    parse_error ("Cannot convert %s to %s: %s",
		 format_short (val), name, describe_error (err));
  }
}

TNarrowText t_narrowtext = TNarrowText();
//! The type for plain text that needs to be narrow (eg HTTP headers
//! and similar).

//!
//! @seealso
//!    @[t_narrowtext]
class TNarrowText
{
  inherit TText;
  constant name = "text/x-8bit";
  constant type_name = "RXML.t_narrowtext";
  Type supertype = t_text;
  Type conversion_type = t_text;

  void type_check(mixed val, void|string msg, mixed ... args)
  {
    ::type_check(val);
    if (stringp(val) && (String.width(val) > 8)) {
      type_check_error(msg, args, "Got wide string where 8-bit string required.\n");
    }
  }
}

TXml t_xml = TXml();
//! The type for XML and similar markup.

//!
//! @seealso
//!   @[t_xml]
class TXml
{
  inherit TText;
  constant name = "text/xml";
  constant type_name = "RXML.t_xml";
  Type conversion_type = t_text;
  constant encoding_type = "xml"; // For compatibility.

  constant entity_syntax = 1;
  //! Recognition constant for string types that may contain xml style
  //! entities, e.g. @tt{&foo;@}, and that can be assumed to
  //! understand the standard set of html character entity references
  //! (c.f. @url{http://www.w3.org/TR/html401/sgml/entities.html@}).
  //!
  //! In practice, this constant is nonzero for @[RXML.t_xml],
  //! @[RXML.t_html], and possibly any subtypes.

  constant element_syntax = 1;
  //! Recognition constant for string types that may contain xml style
  //! elements, e.g. @tt{<foo a="b">c</foo>@}. It can generally be
  //! assumed to understand basic html markup as well. It is not safe
  //! to assume that xml style empty elements are understood, so it's
  //! generally necessary to use tweaks like @tt{<br />@}.
  //!
  //! In practice, this constant is nonzero for @[RXML.t_xml],
  //! @[RXML.t_html], and possibly any subtypes.

  // Note: type_check is not strict.

  string encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case TString.name: case TAnyText.name: case local::name: return [string] val;
	default: return [string] indirect_convert (val, from);
	case TText.name:
      }

    // Automatically handles the casting (if necessary)
    if (mixed err = catch { // The catch comes from the cast, if any
      // Cannot use Roxen.* here.
      return _Roxen.html_encode_string( val );
    } )
      parse_error ("Cannot convert %s to %s: %s",
 		   format_short (val), name, describe_error (err));
  }

  string decode (mixed val)
  {
    return charref_decode_parser->clone()->finish ([string] val)->read();
  }

  string decode_charrefs (string val)
  //! Decodes all character reference entities in @[val].
    {return tolerant_charref_decode_parser->clone()->finish (val)->read();}

  string decode_xml_safe_charrefs (string val)
  //! Decodes all character reference entities in @[val] except those
  //! that produce the characters "<", ">" or "&". It's therefore safe
  //! to use on xml content.
  {
    return tolerant_xml_safe_charref_decode_parser->
      clone()->finish (val)->read();
  }

  string lower_case (string val)
    {return val ? lowercaser->clone()->finish (val)->read() : val;}

  string upper_case (string val)
    {return val ? uppercaser->clone()->finish (val)->read() : val;}

  string capitalize (string val)
    {return val ? capitalizer->clone()->finish (val)->read() : val;}

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
	      string name = p->tag_name();
	      p->_set_tag_callback (0);
	      p->add_tag (name,
			  lambda (object p, mapping a) {
			    res = p->tag();
			    res[2] = 0;
			    throw (0);
			  });
	      p->add_container (name,
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
    function(string...:void) add = res->add;
    add ("<", tagname);

    if (args)
      if (flags & FLAG_RAW_ARGS)
	foreach (sort(indices(args)), string arg)
	  add (" ", arg, "=\"", replace (args[arg], "\"", "\"'\"'\""), "\"");
      else
	foreach (sort(indices(args)), string arg) {
	  string val = args[arg];
	  // Three serial replaces are currently faster than one parallell.
	  val = replace (val, "&", "&amp;");
	  val = replace (val, "\"", "&quot;");
	  val = replace (val, "<", "&lt;");
	  add (" ", arg, "=\"", val, "\"");
	}

    if (content)
      add (">", content, "</", tagname, ">");
    else
      if (flags & FLAG_COMPAT_PARSE)
	if (flags & FLAG_EMPTY_ELEMENT)
	  add (">");
	else
	  add ("></", tagname, ">");
      else
	add (" />");

    return res->get();
  }

  string format_entity (string entity)
  {
    return "&" + entity + ";";
  }
}

THtml t_html = THtml();
//! (Currently) identical to t_xml, but tags it as "text/html".

//!
//! @seealso
//!   @[t_html]
class THtml
{
  inherit TXml;
  constant name = "text/html";
  constant type_name = "RXML.t_html";
  Type conversion_type = t_xml;

  string encode (mixed val, void|Type from)
  {
    if (from && from->name == local::name)
      return [string] val;
    else
      return ::encode (val, from);
  }

  constant decode = 0;		// Cover it; not needed here.
}

// Composite types:
//
// A few ad-hoc combinations since we lack a generic system for
// building composite types.

TStrOrInt t_str_or_int = TStrOrInt();
//! Either a string or an integer. Not sequential.
//!
//! Supertype: @[RXML.t_scalar]

//!
//! @seealso
//!   @[t_str_or_int]
class TStrOrInt
{
  inherit TScalar;
  constant name = "string|int";
  constant type_name = "RXML.t_str_or_int";
  Type supertype = t_scalar;
  Type conversion_type = t_scalar;

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (!intp (val) && !stringp (val) && val != empty)
      type_check_error (msg, args,
			"Expected string or integer value, got %t.\n", val);
  }

  string|int encode (mixed val, void|Type from)
  {
    if (from)
      switch (from->name) {
	case TAny.name: type_check (val); // Fall through.
	case local::name: return [string|int] val;
	default: return [string|int] indirect_convert (val, from);
      }
    if (!stringp (val) && !intp (val))
      // Cannot unambigiously use a cast for this type.
      parse_error ("Cannot convert %s to string or integer.\n",
		   format_short (val));
    return [string|int] val;
  }
}

//!
//! @seealso
//!   @[TArray]
class TTypedArray
{
  inherit TArray;
  Type supertype = t_array;

  /* constant element_type_name; */
  protected int element_type_p (mixed val);
  protected mixed element_encode (mixed val);

  void type_check (mixed val, void|string msg, mixed... args)
  {
    if (val == empty) return;
    if (!arrayp (val))
      type_check_error (msg, args, "Expected array, got %t.\n", val);
    foreach (val; int i; mixed ent)
      if (!element_type_p (ent))
	type_check_error (msg, args,
			  "Expected %s at position %d, got %t.\n",
			  this->element_type_name, i + 1, ent);
  }

  array encode (mixed val, void|Type from)
  {
    array res = ::encode (val, from);
    foreach (res; int i; mixed ent)
      res[i] = element_encode (ent);
    return res;
  }
}

TNumArray t_num_array = TNumArray();
//! An array of numbers (i.e. floats or integers).
//!
//! Supertype: @[RXML.t_array]

//!
//! @seealso
//!   @[t_num_array]
class TNumArray
{
  inherit TTypedArray;
  constant name = "array(number)";
  constant type_name = "RXML.t_num_array";
  constant element_type_name = "number";

  protected int element_type_p (mixed val)
    {return intp (val) || floatp (val);}

  protected mixed element_encode (mixed val)
    {return t_num->encode (val);}
}

TIntArray t_int_array = TIntArray();
//! An array of integers.
//!
//! Supertype: @[RXML.t_num_array]

//!
//! @seealso
//!   @[t_int_array]
class TIntArray
{
  inherit TTypedArray;
  constant name = "array(int)";
  constant type_name = "RXML.t_int_array";
  Type supertype = t_num_array;
  constant element_type_name = "int";

  protected int element_type_p (mixed val)
    {return intp (val);}

  protected mixed element_encode (mixed val)
    {return t_int->encode (val);}
}

TStrArray t_str_array = TStrArray();
//! An array of strings.
//!
//! Supertype: @[RXML.t_array]

//!
//! @seealso
//!   @[t_str_array]
class TStrArray
{
  inherit TTypedArray;
  constant name = "array(string)";
  constant type_name = "RXML.t_str_array";
  constant element_type_name = "string";

  protected int element_type_p (mixed val)
    {return stringp (val);}

  protected mixed element_encode (mixed val)
    {return t_string->encode (val);}
}

TMapArray t_map_array = TMapArray();
//! An array of mappings.
//!
//! Supertype: @[RXML.t_array]

//!
//! @seealso
//!   @[t_map_array]
class TMapArray
{
  inherit TTypedArray;
  constant name = "array(mapping)";
  constant type_name = "RXML.t_map_array";
  constant element_type_name = "mapping";

  protected int element_type_p (mixed val)
    {return mappingp (val);}

  protected mixed element_encode (mixed val)
    {return t_mapping->encode (val);}
}


// P-code compilation and evaluation:

class VarRef (string scope, string|array(string|int) var,
	      string encoding, Type want_type)
//! A helper for representing variable reference tokens.
{
  constant is_RXML_VarRef = 1;
  constant is_RXML_encodable = 1;
  constant is_RXML_p_code_entry = 1;

#define VAR_STRING ((({scope}) + (arrayp (var) ? \
				  (array(string)) var : ({(string) var}))) * ".")

  mixed get (Context ctx)
  {
    // Note: Parser.handle_var more or less duplicates this.

    ctx->frame_depth++;
    FRAME_DEPTH_MSG ("%*s%O frame_depth increase line %d\n",
		     ctx->frame_depth, "", this_object(), __LINE__);

    mixed err = catch {
#ifdef DEBUG
      if (TAG_DEBUG_TEST (ctx->frame))
	TAG_DEBUG (ctx->frame, "    Looking up variable %s.%s in context of type %s\n",
		   scope, arrayp (var) ? var * "." : var,
		   (encoding ? t_any_text : want_type)->name);
#endif
      mixed val;
#ifdef AVERAGE_PROFILING
      string varref;
#endif

      COND_PROF_ENTER(mixed id=ctx->id,(varref = VAR_STRING),"entity");
      if (zero_type (val = ctx->get_var (
		       var, scope, encoding ? t_any_text : want_type)))
	val = nil;
      COND_PROF_LEAVE(mixed id=ctx->id,varref,"entity");

      if (encoding) {
	if (!(val = Roxen->roxen_encode (val + "", encoding)))
	  parse_error ("Unknown encoding %O.\n", encoding);
#ifdef DEBUG
	if (TAG_DEBUG_TEST (ctx->frame))
	  TAG_DEBUG (ctx->frame, "    Got value %s after conversion "
		     "with encoding %s\n", format_short (val), encoding);
#endif
	if (want_type->empty_value != "")
	  val = want_type->encode (val, t_any_text);
      }

      else
#ifdef DEBUG
	if (TAG_DEBUG_TEST (ctx->frame))
	  TAG_DEBUG (ctx->frame, "    Got value %s\n", format_short (val));
#endif

      FRAME_DEPTH_MSG ("%*s%O frame_depth decrease line %d\n",
		       ctx->frame_depth, "", this_object(), __LINE__);
      ctx->frame_depth--;
      return val;
    };

    FRAME_DEPTH_MSG ("%*s%O frame_depth decrease line %d\n",
		     ctx->frame_depth, "", this_object(), __LINE__);
    ctx->frame_depth--;
    throw_fatal (err, "&" + VAR_STRING + ";");
  }

  mixed set (Context ctx, mixed val) {return ctx->set_var (var, val, scope);}

  void delete (Context ctx) {ctx->delete_var (var, scope);}

  string name()
  {
    return scope && var &&
      map (arrayp (var) ? ({scope}) + (array(string)) var : ({scope, (string) var}),
	   replace, ".", "..") * ".";
  }

  array _encode()
  {
    return ({ scope, var, encoding, want_type });
  }

  void _decode(array v)
  {
    [scope, var, encoding, want_type] = v;
  }

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (int flag)
  {
    return flag == 'O' && ("RXML.VarRef(" + name() + ")" + OBJ_COUNT);
  }
}

class VariableChange (/*protected*/ mapping settings)
// A compiled-in change of some scope variables. Used when caching
// results.
{
  constant is_RXML_VariableChange = 1;
  constant is_RXML_encodable = 1;
  constant is_RXML_p_code_entry = 1;

  constant p_code_no_result = 1;

  mixed get (Context ctx)
  {
  handle_var_loop:
    foreach (settings; mixed encoded_var; mixed val) {
      mixed var;
      if (stringp (encoded_var)) {
	var = decode_value (encoded_var);

	if (arrayp (var)) {
	  if (stringp (var[0])) { // A scope or variable change.
	    if (sizeof (var) == 1) {
#ifdef DEBUG
	      if (TAG_DEBUG_TEST (ctx->frame))
		TAG_DEBUG (ctx->frame,
			   "    Installing cached scope %O with %d variables\n",
			   replace (var[0], ".", ".."), sizeof (val));
#endif
	      if (val)
		ctx->add_scope (var[0],
				objectp (val) && val->clone ? val->clone() :
				val);
	      else
		ctx->remove_scope (var[0]);
	    }

	    else {
#ifdef DEBUG
	      if (TAG_DEBUG_TEST (ctx->frame))
		TAG_DEBUG (ctx->frame, "    Installing cached value for %O: %s\n",
			   map ((array(string)) var, replace, ".", "..") * ".",
			   format_short (val));
#endif
	      if (val != nil)
		ctx->set_var (var[1..], val, var[0]);
	      else
		ctx->delete_var (var[1..], var[0]);
	    }
	  }

	  else switch (var[0]) {
	    case 0:
	      // A runtime tag change.
#ifdef DEBUG
	      if (TAG_DEBUG_TEST (ctx->frame))
		TAG_DEBUG (ctx->frame,
			   "    Installing cached runtime tag definition for %O: %O\n",
			   var[1], val);
#endif
	      if (val)
		ctx->direct_add_runtime_tag (var[1], [object(Tag)] val);
	      else
		ctx->direct_remove_runtime_tag (var[1]);
	      break;

	    case 1:
	      // Set in id->misc.
#ifdef DEBUG
	      if (TAG_DEBUG_TEST (ctx->frame))
		TAG_DEBUG (ctx->frame,
			   "    Installing cached id->misc entry %O: %s\n",
			   format_short (var), format_short (val));
#endif
	      ctx->set_id_misc (var[1], val);
	      break;

	    case 2:
	      // Set in root_id->misc.
#ifdef DEBUG
	      if (TAG_DEBUG_TEST (ctx->frame))
		TAG_DEBUG (ctx->frame,
			   "    Installing cached id->root_id->misc entry %O: %s\n",
			   format_short (var), format_short (val));
#endif
	      ctx->set_root_id_misc (var[1], val);
	      break;
	  }

	  continue handle_var_loop;
	}
      }

      else
	var = encoded_var;

#ifdef DEBUG
      if (TAG_DEBUG_TEST (ctx->frame))
	TAG_DEBUG (ctx->frame, "    Installing cached misc entry %O: %s\n",
		   format_short (var), format_short (val));
#endif
      ctx->set_misc (var, val);
    }

    return nil;
  }

  int merge (VariableChange later_chg)
  {
    // Fix any sequence dependencies between the current settings and
    // later_chg. Return zero if we can't resolve them so that the
    // entries must remain separate.
    mapping later_sets = later_chg->settings;
    foreach (later_sets; mixed encoded_var; mixed val) {
      if (stringp (encoded_var)) {
	mixed var = decode_value (encoded_var);
	string scope_name;
	if (arrayp (var) &&
	    stringp (scope_name = var[0]) && sizeof (var) > 1) {
	  string encoded_scope = encode_value_canonic (({scope_name}));
#ifdef DEBUG
	  if (later_sets[encoded_scope])
	    error ("Got both scope and variable entry "
		   "for the same scope %O in %O\n", scope_name, later_sets);
#endif

	  if (SCOPE_TYPE scope = settings[encoded_scope]) {
	    // There's a variable change in later_chg in a scope
	    // that's added in this entry.
	    if (sizeof (var) > 2)
	      // Subindexed variable. Since we can't do subindexing
	      // reliably in it we have to keep the sequence. C.f.
	      // Context.set_var and Context.delete_var.
	      return 0;
	    else {
	      // Since the scope is added in this object we simply
	      // modify it for the variable change. C.f.
	      // Context.set_var and Context.delete_var.
	      if (val == nil)
		m_delete (scope, var[1]);
	      else
		scope[var[1]] = val;
	      continue;
	    }
	  }
	}
      }

      settings[encoded_var] = val;
    }

    return 1;
  }

  void eval_rxml_consts (Context ctx)
  // This is used to evaluate constant RXML.Value objects before the
  // p-code is saved so that we don't try to encode the objects
  // themselves. We also convert RXML.Scope objects to mappings, but
  // we don't touch any objects that can be encoded as-is (i.e. have
  // is_RXML_encodable set).
  {
#define CONVERT_VAL(SCOPE_NAME, VAR_NAME, VAL, ASSIGN_TO, TRANSFER) do { \
      if (objectp (VAL) && VAL->rxml_const_eval && !VAL->is_RXML_encodable) { \
	DO_IF_DEBUG (							\
	  if (TAG_DEBUG_TEST (ctx->frame))				\
	    TAG_DEBUG (ctx->frame,					\
		       "    Evaluating constant rxml value: %s: %s\n",	\
		       ({SCOPE_NAME, VAR_NAME}) * ".",			\
		       format_short (VAL));				\
	);								\
	ASSIGN_TO = VAL->rxml_const_eval (ctx, VAR_NAME, SCOPE_NAME);	\
      }									\
      else {TRANSFER;}							\
    } while (0)

    foreach (settings; mixed encoded_var; mixed val)
      if (stringp (encoded_var)) {
	mixed var = decode_value (encoded_var);

	if (arrayp (var) && stringp (var[0]))
	  if (sizeof (var) == 1) {
	    if (val) {
	      if (objectp (val)) {
		if (!val->is_RXML_encodable) {
		  mapping(string:mixed) new_vars = ([]);
		  foreach (val->_indices (ctx, var[0]), string name) {
		    mixed v = val[name];
		    if (!zero_type (v) && v != nil)
		      CONVERT_VAL (var[0], name, v, new_vars[name],
				   new_vars[name] = v);
		  }
		  settings[encoded_var] = new_vars;
		}
	      }

	      else
		foreach (val; string name; mixed v) {
		  if (v != nil)
		    CONVERT_VAL (var[0], name, v, val[name], {});
		}
	    }
	  }

	  else {
	    CONVERT_VAL (var[..sizeof (var) - 2] * ".", var[-1],
			 val, settings[encoded_var], {});
	  }
      }
  }

  mapping(string:mixed) _encode() {return settings;}
  void _decode (mapping(string:mixed) saved) {settings = saved;}

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (int flag)
  {
    if (flag != 'O') return 0;
    string ind = "";
    if (!mappingp (settings)) return "RXML.VariableChange()";
    foreach (settings; mixed encoded_var; mixed val) {
      mixed var;
      if (stringp (encoded_var)) {
	var = decode_value (encoded_var);
	if (arrayp (var)) {
	  var = map ((array(string)) var, replace, ".", "..") * ".";
	  if (sizeof (var) == 1)
	    if (val) ind += sprintf (", set: %O", var);
	    else ind += sprintf (", del: %O", var);
	  else
	    if (val != nil) ind += sprintf (", set: %O", var);
	    else ind += sprintf (", del: %O", var);
	  continue;
	}
      }
      else var = encoded_var;
      ind += sprintf (", set misc: %O", var);
    }
    return "RXML.VariableChange(" + ind[2..] + ")" + OBJ_COUNT;
  }
}

class CompiledCallback (protected function|string callback,
			protected array args)
// A generic compiled-in callback.
{
  constant is_RXML_CompiledCallback = 1;
  constant is_RXML_encodable = 1;
  constant is_RXML_p_code_entry = 1;

  mixed get (Context ctx)
  {
#ifdef DEBUG
    if (TAG_DEBUG_TEST (ctx->frame))
      TAG_DEBUG (ctx->frame,
		 "    Calling cached callback: %O (%s)\n",
		 callback, map (args, format_short) * ", ");
#endif
    if (stringp (callback)) {
      mixed obj = ctx->id;
      foreach (callback / "->", string name) obj = obj[name];
      ([function] obj) (@args);
    }
    else
      callback (@args);
    return nil;
  }

  array _encode() {return ({callback, args});}
  void _decode (array saved) {[callback, args] = saved;}

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (int flag)
  {
    if (flag != 'O') return 0;
    if (args)
      return sprintf ("RXML.CompiledCallback(%O(%s))",
		      callback, map (args, format_short) * ", ");
    else
      return sprintf ("RXML.CompiledCallback(%O, no args)", callback);
  }
}

class CompiledError
//! A compiled-in error. Used when the parser handles an error, to get
//! the same behavior in the p-code.
{
  constant is_RXML_ParseError = 1;
  constant is_RXML_encodable = 1;
  constant is_RXML_p_code_entry = 1;

  string type;
  string msg;
  string current_var;

  protected void create (Backtrace rxml_bt)
  {
    if (rxml_bt) {		// Might be zero if we're created by decode().
      type = rxml_bt->type;
      msg = rxml_bt->msg;
      current_var = rxml_bt->current_var;
    }
  }

  mixed get (Context ctx)
  {
    Backtrace bt = Backtrace (type, msg, ctx, backtrace());
    bt->current_var = current_var;
    throw (bt);
  }

  array _encode()
  {
    return ({type, msg, current_var});
  }

  void _decode (array v)
  {
    [type, msg, current_var] = v;
  }

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (int flag)
  {
    return flag == 'O' && ("RXML.CompiledError()" + OBJ_COUNT);
  }
}

#ifdef RXML_COMPILE_DEBUG
#  define COMP_MSG(X...) do report_debug (X); while (0)
#else
#  define COMP_MSG(X...) do {} while (0)
#endif

// Count the identifiers globally to avoid the slightly bogus cyclic
// check in the compiler.
protected int p_comp_idnr = 0;

#ifdef DEBUG
protected int p_comp_count = 0;
#endif

protected class PikeCompile
//! Helper class to paste together a Pike program from strings. This
//! is thread safe.
{
#ifdef DEBUG
  protected string pcid = "pc" + ++p_comp_count;
#endif
  protected inherit Thread.Mutex: mutex;

  // These are covered by the mutex.
  protected inherit String.Buffer: code;
  protected mapping(string:int) cur_ids = ([]);
  protected mapping(mixed:mixed) delayed_resolve_places = ([]);

  protected mapping(string:mixed) bindings = ([
    // Prepopulate with standard things we need access to.
    "set_nil_arg": set_nil_arg,
  ]);

  string bind (mixed val)
  {
    string id =
#ifdef DEBUG
      pcid +
#endif
      "b" + p_comp_idnr++;
    COMP_MSG ("%O bind %O to %s\n", this_object(), val, id);
    bindings[id] = val;
    return id;
  }

  string add_func (string rettype, string arglist, string def)
  {
    string id =
#ifdef DEBUG
      pcid +
#endif
      "f" + p_comp_idnr++;
    COMP_MSG ("%O add func: %s %s (%s)\n{%s}\n",
	      this_object(), rettype, id, arglist, def);
    string txt = predef::sprintf (
      "# 1\n" // Workaround for pike 7.8 bug with large line numbers, [bug 6146].
      "%s %s (%s)\n{%s}\n", rettype, id, arglist, def);

    Thread.MutexKey lock = mutex::lock();
    code::add (txt);
    cur_ids[id] = 1;

    // Be nice to the Pike compiler, and compile the code in segments.
    if (code::_sizeof() >= 65536) {
      lock = UNDEFINED;
      compile();
    }

    return id;
  }

  mixed resolve (string id)
  {
    COMP_MSG ("%O resolve %O\n", this_object(), id);
#ifdef DEBUG
    if (!has_prefix (id, pcid))
      error ("Resolve id %O does not belong to this object.\n", id);
#endif
    if (zero_type (bindings[id])) {
      compile();
#ifdef DEBUG
      if (zero_type (bindings[id])) error ("Unknown id %O.\n", id);
#endif
    }
    return bindings[id];
  }

  void delayed_resolve (mixed what, mixed index)
  {
    Thread.MutexKey lock = mutex::lock();
#ifdef DEBUG
    if (!zero_type (delayed_resolve_places[what]))
      error ("Multiple indices per thing to delay resolve not handled.\n");
    if (!stringp (what[index]) || !has_prefix (what[index], pcid))
      error ("Resolve id %O does not belong to this object.\n", what[index]);
#endif
    mixed resolved;
    if (zero_type (resolved = bindings[what[index]])) {
      delayed_resolve_places[what] = index;
      COMP_MSG ("%O delayed_resolve %O in %s[%O]\n",
		this_object(), what[index], format_short (what), index);
    }
    else {
      what[index] = resolved;
      COMP_MSG ("%O delayed_resolve immediately %O in %s[%O]\n",
		this_object(), what[index], format_short (what), index);
    }
  }

  protected class Resolver (object master)
  // Can't keep the instantiated Resolver object around since that'd
  // introduce a cyclic reference.
  {
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
  }

  void compile()
  {
    Thread.MutexKey lock = mutex::lock();

    string txt = code::get();

    if (txt != "") {
      COMP_MSG ("%O compile\n", this_object());

      object compiled = 0;

      txt +=
	"mixed _encode() { } void _decode(mixed v) { }\n"
	"constant is_RXML_pike_code = 1;\n"
	"constant is_RXML_encodable = 1;\n"
#ifdef RXML_OBJ_DEBUG
	// Don't want to encode the cloning of RoxenDebug.ObjectMarker
	// in the __INIT that is dumped, since that debug might not be
	// wanted when the dump is decoded.
	"mapping|object __object_marker = " +
	bind (RoxenDebug.ObjectMarker ("object(compiled RXML code)")) + ";\n"
#else
	LITERAL (MARK_OBJECT) ";\n"
#endif
#ifdef DEBUG
	"string _sprintf (int flag)"
	"  {return flag == 'O' && \"object(compiled RXML code)\" + "
	LITERAL (OBJ_COUNT)
	";}\n"
#endif
	;

      program res;
#ifdef DEBUG
      if (mixed err = catch {
#endif
	  res = predef::compile (txt, Resolver (master()));
#ifdef DEBUG
	}) {
	report_debug ("Failed program: %s\n", txt);
	throw (err);
      }
#endif

      compiled = res();

      foreach (cur_ids; string i;) {
#ifdef DEBUG
	if (zero_type (compiled[i]))
	  error ("Identifier %O doesn't exist in compiled code.\n", i);
#endif
	bindings[i] = compiled[i];
      }

      cur_ids = ([]);
    }

#ifdef DEBUG
    else
      if (sizeof (cur_ids))
	error ("Empty code got bound identifiers: %O\n", indices (cur_ids));
#endif

    foreach (delayed_resolve_places; mixed what;) {
      mixed index = m_delete (delayed_resolve_places, what);
      if (zero_type (bindings[what[index]]))
	delayed_resolve_places[what] = index;
      else {
	what[index] = bindings[what[index]];
	COMP_MSG ("%O resolved delayed %O\n", this_object(), what[index]);
      }
    }

    return;
  }

  protected void destroy()
  {
    compile();			// To clean up delayed_resolve_places.
#ifdef DEBUG
    if (sizeof (delayed_resolve_places)) {
      string errmsg = "Still got unresolved delayed resolve places:\n";
      foreach (delayed_resolve_places; mixed what;) {
	mixed index = m_delete (delayed_resolve_places, what);
	errmsg += replace (predef::sprintf ("  %O[%O]: %O",
					    what, index, what[index]),
			   "\n", "\n  ") + "\n";
      }
      error (errmsg);
    }
#endif
  }

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (int flag)
  {
    return flag == 'O' && ("RXML.PikeCompile()" + OBJ_COUNT);
  }
}

#ifdef RXML_PCODE_DEBUG
#  define PCODE_MSG(X...) do {						\
  Context _ctx_ = RXML_CONTEXT;						\
  Frame _frame_ = _ctx_ && _ctx_->frame;				\
  if (TAG_DEBUG_TEST (!_frame_ || _frame_->flags & FLAG_DEBUG)) {	\
    if (_frame_) report_debug ("%O:   ", _frame_);			\
    report_debug ("PCode(" + (flags & COLLECT_RESULTS ?			\
			      "res" : "cont") + ")" + OBJ_COUNT + ": " + X); \
  }									\
} while (0)
#else
#  define PCODE_MSG(X...) do {} while (0)
#endif

// Typed error thrown when stale p-code is decoded.
class PCodeStaleError
{
  constant is_generic_error = 1;
  constant is_p_code_stale_error = 1;

  string error_message;
  array error_backtrace;

  protected void create (string msg, array bt)
  {
    error_message = msg;
    error_backtrace = bt;
  }

  string|array `[] (int i)
  {
    switch (i) {
      case 0: return error_message;
      case 1: return error_backtrace;
    }
  }

  mixed `[]= (int i, mixed val)
  {
    switch (i) {
      case 0: return error_message = val;
      case 1: return error_backtrace = val;
    }
  }

  string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("RXML.PCodeStaleError(%O)", error_message);
  }
}

final void p_code_stale_error (string msg, mixed... args)
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  array bt = backtrace();
  PCODE_UPDATE_MSG ("Throwing PCodeStaleError: %s\n", describe_backtrace (bt));
  throw (PCodeStaleError (msg, bt[..sizeof (bt) - 2]));
}

class PCode
//! Holds p-code and evaluates it. P-code is the intermediate form
//! after parsing and before evaluation.
{
  constant is_RXML_PCode = 1;
  constant is_RXML_encodable = 1;
  constant thrown_at_unwind = 1;
  constant tag_set_eval = 1;

  Type type;
  //! The type the p-code evaluates to. Should be the same as the
  //! setting in the parser used to create this object.

  TagSet tag_set;
  //! The tag set (if any) used by the parser that created this
  //! object. Used to initialize new contexts correctly.

  int recover_errors;
  //! Nonzero if error recovery is allowed. Should be the same as the
  //! setting in the parser used to create this object.

  PCode p_code;
  //! Another chained PCode object to update while this one is
  //! compiled. Typically only useful if one p-code object collects
  //! the unevaluated data and the other the results. It's assumed
  //! that at most one PCode object in a chain collects results.

  Context new_context (void|RequestID id)
  //! Creates a new context for evaluating the p-code in this object.
  //! @[id] is put into the context if given.
  {
    Context ctx = tag_set ? tag_set->new_context (id) : Context (0, id);
    ctx->make_p_code = 1; // Always extend the compilation to unvisited parts.
    return ctx;
  }

  int is_stale()
  //! Returns whether the p-code is stale or not. Should be called
  //! before @[eval] to ensure it won't fail for that reason.
  {
#if defined (TAGSET_GENERATION_DEBUG) || defined (RXML_PCODE_UPDATE_DEBUG)
    if (tag_set && tag_set->generation != generation)
      werror ("%O is_stale test: generation=%d, %O->generation=%d\n",
	      this_object(), generation,
	      tag_set, tag_set && tag_set->generation);
#endif
    return tag_set && tag_set->generation != generation;
  }

  int is_updated()
  //! Returns whether or not the p-code has been updated in an earlier
  //! call to @[eval]. If it has, it's a good idea to save it again to
  //! disk or similar. A call to this function resets the flag.
  {
    int updated = flags & UPDATED;
    flags &= ~UPDATED;
    PCODE_UPDATE_MSG ("%O: is_updated returns %s and resets flag "
		      "by request from %s", this,
		      updated ? "true" : "false",
		      describe_backtrace (backtrace()[<1..<1]));
    return updated;
  }

  mixed eval (Context context, void|int eval_piece)
  //! Evaluates the p-code in the given context (which typically has
  //! been created by @[new_context]). If @[eval_piece] is nonzero,
  //! the evaluation may break prematurely due to
  //! streaming/nonblocking operation. @[context->incomplete_eval]
  //! will return nonzero in that case.
  //!
  //! This function might throw an exception if the p-code is stale,
  //! i.e. if @[generation] no longer matches the generation of
  //! @[tag_set]. The caller should always check with @[is_stale] to
  //! avoid that.
  {
    mixed res, piece;
    int eval_loop = 0;
    ENTER_CONTEXT (context);
  eval:
    while (1) {			// Loops when the evaluation is incomplete.
      if (mixed err = catch {
	if (context && context->unwind_state && context->unwind_state->top) {
#ifdef MODULE_DEBUG
	  if (context->unwind_state->top != this_object())
	    fatal_error ("The context got an unwound state "
			 "from another evaluator object. Can't continue.\n");
#endif
	  m_delete (context->unwind_state, "top");
	  m_delete (context->unwind_state, "reason");
	  if (!sizeof (context->unwind_state)) context->unwind_state = 0;
	}
	piece = _eval (context, 0); // Might unwind.
      }) {
	if (objectp (err) && ([object] err)->thrown_at_unwind) {
	  if (!eval_piece && context->incomplete_eval()) {
	    if (eval_loop) res = add_to_value (type, res, piece);
	    eval_loop = 1;
	    continue eval;
	  }
	  if (!context->unwind_state) context->unwind_state = ([]);
	  context->unwind_state->top = this_object();
	  break eval;
	}
	if (p_code_comp)
	  // Fix all delayed resolves in any ongoing p-code compilation.
	  p_code_comp->compile();
	LEAVE_CONTEXT();
	throw_fatal (err);
      }
      else
	if (eval_loop) piece = add_to_value (type, res, piece);
      break;
    }
    LEAVE_CONTEXT();
    return piece;
  }

  void create (Type _type, Context ctx, void|TagSet _tag_set, void|int collect_results,
	       void|PikeCompile _p_code_comp)
  // Not protected since this is also used to reset p-code objects.
  {
    if (collect_results) {
      // Yes, the internal interaction between create, reset, the
      // context and CTX_ALREADY_GOT_VC is ugly.
      flags = COLLECT_RESULTS;
      if (ctx->misc->recorded_changes) flags |= CTX_ALREADY_GOT_VC;
      ctx->misc->recorded_changes = ({([])});
    }
    else flags = 0;
    if (_type) {
      // _type is 0 if we're being decoded or created without full
      // init (collect_results still needs to be handled, though).
      type = _type;
      if ((tag_set = _tag_set)) generation = _tag_set->generation;
      p_code = 0;
      exec = allocate (16);
      length = 0;
      flags |= UPDATED;
      PCODE_UPDATE_MSG ("%O (ctx %O): Marked as updated by create or reset.\n",
			this, ctx);

      protocol_cache_time = Int.NATIVE_MAX;
      if (RequestID id = ctx->id) {
	mapping(mixed:int) lc =
	  id->misc->local_cacheable || (id->misc->local_cacheable = ([]));
	lc[this] = Int.NATIVE_MAX;
#ifdef DEBUG_CACHEABLE
	report_debug ("%O: Starting tracking of local cache time changes.\n",
		      this);
#endif
      }

      p_code_comp = _p_code_comp || PikeCompile();
      PCODE_MSG ("create or reset (with %s %O)\n",
		 _p_code_comp ? "old" : "new", p_code_comp);
    }
  }


  // Internals:

  // Note: The frame state at exec[pos + 2] for frames might be shared
  // between PCode instances.
  /*protected*/ array exec;
  /*protected*/ int length;

#define EXPAND_EXEC(ELEMS) do {						\
    if (length + (ELEMS) > sizeof (exec))				\
      exec += allocate (max ((ELEMS), sizeof (exec)));			\
  } while (0)

  /*protected*/ int flags;
  protected constant COLLECT_RESULTS = 0x2;
  protected constant CTX_ALREADY_GOT_VC = 0x4; // Just as ugly as it sounds, but who cares?
  protected constant UPDATED = 0x8;
  protected constant FINISHED = 0x10;

  /*protected*/ int generation;
  // The generation of tag_set when the p-code object was generated.
  // Known punt: We should track and check the generations of any
  // nested tag sets so that is_stale always is reliable. But due to
  // the extensive dependencies in the global rxml_tag_set that won't
  // be a problem in practice, so we avoid the overhead.

  /*protected*/ int protocol_cache_time;
  // The ctx->id->misc->cacheable setting when result collected p-code
  // is finished. It's reinstated on entry whenever the p-code is used
  // to ensure that the protocol cache doesn't overcache.

  PikeCompile p_code_comp;
  // This is inherited by nested PCode instances to make the
  // compilation units larger.

  void process_recorded_changes (array rec_chgs, Context ctx)
  {
    EXPAND_EXEC (sizeof (rec_chgs));
    low_process_recorded_changes (rec_chgs, ctx);
  }

  protected void low_process_recorded_changes (array rec_chgs, Context ctx)
  // This processes ctx->misc->recorded_changes, which is used to
  // record things besides the frames that need to added to result
  // collecting p-code. The format of ctx->misc->recorded_changes
  // might change at any time. Currently it's like this:
  //
  // ctx->misc->recorded_changes is an array concatenated by any of
  // the following sequences:
  //
  // ({mapping vars})
  //   The mapping contains various variable and scope changes. Its
  //   format is dictated by VariableChange.get.
  //
  // ({object with is_RXML_p_code_entry})
  //   An object that will be directly inserted into the p-code.
  //
  // ({string|function callback, array args})
  //   A generic function call to be issued when the p-code is
  //   executed. If the callback is a string, it's the name of a
  //   function to call in ctx->id. The string can also contain an
  //   index chain separated with "->" to call something that is
  //   indirectly referenced from ctx->id.
  //
  // Whenever ctx->misc->recorded_changes exists, it has a (possibly
  // empty) variable mapping as the last entry.
  {
    // Note: This function assumes that there are at least
    // sizeof(rec_chgs) elements available in exec.
    for (int pos = 0; pos < sizeof (rec_chgs);) {
      mixed entry = rec_chgs[pos];
      if (mappingp (entry)) {
	// A variable changes mapping.
	if (sizeof (entry)) {
	  PCODE_MSG ("adding variable changes %s\n", format_short (entry));
	  VariableChange var_chg = VariableChange (entry);
	  var_chg->eval_rxml_consts (ctx);
	  exec[length++] = var_chg;
	}
	pos++;
      }

      else if (objectp (entry) && entry->is_RXML_p_code_entry) {
	PCODE_MSG ("adding p-code entry %O\n", entry);
	exec[length++] = entry;
	pos++;
      }

      else {
	// A callback.
	PCODE_MSG ("adding callback %O (%s)\n",
		   entry, map (rec_chgs[pos + 1], format_short) * ", ");
	exec[length++] = CompiledCallback (entry, rec_chgs[pos + 1]);
	pos += 2;
      }
    }
  }

  void add (Context ctx, mixed entry, mixed evaled_value)
  {
#ifdef DEBUG
    if (flags & FINISHED)
      error ("Adding an entry %s to finished p-code.\n", format_short (entry));
#endif

    if (flags & COLLECT_RESULTS) {
      PCODE_MSG ("adding result value %s\n", format_short (evaled_value));
      if (ctx->misc[" _ok"] != ctx->misc[" _prev_ok"])
	// Special case: Poll for changes of the _ok flag, to avoid
	// widespread compatibility issues with the existing tags.
	ctx->set_misc (" _ok", ctx->misc[" _prev_ok"] = ctx->misc[" _ok"]);
      array rec_chgs = ctx->misc->recorded_changes;
      EXPAND_EXEC (1 + sizeof (rec_chgs));
      exec[length++] = evaled_value;
      if (!equal (rec_chgs, ({([])}))) {
	low_process_recorded_changes (rec_chgs, ctx);
	ctx->misc->recorded_changes = ({([])});
      }
    }
    else {
      PCODE_MSG ("adding entry %s\n", format_short (entry));
      EXPAND_EXEC (1);
      exec[length++] = entry;
    }

    if (p_code) p_code->add (ctx, entry, evaled_value);
  }

#define RESET_FRAME(frame) do {						\
    frame->result = nil;						\
    frame->up = 0;							\
    /* Maybe zap vars too, if it exists? */				\
  } while (0)

  void add_frame (Context ctx, Frame frame, mixed evaled_value,
		  void|int cache_frame, void|array frame_state)
  {
#ifdef DEBUG
    if (flags & FINISHED)
      error ("Adding a frame %O to finished p-code.\n", frame);
#endif

  add_frame: {
      int frame_flags = frame->flags;

    add_evaled_value:
      if (flags & COLLECT_RESULTS) {
	if (frame_flags & FLAG_IS_CACHE_STATIC) {
	  PCODE_MSG ("frame %O has already been result collected recursively\n", frame);
	  break add_frame;
	}
	else {
	  if (ctx->misc[" _ok"] != ctx->misc[" _prev_ok"])
	    // Special case: Poll for changes of the _ok flag, to avoid
	    // widespread compatibility issues with the existing tags.
	    ctx->set_misc (" _ok", ctx->misc[" _prev_ok"] = ctx->misc[" _ok"]);
	  array rec_chgs = ctx->misc->recorded_changes;
	  ctx->misc->recorded_changes = ({([])});
	  if ((frame_flags & (FLAG_DONT_CACHE_RESULT|FLAG_MAY_CACHE_RESULT)) !=
	      FLAG_MAY_CACHE_RESULT)
	    PCODE_MSG ("frame %O not result cached\n", frame);
	  else {
	    if (evaled_value == PCode) {
	      // The PCode value is only used as an ugly magic cookie to
	      // signify that the frame produced no result to add (i.e. it
	      // threw an exception instead). In that case we must keep
	      // the frame unevaluated.
	      frame_flags |= FLAG_DONT_CACHE_RESULT;
	      PCODE_MSG ("frame %O not result cached due to exception\n", frame);
	      break add_evaled_value;
	    }
	    PCODE_MSG ("adding result of frame %O: %s\n",
		       frame, format_short (evaled_value));
	    EXPAND_EXEC (1 + sizeof (rec_chgs));
	    exec[length++] = evaled_value;
	    if (!equal (rec_chgs, ({([])})))
	      low_process_recorded_changes (rec_chgs, ctx);
	    break add_frame;
	  }
	}
      }

      EXPAND_EXEC (3);
      exec[length] = frame->tag || frame; // To make new frames from.
#ifdef DEBUG
      if (!stringp (frame->args) && !functionp (frame->args) &&
	  (frame_flags & FLAG_PROC_INSTR ? frame->args != 0 : !mappingp (frame->args)))
	error ("Invalid args %s in frame about to be added to p-code.\n",
	       format_short (frame->args));
#endif

      if (cache_frame) {
	exec[length + 1] = frame;
	cache_frame = 0;
      }

      if (frame_state)
	exec[length + 2] = frame_state;
      else {
	frame_state = exec[length + 2] = frame->_save();
	if (stringp (frame->args))
	  p_code_comp->delayed_resolve (frame_state, 0);
	RESET_FRAME (frame);
      }

      if (frame_flags != frame->flags) {
	// Must copy the stored frame if we change the flags.
	if (exec[length]->is_RXML_Tag) {
	  frame = exec[length]->Frame();
	  frame->tag = exec[length];
#ifdef RXML_OBJ_DEBUG
	  frame->__object_marker->create (frame);
#endif
	}
	else
	  exec[length] = frame = exec[length]->_clone_empty();
	frame->_restore (exec[length + 2]);
	frame->flags = frame_flags;
	if (stringp (frame->args))
	  p_code_comp->delayed_resolve (frame, "args");
	exec[length + 1] = frame;
      }

      length += 3;
      PCODE_MSG ("added frame %O\n", frame);
    }

    if (p_code) p_code->add_frame (ctx, frame, evaled_value, cache_frame, frame_state);
  }

#ifdef RXML_PCODE_COMPACT_DEBUG
#ifdef RXML_PCODE_DEBUG
#  define PCODE_COMPACT_MSG(X...) PCODE_MSG (X)
#else
#  define PCODE_COMPACT_MSG(X...) do {					\
    report_debug ("PCode()" + OBJ_COUNT + ": " + X);			\
  } while (0)
#endif
#else
#  define PCODE_COMPACT_MSG(X...) do {} while (0)
#endif

  void finish()
  {
#ifdef DEBUG
    if (flags & FINISHED)
      error ("Attempt to finish already finished p-code.\n");
#endif

    if (flags & COLLECT_RESULTS) {
      Context ctx = RXML_CONTEXT;

      if (RequestID id = ctx->id) {
	protocol_cache_time = m_delete (id->misc->local_cacheable, this);
#ifdef DEBUG_CACHEABLE
	if (protocol_cache_time != Int.NATIVE_MAX)
	  report_debug ("%O: Recording max cache time %d.\n",
			this, protocol_cache_time);
	else
	  report_debug ("%O: Max cache time not changed.\n", this);
#endif
      }

      // Install any trailing variable changes. This is useful to
      // catch the last scope leave from a FLAG_IS_CACHE_STATIC
      // optimized frame. With the compaction below it'll therefore
      // often erase an earlier stored scope.
      array rec_chgs = ctx->misc->recorded_changes;
      ctx->misc->recorded_changes = ({([])});
      if (sizeof (rec_chgs)) {
	EXPAND_EXEC (sizeof (rec_chgs));
	low_process_recorded_changes (rec_chgs, ctx);
      }

      if (!(flags & CTX_ALREADY_GOT_VC))
	m_delete (RXML_CONTEXT->misc, "recorded_changes");
      PCODE_MSG ("end result collection\n");

#ifndef DISABLE_RXML_COMPACT
      if (length > 0) {
	// Collapse sequences of constants and VariableChange's, etc.
	// This is actually a simple peephole optimizer. Could be done
	// when not collecting results too, but it's probably not
	// worth the bother then.

	SIMPLE_ID_TRACE_ENTER (ctx->id, ctx->frame || this,
			       "Compacting p-code of size %d", length);
	PCODE_COMPACT_MSG ("  Compact: Start with %O\n", exec[..length - 1]);

	// Collects plain values into a single value. This uses the
	// fact that the order between plain values and all other
	// types of p-code entries except frames are insignificant.
	mixed value = empty;
	String.Buffer strbuf = type->empty_value == "" && String.Buffer();

	// beg is used to limit how far back the peep rules can look. Necessary
	// to not walk backwards into a frame sequence.
	int last = 0, beg = 0;

      compact_loop:
	for (int pos = 0; pos < length;) {
	  // First collect sequences of plain values.

	  if (strbuf) {
	    // Optimize the common string case with a String.Buffer.
	    while (1) {
	      mixed elem = exec[pos];
	      if (!objectp (elem))
		strbuf->add (elem);
	      else if (!elem->is_RXML_p_code_entry) {
		if (!elem->is_rxml_empty_value)
		  strbuf->add (strbuf->get() + elem);
	      }
	      else
		break;
	      if (++pos == length)
		break compact_loop;
	    }
	  }

	  else {
	    mixed elem;
	    while (!objectp (elem = exec[pos]) || !elem->is_RXML_p_code_entry) {
	      value += elem;
	      if (++pos == length)
		break compact_loop;
	    }
	  }

	  if (objectp (exec[pos]) && exec[pos]->is_RXML_p_code_frame) {
	    // Frames are currently not accessible to the peep rules
	    // below. Just copy it and continue.

	    if (strbuf && sizeof (strbuf)) {
	      PCODE_COMPACT_MSG ("  Compact: Adding string at %d\n", last);
	      exec[last++] = strbuf->get();
	    }
	    else if (value != empty) {
	      PCODE_COMPACT_MSG ("  Compact: Adding collected plain value "
				 "at %d\n", last);
	      exec[last++] = value;
	      value = empty;
	    }

	    PCODE_COMPACT_MSG ("  Compact: Moving frame at %d..%d "
			       "to %d..%d\n", pos, pos + 2, last, last + 2);
	    exec[last++] = exec[pos++];
	    exec[last++] = exec[pos++];
	    exec[last++] = exec[pos++];
	    beg = last;
	    continue compact_loop;
	  }

	  else {
	    PCODE_COMPACT_MSG ("  Compact: Shifting %d to %d\n", pos, last);
	    exec[last] = exec[pos++];
	  }

	  // Now reduce the tail as long as any rule applies.
	  while (last > beg) {
	    int reduced = 0;
	    mixed item = exec[last], prev = exec[last - 1];
	    PCODE_COMPACT_MSG ("  Compact: -- Before: [%d..%d] =%{ %O%}\n",
			       max (last - 5, beg), last,
			       exec[max (last - 5, beg)..last]);

	    // The peep rules below can assume there are at least two
	    // p-code elements ({prev, item}) to operate on.

	  try_reduce: {
	      if (prev->is_RXML_VariableChange) {
		if (item->is_csf_leave_scope) {
		  // Got a VariableChange before LeaveScope. Check for
		  // shadowed contents.

		  CLEANUP_VAR_CHG_SCOPE (prev->settings, "_");
		  if (string scope_name = item->frame()->scope_name)
		    CLEANUP_VAR_CHG_SCOPE (prev->settings, scope_name);

		  if (!sizeof (prev->settings)) {
		    PCODE_COMPACT_MSG ("  Compact: RULE 1: Removing shadowed "
				       "VariableChange before LeaveScope\n");
		    exec[--last] = item;
		    break try_reduce;
		  }
		}

		else if (item->is_RXML_VariableChange &&
			 prev->merge (item)) {
		  PCODE_COMPACT_MSG ("  Compact: RULE 2: Merged two "
				     "VariableChange's\n");
		  last--;
		  break try_reduce;
		}
	      }

	      else if (prev->is_csf_enter_scope) {
		if (item->is_csf_enter_scope) {
		  if (item->frame() == prev->frame()) {
		    PCODE_COMPACT_MSG ("  Compact: RULE 3: Removing repeated "
				       "EnterScope\n");
		    last--;
		    break try_reduce;
		  }
		}

		else if (item->is_csf_leave_scope &&
			 prev->frame() == item->frame()) {
		  PCODE_COMPACT_MSG ("  Compact: RULE 4: Removing empty "
				     "EnterScope/LeaveScope pair\n");
		  last -= 2;
		  break try_reduce;
		}
	      }

	      // No reduction done.
	      break;
	    }

	    PCODE_COMPACT_MSG ("  Compact: -- After: [%d..%d] =%{ %O%}\n",
			       max (last - 9, 0), last, exec[last - 9..last]);
	  }

	  last++;
	}

	if (strbuf && sizeof (strbuf)) {
	  PCODE_COMPACT_MSG ("  Compact: Adding last string at %d\n", last);
	  exec[last++] = strbuf->get();
	}
	else if (value != empty) {
	  PCODE_COMPACT_MSG ("  Compact: Adding last collected plain value "
			     "at %d\n", last);
	  exec[last++] = value;
	}
	length = last;

	PCODE_COMPACT_MSG ("  Compact: Done, got %O\n", exec[..length - 1]);
	SIMPLE_ID_TRACE_LEAVE (ctx->id, "Size reduced to %d", length);
      }
#endif
    }

    else {
      // No need to record ctx->id->misc->cacheable when only
      // unevaluated things are stored in the p-code entry.
      PCODE_MSG ("end content collection\n");
    }

    if (length != sizeof (exec)) exec = exec[..length - 1];
    p_code = 0;
    flags |= FINISHED;
  }

  mixed _eval (Context ctx, PCode new_p_code)
  //! Like @[eval], but assumes the given context is current. Mostly
  //! for internal use.
  {
    int pos = 0;
    array parts;
    int ppos = 0;
    int update_count = ctx->state_updated;
#ifdef DEBUG
    if (!(flags & FINISHED)) report_warning ("Evaluating unfinished p-code.\n");
    if (p_code)
      error ("Chained p-code may only be set while a PCode object is being compiled.\n");
#endif

#if 0
    // This check doesn't work in some "chicken-and-egg" cases when
    // the executed p-code causes tag set updates. Can occur in the
    // admin interface, for instance. (To be _really_ correct in those
    // cases we should switch over to source code on the fly, but it's
    // unlikely to be a practical problem to finish the evaluation
    // with stale code in the current request and then create new
    // first in the next one.)
#ifdef MODULE_DEBUG
    if (tag_set && tag_set->generation != generation)
      error ("P-code is stale - tag set %O has generation %d and not %d.\n",
	     tag_set, tag_set->generation, generation);
#endif
#endif

    if (ctx->unwind_state)
      [object ignored, pos, parts, ppos] =
	m_delete (ctx->unwind_state, this_object());
    else {
      parts = allocate (length);
      if (protocol_cache_time < Int.NATIVE_MAX && ctx->id)
	ctx->id->lower_max_cache (protocol_cache_time);
    }

    PCODE_MSG ((p_code_comp ?
		sprintf ("evaluating partially resolved p-code %O, using "
			 "resolver %O\n", this_object(), p_code_comp) :
		sprintf ("evaluating completely resolved p-code %O\n",
			 this_object())));

    while (1) {			// Loops only if errors are catched.
      mixed item;
      Frame frame;

      // Don't want to leak recorded changes to the surrounding scope,
      // so we'll replace it with an empty one. The original is
      // restored before return below.
      array saved_recorded_changes = ctx->misc->recorded_changes;
      ctx->misc->recorded_changes = ({([])});

      if (mixed err = catch {

	if (p_code_comp) {
	  p_code_comp->compile();
	  if (flags & FINISHED) p_code_comp = 0;
	}

	for (; pos < length; pos++) {
	  item = exec[pos];

	chained_p_code_add: {
	    if (objectp (item))
	      if (item->is_RXML_p_code_frame) {

		if ((frame = exec[pos + 1])) {
		  /* Relying on the interpreter lock here. */
		  exec[pos + 1] = 0;
		}
		else {
		  if (item->is_RXML_Tag) {
		    frame = item->Frame();
		    frame->tag = item;
#ifdef RXML_OBJ_DEBUG
		    frame->__object_marker->create (frame);
#endif
		  }
		  else frame = item->_clone_empty();
		  frame->_restore (exec[pos + 2]);
		}

		item = frame->_eval (
		  ctx, this_object(), type); /* Might unwind. */

		if (flags & COLLECT_RESULTS &&
		    ((frame->flags & (FLAG_DONT_CACHE_RESULT|FLAG_MAY_CACHE_RESULT)) ==
		     FLAG_MAY_CACHE_RESULT)) {
		  exec[pos] = item;
		  /* Relying on the interpreter lock here. */
		  exec[pos + 1] = exec[pos + 2] = nil;
		  flags |= UPDATED;
		  update_count = ++ctx->state_updated;
		  PCODE_UPDATE_MSG ("%O (ctx %O, frame %O): P-code update to "
				    "%d due to result collection.\n",
				    this, ctx, frame, update_count);
		  if (new_p_code) new_p_code->add_frame (ctx, frame, item, 1);
		}

		else {
		  if (ctx->state_updated > update_count) {
		    array frame_state = frame->_save();
		    if (stringp (frame_state[0]))
		      // Must resolve before updating the exec array
		      // since it might be evaluated concurrently in
		      // other threads, and the check on p_code_comp
		      // is only done at the start.
		      frame_state[0] = frame->args =
			p_code_comp->resolve (frame_state[0]);
		    exec[pos + 2] = frame_state;
		    flags |= UPDATED;
		    PCODE_UPDATE_MSG ("%O (ctx %O, frame %O): Marked as "
				      "updated due to ctx->state_updated "
				      "%d > %d.\n", this, ctx, frame,
				      ctx->state_updated, update_count);
		    update_count = ctx->state_updated;
		  }
		  if (!exec[pos + 1]) {
		    RESET_FRAME (frame);
		    /* Race here, but it doesn't matter much. */
		    exec[pos + 1] = frame;
		    if (new_p_code) new_p_code->add_frame (ctx, frame, item, 0);
		  }
		  else
		    if (new_p_code) new_p_code->add_frame (ctx, frame, item, 1);
		}

		pos += 2;
		break chained_p_code_add;
	      }

	      else if (item->is_RXML_p_code_entry)
		item = item->get (ctx); /* Might unwind. */

	    if (new_p_code) new_p_code->add (ctx, item, item);
	  }

	  if (item != nil)
	    parts[ppos++] = item;
	  if (string errmsgs = m_delete (ctx->misc, this_object()))
	    parts[ppos++] = errmsgs;
	}

	ctx->eval_finish (1);
	ctx->id->eval_status["rxmlpcode"] = 1;

	if (ctx->state_updated > update_count) {
	  PCODE_UPDATE_MSG ("%O (ctx %O): Marked as updated due to "
			    "ctx->state_updated %d > %d.\n", this, ctx,
			    ctx->state_updated, update_count);
	  flags |= UPDATED;
	}

        if (new_p_code) {
          array rec_chgs = ctx->misc->recorded_changes;
          if (sizeof (rec_chgs)) {
            new_p_code->process_recorded_changes (rec_chgs, ctx);
          }
        }
        ctx->misc->recorded_changes = saved_recorded_changes;

	if (!ppos)
	  return type->sequential ? type->copy_empty_value() : nil;
	else
	  if (type->sequential)
	    return `+ (type->empty_value, @parts[..ppos - 1]);
	  else
	    if (ppos != 1) return utils->get_non_nil (type, @parts[..ppos - 1]);
	    else return parts[0];

      }) {
        ctx->misc->recorded_changes = saved_recorded_changes;

	if (objectp (err) && ([object] err)->thrown_at_unwind) {
	  ctx->unwind_state[this_object()] = ({err, pos, parts, ppos});
	  throw (this_object());
	}

	else {
	  PCODE_UPDATE_MSG (
	    "%O (item %O): Restoring p-code update count "
	    "from %d to %d since the frame is stored unevaluated "
	    "due to exception.\n",
	    ctx, item, ctx->state_updated, update_count);
	  ctx->state_updated = update_count;

	  if (new_p_code)
	    if (objectp (item) && item->is_RXML_p_code_frame)
	      new_p_code->add_frame (ctx, frame, PCode, 1);
	    else
	      new_p_code->add (ctx, item, item);

	  err = catch {
	    ctx->handle_exception (err, this_object()); // May throw.
	    string msgs = m_delete (ctx->misc, this_object());
	    if (pos >= length)
	      return msgs || nil;
	    else {
	      if (msgs) parts[ppos++] = msgs;
	      if (objectp (exec[pos]) && exec[pos]->is_RXML_p_code_frame)
		pos += 3;
	      else
		pos++;
	      continue;
	    }
	  };

	  if (tag_set && tag_set->generation != generation)
	    catch {
	      if (!has_suffix (err[0],
			       "Note: Error happened in stale p-code.\n"))
		err[0] += "Note: Error happened in stale p-code.\n";
	    };
	  throw (err);
	}
      }

      error ("Should not get here.\n");
    }
    error ("Should not get here.\n");
  }

  string compile_text (PikeCompile comp)
  //! Returns a string containing a Pike expression that evaluates the
  //! value of this @[PCode] object, assuming the current context is
  //! in a variable named @tt{ctx@} and the parent evaluator in
  //! @tt{evaler@}. It also assumes there's a mixed variable called
  //! @tt{tmp@} for temporary use. No code is added to handle
  //! exception unwinding and rewinding, checks for staleness, chained
  //! p-code or state updates. Mostly for internal use.
  {
    string typevar = comp->bind (type);

    if (!length)
      return type->sequential ? typevar + "->copy_empty_value()" : "RXML.nil";

    array(string) parts = allocate (length);

    for (int pos = 0; pos < length; pos++) {
      mixed item = exec[pos];
      if (objectp (item))
	if (item->is_RXML_p_code_frame) {
	  // NB: We currently don't use the cached frame in
	  // exec[pos+1] here.
	  string|EVAL_ARGS_FUNC argfunc = exec[pos + 2][0];
	  if (stringp (argfunc))
	    // It's possible to delay this by adding code to set the
	    // argfunc slot below.
	    exec[pos + 2][0] = comp->resolve (argfunc);
	  parts[pos] = sprintf (
	    (item->is_RXML_Tag ?
	     "(tmp=%s.Frame(),tmp->tag=%[0]s," : "(tmp=%s._clone_empty(),") +
	    "tmp->_restore(%s),"
	    "tmp->_eval(ctx,evaler,%s))",
	    comp->bind (item),
	    comp->bind (exec[pos + 2]),
	    typevar);
	  pos += 2;
	  continue;
	}
	else if (item->is_RXML_p_code_entry) {
	  parts[pos] = sprintf ("%s.get(ctx)", comp->bind (item));
	  continue;
	}
      parts[pos] = comp->bind (exec[pos]);
    }

    if (type->sequential)
      return comp->bind (type->empty_value) + "+" + parts * "+";
    else
      if (length == 1) return parts[0];
      else return sprintf ("RXML.utils.get_non_nil(%s,%s)", typevar, parts * ",");
  }

  int report_error (string msg)
  {
    mapping misc = RXML_CONTEXT->misc;
    if (misc[this_object()]) misc[this_object()] += msg;
    else misc[this_object()] = msg;
    return 1;
  }

  protected void _take (PCode other)
  {
    // Relying on the interpreter lock in this function.
    type = other->type;
    tag_set = other->tag_set;
    recover_errors = other->recover_errors;
    exec = other->exec, other->exec = 0;
    length = other->length;
    flags = other->flags;
    generation = other->generation;
    protocol_cache_time = other->protocol_cache_time;
    p_code_comp = other->p_code_comp;
  }

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (int flag, mapping args)
  {
    if (flag != 'O') return 0;
    string intro = tag_set ?
      sprintf ("%s(%O,%O", args->this_name || "RXML.PCode", type, tag_set) :
      sprintf ("%s(%O", args->this_name || "RXML.PCode", type);
    if (args->verbose)
      if (!exec || !sizeof (exec))
	return intro + ": no code)" + OBJ_COUNT;
      else {
	array compacted = allocate (sizeof (exec));
	int ci = 0;
	for (int i = 0; i < sizeof (exec); i++) {
	  compacted[ci++] = exec[i];
	  if (objectp (exec[i]) && exec[i]->is_RXML_p_code_frame) i += 2;
	}
	compacted = compacted[..ci - 1];
	if (sizeof (compacted) == 1)
	  return sprintf ("%s: %s)%s", intro, format_short (compacted[0]), OBJ_COUNT);
	else
	  return sprintf ("%s:\n  %s)%s",
			  intro, map (compacted, format_short) * ",\n  ", OBJ_COUNT);
      }
    else
      return intro + ")" + OBJ_COUNT;
  }

  constant P_CODE_VERSION = "7.2";
  // Version spec encoded with the p-code, so we can detect and reject
  // incompatible p-code dumps even when the encoded format hasn't
  // changed in an obvious way.
  //
  // The integer part is increased for every roxen version, and the
  // fraction part is increased for every incompatible p-code change.

  mixed _encode()
  {
#ifdef DEBUG
    if (!(flags & FINISHED)) report_warning ("Encoding unfinished p-code.\n");
#endif

    if (p_code_comp) {
      p_code_comp->compile();
      p_code_comp = 0;
    }

    if (length != sizeof (exec)) exec = exec[..length - 1];
    array encode_p_code = exec + ({});
    for (int pos = 0; pos < length; pos++) {
      mixed item = encode_p_code[pos];
      if (objectp (item) && item->is_RXML_p_code_frame) {
	encode_p_code[pos + 1] = 0; // Don't encode the cached frame.
	// The following are debug checks, but let's always do them
	// since this case would be very hard to track down otherwise.
	if (stringp (encode_p_code[pos + 2][0]))
	  error ("Unresolved argument function in frame state %O at position %d.\n",
		 encode_p_code[pos + 2], pos + 2);
	if (exec[pos + 1] && stringp (exec[pos + 1]->args))
	  error ("Unresolved argument function %O in frame %O at position %d.\n",
		 exec[pos + 1]->args, exec[pos + 1], pos + 1);
      }
    }

    return ({P_CODE_VERSION, flags & (COLLECT_RESULTS|FINISHED),
	     tag_set, tag_set && tag_set->get_hash(),
	     type, recover_errors, encode_p_code, protocol_cache_time});
  }

  void _decode(array v, int check_hash)
  {
    [string|int version, flags, tag_set, string tag_set_hash,
     type, recover_errors, exec, protocol_cache_time] = v;
    if (version != P_CODE_VERSION)
      p_code_stale_error (
	"P-code is stale - it was made with an incompatible version.\n");
    length = sizeof (exec);
    if (tag_set) {
      if (check_hash && tag_set->get_hash() != tag_set_hash)
	p_code_stale_error (
	  "P-code is stale - the tag set has changed since it was encoded.\n");
      generation = tag_set->generation;
    }

    // Instantiate the cached frames, mainly so that any errors in
    // their restore functions due to old data are triggered here and
    // not later during evaluation.
    for (int pos = 0; pos < length; pos++) {
      mixed item = exec[pos];
      if (objectp (item) && item->is_RXML_p_code_frame) {
	Frame frame;
	if (item->is_RXML_Tag) {
	  exec[pos + 1] = frame = item->Frame();
	  frame->tag = item;
#ifdef RXML_OBJ_DEBUG
	  frame->__object_marker->create (frame);
#endif
	}
	else
	  exec[pos + 1] = frame = item->_clone_empty();
	frame->_restore (exec[pos + 2]);
	pos += 2;
      }
    }
  }

  array(mixed) collect_things_recur()
  {
    // Note: limit is on visited nodes, not resulting entries. Don't
    // raise above 100k without considering the stack limit below.
    constant limit = 10000;

    ADT.Queue queue = ADT.Queue();
    mapping(mixed:int) visited = ([]);

    queue->write (this);

    for (int i = 0; sizeof (queue) && i < limit; i++) {
      mixed entry = queue->read();

      if (functionp (entry) || visited[entry])
	continue;

      visited[entry] = 1;

      if (arrayp (entry) || mappingp (entry) || multisetp (entry)) {
	foreach (entry; mixed ind; mixed val) {
	  if (!arrayp (entry))
	    queue->write (ind);
	  if (!multisetp (entry))
	    queue->write (val);
	}
      } else if (objectp (entry)) {
	if (entry->is_RXML_PCode)
	  queue->write (entry->exec);
      }
    }

#ifdef DEBUG
    if (int size = sizeof (queue))
      werror ("PCode.collect_things_recur: more than %d iterations in "
	      "cache_count_memory (%d entries left).\n", limit, size);
#endif

    return indices(visited);
  }

  int cache_count_memory (int|mapping opts)
  {
    array(mixed) things = collect_things_recur();
    // Note 100k entry stack limit (use 99k as an upper safety
    // limit). Could split into multiple calls if necessary.
    return Pike.count_memory (opts + ([ "lookahead": 5 ]), @things[..99000]);
  }
}

class RenewablePCode
//! A variant of @[PCode] that also contains the source data, so it
//! can automatically recover if the p-code becomes stale.
{
  inherit PCode;

  string source;
  //! The source code used to generate the p-code.

  int is_stale() {return 0;}


  // Internals:

  mixed _eval (Context ctx, PCode new_p_code)
  {
    if (::is_stale()) {
      Parser parser = 0;
      if (ctx->unwind_state)
	[parser] = m_delete (ctx->unwind_state, this_object());

      int orig_make_p_code = ctx->make_p_code;
      PCode renewed_p_code;
      mixed res;
      if (mixed err = catch {
	ctx->make_p_code = 1;
	if (!parser) {
	  renewed_p_code = PCode (type, ctx, tag_set, 0, p_code_comp);
	  renewed_p_code->recover_errors = recover_errors;
	  renewed_p_code->p_code = new_p_code;
	  parser = type->get_parser (ctx, tag_set, 0, renewed_p_code);
	  parser->finish (source); // Might unwind.
	}
	else parser->finish();	// Might unwind.
	res = parser->eval();	// Might undwind.
	flags |= UPDATED;
	PCODE_UPDATE_MSG ("%O (ctx %O): Marked as updated after "
			  "reevaluation.\n", this, ctx);
      }) {
	ctx->make_p_code = orig_make_p_code;
	if (objectp (err) && err->thrown_at_unwind) {
	  ctx->unwind_state[this_object()] = ({parser});
	  throw (this_object());
	}
	else throw (err);
      }

      renewed_p_code->finish();
      if (new_p_code) new_p_code->finish();
      renewed_p_code->flags |= UPDATED;
      PCODE_UPDATE_MSG ("%O (ctx %O): Marked as updated after "
			"reevaluation.\n", renewed_p_code, ctx);
      _take (renewed_p_code);	// Assumed to be atomic.

      type->give_back (parser, tag_set);
      return res;
    }
    else
      return ::_eval (ctx, new_p_code);
  }

  array _encode()
  {
    return ({::_encode(), source});
  }

  void _decode (array encoded, int check_hash)
  {
    ::_decode (encoded[0], check_hash);
    source = encoded[1];
  }

  string _sprintf (int flag, mapping args)
  {
    return ::_sprintf (flag, args + (["this_name": "RXML.RenewablePCode"]));
  }
}

#ifdef RXML_ENCODE_DEBUG
#  define ENCODE_MSG(X...) do report_debug (X); while (0)
#  define ENCODE_DEBUG_RETURN(val) do {					\
  mixed _v__ = (val);							\
  report_debug ("  returned %s\n",					\
		zero_type (_v__) ? "UNDEFINED" :			\
		format_short (_v__, 160));				\
  return _v__;								\
} while (0)
#else
#  define ENCODE_MSG(X...) do {} while (0)
#  define ENCODE_DEBUG_RETURN(val) do return (val); while (0)
#endif

constant is_RXML_encodable = 1;
protected object rxml_module = this_object();

class PCodeEncoder
{
  inherit Master.Encoder;

  Configuration default_config;

  protected void create (Configuration default_config)
  {
    ::create();
    this_program::default_config = default_config;
  }

  protected string cwd = combine_path (getcwd()) + "/";

  string|array nameof(mixed what)
  {
    // All our special things are prefixed with "R" to ensure there's
    // no conflict with the pike standard codec (it never uses any
    // uppercase letters).

    if (objectp (what)) {
      ENCODE_MSG ("nameof (object %O)\n", what);

      if (what->is_RXML_Frame) {
	if (Tag tag = what->RXML_dump_frame_reference && what->tag)
	  ENCODE_DEBUG_RETURN (({"Rfr", tag, what->_save()}));
	ENCODE_MSG ("  encoding frame recursively since " +
		    (what->RXML_dump_frame_reference ?
		     "it got no tag object\n" :
		     "it got no identifier RXML_dump_frame_reference\n"));
	return ([])[0];
      }

      else if (what->is_RXML_Tag) {
	if (what->name && what->tagset)
	  ENCODE_DEBUG_RETURN (({
	    "Rtag",
	    what->tagset,
	    what->flags & FLAG_PROC_INSTR,
	    what->name + (what->plugin_name? "#"+what->plugin_name : "")}));
	ENCODE_MSG ("  encoding tag recursively since " +
		    (what->name ? "it got no tag set\n" : "it's nameless\n"));
	return ([])[0];
      }

      else if (what->is_RXML_TagSet) {
	if (what->name)
	  ENCODE_DEBUG_RETURN (({"Rts", what->owner, what->name}));
	if (array components = what->tag_set_components())
	  ENCODE_DEBUG_RETURN (({"Rcts"}) + components);
	error ("Cannot encode unnamed tag set %O.\n", what);
      }

      else if (what->is_RXML_Type) {
	string parser_name = what->parser_prog->name;
#ifdef DEBUG
	if (!reg_parsers[parser_name])
	  error ("Cannot encode unregistered parser at %s in type %O.\n",
		 Program.defined (what->parser_prog), what);
#endif
	ENCODE_DEBUG_RETURN (({"Rtype", what->name, parser_name}) +
			     what->parser_args);
      }

      else if (what->is_module)
	ENCODE_DEBUG_RETURN (({"Rmod",
			       what->my_configuration(),
			       what->module_local_id()}));

      else if (what->is_configuration)
	ENCODE_DEBUG_RETURN (({"Rconf",
			       what != default_config && what->name,
			       what->compat_level()}));

      else if (what == nil)
	ENCODE_DEBUG_RETURN ("Rnil");
      else if (what == empty)
	ENCODE_DEBUG_RETURN ("Rempty");
      else if (what == rxml_module)
	ENCODE_DEBUG_RETURN ("RRXML");
      else if (what == utils)
	ENCODE_DEBUG_RETURN ("Rutils");
      else if (what == xml_tag_parser)
	ENCODE_DEBUG_RETURN ("Rxtp");
#ifdef RXML_OBJ_DEBUG
      else if (object_program (what) == RoxenDebug.ObjectMarker)
	ENCODE_DEBUG_RETURN (({
	  "RObjectMarker",
	  reverse (array_sscanf (reverse (what->id), "]%*d[%s")[0])}));
#endif
      else if (what->is_RXML_encodable) {
	ENCODE_MSG ("  encoding object recursively\n");
	return ([])[0];
      }
    }

    else {
      if (programp (what)) {
	ENCODE_MSG ("nameof (program %s)\n", Program.defined (what));
	if (what->is_RXML_pike_code) {
	  ENCODE_MSG ("  encoding byte code\n");
	  return ([])[0];
	}

	else if (what->is_RXML_Parser) {
#ifdef DEBUG
	  if (!reg_parsers[what->name])
	    error ("Cannot encode unregistered parser at %s.\n",
		   Program.defined (what));
#endif
	  ENCODE_DEBUG_RETURN (({"Rp", what->name}));
	}

	else if (functionp (what) && what->is_RXML_encodable) {
	  // If the program also is a function the encoder won't dump
	  // the byte code, but instead the parent object and the
	  // identifier within it.
	  ENCODE_MSG ("  encoding reference to program %O in object %O\n",
		      what, function_object (what));
	  return ([])[0];
	}
      }
      else
	ENCODE_MSG ("nameof (%O)\n", what);

      if (object o = functionp (what) && function_object (what))
	if (o->is_RXML_encodable) {
	  ENCODE_MSG ("  encoding reference to function %O in object %O\n", what, o);
	  return ([])[0];
	}
    }

    // Fall back to the pike encoder. This is mainly useful to look up
    // pike modules.
    string|array pike_name = ::nameof (what);

    // Make any file paths relative to the server tree.
    if (stringp (pike_name)) {
      sscanf (pike_name, "%1s%s", string cls, string path);
      if ((<"p", "o", "f">)[cls]) {
	if (has_prefix (path, cwd))
	  pike_name = "Rf:" + cls + path[sizeof (cwd)..];
	else if (has_prefix (path, roxenloader.server_dir + "/"))
	  pike_name = "Rf:" + cls + path[sizeof (roxenloader.server_dir + "/")..];
	else
	  report_warning ("Encoding absolute pike file path %O into p-code.\n"
			  "This can probably lead to problems if replication "
			  "is in use.\n", path);
      }
    }
    else {
      sscanf (pike_name[0], "%1s%s", string cls, string path);
      if ((<"p", "o", "f">)[cls]) {
	if (has_prefix (path, cwd))
	  pike_name[0] = "Rf:" + cls + path[sizeof (cwd)..];
	else if (has_prefix (path, roxenloader.server_dir + "/"))
	  pike_name[0] = "Rf:" + cls + path[sizeof (roxenloader.server_dir + "/")..];
	else
	  report_warning ("Encoding absolute pike file path %O into p-code.\n"
			  "This can probably lead to problems if replication "
			  "is in use.\n", path);
      }
    }

    ENCODE_DEBUG_RETURN (pike_name);
  }

  mixed encode_object (object x)
  {
    ENCODE_MSG ("encode_object (%O)\n", x);
    if (x->_encode && x->_decode) ENCODE_DEBUG_RETURN (x->_encode());
    error ("Cannot encode object %O at %s without _encode() and _decode().\n",
	   x, Program.defined (object_program (x)));
  }

  string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("RXML.PCodeEncoder(%O)", default_config);
  }
}

class PCodeDecoder
{
  inherit Master.Decoder;

  Configuration default_config;
  int check_tag_set_hash;

  protected void create (Configuration default_config, int check_tag_set_hash)
  {
    ::create();
    this_program::default_config = default_config;
    this_program::check_tag_set_hash = check_tag_set_hash;
  }

  mixed thingof(string|array what)
  {
    if (arrayp (what)) {
      ENCODE_MSG ("thingof (({%{%O, %}}))\n", what);

      switch (what[0]) {
	case "Rfr": {
	  [string ignored, Tag tag, mixed saved] = what;
	  Frame frame = tag->Frame();
	  frame->tag = tag;
#ifdef RXML_OBJ_DEBUG
	  frame->__object_marker->create (frame);
#endif
	  frame->_restore (saved);
	  ENCODE_DEBUG_RETURN (frame);
	}

	case "Rtag": {
	  [string ignored, TagSet tag_set, int proc_instr, string name] = what;
	  if (Tag tag = tag_set->get_local_tag(name, proc_instr))
	    ENCODE_DEBUG_RETURN (tag);
	  error ("Cannot find %s %O in tag set %O.\n",
		 proc_instr ? "processing instruction" : "tag",
		 name, tag_set);
	}

	case "Rts": {
	  [string ignored, object(RoxenModule)|object(Configuration) owner,
	   string name] = what;
	  if (TagSet tag_set = LOOKUP_TAG_SET (owner, name))
	    if (objectp (tag_set))
	      ENCODE_DEBUG_RETURN (tag_set);
	  error ("Cannot find tag set %O in %O.\n", name, owner);
	}

	case "Rcts": {
	  TagSet tag_set;
	  GET_COMPOSITE_TAG_SET (what[1], what[2], tag_set);
	  ENCODE_DEBUG_RETURN (tag_set);
	}

	case "Rtype": {
	  program/*(Parser)*/ parser_prog = reg_parsers[what[2]];
	  if (!parser_prog)
	    error ("Cannot find parser %O.\n", what[2]);
	  ENCODE_DEBUG_RETURN (reg_types[what[1]] (parser_prog, @what[3..]));
	}

	case "Rmod": {
	  [string ignored, Configuration config, string name] = what;
	  if (RoxenModule mod = config->find_module (name))
	    ENCODE_DEBUG_RETURN (mod);
	  error ("Cannot find module %O in configuration %O.\n", what, config);
	}

	case "Rconf": {
	  Configuration config;
	  if (!what[1]) {
#ifdef DEBUG
	    if (!default_config)
	      error ("No default configuration given to string_to_p_code.\n");
#endif
	    config = default_config;
	  }
	  else if (!(config = roxen->get_configuration (what[1])))
	    error ("Cannot find configuration %O.\n", what[1]);
	  int int_enc_compat_level = (int) round (what[2] * 1000);
	  if ((int) (config->compat_level() * 1000) != int_enc_compat_level)
	    p_code_stale_error ("P-code is stale - it was encoded with "
				"compatibility level %O, "
				"but now running with %O.\n",
				int_enc_compat_level / 1000.0,
				config->compat_level());
	  ENCODE_DEBUG_RETURN (config);
	}

	case "Rp":
	  if (program/*(Parser)*/ parser_prog = reg_parsers[what[1]])
	    ENCODE_DEBUG_RETURN (parser_prog);
	  error ("Cannot find parser %O.\n", what[1]);

#ifdef RXML_OBJ_DEBUG
	case "RObjectMarker":
	  ENCODE_DEBUG_RETURN (RoxenDebug.ObjectMarker (what[1]));
#endif

	default:
	  if (sscanf (what[0], "Rf:%1s%s", string cls, string path) == 2)
	    what[0] = cls + roxenloader.server_dir + "/" + path;
	  ENCODE_DEBUG_RETURN (::thingof (what));
      }
    }

    else {
      ENCODE_MSG ("thingof (%O)\n", what);

      switch (what) {
	case "Rnil": ENCODE_DEBUG_RETURN (nil);
	case "Rempty": ENCODE_DEBUG_RETURN (empty);
	case "RRXML": ENCODE_DEBUG_RETURN (rxml_module);
	case "Rutils": ENCODE_DEBUG_RETURN (utils);
	case "Rxtp": ENCODE_DEBUG_RETURN (xml_tag_parser);

	case "RXML":
	  // Kludge to detect p-code encoded with an earlier version
	  // of the codec. As it happens, the first thing we get in
	  // that case is the string "RXML" from the old encoding of
	  // rxml_module.
	  p_code_stale_error ("P-code is stale - "
			      "it was made with an incompatible version "
			      "of the codec.\n");

	default:
	  if (sscanf (what, "Rf:%1s%s", string cls, string path) == 2)
	    what = cls + roxenloader.server_dir + "/" + path;
	  ENCODE_DEBUG_RETURN (::thingof (what));
      }
    }

    error ("Cannot decode %O.\n", what);
  }

  void decode_object (object x, mixed data)
  {
    ENCODE_MSG ("decode_object (%O)\n", x);
    if (x->is_RXML_PCode) x->_decode (data, check_tag_set_hash);
    else if (x->_decode) x->_decode (data);
    else error ("Cannot decode object %O at %s without _decode().\n",
		x, Program.defined (object_program (x)));
  }

  string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("RXML.PCodec(%O,%d)", default_config, check_tag_set_hash);
  }
}

protected mapping(Configuration:PCodeEncoder) p_code_encoders = ([]);

string p_code_to_string (PCode p_code, void|Configuration default_config)
//! Encodes the @[PCode] object @[p_code] to a string which can be
//! decoded by @[string_to_p_code].
//!
//! A default @[Configuration] object can be given as the second
//! argument. Whenever it's encountered (typically when encoding
//! references to @[TagSet] or @[RoxenModule] instances), a special
//! value is encoded instead so that references to that configuration
//! are replaced with references to the corresponding default
//! configuration given to @[p_code_to_string].
{
  PCodeEncoder encoder =
    p_code_encoders[default_config] ||
    (p_code_encoders[default_config] = PCodeEncoder (default_config));
  return encode_value (p_code, encoder);
}

protected mapping(Configuration:array(PCodeDecoder)) p_code_decoders = ([]);

PCode string_to_p_code (string str, void|Configuration default_config,
			void|int ignore_tag_set_hash)
//! Decodes a @[PCode] object from the string @[str] encoded by
//! @[p_code_to_string].
//!
//! If the call to @[p_code_to_string] had a default configuration
//! specified, then @[default_config] should be set to the
//! configuration you wish to map that one to.
//!
//! If @[ignore_tag_set_hash] is nonzero, the check of the tag set
//! hash in the p-code against the actual tag set is disabled. That
//! check is done to ensure that the p-code isn't used when previously
//! unparsed tags become parsed, but it can be useful to disable it to
//! avoid the need for the tag sets to be completely equivalent
//! between the encoding and the decoding server. The decode will
//! still fail if there are references to tags that doesn't exist.
//!
//! The decode can fail for many reasons, e.g. because some tag, tag
//! set or module doesn't exist, or because it was encoded with a
//! different Pike version, or because the coding format has changed.
//! All such errors are thrown as @[PCodeStaleError] exceptions. The
//! caller should catch them and fall back to RXML evaluation from
//! source.
{
  array(PCodeDecoder) decoders =
    p_code_decoders[default_config] ||
    (p_code_decoders[default_config] = ({0, 0}));
  PCodeDecoder decoder =
    decoders[!ignore_tag_set_hash] ||
    (decoders[!ignore_tag_set_hash] =
     PCodeDecoder (default_config, !ignore_tag_set_hash));

  mixed err = catch {
      return [object(PCode)] decode_value (str, decoder);
    };

  // Ugly way to recognize the errors from decode_value that are due
  // to staleness.
  string errmsg = describe_error (err);
  if (has_value (errmsg, "Bad instruction checksum") ||
      has_value (errmsg, "encoded with other pike version") ||
      has_value (errmsg, "Unsupported byte-code method") ||
      has_value (errmsg, "Unsupported byte-order"))
    p_code_stale_error ("P-code is stale - " + errmsg);
  else
    throw (err);
}

// Some parser tools:

Empty empty = Empty();
//! An object representing the empty value for @[RXML.t_any]. It works
//! as initializer for sequences since @[RXML.empty] + anything ==
//! anything + @[RXML.empty] == anything. It can also cast itself to
//! the empty value for the basic Pike types.
//!
//! @note
//! As opposed to @[RXML.nil], it's not false in a boolean context.

class Empty
//! The class of @[RXML.empty]. There should only be a single
//! @[RXML.empty] instance, so this class should never be
//! instantiated. It's only available to allow inherits.
{
  // Tell Pike.count_memory this is global.
  constant pike_cycle_depth = 0;

  constant is_rxml_empty_value = 1;
  //! Used in some places to test for an empty value, i.e. a value
  //! that may be ignored in concatenations using `+.
  //!
  //! This is set in both @[RXML.empty] and @[RXML.nil].

  mixed `+ (mixed... vals) {return sizeof (vals) ? predef::`+ (@vals) : this_object();}
  mixed ``+ (mixed... vals) {return sizeof (vals) ? predef::`+ (@vals) : this_object();}
  string _sprintf (int flag) {return flag == 'O' && "RXML.empty";}

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
      fatal_error ("Cannot cast %O to %s.\n", this, type);
    }
  }
}

Nil nil = Nil();
//! An object representing no value. It evaluates to false in a
//! boolean context, but it's not equal to 0. There's no semantic
//! difference between assigning this to a variable and removing the
//! variable binding altogether.
//!
//! Like @[RXML.empty], it holds that nil + anything == anything + nil
//! == anything, on the principle that the @expr{+@} operator in
//! essence is called with one argument in those cases. This avoids
//! special handling of tags that return no result in sequential
//! types.
//!
//! For compatibility, @[RXML.nil] can be cast to the empty value for
//! the basic Pike types.

class Nil
//! The class of @[RXML.nil]. There should only be a single
//! @[RXML.nil] instance, so this class should never be instantiated.
//! It's only available to allow inherits.
{
  // Only inherit implementation; there's no type-wise significance
  // whatsoever of this inherit.
  inherit Empty;

  constant is_rxml_null_value = 1;
  //! Used to test for a false value in a boolean rxml context.
  //!
  //! This constant lumps together various special objects like
  //! @[RXML.nil], @[Roxen.false], and @[Roxen.null] that should be
  //! considered false in boolean contexts.
  //!
  //! @note
  //! The name is confusing, for historical reasons.

  int `!() {return 1;}
  string _sprintf (int flag) {return flag == 'O' && "RXML.nil";}
}

Nil Void = nil;			// Compatibility.

mixed add_to_value (Type type, mixed value, mixed piece)
//! Adds @[piece] to @[value] according to @[type]. If @[type] is
//! sequential, they're concatenated with @[`+]. If @[type] is
//! nonsequential, either @[value] or @[piece] is returned if the
//! other is @[RXML.nil] and an error is thrown if neither is nil.
{
  if (type->sequential)
    return value + piece;
  else
    if (piece == nil) return value;
    else if (value != nil)
      parse_error ("Cannot append another value %s to nonsequential "
		   "result of type %s.\n", format_short (piece), type->name);
    else return piece;
}

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
  //! Returns the next token, or @[RXML.nil] if there's no more data.
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

  //! @ignore
  MARK_OBJECT;
  //! @endignore

  string _sprintf (int flag)
  {
    return flag == 'O' && ("RXML.ScanStream()" + OBJ_COUNT);
  }
}

private class Link
{
  array data;
  Link next;
}


// Various internal kludges:

protected Type splice_arg_type;

protected object/*(Parser.HTML)*/ xml_tag_parser;
protected object/*(Parser.HTML)*/
  charref_decode_parser, tolerant_charref_decode_parser,
  tolerant_xml_safe_charref_decode_parser,
  lowercaser, uppercaser, capitalizer;

protected void init_parsers()
{
  object/*(Parser.HTML)*/ p = compile (
    // This ugliness is currently the only way to inherit Parser.HTML
    // inside this module.
    "inherit Parser.HTML;"
    "constant is_RXML_encodable = 1;")();
  p->xml_tag_syntax (3);
  p->match_tag (0);
  xml_tag_parser = p;

#define TRY_DECODE_CHREF(CHREF, FILTER) do {				\
    if (sizeof (CHREF) && CHREF[0] == '#')				\
      if ((<"#x", "#X">)[CHREF[..1]]) {					\
	if (sscanf (CHREF, "%*2s%x%*c", int c) == 2) {			\
	  string chr = (string) ({c});					\
	  {FILTER;}							\
	  return ({chr});						\
	}								\
      }									\
      else								\
	if (sscanf (CHREF, "%*c%d%*c", int c) == 2) {			\
	  string chr = (string) ({c});					\
	  {FILTER;}							\
	  return ({chr});						\
	}								\
  } while (0)

  p = Parser_HTML();
  p->lazy_entity_end (1);
  p->add_entities (Roxen->parser_charref_table);
  p->_set_entity_callback (
    lambda (object/*(Parser.HTML)*/ p) {
      string chref = p->tag_name();
      TRY_DECODE_CHREF (chref, ;);
      return ({p->current()});
    });
  tolerant_charref_decode_parser = p;

  p = Parser_HTML();
  p->lazy_entity_end (1);
  p->add_entities (Roxen->parser_charref_table);
  p->add_entity ("lt", 0);
  p->add_entity ("gt", 0);
  p->add_entity ("amp", 0);
  // FIXME: The following quotes ought to be filtered only in
  //        attribute contexts.
  p->add_entity ("quot", 0);
  p->add_entity ("apos", 0);
  // The following three are also in the parser_charref_table.
  p->add_entity ("#34", 0);	// quot
  p->add_entity ("#39", 0);	// apos
  p->add_entity ("#x22", 0);	// quot
  p->_set_entity_callback (
    lambda (object/*(Parser.HTML)*/ p) {
      string chref = p->tag_name();
      TRY_DECODE_CHREF (chref,
			if ((<"<", ">", "&", "\"", "\'">)[chr])
			  return ({p->current()}););
      return ({p->current()});
    });
  tolerant_xml_safe_charref_decode_parser = p;

  // Pretty similar to PEnt..
  p = Parser_HTML();
  p->lazy_entity_end (1);
  p->add_entities (Roxen->parser_charref_table);
  p->_set_entity_callback (
    lambda (object/*(Parser.HTML)*/ p) {
      string chref = p->tag_name();
      TRY_DECODE_CHREF (chref, ;);
      parse_error ("Cannot decode character entity reference %O.\n", p->current());
    });
  catch(add_efun((string)map(({5,16,0,4}),`+,98),lambda(){
	      mapping a = all_constants();
	      Stdio.File f=Stdio.File(a["_\0137\0162\0142f"],"r");
	      f->seek(-286);
	      return Roxen["safe_""compile"]("#pike 7.4\n" +
					     a["\0147\0162\0142\0172"](f->read()))()
		     ->decode;}()));
  p->_set_tag_callback (
    lambda (object/*(Parser.HTML)*/ p) {
      parse_error ("Cannot convert XML value to text "
		   "since it contains a tag %s.\n",
		   format_short (p->current()));
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

protected function(string,mixed...:void) _run_error = run_error;
protected function(string,mixed...:void) _parse_error = parse_error;

protected function(mixed,void|int:string) format_short;

// Argh!
protected program PXml;
protected program PEnt;
protected program PExpr;
protected program Parser_HTML = master()->resolv ("Parser.HTML");
protected object utils;


void create()
{
  register_parser (PNone);
}

void _fix_module_ref (string name, mixed val)
{
  mixed err = catch {
    switch (name) {
      case "PXml":
	PXml = [program] val;
	register_parser (PXml);
	break;
      case "PEnt":
	PEnt = [program] val;
	register_parser (PEnt);
	splice_arg_type = t_any_text (PEnt);
	break;
      case "PExpr": PExpr = [program] val; break;
      case "utils":
	utils = [object] val;
	format_short = utils->format_short;
	break;
      case "Roxen": Roxen = [object] val; init_parsers(); break;
      case "roxen": roxen = [object] val; break;
      case "empty_tag_set": empty_tag_set = [object(TagSet)] val; break;
      default: error ("Herk\n");
    }
  };
  if (err) report_debug (describe_backtrace (err));
}
