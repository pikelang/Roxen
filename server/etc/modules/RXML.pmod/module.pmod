//! RXML parser and compiler framework.
//!
//! Created 1999-07-30 by Martin Stjernholm.
//!
//! $Id: module.pmod,v 1.4 1999/12/27 15:29:04 grubba Exp $

//! Kludge: Must use "RXML.refs" somewhere for the whole module to be
//! loaded correctly.

//! WARNING: This API is not yet set in stone; expect incompatible
//! changes.

#pragma strict_types

#if !constant (RequestID)
class RequestID {}
#endif


class Tag
//! Interface class for the static information about a tag.
{
  //! Interface.

  //!string name;
  //! The name of the tag. Required and considered constant.

  int flags;
  //! Various bit flags that affect parsing; see the FLAG_* constants.
  //! RXML.Frame.flags is initialized from this.

  mapping(string:Type) req_arg_types;
  mapping(string:Type) opt_arg_types;
  //! Define to declare the names and types of the required and
  //! optional arguments. If a type specifies a parser, it'll be used
  //! on the argument value. Note that the order in which arguments
  //! are parsed is arbitrary.

  Type content_type = t_text (PHtml);
  //! The handled type of the content, if the tag is used as a
  //! container. It's taken from the actual result type if set to
  //! zero.
  //!
  //! This default says it's text, but the HTML parser is used to read
  //! it, which means that the content is preparsed with HTML syntax.
  //! Use t_text directly with no parser to get the raw text.

  array(Type) result_types = ({t_text});
  //! The possible types of the result, in order of precedence.

  string scope_name;
  //! RXML.Frame.scope_name is initialized from this.

  TagSet additional_tags, local_tags;
  //! RXML.Frame.additional_tags and RXML.Frame.local_tags are
  //! initialized from these.

  function(:Frame) frame();
  //! This function should return an object to be used as a frame. The
  //! frame object must (in practice) inherit RXML.Frame.

  //! Services.

  inline Frame `() (mapping(string:mixed) args, void|mixed|PCode content)
  //! Make an initialized frame for the tag. Typically useful when
  //! returning generated tags from e.g. RXML.Frame.do_return(). The
  //! argument values and the content are not parsed; see
  //! RXML.Frame.do_return() for details. Note: Never reuse the same
  //! frame object.
  {
    Tag this = this_object();
    Frame frame = ([function(:Frame)] this->frame)();
    frame->tag = this;
    frame->flags = flags;
    if (scope_name) frame->scope_name = scope_name;
    if (additional_tags) frame->additional_tags = additional_tags;
    if (local_tags) frame->local_tags = local_tags;
    frame->args = args;
    if (!zero_type (content)) frame->content = content;
    return frame;
  }

  // Internals.

  array handle_tag (TagSetParser parser, mapping(string:string) args, void|string content)
  // Callback for tag set parsers. Returns a sequence of result values
  // to be added to the result queue.
  {
    Context ctx = parser->context;
    // FIXME: P-code generation.
    Frame frame;
    if (mapping(string:mixed)|mapping(object:array) ustate = ctx->unwind_state)
      if (ustate[parser]) frame = ustate[parser][0];
      else frame = `() (args, Void);
    else frame = `() (args, Void);

    mixed err = catch {
      frame->_eval (parser, args, content);
      return frame->result == Void ? ({}) : ({frame->result});
    };

    if (objectp (err) && ([object] err)->thrown_at_unwind) {
      mapping(string:mixed)|mapping(object:array) ustate = ctx->unwind_state;
      if (!ustate) ustate = ctx->unwind_state = ([]);
#ifdef DEBUG
      if (err != frame)
	parse_error ("Internal error: Unexpected unwind object catched.\n");
      if (ustate[parser])
	parse_error ("Internal error: Clobbering unwind state for parser.\n");
#endif
      ustate[parser] = ({err});
      err = parser;
    }

    throw (err);
  }

  string _sprintf()
  {
    return "Tag(" + [string] this_object()->name + ")";
  }
}


class TagSet
//! Contains a set of tags. Tag sets can import other tag sets, and
//! later changes are propagated. Parser instances (contexts) to parse
//! data are also created from this. TagSet objects may somewhat
//! safely be destructed explicitly; the tags in a destructed tag set
//! will not be active in parsers that are instantiated later, but
//! will work in current instances.
{
  string prefix;
  //! A prefix that may precede the tags. If zero, it's up to the
  //! importing tag set(s).

  int prefix_required;
  //! The prefix must precede the tags.

  array(TagSet) imported = ({});
  //! Other tag sets that will be used. The precedence is local tags
  //! first, then imported from left to right. It's not safe to
  //! destructively change entries in this array.

  int generation = 1;
  //! A number that is increased every time something changes in this
  //! object or in some tag set it imports.

  mapping(string:string|
	  function(:int(0..1)|string|array)|
	  function(Parser,mapping(string:string):
		   int(0..1)|string|array)) low_tags;
  mapping(string:string|
	  function(:int(0..1)|string|array)|
	  function(Parser,mapping(string:string),string:
		   int(0..1)|string|array)) low_containers;
  mapping(string:string|
	  function(:int(0..1)|string|array)|
	  function(Parser,string:
		   int(0..1)|string|array)) low_entities;
  //! Passed directly to Parser.HTML. Note: Changes in these aren't
  //! tracked; changed() must be called.

  void create (void|array(Tag) _tags)
  //!
  {
    if (_tags) tags = mkmapping ([array(string)] _tags->name, _tags);
  }

  void add_tag (Tag tag)
  //!
  {
    tags[tag->name] = tag;
    changed();
  }

  void add_tags (array(Tag) _tags)
  //!
  {
    tags += mkmapping (/*[array(string)]HMM*/ _tags->name, _tags);
    changed();
  }

  void remove_tag (string|Tag tag)
  //!
  {
    if (stringp (tag))
      m_delete (tags, tag);
    else for (string n; !zero_type (n = search (tags, [object(Tag)] tag));)
      m_delete (tags, n);
    changed();
  }

  Tag get_tag (string name)
  //!
  {
    Tag tag;
    if ((tag = tags[name])) return tag;
    foreach (imported, TagSet tag_set)
      if ((tag = tag_set->get_tag (name))) return tag;
    return 0;
  }

  Tag get_local_tag (string name)
  //!
  {
    return tags[name];
  }

  array(Tag) get_local_tags()
  //!
  {
    return values (tags);
  }

  mixed `->= (string var, mixed val)
  {
    switch (var) {
      case "imported":
	(imported - ({0}))->dont_notify (changed);
	imported = [array(TagSet)] val;
	imported->do_notify (changed);
	break;
      default:
	::`->= (var, val);
    }
    changed();
    return val;
  }

  mixed `[]= (string var, mixed val) {return `->= (var, val);}

  Parser `() (Type top_level_type, void|RequestID id)
  //! Creates a new context for parsing content of the specified type,
  //! and returns the parser object for it. id is put into the
  //! context.
  {
    return Context (this_object(), id)->new_parser (top_level_type);
  }

  void changed()
  //! Should be called whenever something is changed. Done
  //! automatically most of the time, however.
  {
    generation++;
    (notify_funcs -= ({0}))();
    set_weak_flag (notify_funcs, 1);
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

  private mapping(string:Tag) tags = ([]);
  // Private since we want to track changes in this.

  private array(function(:void)) notify_funcs = ({});
  // Weak (when nonempty).
}

TagSet empty_tag_set;
//! The empty tag set.


class Context
//! A parser context. This contains the current variable bindings and
//! so on. The current context can always be retrieved with
//! get_context().
//!
//! Note: Don't keep pointers to this object since that will likely
//! introduce circular references. It can be retrieved easily through
//! get_context() or parser->context.
{
  Frame frame;
  //! The currently evaluating frame.

  RequestID id;
  //!

  int type_check;
  //! Whether to do type checking.

  TagSet tag_set;
  //! The current tag set that will be inherited by subparsers.

  int tag_set_is_local;
  //! Nonzero if tag_set is a copy local to this context. A local tag
  //! set that imports the old tag_set might be created whenever
  //! needed.

  mixed get_var (string var, void|string scope_name)
  //! Returns the value a variable in the specified scope, or the
  //! current scope if none is given. Returns zero with zero_type 1 if
  //! there's no such variable.
  {
    if (mapping(string:mixed) vars = scopes[scope_name || ""]) {
      mixed val;
      if (zero_type (val = vars[var])) return ([])[0];
      else if (objectp (val) && ([object] val)->eval)
	return ([function(Context,string,string:mixed)] ([object] val)->eval) (
	  this_object(), var, scope_name);
      else return val;
    }
    else if (scope_name) error ("Unknown scope %O.\n", scope_name);
    else error ("No current scope.\n");
  }

  mixed set_var (string var, mixed val, void|string scope_name)
  //! Sets the value of a variable in the specified scope, or the
  //! current scope if none is given. Returns val.
  {
    if (mapping(string:mixed) vars = scopes[scope_name || ""])
      return vars[var] = val;
    else if (scope_name) error ("Unknown scope %O.\n", scope_name);
    else error ("No current scope.\n");
  }

  void delete_var (string var, void|string scope_name)
  //! Removes a variable in the specified scope, or the current scope
  //! if none is given.
  {
    if (mapping(string:mixed) vars = scopes[scope_name || ""])
      m_delete (vars, var);
    else if (scope_name) error ("Unknown scope %O.\n", scope_name);
    else error ("No current scope.\n");
  }

  array(string) list_var (void|string scope_name)
  //! Returns the names of all variables in the specified scope, or
  //! the current scope if none is given.
  {
    if (mapping(string:mixed) vars = scopes[scope_name || ""])
      return indices (vars);
    else if (scope_name) error ("Unknown scope %O.\n", scope_name);
    else error ("No current scope.\n");
  }

  void add_runtime_tag (Tag tag)
  //! Adds a tag that will exist from this point forward in the
  //! current context only.
  {
    if (tag_set_is_local) make_tag_set_local();
    tag_set->add_tag (tag);
  }

  void remove_runtime_tag (string|Tag tag)
  //! Removes a tag added by add_runtime_tag().
  {
    if (tag_set_is_local) make_tag_set_local();
    tag_set->remove_tag (tag);
  }

  array(string) list_scopes()
  //! Returns the names of all defined scopes.
  {
    return indices (scopes) - ({""});
  }

  void add_scope (string scope_name, mapping(string:mixed) vars)
  //! Adds or replaces the specified scope at the global level.
  {
    if (scopes[scope_name])
      if (scope_name == "") {
	mapping(string:mixed) inner = scopes[""];
	while (mapping(string:mixed) outer = hidden[inner]) inner = outer;
	hidden[inner] = vars;
      }
      else {
	Frame outermost;
	for (Frame f = frame; f; f = f->up)
	  if (f->scope_name == scope_name) outermost = f;
	if (outermost) hidden[outermost] = vars;
	else scopes[scope_name] = vars;
      }
    else scopes[scope_name] = vars;
  }

  void remove_scope (string scope_name)
  //! Removes the named scope from the global level, if it exists.
  {
#ifdef MODULE_DEBUG
    if (scope_name == "") error ("Cannot remove current scope.\n");
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
    if (mapping(string:mixed) vars = scopes[""]) {
      string scope_name;
      while (scope_name = search (scopes, vars, scope_name))
	if (scope_name != "") return scope_name;
    }
    return 0;
  }

  void error (string msg, mixed... args)
  //! Throws an error with a dump of the parser stack.
  {
    if (sizeof (args)) msg = sprintf (msg, @args);
    msg = "RXML parser error: " + msg;
    for (Frame f = frame; f; f = f->up) {
      if (f->tag) msg += "<" + f->tag->name;
      else if (!f->up) break;
      else msg += "<(unknown tag)";
      if (f->args)
	foreach (sort (indices (f->args)), string arg) {
	  mixed val = f->args[arg];
	  msg += " " + arg + "=";
	  if (arrayp (val)) msg += map (val, error_print_val) * ",";
	  else msg += error_print_val (val);
	}
      else msg += " (no argmap)";
      msg += ">\n";
    }
    array b = backtrace();
    throw (({msg, b[..sizeof (b) - 2]}));
  }

  // Internals.

  private string error_print_val (mixed val)
  {
    if (arrayp (val)) return "array";
    else if (mappingp (val)) return "mapping";
    else if (multisetp (val)) return "multiset";
    else return sprintf ("%O", val);
  }

  mapping(string:mapping(string:mixed)) scopes = ([]);
  // The variable mappings for every currently visible scope. A
  // special entry "" points to the current local scope.

  mapping(mapping(string:mixed)|Frame:mapping(string:mixed)) hidden = ([]);
  // The currently hidden variable mappings in scopes. The old ""
  // entries are indexed by the replacing variable mapping. The old
  // named scope entries are indexed by the frame object which
  // replaced them.

  void enter_scope (Frame frame)
  {
    mapping(string:mixed) vars;
#ifdef DEBUG
    if (!frame->vars) error ("Internal error: Frame has no variables.\n");
#endif
    if ((vars = [mapping(string:mixed)] frame->vars) != scopes[""]) {
      hidden[vars] = scopes[""];
      scopes[""] = vars;
      if (string scope_name = [string] frame->scope_name) {
	hidden[frame] = scopes[scope_name];
	scopes[scope_name] = vars;
      }
    }
  }

  void leave_scope (Frame frame)
  {
    if (string scope_name = [string] frame->scope_name)
      if (hidden[frame]) {
	scopes[scope_name] = hidden[frame];
	m_delete (hidden, frame);
      }
    mapping(string:mixed) vars;
    if (hidden[vars = [mapping(string:mixed)] frame->vars]) {
      scopes[""] = hidden[vars];
      m_delete (hidden, vars);
    }
  }

#define ENTER_SCOPE(ctx, frame) (frame->vars && ctx->enter_scope (frame))
#define LEAVE_SCOPE(ctx, frame) (frame->vars && ctx->leave_scope (frame))

  void make_tag_set_local()
  {
    if (!tag_set_is_local) {
      TagSet new_tag_set = TagSet(); // FIXME: Cache this?
      new_tag_set->imported = ({tag_set});
      tag_set = new_tag_set;
      tag_set_is_local = 1;
    }
  }

  Parser new_parser (Type top_level_type)
  // Returns a new parser object to start parsing with this context.
  // Normally TagSet.`() should be used instead of this.
  {
#ifdef MODULE_DEBUG
    if (in_use || frame) error ("Context already in use.\n");
#endif
    return top_level_type->get_parser (this_object());
  }

  void create (TagSet _tag_set, void|RequestID _id)
  // Normally TagSet.`() should be used instead of this.
  {
    tag_set = _tag_set;
    id = _id;
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
  //	do_return() with this stream piece.)
  // "exec_left": array (Exec array left to evaluate. Only used
  //	between Frame._exec_array() and Frame._eval().)

#ifdef MODULE_DEBUG
  int in_use;
#endif
}


//! Current context.

//! It's set before any function in RXML.Tag or RXML.Frame is called.

#if constant (thread_create)
private Thread.Local _context = thread_local();
inline void set_context (Context ctx) {_context->set (ctx);}
inline Context get_context() {return [object(Context)] _context->get();}
#else
private Context _context;
inline void set_context (Context ctx) {_context = ctx;}
inline Context get_context() {return _context;}
#endif

#ifdef MODULE_DEBUG

// Got races in this debug check, but looks like we have to live with that. :\

#define ENTER_CONTEXT(ctx)						\
  Context __old_ctx = get_context();					\
  set_context (ctx);							\
  if (ctx) {								\
    if (ctx->in_use && __old_ctx != ctx)				\
      parse_error ("Attempt to use context asynchronously.\n");		\
    ctx->in_use = 1;							\
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

void parse_error (string msg, mixed... args)
//! Tries to throw an error with error() in the current context to
//! include the frame stack.
{
  Context ctx = get_context();
  if (ctx && ctx->error)
    ctx->error (msg, @args);
  else {
    if (sizeof (args)) msg = sprintf (msg, @args);
    msg = "RXML parser error (no context): " + msg;
    array b = backtrace();
    throw (({msg, b[..sizeof (b) - 2]}));
  }
}


//! Constants for the bit field RXML.Frame.flags.

//! Static flags (i.e. tested in the Tag object).

constant FLAG_CONTAINER = 0x00000001;
//! If set, the tag accepts non-empty content. E.g. with the standard
//! HTML parser this defines whether the tag is a container or not.

//! The rest of the flags are dynamic (i.e. tested in the Frame object).

constant FLAG_PARENT_SCOPE = 0x00000100;
//! If set, the array from do_return() and cached_return() will be
//! interpreted in the scope of the parent tag, rather than in the
//! current one.

constant FLAG_NO_IMPLICIT_ARGS = 0x00000200;
//! If set, the parser won't apply any implicit arguments. FIXME: Not
//! yet implemented.

constant FLAG_STREAM_RESULT = 0x00000400;
//! If set, the do_return() function will be called repeatedly until
//! it returns 0 or no more content is wanted.

constant FLAG_STREAM_CONTENT = 0x00000800;
//! If set, the tag supports getting its content in streaming mode:
//! do_return() will be called repeatedly with successive parts of the
//! content then. Can't be changed from do_return().

//! Note: It might be obvious, but using streaming is significantly
//! less effective than nonstreaming, so it should only be done when
//! big delays are expected.

constant FLAG_STREAM = FLAG_STREAM_RESULT | FLAG_STREAM_CONTENT;

//! The following flags specifies whether certain conditions must be
//! met for a cached frame to be considered (if RXML.Frame.is_valid()
//! is defined). They may be read directly after do_return() returns.
//! The tag name is always the same. FIXME: These are ideas only; not
//! yet implemented.

constant FLAG_CACHE_DIFF_ARGS = 0x00010000;
//! If set, the arguments to the tag need not be the same (using
//! equal()) as the cached args.

constant FLAG_CACHE_DIFF_CONTENT = 0x00020000;
//! If set, the content need not be the same.

constant FLAG_CACHE_DIFF_RESULT_TYPE = 0x00040000;
//! If set, the result type need not be the same. (Typically
//! not useful unless cached_return() is used.)

constant FLAG_CACHE_DIFF_VARS = 0x00080000;
//! If set, the variables with external scope in vars (i.e. normally
//! those that has been accessed with get_var()) need not have the
//! same values (using equal()) as the actual variables.

constant FLAG_CACHE_SAME_STACK = 0x00100000;
//! If set, the stack of call frames needs to be the same.

constant FLAG_CACHE_EXECUTE_RESULT = 0x00200000;
//! If set, an array to execute will be stored in the frame instead of
//! the final result. On a cache hit it'll be executed like the return
//! value from do_return() to produce the result.


class Frame
//! A tag instance.
{
  constant is_RXML_Frame = 1;
  constant thrown_at_unwind = 1;

  //! Interface.

  Frame up;
  //! The parent frame. This frame is either created from the content
  //! inside the up frame, or it's in the array returned from
  //! do_return() in the up frame.

  Tag tag;
  //! The RXML.Tag object this frame was created from.

  int flags;
  //! Various bit flags that affect parsing. See the FLAG_* constants.

  mapping(string:mixed) args;
  //! The arguments passed to the tag. Set before
  //! do_enter()/do_return() are called.

  Type content_type;
  //! The type of the content.

  mixed content = Void;
  //! The content. Set before do_return() is called, but only when the
  //! tag is actually used with container syntax.

  Type result_type;
  //! The required result type. Set before do_enter()/do_return() are
  //! called. do_return() should produce a result of this type.

  mixed result = Void;
  //! The result.

  //!mapping(string:mixed) vars;
  //! Set this to introduce a new variable scope that will be active
  //! during parsing of the content and return values (but see also
  //! FLAG_PARENT_SCOPE). Don't replace or remove the mapping later.

  //!string scope_name;
  //! The scope name for the variables. Don't change this later.

  //!TagSet additional_tags;
  //! If set, the tags in this tag set will be used in addition to the
  //! tags inherited from the surrounding parser. The additional tags
  //! will in turn be inherited by subparsers.

  //!TagSet local_tags;
  //! If set, the tags in this tag set will be used in the parser for
  //! the content, instead of the one inherited from the surrounding
  //! parser. The tags are not inherited by subparsers.

  int|function(RequestID:int|function) do_enter (RequestID id);
  //! Called before the content (if any) is processed. This function
  //! typically only initializes vars. Return values:
  //!
  //! int -	Do this many passes through the content. do_return()
  //!		will be called after each pass.
  //! function(RequestID:int|function) - A function that is handled
  //!		just like do_enter(), only repeatedly until it returns
  //!		0 or another function.
  //!
  //! If this function is missing, one pass is done.

  //!array do_return (RequestID id, void|mixed piece);
  //! Called after the content (if any) has been processed.
  //!
  //! The result_type variable is set to the type of result the parser
  //! wants. It's any type that is valid by tag->result_type. If the
  //! result type is sequential, it's spliced into the surrounding
  //! content, otherwise it replaces the previous value of the
  //! content, if any.
  //!
  //! Return values:
  //!
  //! array -	A so-called execution array to be handled by the parser:
  //!
  //!	string - Added or put into the result. If the result type has
  //!		a parser, the string will be parsed with it before
  //!		it's assigned to the result variable and passed on.
  //!	RXML.Frame - Already initialized frame to process. Neither
  //!		arguments nor content will be parsed. It's result is
  //!		added or put into the result of this tag.
  //!	mapping(string:mixed) - Fields to merge into the headers.
  //!		FIXME: Not yet implemented. FIXME: Somehow represent
  //!		removal of headers?
  //!	object - Treated as a file object to read in blocking or
  //!		nonblocking mode. FIXME: Not yet implemented, details
  //!		not decided.
  //!	multiset(mixed) - Should only contain one element that'll be
  //!		added or put into the result. Normally not necessary;
  //!		assign it directly to the result variable instead.
  //!
  //! 0 -	Do nothing special. Ends the stream when
  //!		FLAG_STREAM_RESULT is set.
  //!
  //! Note that the intended use is not to postparse by returning
  //! strings, but instead to return an array with literal strings and
  //! RXML.Frame objects where parsing (or, more accurately,
  //! evaluation) needs to be done.
  //!
  //! piece is used when the tag is operating in streaming mode (i.e.
  //! FLAG_STREAM_CONTENT is set). It's then set to each successive
  //! part of the content in the stream, and the content variable is
  //! never touched. do_return() is also called "normally" with no
  //! piece argument afterwards. Note that tags that support streaming
  //! mode might still be used nonstreaming (it might also vary
  //! between iterations).
  //!
  //! As long as FLAG_STREAM_RESULT is set, do_return() will be called
  //! repeatedly until it returns 0. It's only the result piece from
  //! the execution array that is propagated after each turn; the
  //! result variable only accumulates all these pieces.
  //!
  //! If this function is an array, it's executed as above. If it's
  //! zero, the value in the result variable is simply used. If the
  //! result variable is Void, content is used as result if it's of a
  //! compatible type.

  //!int|function(:int) is_valid;
  //! When defined, the frame may be cached. First the name of the tag
  //! must be the same. Then the conditions specified by the cache
  //! bits in flag are checked. Then, if this is a function, it's
  //! called. If it returns 1, the frame is reused. FIXME: Not yet
  //! implemented.

  array cached_return (Context ctx, void|mixed piece);
  //! If defined, this will be called to get the value from a cached
  //! frame (that's still valid) instead of using the cached result.
  //! It's otherwise handled like do_return(). Note that the cached
  //! frame may be used from several threads. FIXME: Not yet
  //! implemented.

  //! Services.

  void error (string msg, mixed... args)
  //! Throws an error with a backtrace from the current context.
  {
    parse_error (msg, @args);
  }

  void terminate()
  //! Makes the parser abort. The data parsed so far will be returned.
  //! Does not return; throws a special exception instead.
  {
    // FIXME
  }

  void suspend()
  //! Used together with resume() for nonblocking mode. May be called
  //! from do_enter() or do_return() to suspend the parser: The parser
  //! will just stop, leaving the context intact. If it returns, the
  //! parser is used in a place that doesn't support nonblocking, so
  //! just go ahead and block.
  {
    // FIXME
  }

  void resume()
  //! Makes the parser continue where it left off. The function that
  //! called suspend() will be called again.
  {
    // FIXME
  }

  // Internals.

  mixed _exec_array (Context ctx, array exec)
  {
    Frame this = this_object();
    int i = 0;
    mixed res = Void;
    Parser subparser = 0;

    mixed err = catch {
      if (flags & FLAG_PARENT_SCOPE) LEAVE_SCOPE (ctx, this);

      for (; i < sizeof (exec); i++) {
	mixed elem = exec[i], piece = Void;

	switch (sprintf ("%t", elem)) {
	  case "string":
	    if (result_type->_parser_prog == PNone)
	      piece = elem;
	    else {
	      subparser = result_type->get_parser (ctx);
	      subparser->finish ([string] elem); // Might unwind.
	      piece = subparser->eval(); // Might unwind.
	      subparser = 0;
	    }
	    break;
	  case "object":
	    if (([object] elem)->is_RXML_Frame) {
	      ([object(Frame)] elem)->_eval (0); // Might unwind.
	      piece = ([object(Frame)] elem)->result;
	    }
	    else if (([object] elem)->is_RXML_Parser) {
	      // The subparser above unwound.
	      ([object(Parser)] elem)->finish(); // Might unwind.
	      piece = ([object(Parser)] elem)->eval(); // Might unwind.
	    }
	    else
	      error ("File objects not yet implemented.\n");
	    break;
	  case "mapping":
	    error ("Header mappings not yet implemented.\n");
	    break;
	  case "multiset":
	    if (sizeof ([multiset] elem) == 1) piece = ((array) elem)[0];
	    else if (sizeof ([multiset] elem) > 1)
	      error (sizeof ([multiset] elem) + " values in multiset in exec array.\n");
	    else error ("No value in multiset in exec array.\n");
	    break;
	  default:
	    error ("Invalid type %t in exec array.\n", elem);
	}

	if (result_type->sequential) res += piece;
	else if (piece != Void) result = res = piece;
      }

      if (result_type->sequential) result += res;
      if (flags & FLAG_PARENT_SCOPE) ENTER_SCOPE (ctx, this);
      return res;
    };

    if (result_type->sequential) result += res;

    if (objectp (err) && ([object] err)->thrown_at_unwind) {
      mapping(string:mixed)|mapping(object:array) ustate;
      if ((ustate = ctx->unwind_state) && !zero_type (ustate->stream_piece))
	// Subframe wants to stream. Update stream_piece and send it on.
	if (result_type->sequential)
	  ustate->stream_piece = res + ustate->stream_piece;
	else if (ustate->stream_piece == Void)
	  ustate->stream_piece = res;
      ustate->exec_left = exec[i..]; // Left to execute.
      if (subparser)
	// Replace the string with the subparser object so that we'll
	// continue in it later. It's done here to keep the original
	// exec array untouched.
	([array] ustate->exec_left)[0] = subparser;
    }
    throw (err);
  }

  void _eval (TagSetParser parser,
	      void|mapping(string:string) raw_args,
	      void|string raw_content)
  // Note: It might be somewhat tricky to override this function.
  {
    Frame this = this_object();
    Context ctx = parser->context;
#ifdef DEBUG
    if (ctx != get_context()) error ("Internal error: Context not current.\n");
    if (!parser->tag_set_eval)
      error ("Internal error: Calling _eval() with non-tag set parser.\n");
#endif

    // Unwind state data.
    int|function(RequestID:int|function) fn, iter;
    //string raw_content;
    Parser subparser;
    mixed piece;
    array exec;
    int tags_added;		// Flag that we added additional_tags to ctx->tag_set.

#define PRE_INIT_ERROR(X) (ctx->frame = this, error (X))
    if (array state = ctx->unwind_state && ctx->unwind_state[this]) {
#ifdef DEBUG
      if (!up)
	PRE_INIT_ERROR ("Internal error: Resuming frame without up pointer.\n");
      if (raw_args || raw_content)
	PRE_INIT_ERROR ("Internal error: Can't feed new arguments or content "
			"when resuming parse.\n");
#endif
      object ignored;
      [ignored, fn, iter, raw_content, subparser, piece, exec, tags_added] = state;
      m_delete (ctx->unwind_state, this);
      if (!sizeof (ctx->unwind_state)) ctx->unwind_state = 0;
    }
    else {
#ifdef MODULE_DEBUG
      if (up && up != ctx->frame)
	PRE_INIT_ERROR ("Reuse of frame in different context.\n");
#endif
      up = ctx->frame;
      piece = Void;
    }
#undef PRE_INIT_ERROR
    ctx->frame = this;

    int tag_set_gen = parser->tag_set->generation;

    if (raw_args) {
      args = ([]);
      mapping(string:Type) atypes;
      if (tag->req_arg_types) {
	atypes = raw_args & tag->req_arg_types;
	if (sizeof (atypes) < sizeof (tag->req_arg_types)) {
	  array(string) missing = sort (indices (tag->req_arg_types - atypes));
	  parse_error ("Required " +
		       (sizeof (missing) > 1 ?
			"arguments " + String.implode_nicely (missing) + " are" :
			"argument " + missing[0] + " is") + " missing.\n");
	}
      }
      if (tag->opt_arg_types)
	if (atypes) atypes += raw_args & tag->opt_arg_types;
	else atypes = raw_args & tag->opt_arg_types;
      if (atypes)
	if (mixed err = catch {
	  foreach (indices (atypes), string arg)
	    args[arg] = atypes[arg]->eval (
	      raw_args[arg], ctx, 0, 1); // Should currently NOT unwind.
	}) {
	  if (objectp (err) && ([object] err)->thrown_at_unwind)
	    error ("Can't save parser state when evaluating arguments.\n");
	  throw (err);
	}
    }
#ifdef DEBUG
    if (!args) error ("Internal error: args not set.\n");
#endif

    if (TagSet add_tags = raw_content && [object(TagSet)] this->additional_tags) {
      if (!ctx->tag_set_is_local) ctx->make_tag_set_local();
      if (search (ctx->tag_set->imported, add_tags) < 0) {
	ctx->tag_set->imported = ({add_tags}) + ctx->tag_set->imported;
	tags_added = 1;
      }
    }

    if (!result_type) {
      Type ptype = parser->type;
      foreach (tag->result_types, Type rtype)
	if (rtype->subtype_of (ptype)) {result_type = rtype; break;}
      if (!result_type)		// Sigh..
	error ("Tag returns " +
	       String.implode_nicely ([array(string)] tag->result_types->name, "or") +
	       " but " + [string] parser->type->name + " is expected.\n");
    }
    if (!content_type) content_type = tag->content_type || result_type;

    mixed err = catch {
      if (!fn) fn = this->do_enter ? this->do_enter (ctx->id) : 1; // Might unwind.

      do {
	if (!iter) {
	  iter = fn;
	  while (functionp (iter)) { // Got a function from do_enter.
	    int|function(RequestID:int|function) newiter =
	      [int|function(RequestID:int|function)] iter (ctx->id); // Might unwind.
	    fn = iter, iter = newiter;
	  }
	}
	ENTER_SCOPE (ctx, this);
	for (; iter > 0; iter--) {

	  if (raw_content) {	// Got nested parsing to do.
	    int finished = 0;
	    if (!subparser) {	// The nested content is not yet parsed.
	      subparser = content_type->get_parser (
		ctx, [object(TagSet)] this->local_tags);
	      subparser->finish (raw_content); // Might unwind.
	      finished = 1;
	    }

	    do {
	      if (flags & FLAG_STREAM_CONTENT && subparser->read) {
		// Handle a stream piece.
		// Squeeze out any free text from the subparser first.
		mixed res = ([function(:mixed)] subparser->read)();
		if (content_type->sequential) piece = res + piece;
		else if (piece == Void) piece = res;
		if (piece != Void) {
		  array|function(RequestID,mixed:array) do_return;
		  if ((do_return =
		       [array|function(RequestID,mixed:array)] this->do_return) &&
		      !arrayp (do_return)) {
		    if (!exec) exec = do_return (ctx->id, piece); // Might unwind.
		    if (exec) {
		      mixed res = _exec_array (ctx, exec); // Might unwind.
		      if (flags & FLAG_STREAM_RESULT) {
#ifdef DEBUG
			if (!zero_type (ctx->unwind_state->stream_piece))
			  error ("Internal error: "
				 "Clobbering unwind_state->stream_piece.\n");
#endif
			ctx->unwind_state->stream_piece = res;
			throw (this);
		      }
		      exec = 0;
		    }
		    else if (flags & FLAG_STREAM_RESULT) {
		      // do_return() finished the stream. Ignore remaining content.
		      ctx->unwind_state = 0;
		      piece = Void;
		      break;
		    }
		  }
		  piece = Void;
		}
		if (finished) break;
	      }
	      else {		// The frame doesn't handle streamed content.
		piece = Void;
		if (finished) {
		  mixed res = subparser->eval(); // Might unwind.
		  if (content_type->sequential) content += res;
		  else if (res != Void) content = res;
		  break;
		}
	      }

	      subparser->finish(); // Might unwind.
	      finished = 1;
	    } while (1); // Only loops when an unwound subparser has been recovered.
	    subparser = 0;
	  }

	  if (array|function(RequestID,mixed:array) do_return =
	      [array|function(RequestID,mixed:array)] this->do_return) {
	    if (!exec)
	      exec = arrayp (do_return) ?
		[array] do_return : do_return (ctx->id); // Might unwind.
	    if (exec) {
	      mixed res = _exec_array (ctx, exec); // Might unwind.
	      if (flags & FLAG_STREAM_RESULT) {
#ifdef DEBUG
		if (ctx->unwind_state)
		  error ("Internal error: Clobbering unwind_state to do streaming.\n");
		if (piece != Void)
		  error ("Internal error: Thanks, we think about how nice it must "
			 "be to play the harmonica...\n");
#endif
		ctx->unwind_state = (["stream_piece": res]);
		throw (this);
	      }
	    }
	  }
	  else if (result == Void && content_type->subtype_of (result_type))
	    result = content;

	}
      } while (fn);
    };

    LEAVE_SCOPE (ctx, this);
    if (tag_set_gen != parser->tag_set->generation &&
	ctx->tag_set == parser->tag_set)
      parser->recheck_tags();

    if (err) {
      string action;
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
	mapping(string:mixed)|mapping(object:array) ustate = ctx->unwind_state;
	if (!ustate) ustate = ctx->unwind_state = ([]);
#ifdef DEBUG
	if (ustate[this])
	  error ("Internal error: Frame already has an unwind state.\n");
#endif

	if (ustate->exec_left) {
	  exec = [array] ustate->exec_left;
	  m_delete (ustate, "exec_left");
	}

	if (err == this || exec && sizeof (exec) && err == exec[0])
	  // This frame or a frame in the exec array wants to stream.
	  if (parser->unwind_safe) {
	    // Rethrow to continue in parent since we've already done
	    // the appropriate do_return stuff in this frame in either
	    // case.
	    if (err == this) err = 0;
	    if (tags_added) {
	      ctx->tag_set->imported -= ({/*[object(TagSet)]HMM*/ this->additional_tags});
	      tags_added = 0;
	    }
	    action = "break";
	  }
	  else {
	    // Can't stream since the parser isn't unwind safe. Just
	    // continue.
	    m_delete (ustate, "stream_piece");
	    action = "continue";
	  }
	else if (!zero_type (ustate->stream_piece)) {
	  // Got a stream piece from a subframe. We handle it above;
	  // store the state and tail recurse.
	  piece = ustate->stream_piece;
	  m_delete (ustate, "stream_piece");
	  action = "continue";
	}
	else action = "break";	// Some other reason - back up to the top.

	ustate[this] = ({err, fn, iter, raw_content, subparser, piece, exec, tags_added});
      }
      else action = "throw";

      switch (action) {
	case "break":		// Throw and handle in parent frame.
#ifdef MODULE_DEBUG
	  if (!parser->unwind_state)
	    error ("Trying to unwind inside a parser that isn't unwind safe.\n");
#endif
	  throw (this);
	case "continue":	// Continue in this frame through tail recursion.
	  _eval (parser);
	  return;
	case "throw":		// Any old exception.
	  throw (err);
	default:
	  error ("Internal error: Don't you come here and %O on me!\n", action);
      }
    }

    else {
      if (tags_added)
	ctx->tag_set->imported -= ({/*[object(TagSet)]HMM*/ this->additional_tags});
      ctx->frame = up;
    }
  }

  string _sprintf()
  {
    return "Frame(" + (tag && [string] tag->name) + ")";
  }
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
    mixed err = catch {
      if (context && context->unwind_state && context->unwind_state->top) {
	m_delete (context->unwind_state, "top");
	if (!sizeof (context->unwind_state)) context->unwind_state = 0;
      }
      if (feed (in)) res = 1;	// Might unwind.
      if (res && data_callback) data_callback (this_object());
    };
    LEAVE_CONTEXT();
    if (err)
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
	if (!context->unwind_state) context->unwind_state = ([]);
	context->unwind_state->top = err;
      }
      else throw (err);
    return res;
  }

  void write_end (void|string in)
  //! Closes the source data stream, optionally with a last bit of
  //! data.
  {
    int res;
    ENTER_CONTEXT (context);
    mixed err = catch {
      if (context && context->unwind_state && context->unwind_state->top) {
	m_delete (context->unwind_state, "top");
	if (!sizeof (context->unwind_state)) context->unwind_state = 0;
      }
      finish (in);		// Might unwind.
      if (data_callback) data_callback (this_object());
    };
    LEAVE_CONTEXT();
    if (err)
      if (objectp (err) && ([object] err)->thrown_at_unwind) {
	if (!context->unwind_state) context->unwind_state = ([]);
	context->unwind_state->top = err;
      }
      else throw (err);
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

  //!mixed unwind_safe;
  //! If nonzero, the parser supports unwinding with throw()/catch().
  //! Whenever an exception is thrown from some evaluation function,
  //! it should be able to call that function again with identical
  //! arguments the next time it continues.

  mixed feed (string in);
  //! Feeds some source data to the parse stream. The parser may do
  //! scanning and parsing before returning. If context is set, it may
  //! also do evaluation in that context. Returns nonzero if there
  //! could be new data to get from eval().

  void finish (void|string in);
  //! Like feed(), but also finishes the parse stream. A last bit of
  //! data may be given. It should work to call this on an already
  //! finished stream if no argument is given to it.

  mixed read();
  //! Define to allow streaming operation. Returns the evaluated
  //! result so far, but does not do any evaluation. Returns Void if
  //! there's no data (for sequential types the empty value is also
  //! ok).

  mixed eval();
  //! Evaluates the data fed so far and returns the result. The result
  //! returned by previous eval() calls should not be returned again
  //! as (part of) this return value. Returns Void if there's no data
  //! (for sequential types the empty value is also ok).

  PCode p_compile();
  //! Define this to return a p-code representation of the current
  //! stream, which always is finished.

  void reset (Context ctx, Type type, mixed... args);
  //! Define to support reuse of a parser object. It'll be called
  //! instead of making a new object for a new stream. It keeps the
  //! static configuration, i.e. the type.

  Parser clone (Context ctx, Type type, mixed... args);
  //! Define to create new parser objects by cloning instead of
  //! creating from scratch. It returns a new instance of this parser
  //! with the same static configuration, i.e. the type.

  void create (Context ctx, Type _type /*, mixed... args*/)
  {
    context = ctx;
    type = _type;
  }

  // Internals.

  Parser _next_free;
  // Used to link together unused parser objects for reuse.
}


class TagSetParser
//! Interface class for parsers that evaluates using the tag set. It
//! provides the evaluation and compilation functionality. The parser
//! should call Tag.handle_tag() from feed() and finish() for every
//! encountered tag, and Context.get_var() for encountered variable
//! references. The parser must provide a result queue with
//! write_out() and read(). It must be able to continue cleanly after
//! throw() from Tag.handle_tag().
{
  inherit Parser;

  constant tag_set_eval = 1;

  // Interface.

  TagSet tag_set;
  //! The tag set used for parsing.

  void reset (Context ctx, Type type, TagSet tag_set, mixed... args);
  Parser clone (Context ctx, Type type, TagSet tag_set, mixed... args);
  void create (Context ctx, Type type, TagSet _tag_set /*, mixed... args*/)
  {
    ::create (ctx, type);
    tag_set = _tag_set;
  }
  //! In addition to the type, the tag set is part of the static
  //! configuration.

  void recheck_tags();
  //! Called when the tags in tag_set have changed during the
  //! evaluation and need to take effect immediately. Only the local
  //! tags in tag_set needs to be checked for changes.
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
  //! "image/png" is a subtype of "image/*", and "array(string)" is a
  //! subtype of "array(*)".

  //!mixed sequential;
  //! Nonzero if data of this type is sequential, defined as:
  //! o  One or more data items can be concatenated with `+.
  //! o  (Sane) parsers are homomorphic on the type, i.e.
  //!	    eval ("da") + eval ("ta") == eval ("da" + "ta")
  //!    and
  //!	    eval ("data") + eval ("") == eval ("data")

  //!mixed empty_value;
  //! The empty value for sequential data types, i.e. what eval ("")
  //! would produce.

  //!mixed free_text;
  //! Nonzero if the type keeps the free text between parsed tokens,
  //! e.g. the plain text between tags in HTML. The type must be
  //! sequential and use strings.

  void type_check (mixed val);
  //! Checks whether the given value is a valid one of this type.
  //! Errors are thrown with parse_error().

  Type clone()
  //! Returns a copy of the type.
  {
    Type newtype = object_program (this_object())();
    newtype->_parser_prog = _parser_prog;
    newtype->_parser_args = _parser_args;
    newtype->_t_obj_cache = _t_obj_cache;
    return newtype;
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

  Type `() (program newparser, mixed... parser_args)
  //! Returns a type identical to this one, but which has the given
  //! parser. parser_args is passed as extra arguments to the
  //! create()/reset()/clone() functions.
  {
    Type newtype;
    if (sizeof (parser_args)) {	// Can't cache this.
      newtype = clone();
      newtype->_parser_args = parser_args;
      if (newparser->tag_set_eval) newtype->_p_cache = ([]);
    }
    else {
      if (!_t_obj_cache) _t_obj_cache = ([]);
      if (!(newtype = _t_obj_cache[newparser]))
	if (newparser == _parser_prog)
	  _t_obj_cache[newparser] = newtype = this_object();
	else {
	  _t_obj_cache[newparser] = newtype = clone();
	  newtype->_parser_prog = newparser;
	  if (newparser->tag_set_eval) newtype->_p_cache = ([]);
	}
    }
    return newtype;
  }

  inline Parser get_parser (Context ctx, void|TagSet tag_set)
  //! Returns a parser instance initialized with the given context.
  {
    Parser p;
    if (_p_cache) {		// It's a tag set parser.
      TagSet tset;
      // vvv Using interpreter lock from here.
      PCacheObj pco = _p_cache[tset = tag_set || ctx->tag_set];
      if (pco && pco->tag_set_gen == tset->generation) {
	if ((p = pco->free_parser)) {
	  pco->free_parser = p->_next_free;
	  // ^^^ Using interpreter lock to here.
	  p->data_callback = p->compile = 0;
	  p->reset (ctx, this_object(), @_parser_args);
	}
	else
	  // ^^^ Using interpreter lock to here.
	  if (pco->clone_parser)
	    p = [object(Parser)] pco->clone_parser->clone (
	      ctx, this_object(), @_parser_args);
	  else if ((p = _parser_prog (ctx, this_object(), @_parser_args))->clone)
	    // pco->clone_parser might already be initialized here due
	    // to race, but that doesn't matter.
	    p = [object(Parser)] (pco->clone_parser = p)->clone (
	      ctx, this_object(), @_parser_args);
      }
      else {
	// ^^^ Using interpreter lock to here.
	pco = PCacheObj();
	pco->tag_set_gen = tset->generation;
	_p_cache[tset] = pco;	// Might replace an object due to race, but that's ok.
	if ((p = _parser_prog (ctx, this_object(), @_parser_args))->clone)
	  // pco->clone_parser might already be initialized here due
	  // to race, but that doesn't matter.
	  p = [object(Parser)] (pco->clone_parser = p)->clone (
	    ctx, this_object(), @_parser_args);
      }
    }
    else {
      if ((p = free_parser)) {
	// Relying on interpreter lock here.
	free_parser = p->_next_free;
	p->data_callback = p->compile = 0;
	p->reset (ctx, this_object(), @_parser_args);
      }
      else if (clone_parser)
	// Relying on interpreter lock here.
	p = [object(Parser)] clone_parser->clone (
	  ctx, this_object(), @_parser_args);
      else if ((p = _parser_prog (ctx, this_object(), @_parser_args))->clone)
	// clone_parser might already be initialized here due to race,
	// but that doesn't matter.
	p = [object(Parser)] (clone_parser = p)->clone (
	  ctx, this_object(), @_parser_args);
    }
    return p;
  }

  mixed eval (string in, void|Context ctx, void|TagSet tag_set, void|int dont_switch_ctx)
  //! Convenience function to parse and evaluate the value in the
  //! given string. If a context isn't given, the current one is used.
  //! The current context and ctx are assumed to be the same if
  //! dont_switch_ctx is nonzero.
  {
    mixed res;
    if (!ctx) ctx = get_context();
    if (_parser_prog == PNone) res = in;
    else {
      Parser p = get_parser (ctx, tag_set);
      if (dont_switch_ctx) p->finish (in); // Optimize the job in p->write_end().
      else p->write_end (in);
      res = p->eval();
      if (p->reset)
	if (_p_cache) {
	  // Relying on interpreter lock in this block.
	  PCacheObj pco = _p_cache[tag_set || ctx->tag_set];
	  p->_next_free = pco->free_parser;
	  pco->free_parser = p;
	}
	else {
	  // Relying on interpreter lock in this block.
	  p->_next_free = free_parser;
	  free_parser = p;
	}
    }
    if (ctx->type_check) type_check (res);
    return res;
  }

  // Internals.

  program/*(Parser)HMM*/ _parser_prog = PNone;
  // The parser to use. Should never be changed in a type object.

  private array(mixed) _parser_args = ({});

  /*private*/ mapping(program:Type) _t_obj_cache;
  // To avoid creating new type objects all the time in `().

  // Cache used for parsers that doesn't depend on the tag set.
  private Parser clone_parser;	// Used with Parser.clone().
  private Parser free_parser;	// The list of objects to reuse with Parser.reset().

  // Cache used for parsers that depend on the tag set.
  private class PCacheObj
  {
    int tag_set_gen;
    Parser clone_parser;
    Parser free_parser;
  }
  /*private*/ mapping(TagSet:PCacheObj) _p_cache;
}


Type t_text = class
//! The standard type for generic document text.
{
  inherit Type;
  constant name = "text/*";
  constant sequential = 1;
  constant empty_value = "";
  constant free_text = 1;
}();


Type t_any = class
//! A completely unspecified nonsequential type.
{
  inherit Type;
  constant name = "*";
}();


// P-code compilation and evaluation.

class VarRef
//! A helper for representing variable reference tokens.
{
  constant is_RXML_VarRef = 1;
  string scope, var;
  void create (string _scope, string _var) {scope = _scope, var = _var;}
  int valid (Context ctx) {return !!ctx->scopes[scope];}
  mixed get (Context ctx) {return ctx->scopes[scope][var];}
  mixed set (Context ctx, mixed val) {return ctx->scopes[scope][var] = val;}
  void remove (Context ctx) {m_delete (ctx->scopes[scope], var);}
  string name() {return scope + "." + var;}
}

class PCode
//! Holds p-code and evaluates it. P-code is the intermediate form
//! after parsing and before evaluation.
{
  constant is_RXML_PCode = 1;
  constant thrown_at_unwind = 1;

  array p_code = ({});

  mixed eval (Context ctx)
  //! Evaluates the p-code in the given context.
  {
    // FIXME
  }

  function(Context:mixed) compile();
  //! Returns a compiled function for doing the evaluation. The
  //! function will receive a context to do the evaluation in.
}


//! Some parser tools.

static class VoidType
{
  mixed `+ (mixed... vals) {return sizeof (vals) ? predef::`+ (@vals) : this_object();}
  mixed ``+ (mixed val) {return val;}
  int `!() {return 1;}
  string _sprintf (int flag) {return (flag == 'O') && "Void";}
};
VoidType Void = VoidType();
//! An object representing the void value. Works as initializer for
//! sequences, since Void + anything == anything + Void == anything.

class ScanStream
//! A helper class for the input and scanner stage in a parser. It's a
//! stream that takes unparsed strings and splits them into tokens
//! which are queued. Intended to be inherited in a Parser class.
{
  private class Link
  {
    array data;
    Link next;
  }
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
    if (fin) error ("Cannot feed data to a finished stream.\n");
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
      if (in && fin) error ("Cannot feed data to a finished stream.\n");
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
  //! Returns the next token, or Void if there's no more data.
  {
    while (head->next)
      if (next_token >= sizeof (head->data)) {
	next_token = 0;
	head = head->next;
      }
      else return head->data[next_token++];
    return Void;
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
}


// Various internal stuff.

// Argh!
static program PHtml;
static program PExpr;
void _fix_module_ref (string name, mixed val)
{
  mixed err = catch {
    switch (name) {
      case "PHtml": PHtml = [program] val; break;
      case "PExpr": PExpr = [program] val; break;
      case "empty_tag_set": empty_tag_set = [object(TagSet)] val; break;
      default: error ("Herk\n");
    }
  };
  if (err) werror (describe_backtrace (err));
}
