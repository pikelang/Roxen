#pike __REAL_VERSION__
#require constant(Regexp.PCRE)

//! This is a port of the Logic-less {{mustache}} templates with JavaScript
//! @url{http://mustache.github.com/@}.
//!
//! Cred goes to Chris Wanstrath (Ruby), Jan Lehnardt (JavaScript) and the
//! mustache.js community.
//!
//! @example
//! @code
//! string tmpl = #"
//! <h1>{{header}}</h1>
//!
//! {{#preamble}}
//!   <p>{{preamble}}</p>
//! {{/preamble}}
//! {{^preamble}}
//!   <div class="notify">Preamble is missing</div>
//! {{/preamble}}
//!
//! <ul>
//!   {{#names}}
//!   <li>{{>name_row}}</li>
//!   {{/names}}
//! </ul>";
//!
//! Mustache stash = Mustache();
//!
//! // Not strictly necessary, but this pre-parses and caches the template
//! stash->parse(tmpl);
//!
//! mappping data = ([
//!   "header"   : "This is a header",
//!   "preamble" : "This is the preamble text",
//!   "names"    : ({
//!     ([ "name" : "Lisa", "age" : 29 ]),
//!     ([ "name" : "Mark", "age" : 43 ]),
//!     ([ "name" : "Anna", "age" : 61 ])
//!   })
//! ]);
//!
//! string html = stash->render(tmpl, data,
//!                             ([ "name_row" :
//!                                "<li>{{name}} is {{age}} years old</li>"]));
//! @endcode
//!
//! The output of the above would be something like
//!
//! @code
//! <h1>This is a header</h1>
//! <p>This is the preamble text</p>
//! <ul>
//!   <li>Lisa is 29 years old</li>
//!   <li>Mark is 43 years old</li>
//!   <li>Anna is 61 years old</li>
//! </ul>
//! @endcode

import Regexp.PCRE;

#ifdef MUSTACHE_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...)0
#endif


//! Parses and caches the given template in the default writer and returns the
//! array of tokens it contains. Doing this ahead of time avoids the need to
//! parse templates on the fly as they are rendered.
//!
//! @param template
//!  Mustache template
//!
//! @param tags
//!  Optional tags to use instead of the default @tt{ {{ }} @}
public array(Token) parse(string template, void|array(string) tags)
{
  return parse_template(template, tags);
}

//! Renders the @[template] with the given @[view] and @[partials].
public string render(string template, mixed view, void|mixed partials)
{
  return render_template(template, view, partials);
}

//! Clears all cached templates
public void clear_cache()
{
  __cache = ([]);
}


//! @ignore
//! Internal helper class
protected class Re
{
  inherit Widestring;

  int search(string s)
  {
    array(int)|int r = ::exec(s);

    if (intp(r) && r != -1) {
      error("Regex error %d!\n", r);
    }

    return intp(r) ? r : r[0];
  }
}
//! @endignore

protected array(string) tags = ({ "{{", "}}" });

protected Re
  _re_escape_re   = Re("[\\-\\[\\]{}()*+?.,\\\\^$|#\\s]"),
  _re_escape_html = Re("[&<>\"'`=/]"),
  _re_nonspace    = Re("\\S"),
  _re_white       = Re("\\s*"),
  _re_space       = Re("\\s+"),
  _re_equals      = Re("\\s*="),
  _re_curly       = Re("\\s*\\}"),
  _re_tag         = Re("#|\\^|\\/|>|\\{|&|=|!");

//! Regexp escape the string @[s]
protected string escape_regexp(string s)
{
  return _re_escape_re->replace(s, lambda (string a) {
    return "\\" + a;
  });
}

//! Check if @[obj] has the index @[prop].
protected bool has_property(mixed obj, string prop)
{
  if (objectp(obj) || mappingp(obj) || multisetp(obj) || arrayp(obj)) {
    return has_index(obj, prop);
  }

  return false;
}

//! Check if @[s] is a whitespace character or not
protected bool is_whitespace(string|int s)
{
  if (stringp(s)) {
    return !_re_nonspace->match(s);
  }

  return (< '\n', ' ', '\t', '\r' >)[s];
}

//! Entities to HTML entities mapping
protected mapping entity_map = ([
  "&"  : "&amp;",
  "<"  : "&lt;",
  ">"  : "&gt;",
  "\"" : "&quot;",
  "'"  : "&#39;",
  "/"  : "&#x2F;",
  "`"  : "&#x60;",
  "="  : "&#x3D;"
]);

//! HTML escape the string @[s]
protected string escape_html(string s)
{
  return _re_escape_html->replace(s, lambda (string a) {
    return entity_map[a] || a;
  });
}

//! A simple string scanner that is used by the template parser to find
//! tokens in template strings.
protected class Scanner
{
  string str;
  string tail;
  int pos;

  protected void create(string s)
  {
    str  = s;
    tail = s;
    pos  = 0;
  }

  //! Returns @tt{true@} if the tail is empty (end of string).
  public bool eos()
  {
    return tail == "";
  }

  //! Tries to match the given regular expression at the current position.
  //! Returns the matched text if it can match, @tt{0@} otherwise.
  public string scan(Re re)
  {
    array(int)|int r = re->exec(tail);

    if (intp(r) && r != -1) {
      error("Regexp error: %d", r);
    }

    if ((intp(r) && r == -1) || r[0] != 0) {
      return 0;
    }

    [int start, int end] = r;
    int len = end-start;
    string s = tail[start..end-1];

    tail = tail[len..];
    pos += len;

    return s;
  }


  //! Skips all text until the given regular expression or string can be
  //! matched. Returns the skipped string, which is the entire tail if no
  //! match can be made.
  public string scan_until(Re|string what)
  {
    int index;

    if (stringp(what)) {
      index = search(tail, what);
    }
    else {
      index = what->search(tail);
    }

    string match;

    switch (index)
    {
      case -1:
        match = tail;
        tail = "";
        break;

      case 0:
        match = "";
        break;

      default:
        match = tail[0..index-1];
        tail = tail[index..];
        break;
    }

    pos += sizeof(match);
    return match;
  }

#ifdef MUSTACHE_DEBUG
  protected void destroy()
  {
    TRACE("Scanner destroyed!\n");
  }
#endif
}


//! A @[Token] is an array like object with at least 4 elements. The first
//! element is the mustache symbol that was used inside the tag, e.g. "#" or
//! "&". If the tag did not contain a symbol (i.e. @tt{{{myValue}}@}) this
//! element is "name". For all text that appears outside a symbol this element
//! is "text".
//!
//! The second element of a token is its "value". For mustache tags this is
//! whatever else was inside the tag besides the opening symbol. For text tokens
//! this is the text itself.
//!
//! The third and fourth elements of the token are the start and end indices,
//! respectively, of the token in the original template.
//!
//! Tokens that are the root node of a subtree contain two more elements: 1) an
//! array of tokens in the subtree and 2) the index in the original template at
//! which the closing tag for that section begins.
protected class Token
{
  protected string type;
  protected mixed value;
  protected int start, end;
  protected mixed extra, extra2;

  protected void create(string type, mixed value, int start, int end)
  {
    this::type  = type;
    this::value = value;
    this::start = start;
    this::end   = end;
  }

  mixed `[](int idx)
  {
    switch (idx) {
      case 0: return type;
      case 1: return value;
      case 2: return start;
      case 3: return end;
      case 4: return extra;
      case 5: return extra2;
    }
  }

  mixed `[]=(int idx, mixed val)
  {
    switch (idx)
    {
      case 0: return type   = val;
      case 1: return value  = val;
      case 2: return start  = val;
      case 3: return end    = val;
      case 4: return extra  = val;
      case 5: return extra2 = val;
    }
  }

  mixed cast(string how)
  {
    switch (how)
    {
      case "array":
        return ({ type, value, start, end, extra, extra2 });

      default:
        error("Unknown cast (%O) in object! ", how);
    }
  }

  string _sprintf(int t)
  {
    return sprintf("Token({ %O, %O, %O, %O, %O, %O })",
                   type, value, start, end, extra, extra2);
  }

#ifdef MUSTACHE_DEBUG
  protected void destroy()
  {
    TRACE("Token(%O, ...) destroyed!\n", type);
  }
#endif
}

//! Breaks up the given @[template] string into a tree of tokens. If the
//! @[_tags] argument is given here it must be an array with two string values:
//! the opening and closing tags used in the template (e.g.
//! @tt{[ "<%", "%>" ]@}). Of course, the default is to use mustaches
//! (i.e. mustache.tags).
protected array(Token)
low_parse_template(string|function template, void|array(string) _tags)
{
  if (functionp(template)) {
    template = (string)template(0);
  }

  if (!template || !sizeof(template)) {
    return ({});
  }

  array(Token) sections = ({}); // Stack to hold section tokens
  array(Token) tokens   = ({}); // Buffer to hold the tokens
  array(int)   spaces   = ({}); // Indices of whitespace tokens on the current line
  bool has_tag    = false;      // Is there a {{tag}} on the current line?
  bool none_space = false;      // Is there a non-space char on the current line?

  // Strips all whitespace tokens array for the current line
  // if there was a {{#tag}} on it and otherwise only space.
#define strip_space() do {        \
    if (has_tag && !none_space) { \
      while (sizeof(spaces)) {    \
        int t = spaces[-1];       \
        spaces = spaces[..<1];    \
        tokens[t] = 0;            \
        tokens -= ({ 0 });        \
      }                           \
    }                             \
    else {                        \
      spaces = ({});              \
    }                             \
                                  \
    has_tag = false;              \
    none_space = false;           \
  } while (0);

  Re opening_tag_re, closing_tag_re, closing_curly_re;

  // string|array(string) t
#define compile_tags(T) do {                                     \
    string|array(string) __t = (T);                              \
    if (stringp(__t)) {                                          \
      __t = _re_space->split(__t);                               \
    }                                                            \
                                                                 \
    if (!arrayp(__t) || sizeof(__t) != 2) {                      \
      error("Invalid tags: %O\n", __t);                          \
    }                                                            \
                                                                 \
    opening_tag_re   = Re(escape_regexp(__t[0]) + "\\s*");       \
    closing_tag_re   = Re("\\s*" + escape_regexp(__t[1]));       \
    closing_curly_re = Re("\\s*" + escape_regexp("}" + __t[1])); \
  } while (0);

  compile_tags(_tags || tags);

  Scanner scanner = Scanner(template);

  int start, chr;
  Token token, open_section;
  string value;

  while (!scanner->eos()) {
    start = scanner->pos;
    // Match any text between tags.
    value = scanner->scan_until(opening_tag_re);

    if (value) {
      for (int i; i < sizeof(value); i++) {
        chr = value[i];

        if (is_whitespace(chr)) {
          spaces += ({ sizeof(tokens) });
        }
        else {
          none_space = true;
        }

        tokens += ({ Token("text", value[i..i], start, start + 1) });

        start += 1;

        if (chr == '\n') {
          strip_space();
        }
      }
    }

    // Match the opening tag.
    if (!scanner->scan(opening_tag_re)) {
      break;
    }

    has_tag = true;

    // Get the tag type.
    string type = scanner->scan(_re_tag) || "name";

    scanner->scan(_re_white);

    // Get the tag value.
    if (type == "=") {
      value = scanner->scan_until(_re_equals);
      scanner->scan(_re_equals);
      scanner->scan_until(closing_tag_re);
    }
    else if (type == "{") {
      value = scanner->scan_until(closing_curly_re);
      scanner->scan(_re_curly);
      scanner->scan_until(closing_tag_re);
      type = "&";
    }
    else {
      value = scanner->scan_until(closing_tag_re);
    }

    // Match the closing tag.
    if (!scanner->scan(closing_tag_re)) {
      error("Unclosed tag at byte %d!\n", scanner->pos);
    }

    token = Token(type, value, start, scanner->pos);
    tokens += ({ token });

    if ((< "#", "^" >)[type]) {
      sections += ({ token });
    }
    else if (type == "/") {
      // Check section nesting.
      open_section = sections[-1];
      sections = sections[..<1];

      if (!open_section) {
        error("Unopened section \"%s\" at byte %d!\n", value, start);
      }

      if (open_section[1] != value) {
        error("Unclosed section \"%s\" at byte %d!\n", open_section[1], start);
      }
    }
    else if ((< "name", "{", "&" >)[type]) {
      none_space = true;
    }
    else if (type == "=") {
      // Set the tags for the next time around.
      compile_tags(value);
    }
  }

  // Make sure there are no open sections when we're done.
  if (sizeof(sections)) {
    open_section = sections[-1];
    error("Unclosed section \"%s\" at byte %d!\n",
          open_section[1], scanner->pos);
  }

  return nest_tokens(squash_tokens(tokens));
}


//! Combines the values of consecutive text tokens in the given @[tokens] array
//! to a single token.
protected array(Token) squash_tokens(array(Token) tokens)
{
  array(Token) st = ({});
  Token token, last_token;
  int len = sizeof(tokens);

  for (int i; i < len; ++i) {
    token = tokens[i];

    if (token) {
      if (token[0] == "text" && last_token && last_token[0] == "text") {
        last_token[1] += token[1];
        last_token[3]  = token[3];
      }
      else {
        st += ({ token });
        last_token = token;
      }
    }
  }

  return st;
}

//! Class holding an array of @[Token] objects
class TokRef
{
  private array _data = ({});

  array `data()
  {
    return _data;
  }

  TokRef `+(Token t)
  {
    _data += ({ t });
    return this;
  }

  TokRef `[]=(int index, mixed v)
  {
    if (has_index(_data, index)) {
      _data[index] = v;
    }
    return this;
  }

  Token `[](int t)
  {
    if (sizeof(_data) >= t) {
      return _data[t];
    }
  }

  Token pop()
  {
    if (sizeof(_data)) {
      Token t = _data[-1];
      _data = _data[..<1];
      return t;
    }
  }

  int _sizeof()
  {
    return sizeof(_data);
  }

  mixed cast(string how)
  {
    if (how == "array") {
      array(Token) out = allocate(sizeof(_data));

      for (int i; i < sizeof(_data); i++) {
        out[i] = _data[i];

        if (objectp(out[i][4])) {
          out[i][4] = out[i][4]->cast("array");
        }
      }

      return out;
    }
  }

  string _sprintf(int t)
  {
    return sprintf("%O(%d)", object_program(this), sizeof(_data));
  }

#ifdef MUSTACHE_DEBUG
  protected void destroy()
  {
    TRACE("TokRef destroyed!\n");
  }
#endif
}

//! Forms the given array of @[tokens] into a nested tree structure where
//! tokens that represent a section have two additional items: 1) an array of
//! all tokens that appear in that section and 2) the index in the original
//! template that represents the end of that section.
protected array(Token) nest_tokens(array(Token) tokens)
{
  TokRef
    nested_tokens = TokRef(),
    collector     = nested_tokens,
    sections      = TokRef();

  Token token, section;

  int len = sizeof(tokens);

  for (int i; i < len; ++i) {
    token = tokens[i];

    switch (token[0]) {
      case "#":
      case "^":
        collector += token;
        sections  += token;
        collector = token[4] = TokRef();
        break;

      case "/":
        section = sections->pop();
        section[5] = token[2];
        collector = sizeof(sections)
                       ? sections[-1][4]
                       : nested_tokens;
        break;

      default:
        collector += token;
        break;
    }
  }

  array(Token) my_toks = (array(object(Token))) nested_tokens;
  return my_toks;
}


//! Represents a rendering context by wrapping a view object and
//! maintaining a reference to the parent context.
protected class Context
{
  mixed view;
  mapping cache;
  Context parent;

  //! @param view
  //!  The data structure for this context
  protected void create(mixed view, void|Context parent_context)
  {
    this::view = view;
    this::parent = parent_context;
    cache = ([ "." : view ]);
  }

  //! Creates a new context using the given view with this context
  //! as the parent.
  public Context push(mixed view)
  {
    return Context(view, this);
  }

  //! Returns the value of the given name in this context, traversing
  //! up the context hierarchy if the value is absent in this context's view.
  public mixed lookup(string name)
  {
    mixed value = cache[name];

    if (undefinedp(value)) {
      Context ctx = this;
      array(string) names;
      int index;
      bool lookuphit = false;

      while (ctx) {
        if (search(name, ".") > -1) {
          value = ctx->view;
          names = name/".";
          index = 0;
          int namelen = sizeof(names);

          // TRACE("names: %O\n", names);
          // TRACE("value: %O\n", value);

          /**
           * Using the dot notion path in `name`, we descend through the
           * nested objects.
           *
           * To be certain that the lookup has been successful, we have to
           * check if the last object in the path actually has the property
           * we are looking for. We store the result in `lookupHit`.
           *
           * This is specially necessary for when the value has been set to
           * `undefined` and we want to avoid looking up parent contexts.
           **/
          while (value && index < namelen) {
            if (index == namelen - 1) {
              lookuphit = has_property(value, names[index]);
            }

            value = value[names[index++]];
          }
        }
        else {
          value = ctx->view[name];
          lookuphit = has_property(ctx->view, name);
        }

        if (lookuphit) {
          break;
        }

        ctx = ctx->parent;
      }

      cache[name] = value;
    }

    if (functionp(value)) {
      value = value(name, view);
    }

    return safe_string(value);
  }

#ifdef MUSTACHE_DEBUG
  protected void destroy()
  {
    TRACE("Context destroyed!\n");
  }
#endif
}


//! @ignore
//! Template cache
private mapping __cache = set_weak_flag(([]), Pike.WEAK);
//! @endignore

//! Parses and caches the given @[template] and returns the array of tokens
//! that is generated from the parse.
protected array(Token)
parse_template(string|function template, void|array(string) tags)
{
  array(Token) tokens = __cache[template];

  if (!tokens) {
    tokens = __cache[template] = low_parse_template(template, tags);
  }

  return tokens;
}

//! High-level method that is used to render the given @[template] with
//! the given @[view].
//!
//! The optional @[partials] argument may be an object/mapping that contains
//! the names and templates of partials that are used in the template. It may
//! also be a function that is used to load partial templates on the fly
//! that takes a single argument: the name of the partial.
protected string render_template(string template, mixed view,
                                 void|mixed partials)
{
  array(Token) tokens = parse_template(template);
  Context ctx = objectp(view) && object_program(view) == Context
                  ? view
                  : Context(view);

  string res = render_tokens(tokens, ctx, partials, template);
  return res;
}


//! Low-level method that renders the given array of @[tokens] using
//! the given @[context] and @[partials].
//!
//! Note: The @[template] is only ever used to extract the portion
//! of the original template that was contained in a higher-order section.
//! If the template doesn't use higher-order sections, this argument may
//! be omitted.
protected string render_tokens(array(Token) tokens, Context ctx,
                               mixed partials, string template)
{
  String.Buffer buf = String.Buffer();
  function add = buf->add;

  Token token;
  string symbol;
  mixed value;
  int len = sizeof(tokens);

  for (int i; i < len; ++i) {
    value = UNDEFINED;
    token = tokens[i];
    symbol = token[0];

    switch (symbol) {
      case "#":
        value = render_section(token, ctx, partials, template);
        break;

      case "^":
        value = render_inverted(token, ctx, partials, template);
        break;

      case ">":
        value = render_partial(token, ctx, partials);
        break;

      case "&":
        value = unescaped_value(token, ctx);
        break;

      case "name":
        value = escaped_value(token, ctx);
        break;

      case "text":
        value = raw_value(token);
        break;
    }

    if (value != UNDEFINED) {
      add(value);
    }
  }

  return buf->get();
}


protected string render_section(Token token, Context ctx, mixed partials,
                                string template)
{
  String.Buffer b = String.Buffer();
  function add = b->add;
  mixed value = ctx->lookup(token[1]);

  if (!value) {
    return "";
  }

  // This function is used to render an arbitrary template
  // in the current context by higher-order sections.
  string subrender(string tmpl) {
    return render_template(tmpl, ctx, partials);
  };

  if (multisetp(value)) {
    value = (array)value;
  }

  if (arrayp(value)) {
    int len = sizeof(value);

    for (int j; j < len; ++j) {
      add(render_tokens(token[4], ctx->push(value[j]), partials, template));
    }
  }
  else if (objectp(value) || mappingp(value)) {
    add(render_tokens(token[4], ctx->push(value), partials, template));
  }
  else if (functionp(value)) {
    if (!stringp(template)) {
      error("Cannot use higher-order sections without the original template");
    }

    value = value(ctx->view, template[token[3]..token[5]-1], subrender);

    if (value && sizeof(value)) {
      add(value);
    }
  }
  else {
    add(safe_string(render_tokens(token[4], ctx, partials, template)));
  }

  return b->get();
}


protected string render_inverted(Token token, Context ctx, mixed partials,
                       string template)
{
  mixed value = ctx->lookup(token[1]);

  if (falsy(value)) {
    return render_tokens(token[4], ctx, partials, template);
  }
}


protected string render_partial(Token token, Context ctx, mixed partials)
{
  if (!partials) {
    return UNDEFINED;
  }

  mixed value = callablep(partials) ? partials(token[1]) : partials[token[1]];

  if (value) {
    return render_tokens(parse_template(value), ctx, partials, value);
  }
}


protected string unescaped_value(Token token, Context ctx)
{
  mixed value = ctx->lookup(token[1]);

  if (value) {
    return (string) value;
  }
}


protected string escaped_value(Token token, Context ctx)
{
  mixed value = ctx->lookup(token[1]);

  if (value != UNDEFINED) {
    return escape_html((string)value);
  }
}


protected string raw_value(Token token)
{
  return (string) token[1];
}

protected mixed safe_string(mixed i)
{
  if (!stringp(i)) {
    return i;
  }

  catch {
    i = utf8_to_string(i);
    return i;
  };

  return i;
}

//! Is the value @[v] a @tt{falsy@} value or not. It's faly if it's
//! @tt{0, UNDEFINED, "" or ({})@}
protected bool falsy(mixed v)
{
  if (!v) return true;
  if ((stringp(v) || arrayp(v)) && !sizeof(v)) {
    return true;
  }

  return false;
}

#ifdef MUSTACHE_DEBUG
protected void destroy()
{
  TRACE("Mustache destroyed!\n");
}
#endif
