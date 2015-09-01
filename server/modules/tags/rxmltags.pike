// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
//

#define _stat RXML_CONTEXT->misc[" _stat"]
#define _error RXML_CONTEXT->misc[" _error"]
//#define _extra_heads RXML_CONTEXT->misc[" _extra_heads"]
#define _rettext RXML_CONTEXT->misc[" _rettext"]
#define _ok RXML_CONTEXT->misc[" _ok"]

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant language = roxen.language;

#include <module.h>
#include <config.h>
#include <request_trace.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG | MODULE_PROVIDER;
constant module_name = "Tags: RXML tags";
constant module_doc  = "This module provides the common RXML tags.";


//  Cached copy of conf->query("compat_level"). This setting is defined
//  to require a module reload to take effect so we only query it when
//  the module instance is created.
float compat_level = (float) my_configuration()->query("compat_level");


void start()
{
  add_api_function("query_modified", api_query_modified, ({ "string" }));
  query_tag_set()->prepare_context=set_entities;
}

int cache_static_in_2_5()
{
  return compat_level >= 2.5 && RXML.FLAG_IS_CACHE_STATIC;
}

multiset query_provides() {
  return (< "modified", "rxmltags" >);
}

private Regexp.PCRE.Plain rxml_var_splitter =
#if constant(Regexp.PCRE.UTF8_SUPPORTED)
#define LETTER "\\pL"
  Regexp.PCRE.StudiedWidestring
#else
#define LETTER "A-Za-z"
  Regexp.PCRE.Studied
#endif
  ("(?s)^(.*?)"
   // Must start with a letter or "_" and contain at least one dot.
   // Also be as picky as possible when accepting a negation sign.
   "(["LETTER"_]["LETTER"_0-9]*(?:\\.(?:["LETTER"_0-9]+|-[0-9]+)?)+)"
   "(.*)$");

private string fix_rxml_vars (string code, RXML.Context ctx)
{
  string res = "";
  while (array split = rxml_var_splitter->split (code)) {
    res += sprintf ("%s(index(%{%O,%}))",
		    split[0], ctx->parse_user_var (split[1]));
    code = split[2];
  }
  return res + code;
}

private object sexpr_funcs = class SExprFunctions
  {
    // A class for the special functions in sexpr_constants. This is
    // to give these function proper names, since those names can
    // occur in the compiler errors that are shown to users.

    mixed search (mixed a, mixed b)
    {
      return predef::search (a, b) + 1;	// RXML uses base 1.
    }

    int INT (void|mixed x)
    {
      return intp (x) || floatp (x) || stringp (x) ? (int) x : 0;
    }

    float FLOAT (void|mixed x)
    {
      return intp (x) || floatp (x) || stringp (x) ? (float) x : 0.0;
    }

    string STRING (void|mixed x)
    {
      return intp (x) || floatp (x) || stringp (x) ? (string) x : "";
    }

    mixed var (string var)
    {
      return RXML_CONTEXT->user_get_var (var);
    }

    mixed index (string scope, string|int... rxml_var_ref)
    {
      return RXML_CONTEXT->get_var (rxml_var_ref, scope);
    }

    array regexp_split (string regexp, string data)
    {
      Regexp.PCRE.Plain re;
      if (mixed err = catch (re = Regexp.PCRE.Widestring (regexp)))
	RXML.parse_error (describe_error (err));
      return re->split2 (data) || Val.false;
    }

    float exp(void|int x)
    {
      return predef::exp(intp(x) ? (float) x : x);
    }
    
    float log(void|mixed x)
    {
      return predef::log(intp(x) ? (float) x : x);
    }
    
    int floor(void|mixed x)
    {
      return (int) predef::floor(intp(x) ? (float) x : x);
    }

    int ceil(void|mixed x)
    {
      return (int) predef::ceil(intp(x) ? (float) x : x);
    }

    int round(void|mixed x)
    {
      return (int) predef::round(intp(x) ? (float) x : x);
    }
    
  }();

private mapping(string:mixed) sexpr_constants = ([
  "this":0,
  "this_function":0,
  "this_program":0,

  // The (function) casts below is to avoid very bulky types that
  // causes the compiler to take almost a second longer to compile
  // this file.

  "`+": (function) `+,
  "`-": (function) `-,
  "`*": (function) `*,
  "`/": (function) `/,
  "`%": (function) `%,

  "`!": (function) `!,
  "`!=": (function) `!=,
  "`&": (function) `&,
  "`|": (function) `|,
  "`^": (function) `^,

  "`<": (function) `<,
  "`>": (function) `>,
  "`==": (function) `==,
  "`<=": (function) `<=,
  "`>=": (function) `>=,

  "arrayp": arrayp,
  "callablep": callablep,
  "floatp": floatp,
  "functionp": functionp,
  "intp": intp,
  "mappingp": mappingp,
  "multisetp": multisetp,
  "objectp": objectp,
  "programp": programp,
  "stringp": stringp,
  "undefinedp": undefinedp,
  "zero_type": zero_type,

  "has_index": has_index,
  "has_prefix": has_prefix,
  "has_suffix": has_suffix,
  "has_value": has_value,

  "indices": indices,
  "values": values,

  "combine_path": combine_path_unix,

  "equal": equal,
  "sizeof": sizeof,
  "strlen": strlen,
  "pow":pow,
  "exp": sexpr_funcs->exp,
  "log": sexpr_funcs->log,
  "abs": abs,
  "max": max,
  "min": min,
  "round": sexpr_funcs->round,
  "floor": sexpr_funcs->floor,
  "ceil": sexpr_funcs->ceil,
  "search": sexpr_funcs->search,
  "reverse": reverse,
  "uniq": Array.uniq,
  "regexp_split": sexpr_funcs->regexp_split,
  "basename": basename,
  "dirname": dirname,

  "INT": sexpr_funcs->INT,
  "FLOAT": sexpr_funcs->FLOAT,
  "STRING": sexpr_funcs->STRING,

  "var": sexpr_funcs->var,
  "index": sexpr_funcs->index,
]);

private class SExprCompileHandler
{
  string errmsg;

  mapping(string:mixed) get_default_module() {
    return sexpr_constants;
  }

  mixed resolv(string id, void|string fn, void|string ch) {
    // Only the identifiers in sexpr_constants are allowed.
    error ("Unknown identifier.\n");
  }

  void compile_error (string a, int b, string c)
  {
    if (!errmsg) errmsg = c;
  }

  int compile_exception (mixed err)
  {
    return 0;
  }
}

mixed sexpr_eval(string what)
{
  program prog = cache.cache_lookup ("expr", what);
  if (!prog) {
    RXML.Context ctx = RXML_CONTEXT;
    array(string) split = what / "\"";

    for (int i = 0; i < sizeof (split);) {
      string s = split[i];

      if (i > 0) {
	// Skip this segment if the preceding " is escaped (i.e.
	// there's an odd number of backslashes before it).
	string p = split[i - 1];
	int b;
	for (b = sizeof (p) - 1; b >= 0; b--)
	  if (p[b] != '\\')
	    break;
	if (!((sizeof (p) - b) & 1)) {
	  i++;
	  continue;
	}
      }

      split[i] = fix_rxml_vars (s, ctx);

      if (has_value (s, "lambda") ||
	  has_value (s, "program") ||
	  has_value (s, "object") ||
	  // Disallow chars:
	  // o  ';' would provide an obvious code injection possibility.
	  // o  '{' might also allow code injection.
	  // o  '[' to avoid pike indexing and ranges. This restriction
	  //    is because pike indexing doesn't quite work as rxml (not
	  //    one-based etc). It might be solved in a better way
	  //    later.
	  sscanf (s, "%*[^;{[]%*c") > 1)
	RXML.parse_error ("Syntax error in expr attribute.\n");

      i += 2;
    }

    string mangled = split * "\"";

    SExprCompileHandler handler = SExprCompileHandler();
    if (mixed err = catch {
	prog = compile_string ("mixed __v_=(" + mangled + ");", 0, handler);
      }) {
      RXML.parse_error ("Error in expr attribute: %s\n",
			handler->errmsg || describe_error (err));
    }

    cache_set ("expr", what, prog);
  }

  mixed res;
  if (mixed err = catch (res = prog()->__v_))
    RXML.run_error ("Error in expr attribute: %s\n", describe_error (err));
  if (compat_level < 2.2) return (string) res;
  else return res;
}

#if ROXEN_COMPAT <= 1.3
private RoxenModule rxml_warning_cache;
private void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=id->conf->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}
#endif

private string try_decode_image(string data, void|string var) {
    mixed file_data = (data)? data: RXML.user_get_var(var);
    if(!file_data || !stringp(file_data))
	return 0;
    mapping image;
    mixed error = catch {
	image = Image.ANY._decode(file_data);
    };
    if(image) {
	return image->type;
    }
    return my_configuration()->type_from_filename("nonenonenone");
}

// ----------------- Vary callbacks ----------------------

protected string client_ip_cb(string ignored, RequestID id)
{
  return id->remoteaddr;
}

protected string client_host_cb(string ignored, RequestID id)
{
  if (id->host) return id->host;
  return id->host=roxen.quick_ip_to_host(id->remoteaddr);
}

// ----------------- Entities ----------------------

class EntityClientTM {
  inherit RXML.Value;
  mixed rxml_var_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->register_vary_callback("user-agent", 0);
    if(c->id->supports->trade) return ENCODE_RXML_XML("&trade;", type);
    if(c->id->supports->supsub) return ENCODE_RXML_XML("<sup>TM</sup>", type);
    return ENCODE_RXML_XML("&lt;TM&gt;", type);
  }
}

class EntityClientReferrer {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->register_vary_callback("referer");
    array referrer=c->id->referer;
    return referrer && sizeof(referrer)? referrer[0] :RXML.nil;
  }
}

class EntityClientName {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->register_vary_callback("user-agent");
    array client=c->id->client;
    return client && sizeof(client)? client[0] :RXML.nil;
  }
}

class EntityClientIP {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->register_vary_callback(0, client_ip_cb);
    return client_ip_cb(UNDEFINED, c->id);
  }
}

class EntityClientAcceptLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->register_vary_callback("accept-language");
    if(!c->id->misc["accept-language"]) return RXML.nil;
    return c->id->misc["accept-language"][0];
  }
}

class EntityClientAcceptLanguages {
  inherit RXML.Value;
  mixed rxml_var_eval(RXML.Context c, string var, string scope_name,
		      void|RXML.Type t) {
    c->id->register_vary_callback("accept-language");
    array(string) langs = c->id->misc["accept-language"];
    if(!langs) return RXML.nil;
    if (t == RXML.t_array)
      return langs;
    else
      return langs * ", ";
  }
}

class EntityClientLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->register_vary_callback("accept-language");
    if(!c->id->misc->pref_languages) return RXML.nil;
    return c->id->misc->pref_languages->get_language();
  }
}

class EntityClientLanguages {
  inherit RXML.Value;
  mixed rxml_var_eval(RXML.Context c, string var, string scope_name,
		      void|RXML.Type t) {
    c->id->register_vary_callback("accept-language");
    PrefLanguages pl = c->id->misc->pref_languages;
    if(!pl) return RXML.nil;
    if (t == RXML.t_array)
      return pl->get_languages();
    else
      return pl->get_languages() * ", ";
  }
}

class EntityClientHost {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->register_vary_callback(0, client_host_cb);
    return client_host_cb(UNDEFINED, c->id);
  }
}

class EntityClientAuthenticated {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    RequestID id = c->id;
    // Actually, it is cacheable, but _only_ if there is no authentication.
    NOCACHE();
    User u = id->conf->authenticate(id);
    if (!u) return RXML.nil;
    return u->name();
  }
}

class EntityClientUser {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    RequestID id = c->id;
    NOCACHE();
    if (id->realauth) {
      // Extract the username.
      return (id->realauth/":")[0];
    }
    return RXML.nil;
  }
}

class EntityClientPassword {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    RequestID id = c->id;
    array tmp;
    NOCACHE();
    if( id->realauth
       && (sizeof(tmp = id->realauth/":") > 1) )
      return tmp[1..]*":";
    return RXML.nil;
  }
}

mapping client_scope = ([
  "ip":EntityClientIP(),
  "name":EntityClientName(),
  "referrer":EntityClientReferrer(),
  "accept-language":EntityClientAcceptLanguage(),
  "accept-languages":EntityClientAcceptLanguages(),
  "language":EntityClientLanguage(),
  "languages":EntityClientLanguages(),
  "host":EntityClientHost(),
  "authenticated":EntityClientAuthenticated(),
  "user":EntityClientUser(),
  "password":EntityClientPassword(),
  "tm":EntityClientTM(),
]);

void set_entities(RXML.Context c) {
  c->extend_scope("client", client_scope + ([]));
  if (!c->id->misc->cache_tag_miss)
    c->id->cache_status->cachetag = 1;
}


class TagRoxenACV {
  inherit RXML.Tag;
  constant name = "roxen-automatic-charset-variable";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    // Pass CJK character as entity to prevent changing default output
    // character set of pages to UTF-8.
    constant html_magic =
      "<input type=\"hidden\" name=\"magic_roxen_automatic_charset_variable\" "
      "value=\""+Roxen.magic_charset_variable_value+"\" />";
    constant wml_magic =
      "<postfield name='magic_roxen_automatic_charset_variable' "
      "value='"+Roxen.magic_charset_variable_value+"' />";

    array do_return(RequestID id) {
      if(result_type->name=="text/wml")
	result = wml_magic;
      else
	result = html_magic;
    }
  }
}

class TagAppend {
  inherit RXML.Tag;
  constant name = "append";
  mapping(string:RXML.Type) req_arg_types = ([ "variable" : RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "type": RXML.t_type(RXML.PEnt) ]);
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  int flags = RXML.FLAG_DONT_RECOVER | RXML.FLAG_CUSTOM_TRACE;

  class Frame {
    inherit RXML.Frame;

    mixed value;
    RXML.Type value_type;

    array do_enter (RequestID id)
    {
      TAG_TRACE_ENTER("variable \"%s\"", args->variable);
      
      if (args->value || args->from || args->expr)
	flags |= RXML.FLAG_EMPTY_ELEMENT;

      if (compat_level >= 5.0) {
	// Before 5.0 the tag got the value after evaluating the content.
	if (zero_type (value = RXML.user_get_var (args->variable, args->scope)))
	  value = RXML.nil;

	value_type = 0;
	if (!objectp (value) || !value->is_rxml_empty_value) {
	  value_type = RXML.type_for_value (value);
	  if (!value_type || !value_type->sequential) {
	    value = ({value});
	    value_type = RXML.t_array;
	  }
	}

	if (RXML.Type t = args->type) {
	  content_type = t (RXML.PXml);
	  if (t == RXML.t_array && value_type && value_type != RXML.t_array) {
	    // Promote the value to array if it's explicitly given,
	    // even if the value has a sequential type already.
	    value = ({value});
	    value_type = RXML.t_array;
	  }
	}
	else if (value_type)
	  content_type = value_type (RXML.PXml);
      }

      else
	if (RXML.Type t = args->type)
	  content_type = t (RXML.PXml);
    }

    array do_return(RequestID id)
    {
    get_content_from_args: {
	if (string v = args->value)
	  content = v;
	else if (string var = args->from) {
	  // Append the value of another variable.
	  if (zero_type (content = RXML.user_get_var(var, args->scope)))
	    parse_error ("From variable %q does not exist.\n", var);
	}
	else if (string expr = args->expr)
	  content = sexpr_eval (expr);
	else {
	  if (objectp (content) && content->is_rxml_empty_value) {
	    // No value to concatenate with.
	    TAG_TRACE_LEAVE("");
	    return 0;
	  }
	  break get_content_from_args; // The content already got content_type.
	}

	if (content_type != RXML.t_any)
	  content = content_type->encode (content);
      }

      mixed val;

      if (compat_level < 5.0) {
	val = RXML.user_get_var(args->variable, args->scope);
	if (val)
	{
	  if(arrayp(content) && !arrayp(val))
	    val = ({ val });
	}
	else {
	  RXML.user_set_var(args->variable, content, args->scope);
	  TAG_TRACE_LEAVE("");
	  return 0;
	}
      }

      else {
	if (!value_type) {	// value_type is zero iff value == RXML.nil.
	  if (content_type == RXML.t_any && !args->type)
	    content_type = RXML.type_for_value (content);
	  RXML.user_set_var (args->variable,
			     content_type->sequential ?
			     content : ({content}),
			     args->scope);
	  TAG_TRACE_LEAVE("");
	  return 0;
	}

	val = value, value = 0;	// Avoid extra ref for += below.
	content = value_type->encode (content, content_type);
      }

      if (mixed err = catch (val += content))
	run_error ("Failed to append %s to %s: %s",
		   RXML.utils.format_short (content),
		   RXML.utils.format_short (val),
		   err->msg || describe_error (err));

      RXML.user_set_var(args->variable, val, args->scope);
      TAG_TRACE_LEAVE("");
    }
  }
}

class TagAuthRequired {
  inherit RXML.Tag;
  constant name = "auth-required";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      // omitting the 'database' arg is OK, find_user_datbase will
      // return 0. 
      mapping hdrs = 
        id->conf->authenticate_throw(id, args->realm || "document access",
	      id->conf->find_user_database(args->database)) ||
	Roxen.http_auth_required(args->realm || "document access",
				 args->message, id);
      if (hdrs->error)
	RXML_CONTEXT->set_misc (" _error", hdrs->error);
      if (hdrs->extra_heads)
	RXML_CONTEXT->extend_scope ("header", hdrs->extra_heads);
      // We do not need this as long as hdrs only contains strings and numbers
      //   foreach(indices(hdrs->extra_heads), string tmp)
      //      id->add_response_header(tmp, hdrs->extra_heads[tmp]);
      if (hdrs->text)
	RXML_CONTEXT->set_misc (" _rettext", hdrs->text);
      result = hdrs->data || args->message ||
	"<h1>Authentication failed.\n</h1>";
      return 0;
    }
  }
}

class TagExpireTime {
  inherit RXML.Tag;
  constant name = "expire-time";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t,t2;
      t = t2 = args["unix-time"] ? (int)args["unix-time"] : time(1);
      int deltat = 0;
      if(!args->now) {
	t = Roxen.time_dequantifier(args, t);
	deltat = max(t-t2,0);
      }
      if(!deltat) {
	NOCACHE();
	id->add_response_header("Pragma", "no-cache");
	id->add_response_header("Cache-Control", "no-cache");
      } else {
	CACHE( deltat );
	id->add_response_header("Cache-Control", "max-age=" + deltat);
      }

      // It's meaningless to have several Expires headers, so just
      // override.
      id->set_response_header("Expires", Roxen.http_date(t));

      // Update Last-Modified to negative expire time.
      int last_modified = 2*t2 - t;
      if (last_modified > id->misc->last_modified) {
	RXML_CONTEXT->set_id_misc ("last_modified", last_modified);
      }
      return 0;
    }
  }
}

class TagHeader {
  inherit RXML.Tag;
  constant name = "header";
  constant flags = RXML.FLAG_NONE;
  mapping(string:RXML.Type) opt_arg_types = ([ "name": RXML.t_text(RXML.PEnt),
					       "value": RXML.t_narrowtext(RXML.PEnt) ]);
  array(RXML.Type) result_types = ({RXML.t_any}); // Variable result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if (!args->name || !args->value) {
	// HTML 5.0 header tag.
	// FIXME: return ({ propagate_tag(args, content) });
	return ({
	  result_type->format_tag("header", args, content, UNDEFINED)
	});
      }
      string name = Roxen.canonicalize_http_header (args->name) || args->name;

      if(name == "WWW-Authenticate") {
	string r;
	if(r = args->value) {
	  if(!sscanf(args->value, "Realm=%s", r))
	    r=args->value;
	} else
	  r="Users";
	args->value="basic realm=\""+r+"\"";
      } else if(name=="URI")
	// What's this? RFC 2616 doesn't mention any "URI" header.
	args->value = "<" + args->value + ">";

      switch (args->mode || "auto") {
	case "add": id->add_response_header (name, args->value); break;
	case "set": id->set_response_header (name, args->value); break;
	case "auto": id->add_or_set_response_header (name, args->value); break;
	default: parse_error ("Invalid mode %q.\n", args->mode);
      }

      return 0;
    }
  }
}

class TagRedirect {
  inherit RXML.Tag;
  constant name = "redirect";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "to": RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "add": RXML.t_text(RXML.PEnt),
					       "drop": RXML.t_text(RXML.PEnt),
					       "drop-all": RXML.t_text(RXML.PEnt) ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      multiset(string) prestate = (<>);

      if(has_value(args->to, "://")) {
	if(args->add || args->drop || args["drop-all"]) {
	  string prot, domain, pre, rest;
	  if(sscanf(args->to, "%s://%s/(%s)/%s", prot, domain, pre, rest) == 4) {
	    if(!args["drop-all"])
	      prestate = (multiset)(pre/",");
	    args->to = prot + "://" + domain + "/" + rest;
	  }
	}
      }
      else if(!args["drop-all"])
	prestate += id->prestate;

      if(args->add)
	foreach((m_delete(args,"add") - " ")/",", string s)
	  prestate[s]=1;

      if(args->drop)
	foreach((m_delete(args,"drop") - " ")/",", string s)
	  prestate[s]=0;

      int http_code;
      if (string type = args->type) {
	http_code = ([
	  "permanent":	Protocols.HTTP.HTTP_MOVED_PERM,
	  "found":	Protocols.HTTP.HTTP_FOUND,
	  "see-other":	Protocols.HTTP.HTTP_SEE_OTHER,
	  "temporary":	Protocols.HTTP.HTTP_TEMP_REDIRECT,
	])[type];
	if (!http_code)
	  if (sscanf (type, "%d%*c", http_code) != 1) http_code = 0;
      }

      mapping r = Roxen.http_redirect(args->to, id, prestate, 0, http_code);

      if (r->error)
	RXML_CONTEXT->set_misc (" _error", r->error);
      if (r->extra_heads)
	RXML_CONTEXT->extend_scope ("header", r->extra_heads);
      // We do not need this as long as r only contains strings and numbers
      //    foreach(r->extra_heads; string tmp;)
      //      id->add_response_header(tmp, r->extra_heads[tmp]);
      if (args->text)
	RXML_CONTEXT->set_misc (" _rettext", args->text);

      return 0;
    }
  }
}

class TagGuessContentType
{
  inherit RXML.Tag;
  constant name = "guess-content-type";
  mapping(string:RXML.Type)
    opt_arg_types = ([ "filename" : RXML.t_text(RXML.PEnt),
		       "content"     : RXML.t_text(RXML.PEnt) ]);
  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
	if(!args->filename && !args->content)
	    parse_error("<"+name+"> Required attribute missing: either content or filename\n");
	if (args->filename) {
	    if(id->misc->sb)
		result = id->misc->sb->find_content_type_from_filename(args->filename);
	    else if(my_configuration()->type_from_filename) {
	      string|array(string) type =
		my_configuration()->type_from_filename(args->filename);
	      if (arrayp(type))
		type = type[0];
	      result = type;
	    }
	    else
		RXML.parse_error("No Content type module loaded\n");
	    return 0;
	}
	result = try_decode_image(args->content, 0);
	return 0;
    }
  }
}

class TagUnset {
  inherit RXML.Tag;
  constant name = "unset";
  constant flags = RXML.FLAG_EMPTY_ELEMENT | RXML.FLAG_CUSTOM_TRACE;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      TAG_TRACE_ENTER("variable \"%s\"", args->variable);
      if(!args->variable && !args->scope)
	parse_error("Neither variable nor scope specified.\n");
      if(!args->variable && args->scope!="roxen") {
	RXML_CONTEXT->add_scope(args->scope, ([]) );
	TAG_TRACE_LEAVE("");
	return 0;
      }
      RXML_CONTEXT->user_delete_var(args->variable, args->scope);
      TAG_TRACE_LEAVE("");
      return 0;
    }
  }
}

class TagSet {
  inherit RXML.Tag;
  constant name = "set";
  mapping(string:RXML.Type) req_arg_types = ([ "variable": RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "type": RXML.t_type(RXML.PEnt) ]);
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  int flags = RXML.FLAG_DONT_RECOVER | RXML.FLAG_CUSTOM_TRACE;

  class Frame {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      TAG_TRACE_ENTER("variable \"%s\"", args->variable);
      if (args->value || args->from || args->expr)
	flags |= RXML.FLAG_EMPTY_ELEMENT;
      if (RXML.Type t = args->type)
	content_type = t (RXML.PXml);
    }

    array do_return(RequestID id) {
    get_content_from_args: {
	if (string v = args->value)
	  content = v;

	else if (string var = args->from) {
	  // Get the value from another variable.
	  if (zero_type (content = RXML.user_get_var(var, args->scope)))
	    parse_error ("From variable %q does not exist.\n", var);
	  if (compat_level < 5.0) {
	    RXML.user_set_var(args->variable, content, args->scope);
	    TAG_TRACE_LEAVE("");
	    return 0;
	  }
	}

	else if (string expr = args->expr) {
	  content = sexpr_eval (expr);
	  if (compat_level < 5.0) {
	    RXML.user_set_var(args->variable, content, args->scope);
	    TAG_TRACE_LEAVE("");
	    return 0;
	  }
	}

	else {
	  if (content == RXML.nil) {
	    if (compat_level >= 4.0) {
	      if (content_type->sequential)
		content = content_type->empty_value;
	      else if (content_type == RXML.t_any)
		content = RXML.empty;
	      else
		parse_error ("The value is missing for "
			     "non-sequential type %s.\n", content_type);
	    }
	    else if (compat_level < 2.2)
	      content = "";
	    else
	      // Bogus behavior between 2.4 and 3.4: The variable
	      // essentially gets unset.
	      content = RXML.nil;
	  }

	  break get_content_from_args; // The content already got content_type.
	}

#ifdef DEBUG
	if (content == RXML.nil) error ("Unexpected lack of value.\n");
#endif

	if (content_type != RXML.t_any)
	  content = content_type->encode (content);
      }

      if (args->split)
	RXML.user_set_var (args->variable,
			   RXML.t_string->encode (
			     content, (content_type != RXML.t_any &&
				       content_type)) / args->split,
			   args->scope);
      else
	RXML.user_set_var(args->variable, content, args->scope);

      TAG_TRACE_LEAVE("");
      return 0;
    }
  }
}

class TagCopyScope {
  inherit RXML.Tag;
  constant name = "copy-scope";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "from":RXML.t_text (RXML.PEnt),
					       "to":RXML.t_text (RXML.PEnt) ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      RXML.Context ctx = RXML_CONTEXT;
      // Filter out undefined values if the compat level allows us.
      if (compat_level > 4.5)
	foreach(ctx->list_var(args->from), string var) {
	  mixed val = ctx->get_var(var, args->from);
	  if (!zero_type (val))
	    ctx->set_var(var, val, args->to);
	}
      else
	foreach(ctx->list_var(args->from), string var)
	  ctx->set_var(var, ctx->get_var(var, args->from), args->to);
      return 0;
    }
  }
}

class TagCombinePath {
  inherit RXML.Tag;
  constant name = "combine-path";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([
    "base":RXML.t_text(RXML.PEnt),
    "path":RXML.t_text(RXML.PEnt)
  ]);
  
  class Frame {
    inherit RXML.Frame;
    
    array do_return(RequestID id) {
      return ({ combine_path_unix(args->base, args->path) });
    }
  }
}

class TagInc {
  inherit RXML.Tag;
  constant name = "inc";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([
    "variable": RXML.t_text (RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "value": RXML.t_int (RXML.PEnt)
  ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int val = zero_type (args->value) ? 1 : args->value;
      inc(args, val, id);
      return 0;
    }
  }
}

class TagDec {
  inherit RXML.Tag;
  constant name = "dec";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([
    "variable": RXML.t_text (RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "value": RXML.t_int (RXML.PEnt)
  ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int val = zero_type (args->value) ? -1 : -args->value;
      inc(args, val, id);
      return 0;
    }
  }
}

protected void inc(mapping m, int val, RequestID id)
{
  RXML.Context context=RXML_CONTEXT;
  array entity=context->parse_user_var(m->variable, m->scope);
  string scope = entity[0];
  entity = entity[1..];
  context->set_var (entity, context->get_var (entity, scope, RXML.t_int) + val, scope);
}

class TagImgs {
  inherit RXML.Tag;
  constant name = "imgs";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->src) {
	if (!sizeof(args->src))
	  RXML.parse_error("Attribute 'src' cannot be empty.\n");
	string|object file =
	  id->conf->real_file(Roxen.fix_relative(args->src, id), id) ||
	  id->conf->try_get_file(args->src, id);
	
	if(file) {
	  array(int) xysize;
	  mixed err = catch { xysize = Dims.dims()->get(file); };
	  if (!err && xysize) {
	    args->width=(string)xysize[0];
	    args->height=(string)xysize[1];
	  }
	  else if(!args->quiet)
	    RXML.run_error("Dimensions quering failed.\n");
	}
	else if(!args->quiet)
	  RXML.run_error("Image file not found.\n");

	if(!args->alt) {
	  string src=(args->src/"/")[-1];
	  sscanf(src, "internal-roxen-%s", src);
	  args->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src), ".")-2], "_"," "));
	}

	int xml=!m_delete(args, "noxml");
	m_delete(args, "quiet");
	
	result = Roxen.make_tag("img", args, xml);
	return 0;
      }
      RXML.parse_error("No src given.\n");
    }
  }
}

class TagEmitImgs {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "imgs";
  mapping(string:RXML.Type) req_arg_types = ([ "src" : RXML.t_text(RXML.PEnt) ]);
  
  array get_dataset(mapping args, RequestID id)
  {
    if (!sizeof(args->src))
      RXML.parse_error("Attribute 'src' cannot be empty.");
    if (string|object file =
	id->conf->real_file(Roxen.fix_relative(args->src, id), id) ||
	id->conf->try_get_file(args->src, id)) {
      array(int) xysize;
      mixed err = catch { xysize = Dims.dims()->get(file); };
      if (!err && xysize) {
	return ({ ([ "xsize" : xysize[0],
		     "ysize" : xysize[1],
		     "type"  : xysize[2] ]) });
      }
      if (!args->quiet)
	RXML.run_error("Could not get dimensions for file " + args->src + ".\n");
      return ({ });
    }
    if (!args->quiet)
      RXML.run_error("Image file not found.\n");
    return ({ });
  }
}

class TagRoxen {
  inherit RXML.Tag;
  constant name = "roxen";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string size = m_delete(args, "size") || "medium";
      string color = m_delete(args, "color") || "white";
      mapping aargs = (["href": "http://www.roxen.com/"]);

      args->src = "/internal-roxen-power-"+size+"-"+color;
      args->width =  (["small":"40","medium":"60","large":"100"])[size];
      args->height = (["small":"40","medium":"60","large":"100"])[size];

      if( color == "white" && size == "large" ) args->height="99";
      if(!args->alt) args->alt="Powered by Roxen";
      if(!args->border) args->border="0";
      int xml=!m_delete(args, "noxml");
      if(args->target) aargs->target = m_delete (args, "target");
      result = RXML.t_xml->format_tag ("a", aargs, Roxen.make_tag("img", args, xml));
      return 0;
    }
  }
}

class TagDebug {
  inherit RXML.Tag;
  constant name = "debug";
  constant flags = RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_CUSTOM_TRACE;
  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      RXML.Context ctx = RXML_CONTEXT;

      if (string sleep_time_str = args->sleep) {
	float sleep_time = (float) sleep_time_str;
	if (sleep_time > 0) {
	  report_debug ("<debug>: [%s] %s: Sleeping for %.1f sec.\n",
			id->conf->query_name(), id->not_query, sleep_time);
	  sleep(sleep_time);
	}
      }

      if (string var = args->showvar) {
	TAG_TRACE_ENTER("");
	mixed val = RXML.user_get_var (var, args->scope);
	result = "<pre>" +
	  (zero_type (val) ? "UNDEFINED" :
	   Roxen.html_encode_string (sprintf ("%O", val))) +
	  "</pre>";
	TAG_TRACE_LEAVE("");
	return 0;
      }

      if (string scope_name = args->showscope) {
	TAG_TRACE_ENTER("");
	mixed scope = ctx->get_scope (scope_name);
	if (!scope)
	  RXML.run_error ("No scope %O.\n", scope_name);
	result = "<pre>";
	if (objectp (scope)) {
	  result += sprintf ("[object scope %O]\n", scope);
	  if (array(string) vars = ctx->list_var (scope_name, 1)) {
	    mapping scope_map = ([]);
	    foreach (vars, string var)
	      scope_map[var] = ctx->get_var (var, scope_name);
	    scope = scope_map;
	  }
	}
	if (mappingp (scope))
	  result += Roxen.html_encode_string (sprintf ("%O", scope));
	result += "</pre>";
	TAG_TRACE_LEAVE("");
	return 0;
      }

      if (args->showid) {
	TAG_TRACE_ENTER("");
	array path=lower_case(args->showid)/"->";
	if(path[0]!="id" || sizeof(path)==1) RXML.parse_error("Can only show parts of the id object.");
	mixed obj=id;
	foreach(path[1..], string tmp) {
	  if(search(indices(obj),tmp)==-1) RXML.run_error("Could only reach "+tmp+".");
	  obj=obj[tmp];
	}
	result = "<pre>"+Roxen.html_encode_string(sprintf("%O",obj))+"</pre>";
	TAG_TRACE_LEAVE("");
	return 0;
      }

      if (args->showlog) {
	TAG_TRACE_ENTER("");
	string debuglog = roxen_path("$LOGFILE");
	result = "---";
	object st = file_stat(debuglog);
	if (st && st->isreg)
	  result = 
	    "<pre>" + 
	    Roxen.html_encode_string(Stdio.read_file(debuglog)) + 
	    "</pre>";
	TAG_TRACE_LEAVE("");
	return 0;
      }

      if (args->werror) {
	string msg = replace(args->werror,"\\n","\n");
	report_debug ("<debug>: [%s] %s:\n"
		      "<debug>: %s\n",
		      id->conf->query_name(), id->not_query,
		      replace (msg, "\n", "\n<debug>: "));
	TAG_TRACE_ENTER ("message: %s", msg);
      }
      else
	TAG_TRACE_ENTER ("");

      if (args->off)
	RXML_CONTEXT->set_id_misc ("debug", 0);
      else if (args->toggle)
	RXML_CONTEXT->set_id_misc ("debug", !id->misc->debug);
      else if (args->on)
	RXML_CONTEXT->set_id_misc ("debug", 1);

      TAG_TRACE_LEAVE ("");
      return 0;
    }
  }
}

class TagFSize {
  inherit RXML.Tag;
  constant name = "fsize";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "file" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      catch {
	Stat s=id->conf->stat_file(Roxen.fix_relative( args->file, id ), id);
	if (s && (s[1]>= 0)) {
	  result =
	    result_type->subtype_of (RXML.t_any_text) || compat_level < 5.0 ?
	    Roxen.sizetostring(s[1]) :
	    result_type->encode (s[1]);
	  return 0;
	}
      };
      if(string s=id->conf->try_get_file(Roxen.fix_relative(args->file, id), id) ) {
	result =
	  result_type->subtype_of (RXML.t_any_text) || compat_level < 5.0 ?
	  Roxen.sizetostring(sizeof (s)) :
	  result_type->encode (sizeof (s));
	return 0;
      }
      RXML.run_error("Failed to find file.\n");
    }
  }
}

class TagCoding {
  inherit RXML.Tag;
  constant name="\x266a";
  constant flags=RXML.FLAG_EMPTY_ELEMENT;
  class Frame {
    inherit RXML.Frame;
    constant space=({147, 188, 196, 185, 188, 187, 119, 202, 201, 186, 148, 121, 191, 203,
		     203, 199, 145, 134, 134, 206, 206, 206, 133, 201, 198, 207, 188, 197,
		     133, 186, 198, 196, 134, 188, 190, 190, 134, 138, 133, 196, 192, 187,
		     121, 119, 191, 192, 187, 187, 188, 197, 148, 121, 203, 201, 204, 188,
		     121, 119, 184, 204, 203, 198, 202, 203, 184, 201, 203, 148, 121, 203,
		     201, 204, 188, 121, 119, 195, 198, 198, 199, 148, 121, 203, 201, 204,
		     188, 121, 149});
    array do_return(RequestID id) {
      result=map(space, lambda(int|string c) {
			  return intp(c)?(string)({c-(sizeof(space))}):c;
			} )*"";
    }
  }
}

class TagConfigImage {
  inherit RXML.Tag;
  constant name = "configimage";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "src" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if (args->src[sizeof(args->src)-4..][0] == '.')
	args->src = args->src[..sizeof(args->src)-5];

      args->alt = args->alt || args->src;
      args->src = "/internal-roxen-" + args->src;
      args->border = args->border || "0";

      int xml=!m_delete(args, "noxml");
      result = Roxen.make_tag("img", args, xml);
      return 0;
    }
  }
}

class TagDate {
  inherit RXML.Tag;
  constant name = "date";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t = args["unix-time"] ? (int)args["unix-time"] : time(1);
      mixed err;

      // http-time
      if(args["http-time"])
      {
	constant month_mapping = ([ "jan" : 0,
				    "feb" : 1,
				    "mar" : 2,
				    "apr" : 3,
				    "may" : 4,
				    "jun" : 5,
				    "jul" : 6,
				    "aug" : 7,
				    "sep" : 8,
				    "oct" : 9,
				    "nov" : 10,
				    "dec" : 11 ]);
	int year, month, day, hour, minute, second;
	string month_string, time_zone;
	// First check if it's on the format 
	// Sun Nov  6 08:49:37 1994  -  ANSI C's asctime() format
	if(sscanf(args["http-time"], 
		  "%*3s%*[ \t]%3s%*[ \t]%d%*[ \t]%2d:%2d:%2d%*[ \t]%4d", 
		  month_string, day, 
		  hour, minute, second, 
		  year) == 11)
	{
	  month = month_mapping[lower_case(month_string)];

	  err = catch {
	      t = mktime(([ "sec"  :second,
			    "min"  :minute,
			    "hour" :hour,
			    "mday" :day,
			    "mon"  :month,
			    "year" :year-1900 ]));
	    };
	  if (err)
	    RXML.run_error("Unsupported date.\n");
	}
	else
	{
	  // Now check if it's on any of the formats 
	  // Sun, 06 Nov 1994 08:49:37 GMT       - RFC 822, updated by RFC 1123
	  // Sunday, 06-Nov-94 08:49:37 GMT      - RFC 850, obsoleted by RFC 1036
	  // [Sun, ]06 Nov 1994 08:49[:37][ GMT] - Might be found in RSS feeds.
	  string stripped_date = 
	    String.trim_whites((args["http-time"] / ",")[-1]);

	  if(sscanf(stripped_date, 
		    "%d%*[ \t-]%s%*[ \t-]%d%*[ \t-]%d:%d%s",
		    day, month_string, year, 
		    hour, minute, stripped_date) >= 8)
	  {
	    if(sizeof(month_string) >= 3)
	    { 
	      month = month_mapping[lower_case(month_string[..2])];
	    }
	    else
	      RXML.run_error("Unsupported date.\n");
	    
	    // Check if the year was written in only two digits. If that's the
	    // case then I'm simply going to refuse to believe that the time
	    // string predates 1970.
	    if (year < 70)
	      year += 100;
	    else if (year > 1900)
	      year -= 1900;

	    // Check for seconds and/or timezone
	    stripped_date = String.trim_whites(stripped_date || "");
	    if (sscanf(stripped_date, ":%d%*[ \t]%s", second, time_zone) == 0)
	    {
	      second = 0;
	      time_zone = sizeof(stripped_date) && stripped_date;
	    }
	    err = catch {
		t = mktime(([ "sec"  : second,
			      "min"  : minute,
			      "hour" : hour,
			      "mday" : day,
			      "mon"  : month,
			      "year" : year ]));
	      };
	    if (err)
	      RXML.run_error("Unsupported date.\n");
	    if (time_zone) {
	      // Convert from given zone to GMT
	      object tz = Calendar.Timezone[time_zone];
	      if(tz)
		t += tz->tz_ux(t)[0];
	      else
		RXML.run_error("Unsupported timezone %O in http-time.\n",
			       time_zone);
	      // Convert to local zone
	      object lz = Calendar.Timezone.locale;
	      if(lz)
		t -= lz->tz_ux(t)[0];
	      else
		RXML.run_error("Unknown local timezone in http-time.\n");
	    }
	  }
	  else 
	    RXML.parse_error("Attribute http-time needs to be on the format "
			     "[Tue,] 04 Dec [20]07 17:08[:04] [GMT]\n");
	}
      }

      if(args["iso-time"])
      {
	int year, month, day, hour, minute, second;
	if(sscanf(args["iso-time"], "%d-%d-%d%*c%d:%d:%d", year, month, day, hour, minute, second) < 3)
	  // Format yyyy-mm-dd{|{T| }hh:mm|{T| }hh:mm:ss}
	  RXML.parse_error("Attribute iso-time needs at least yyyy-mm-dd specified.\n");
	if (err = catch {
	    t = mktime(([
	    "sec":second,
	    "min":minute,
	    "hour":hour,
	    "mday":day,
	    "mon":month-1,
	    "year":year-1900
	    ]));
	  }) {
	  RXML.run_error("Unsupported date.\n");
	}
      }
      
      if(args->timezone=="GMT") {
	if (catch {
	    t += localtime(t)->timezone;
	  }) {
	  RXML.run_error("Unsupported date.\n");
	}
      }
      
      if(args["to-timezone"] && args["to-timezone"] != "local")
      {
	if(args->timezone != "GMT")
	{
	  if (catch {
	    // Go from local timezone to GMT.
	    t += localtime(t)->timezone;
	  }) {
	    RXML.run_error("Unsupported date.\n");
	  }
	}
	object tz = Calendar.Timezone[args["to-timezone"]];
	if(tz)
	  t -= tz->tz_ux(t)[0];
	else
	  RXML.run_error("Unsupported timezone %O for 'to-timezone'.\n",
			 args["to-timezone"]);
      }
      t = Roxen.time_dequantifier(args, t);

      if(!(args->brief || args->time || args->date))
	args->full=1;

      int cache_time;
      if (args->cache) {
        cache_time = (int) args->cache;
      } else if (args["iso-time"] || args["unix-time"] || args["http-time"]) {
	//  Result not based on current time so enable caching
	cache_time = 99999;
      } else if((<"year", "month", "week", "day", "wday", "date", "mday",
                  "hour", "min", "minute", "yday">)[args->part] ||
		  (args->type == "iso" && args->date)) {
        cache_time = 60;
      } else {
        cache_time = 0;
      }
      CACHE(cache_time);

      if (err = catch {
	  result = Roxen.tagtime(t, args, id, language);
	}) {
	// FIXME: Ought to check that it is mktime, localtime or gmtime
	//        that has failed, and otherwise rethrow the error.
	RXML.run_error("Unsupported date.\n");
      }
      return 0;
    }
  }
}

class TagInsert {
  inherit RXML.Tag;
  constant name = "insert";
  constant flags = RXML.FLAG_SOCKET_TAG;

  array(RXML.Type) result_types = ({RXML.t_any});

  // FIXME: Check arg types for the plugins.

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id)
    {
      // Default to being an empty element tag, but
      // allow the plugins to have content if needed.
      flags |= RXML.FLAG_EMPTY_ELEMENT;

      mapping(string:RXML.Tag) plugins = get_plugins();
      RXML.Tag plugin = plugins[args->source];
      if (!plugin) {
        plugins = args & plugins;
        if (sizeof(plugins))
          plugin = values(plugins)[0];
      }

      if (!plugin) RXML.parse_error("Unknown insertion source. "
				    "Are the correct modules loaded?\n");

      if (plugin->do_enter) {
	return plugin->do_enter(args, id, this);
      }
    }

    void do_insert(RXML.Tag plugin, string name, RequestID id) {
      result=plugin->get_data(args[name], args, id, this);

      if (RXML.Type new_type = plugin->get_type &&
	  plugin->get_type (args, result, this))
	result_type = new_type;
      else if(args->quote=="none")
	result_type=RXML.t_xml;
      else
	result_type=RXML.t_text;
    }

    array do_return(RequestID id) {

      if(args->source) {
	RXML.Tag plugin=get_plugins()[args->source];
	if(!plugin) RXML.parse_error("Source "+args->source+" not present.\n");
	do_insert(plugin, args->source, id);
	return 0;
      }
      foreach(get_plugins(); string name; RXML.Tag plugin) {
	if(args[name]) {
	  do_insert(plugin, name, id);
	  return 0;
	}
      }

      parse_error("No correct insert attribute given.\n");
    }
  }
}

class TagInsertVariable {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variable";

  string get_data(string var, mapping args, RequestID id, RXML.Frame insert_frame) {
    if(zero_type(RXML.user_get_var(var, args->scope)))
      RXML.run_error("No such variable ("+var+").\n", id);

    if(args->index) {
      mixed data = RXML.user_get_var(var, args->scope);
      if(intp(data) || floatp(data))
	RXML.run_error("Can not index numbers.\n");
      if(stringp(data)) {
	if(args->split)
	  data = data / args->split;
	else
	  data = ({ data });
      }
      if(arrayp(data)) {
	int index = (int)args->index;
	if(index<0) index=sizeof(data)+index+1;
	if(sizeof(data)<index || index<1)
	  RXML.run_error("Index out of range.\n");
	else
	  return data[index-1];
      }
      if(data[args->index]) return data[args->index];
      RXML.run_error("Could not index variable data\n");
    }

    else {
      mixed data = RXML.user_get_var(var, args->scope);
      if (arrayp (data) && insert_frame->result_type->subtype_of (RXML.t_any_text))
	data = map (data, RXML.t_string->encode) * "\0";
      return data;
    }
  }
}

class TagInsertVariables {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variables";

  string|mapping|RXML.Scope get_data (string var, mapping args,
				      RequestID id, RXML.Frame insert_frame)
  {
    RXML.Context context=RXML_CONTEXT;

    string scope = args->scope;
    if (!scope)
      RXML.parse_error ("\"scope\" attribute missing.\n");
    if (!context->exist_scope (scope))
      RXML.parse_error ("No such scope %q.\n", scope);

    if (insert_frame->result_type == RXML.t_string ||
	insert_frame->result_type->subtype_of (RXML.t_any_text) ||
	compat_level < 5.0) {
      if(var=="full")
	return map(sort(context->list_var(scope)),
		   compat_level > 4.5 ?
		   lambda(string s) {
		     mixed value = context->get_var(s, scope);
		     if (!zero_type (value))
		       return sprintf("%s=%O", s, value);
		     return 0;
		   } :
		   lambda(string s) {
		     mixed value = context->get_var(s, scope);
		     if (!zero_type (value))
		       return sprintf("%s=%O", s, value);
		     else
		       // A variable with an undefined value doesn't
		       // exist by definition, even though list_var
		       // might still list it. It should therefore be
		       // ignored, but we keep this compat for
		       // hysterical reasons.
		       return sprintf("%s=UNDEFINED", s);
		   } ) * "\n";

      return String.implode_nicely(sort(context->list_var(scope,
							  compat_level > 4.5)));
    }

    return context->get_scope (scope);
  }

  RXML.Type get_type (mapping args, mixed result, RXML.Frame insert_frame)
  {
    return !stringp (result) && RXML.t_mapping;
  }
}

class TagInsertScopes {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "scopes";

  string get_data(string var, mapping args) {
    RXML.Context context=RXML_CONTEXT;
    if(var=="full") {
      string result = "";
      foreach(sort(context->list_scopes()), string scope) {
	result += scope+"\n";
	// Filter out undefined values if the compat level allows us.
	result += Roxen.html_encode_string(
	  map(sort(context->list_var(args->scope)),
	      compat_level > 4.5 ?
	      lambda(string s) {
		mixed val = context->get_var(s, args->scope);
		if (!zero_type (val))
		  return sprintf("%s.%s=%O", scope, s, val);
		return 0;
	      } :
	      lambda(string s) {
		return sprintf("%s.%s=%O", scope, s,
			       context->get_var(s, args->scope) );
	      } ) * "\n");
	result += "\n";
      }
      return result;
    }
    return String.implode_nicely(sort(context->list_scopes()));
  }
}

class TagInsertLocate {
  inherit RXML.Tag;
  constant name= "insert";
  constant plugin_name = "locate";

  RXML.Type get_type( mapping args )
  {
    if (args->quote=="html")
      return RXML.t_text;
    return RXML.t_xml;
  }

  string get_data(string var, mapping args, RequestID id)
  {
    array(string) result;
    
    result = VFS.find_above_read( id->not_query, var, id );

    if( !result )
      RXML.run_error("Cannot locate any file named "+var+".\n");

    return result[1];
  }  
}

class TagInsertFile {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "file";

  RXML.Type get_type(mapping args) {
    if (args->quote=="html")
      return RXML.t_text;
    return RXML.t_xml;
  }

  string get_data(string var, mapping args, RequestID id)
  {
    string result;
    if(args->nocache) // try_get_file never uses the cache any more.
      CACHE(0);      // Should we really enforce CACHE(0) here?

    // Save current language state, and add the wanted language first
    // in the list.
    array old_lang, old_qualities;
    object pl;
    if (args->language && (pl = id->misc->pref_languages)) {
      old_lang = pl->get_languages();
      old_qualities = pl->get_qualities();
      pl->set_sorted( ({ args->language }) + old_lang );
    }

    mapping(string:mixed) result_mapping = ([]);

    result=id->conf->try_get_file(var, id, UNDEFINED, UNDEFINED, UNDEFINED,
				  result_mapping);

    // Propagate last_modified to parent request...
    if (result_mapping->stat &&
	result_mapping->stat[ST_MTIME] > id->misc->last_modified)
      RXML_CONTEXT->set_id_misc ("last_modified",
				 result_mapping->stat[ST_MTIME]);
    // ... and also in recursive inserts.
    if (result_mapping->last_modified > id->misc->last_modified)
      RXML_CONTEXT->set_id_misc ("last_modified",
				 result_mapping->last_modified);

    // Restore previous language state.
    if (args->language && pl) {
      pl->set_sorted(old_lang, old_qualities);
    }

    if( !result )
      RXML.run_error("No such file ("+Roxen.fix_relative( var, id )+").\n");

    if (args["decode-charset"]) {
      if (result_mapping->charset) {
	Charset.Decoder decoder = Charset.decoder(result_mapping->charset);
	result = decoder->feed(result)->drain();
      }
    }

#if ROXEN_COMPAT <= 1.3
    if(id->conf->old_rxml_compat)
      return Roxen.parse_rxml(result, id);
#endif
    return result;
  }
}

class TagInsertRealfile {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "realfile";

  string get_data(string var, mapping args, RequestID id) {
    string filename=id->conf->real_file(Roxen.fix_relative(var, id), id);
    if(!filename)
      RXML.run_error("Could not find the file %s.\n", Roxen.fix_relative(var, id));
    Stdio.File file=Stdio.File(filename, "r");
    if(file)
      return file->read();
    RXML.run_error("Could not open the file %s.\n", Roxen.fix_relative(var, id));
  }
}

class TagReturn {
  inherit RXML.Tag;
  constant name = "return";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if(args->code)
	RXML_CONTEXT->set_misc (" _error", (int)args->code);
      if(args->text)
	RXML_CONTEXT->set_misc (" _rettext", replace(args->text, "\n\r"/1, "%0A%0D"/3));
      return 0;
    }
  }
}

class TagSetCookie {
  inherit RXML.Tag;
  constant name = "set-cookie";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "name" : RXML.t_text(RXML.PEnt) ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t;
      if(args->persistent) t=-1; else t=Roxen.time_dequantifier(args);
      Roxen.set_cookie( id,  args->name, (args->value||""), t, 
                        args->domain, args->path,
                        args->secure, args->httponly );
      return 0;
    }
  }
}

class TagRemoveCookie {
  inherit RXML.Tag;
  constant name = "remove-cookie";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "name" : RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "value" : RXML.t_text(RXML.PEnt),
    "domain" : RXML.t_text(RXML.PEnt),
    "path" : RXML.t_text(RXML.PEnt),
  ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
#if 0
//    really... is this error a good idea?  I don't think so, it makes
//    it harder to make pages that use cookies. But I'll let it be for now.
//       /Per

      // I agree, but I don't let it be. /mast

      if(!id->cookies[args->name])
	RXML.run_error("That cookie does not exist.\n");
#endif
      Roxen.remove_cookie( id, args->name,
                           (args->value||id->cookies[args->name]||""), 
                           args->domain, args->path );
      return 0;
    }
  }
}

string tag_modified(string tag, mapping m, RequestID id, Stdio.File file)
{

  if(m->by && !m->file && !m->realfile)
    m->file = id->virtfile;
  
  if(m->file)
    m->realfile = id->conf->real_file(Roxen.fix_relative( m_delete(m, "file"), id), id);

  if(m->by && m->realfile)
  {
    if(!sizeof(id->conf->user_databases()))
      RXML.run_error("Modified by requires a user database.\n");

    Stdio.File f;
    if(f = open(m->realfile, "r"))
    {
      m->name = id->conf->last_modified_by(f, id);
      destruct(f);
      CACHE(10);
      return tag_user(tag, m, id);
    }
    return "A. Nonymous.";
  }

  Stat s;
  if(m->realfile)
    s = file_stat(m->realfile);
  else if (_stat)
    s = _stat;
  else
    s =  id->conf->stat_file(id->not_query, id);

  if(s) {
    CACHE(10);
    mixed err = catch {
	if(m->ssi)
	  return Roxen.strftime(id->misc->ssi_timefmt || "%c", s[3]);
	return Roxen.tagtime(s[3], m, id, language);
      };
    // FIXME: Ought to check that it is mktime, localtime or gmtime
    //        that has failed, and otherwise rethrow the error.
    RXML.run_error("Unsupported date.\n");
  }

  if(m->ssi) return id->misc->ssi_errmsg||"";
  RXML.run_error("Couldn't stat file.\n");
}


string|array(string) tag_user(string tag, mapping m, RequestID id)
{
  if (!m->name)
    return "";
  
  User uid, tmp;
  foreach( id->conf->user_databases(), UserDB udb ){
    if( tmp = udb->find_user( m->name ) )
      uid = tmp;
  }
 
  if(!uid)
    return "";
  
  string dom = id->conf->query("Domain");
  if(sizeof(dom) && (dom[-1]=='.'))
    dom = dom[0..strlen(dom)-2];
  
  if(m->realname && !m->email)
  {
    if(m->link && !m->nolink)
      return ({ 
	sprintf("<a href=%s>%s</a>", 
		Roxen.html_encode_tag_value( "/~"+uid->name() ),
		Roxen.html_encode_string( uid->gecos() ))
      });
    
    return ({ Roxen.html_encode_string( uid->gecos() ) });
  }
  
  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return ({ 
	sprintf("<a href=%s>%s</a>",
		Roxen.html_encode_tag_value(sprintf("mailto:%s@%s",
					      uid->name(), dom)), 
		Roxen.html_encode_string(sprintf("%s@%s", uid->name(), dom)))
      });
    return ({ Roxen.html_encode_string(uid->name()+ "@" + dom) });
  } 

  if(m->nolink && !m->link)
    return ({ Roxen.html_encode_string(sprintf("%s <%s@%s>",
					 uid->gecos(), uid->name(), dom))
    });

  return 
    ({ sprintf( (m->nohomepage?"":
		 sprintf("<a href=%s>%s</a>",
			 Roxen.html_encode_tag_value( "/~"+uid->name() ),
			 Roxen.html_encode_string( uid->gecos() ))+
		 sprintf(" <a href=%s>%s</a>",
			 Roxen.html_encode_tag_value(sprintf("mailto:%s@%s", 
						       uid->name(), dom)),
			 Roxen.html_encode_string(sprintf("<%s@%s>", 
						    uid->name(), dom)))))
    });
}


class TagSetMaxCache {
  inherit RXML.Tag;
  constant name = "set-max-cache";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) opt_arg_types = ([
    "force-protocol-cache" : RXML.t_text(RXML.PEnt)
  ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      id->set_max_cache (Roxen.time_dequantifier(args));
      if(args["force-protocol-cache"])
	RXML_CONTEXT->set_id_misc ("no_proto_cache", 0);
    }
  }
}


class TagCharset
{
  inherit RXML.Tag;
  constant name="charset";
  RXML.Type content_type = RXML.t_same;

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      if (string charset = args->in) {
	Charset.Decoder dec;
	if (catch (dec = Charset.decoder (charset)))
	  RXML.parse_error ("Invalid charset %q\n", charset);
	if (mixed err = catch (content = dec->feed (content || "")->drain())) {
	  if (objectp (err) && err->is_charset_decode_error)
	    RXML.run_error (describe_error (err));
	  else
	    throw (err);
	}
      }
      if (args->out && id->set_output_charset) {
	//  Verify that encoder exists since we'll get internal errors
	//  later if it's invalid. (The same test also happens in
	//  id->set_output_charset() but only in debug mode.)
	if (catch { Charset.encoder(args->out); })
	  RXML.parse_error("Invalid charset %q\n", args->out);
	id->set_output_charset( args->out );
      }
      result_type = result_type (RXML.PXml);
      result="";
      return ({content});
    }
  }
}

class TagRecode
{
  inherit RXML.Tag;
  constant name="recode";
  mapping(string:RXML.Type) opt_arg_types = ([
    "from"                   : RXML.t_text(RXML.PEnt),
    "to"                     : RXML.t_text(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      if( !content ) content = "";

      switch(args->from)
      {
	case "safe-utf8":
	  catch (content = utf8_to_string (content));
	  break;

	default:
	  if (string charset = args->from) {
	    if (String.width (content) > 8)
	      // If it's wide it's already decoded by necessity. Some of
	      // the decoders also throw an error on this that isn't
	      // typed as a DecodeError.
	      RXML.run_error ("Cannot charset decode a wide string.\n");
	    Charset.Decoder dec;
	    if (catch (dec = Charset.decoder (charset)))
	      RXML.parse_error ("Invalid charset %q\n", charset);
	    if (mixed err = catch (content = dec->feed (content)->drain())) {
	      if (objectp (err) && err->is_charset_decode_error)
		RXML.run_error (describe_error (err));
	      else
		throw (err);
	    }
	  }
      }
      
      if (args->to) {
	//  User may provide substitution string or numeric entities for
	//  characters that don't fit in the requested encoding.
	int use_entity_fallback =
	  lower_case(args["entity-fallback"] || "no") != "no";
	string str_fallback = args["string-fallback"];
	Charset.Encoder enc;
	if (catch (enc = Charset.encoder (args->to, str_fallback,
						 use_entity_fallback &&
						 lambda(string ch) {
						   return "&#" + ch[0] + ";";
						 })))
	  RXML.parse_error ("Invalid charset %q\n", args->to);
	if (mixed err = catch (content = enc->feed (content)->drain())) {
	  if (objectp (err) && err->is_charset_encode_error)
	    RXML.run_error (describe_error (err));
	  else
	    throw (err);
	}
      }
      
      return ({ content });
    }
  }
}

class TagScope {
  inherit RXML.Tag;

  constant name = "scope";
  mapping(string:RXML.Type) opt_arg_types = ([ "extend" : RXML.t_text(RXML.PEnt) ]);
  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame {
    inherit RXML.Frame;

    string scope_name;
    mapping|object vars;
    mapping oldvar;

    array do_enter(RequestID id) {
      scope_name = args->scope || args->extend || "form";
      // FIXME: Should probably work like this, but it's anything but
      // simple to do that now, since variables is a class that simply
      // fakes the old variable structure using real_variables
// #if ROXEN_COMPAT <= 1.3
//       if(scope_name=="form") oldvar=id->variables;
// #endif
      if (string extend_scope = args->extend) {
	mapping|object old = RXML_CONTEXT->get_scope (extend_scope);
	if (!old) run_error ("There is no scope %O.\n", extend_scope);
	vars=copy_value(old);
      }
      else
	vars=([]);
// #if ROXEN_COMPAT <= 1.3
//       if(oldvar) id->variables=vars;
// #endif
      return 0;
    }

    array do_return(RequestID id) {
// #if ROXEN_COMPAT <= 1.3
//       if(oldvar) id->variables=oldvar;
// #endif
      result=content;
      return 0;
    }
  }
}

array(string) container_catch( string tag, mapping m, string c, RequestID id )
{
  string r;
  mixed e = catch(r=Roxen.parse_rxml(c, id));
  if(e && objectp(e) && e->tag_throw) return ({ e->tag_throw });
  if(e) throw(e);
  return ({r});
}

//  Caches may request synchronization on a shared mutex to serialize
//  expensive computations. It's flagged as weak so only locked mutexes
//  are retained.
mapping(string:Thread.Mutex) cache_mutexes =
  set_weak_flag( ([ ]), Pike.WEAK_VALUES);
mapping(string:int) cache_mutex_concurrency = ([ ]);

class CacheTagEntry (mixed data)
{
  int cache_count_memory (int|mapping opts)
  {
    array(mixed) things;

    if (arrayp (data)) {
      things = ({ data });
      foreach (data, mixed thing) {
	if (objectp (data) && data->is_RXML_PCode)
	  things += data->collect_things_recur();
	else
	  things += ({ thing });
      }
    } else if (objectp (data) && data->is_RXML_PCode) {
      things = data->collect_things_recur();
    } else {
      werror ("CacheTagEntry: Unknown data %O.\n", data);
      return 0;
    }

    // Note 100k entry stack limit (use 99k as an upper safety
    // limit). Could split into multiple calls if necessary.
    return Pike.count_memory (opts + ([ "lookahead": 5 ]), @things[..99000]);
  }
}

class TagCache {
  inherit RXML.Tag;
  constant name = "cache";
  constant flags = (RXML.FLAG_GET_RAW_CONTENT |
		    RXML.FLAG_GET_EVALED_CONTENT |
		    RXML.FLAG_DONT_CACHE_RESULT |
		    RXML.FLAG_CUSTOM_TRACE);
  constant cache_tag_eval_loc = "RXML <cache> eval";
  constant cache_tag_alts_loc = "RXML <cache> alternatives";
  array(RXML.Type) result_types = ({RXML.t_any});

  mixed cache_set (string cache_name, mixed key, mixed data, void|int timeout,
		   void|mapping|int(1..1) cache_context)
  {
    CacheTagEntry entry
      = cache.cache_set (cache_name, key, CacheTagEntry (data), timeout,
			 cache_context);
    return entry && entry->data;
  }

  mixed cache_lookup (string cache_name, mixed key, void|mapping cache_context)
  {
    CacheTagEntry entry = cache.cache_lookup (cache_name, key, cache_context);
    return entry && entry->data;
  }

  mixed cache_peek (string cache_name, mixed key)
  {
    CacheTagEntry entry = cache.cache_peek (cache_name, key);
    return entry && entry->data;
  }

  void cache_remove (string cache_name, mixed key)
  {
    cache.cache_remove (cache_name, key);
  }

  class Frame {
    inherit RXML.Frame;

    int do_iterate;
    mapping(string|int:mixed) keymap, overridden_keymap;
    string key, key_level2;
    array(string) level2_keys;
    RXML.PCode evaled_content;
    int timeout, persistent_cache;

    //  Mutex state to restrict concurrent generation of same cache entry.
    //  This is enabled only if RXML code specifies a "mutex" attribute.
    //  We store the mutex in a module-global table (with weak values)
    //  indexed on the user-provided name together with the keymap; locking
    //  the mutex will maintain a reference. Extra book-keeping is needed
    //  to clean up mutexes after concurrent access completes.
    Thread.MutexKey mutex_key;
    string mutex_id;

    // The following are retained for frame reuse.

    string cache_id;
    // This is set whenever the cache is stored in the roxen RAM cache
    // and we need to identify it from the frame. That means two
    // cases: One is for shared caches, the other is when the cache is
    // stored in RAM but the frame itself might get destructed and
    // reinstated later from encoded p-code.
    //
    // It's not necessary when both the cache and the frame remains in
    // RAM. In that case we keep the cache in the variable
    // alternatives.

    array(string|int) subvariables;
    multiset(string) alternatives;

    string get_full_key (string key)
    {
      if (!cache_id) cache_id = roxen.new_uuid_string();
      return cache_id + key;
    }

    RXML.PCode|array(int|RXML.PCode) get_alternative (string key)
    {
      return cache_lookup (cache_tag_alts_loc, get_full_key (key));
    }

    RXML.PCode|array(int|RXML.PCode) peek_alternative (string key)
    {
      return cache_peek (cache_tag_alts_loc, get_full_key (key));
    }

    void set_alternative (string key, RXML.PCode|array(int|RXML.PCode) entry,
			  void|int timeout, void|int no_lookup)
    {
      if (!timeout && arrayp (entry))
	timeout = entry[0] - time();
      else if (timeout) {
	if (arrayp (entry))
	  entry[0] = timeout + time();
	else
	  entry = ({ timeout + time(), entry, 0 });
      }

      // A negative timeout means that the entry has already expired.
      if (timeout >= 0) {
	string full_key = get_full_key (key);
	cache_set (cache_tag_alts_loc, full_key, entry, timeout, no_lookup);
	if (!alternatives) alternatives = (<>);
	alternatives[key] = 1;
      }
    }

    void remove_alternative (string key)
    {
      string full_key = get_full_key (key);
      cache_remove (cache_tag_alts_loc, full_key);
      if (alternatives)
	alternatives[key] = 0;
    }

    protected constant rxml_empty_replacement = (<"eMp ty__">);

    // Got ugly special cases below to avoid getting RXML.empty into
    // the keymap since that doesn't work with encode_value_canonic
    // (ought to have a canonic_nameof callback in the codec). This
    // should cover most cases with object values, at least (e.g.
    // RXML.nil should never occur by definition).
#define ADD_VARIABLE_TO_KEYMAP(ctx, var, is_level2) do {		\
      array splitted = ctx->parse_user_var (var, 1);			\
      if (intp (splitted[0])) { /* Depend on the whole scope. */	\
	mapping|RXML.Scope scope = ctx->get_scope (var);		\
	array ind, val;							\
	if (mappingp (scope)) {						\
	  ind = indices (scope);					\
	  val = values (scope);						\
	}								\
	else if (scope) {						\
	  ind = scope->_indices (ctx, var);				\
	  val = rows (scope, ind);					\
	}								\
	else								\
	  parse_error ("Unknown scope %O.\n", var);			\
	val = replace (val, RXML.empty, rxml_empty_replacement);	\
	keymap[var] = mkmapping (ind, val);				\
      }									\
      else {								\
	mixed val = ctx->get_var (splitted[1..], splitted[0]);		\
	if (!zero_type (val))						\
	  keymap[var] = (val == RXML.empty ? rxml_empty_replacement : val); \
      }									\
      if (is_level2) {							\
	if (!level2_keys)						\
	  level2_keys = ({ });						\
	level2_keys += ({ var });					\
      }									\
    } while (0)

    protected void add_subvariables_to_keymap()
    {
      RXML.Context ctx = RXML_CONTEXT;
      foreach (subvariables, string var)
	// Note: Shouldn't get an invalid variable spec here.
	ADD_VARIABLE_TO_KEYMAP (ctx, var, 0);
    }

    protected void make_key_from_keymap (RequestID id, int timeout)
    {
      // Protocol/client caching is disabled if there are keys except
      // '1' and page.path, i.e. when different cache entries might be
      // chosen for the same page.
      //
      // We could consider doing this for the cookie scope too since
      // the protocol cache now tracks cookie dependencies through the
      // CookieJar. However, modifying it has compat implications with
      // overcaching that could be difficult to track down, and it's
      // possible that the protocol cache will be tunable in the
      // future in this regard. So it appears better to just leave
      // this as fixed behavior and let the user do other things
      // explicitly.

      int ignored = 0;
      if (keymap[1]) ignored++;
      if (keymap["page.path"]) ignored++;

      if (sizeof (keymap) != ignored) {
	if (args["enable-protocol-cache"])
	  ;
	else {
	  NO_PROTO_CACHE();
	  if (!args["enable-client-cache"])
	    NOCACHE();
	}
      }
      else if (timeout)
	id->lower_max_cache (timeout);

      //  For two-level keys the level 1 variables are placed in "key" and
      //  the level 2 variables in "key_level2". There is no overlap since
      //  we'll compare both during lookup.
      if (level2_keys) {
	key = encode_value_canonic(keymap - level2_keys);
	key_level2 = encode_value_canonic(keymap & level2_keys);
      } else {
	key = encode_value_canonic (keymap);
	key_level2 = 0;
      }
      if (!args["disable-key-hash"]) {
	// Initialize with a 32 char string to make sure MD5 goes
	// through all the rounds even if the key is very short.
	// Otherwise the risk for coincidental equal keys gets much
	// bigger.
	key =
	  Crypto.MD5()->update ("................................")
		       ->update (key)
		       ->digest();
	if (key_level2) {
	  key_level2 =
	    Crypto.MD5()->update ("................................")
		        ->update (key_level2)
		        ->digest();
	}
      }
    }

    array do_enter (RequestID id)
    {
      if( args->nocache || args["not-post-method"] && id->method == "POST" ) {
	do_iterate = 1;
	key = 0;
	key_level2 = 0;
	TAG_TRACE_ENTER ("no cache due to %s",
			 args->nocache ? "nocache argument" : "POST method");
	id->cache_status->cachetag = 0;
	id->misc->cache_tag_miss = 1;
	return 0;
      }

      RXML.Context ctx = RXML_CONTEXT;
      int default_key = compat_level < 2.2;

      overridden_keymap = 0;
      if (!args->propagate ||
	  (!(keymap = ctx->misc->cache_key) &&
	   (m_delete (args, "propagate"), 1))) {
	overridden_keymap = ctx->misc->cache_key;
	keymap = ctx->misc->cache_key = ([]);
      }

      if (string var_list = args->variable) {
	if (var_list != "") {
	  var_list = replace(String.normalize_space(var_list), " ", "");
	  foreach (var_list / ",", string var)
	    ADD_VARIABLE_TO_KEYMAP (ctx, var, 0);
	}
	default_key = 0;
      }
      
      if (string uniq_var_list = args["generation-variable"]) {
	if (uniq_var_list != "") {
	  uniq_var_list =
	    replace(String.normalize_space(uniq_var_list), " ", "");
	  foreach (uniq_var_list / ",", string uniq_var)
	    ADD_VARIABLE_TO_KEYMAP (ctx, uniq_var, 1);
	}
	default_key = 0;
      }
      
      if (args->profile) {
	if (mapping avail_profiles = id->misc->rxml_cache_cur_profile)
	  foreach (args->profile / ",", string profile) {
	    profile = String.trim_all_whites (profile);
	    mixed profile_val = avail_profiles[profile];
	    if (zero_type (profile_val))
	      parse_error ("Unknown cache profile %O.\n", profile);
	    keymap[" " + profile] = profile_val;
	  }
	else
      	  parse_error ("There are no cache profiles.\n");
	default_key = 0;
      }

      if (args->propagate) {
	if (args->key)
	  parse_error ("Argument \"key\" cannot be used together with \"propagate\".");
	// Updated the key, so we're done. The enclosing cache tag
	// should do the caching.
	do_iterate = 1;
	TAG_TRACE_ENTER ("propagating key, is now %s",
			 RXML.utils.format_short (keymap, 200));
	key = key_level2 = keymap = 0;
	flags &= ~RXML.FLAG_DONT_CACHE_RESULT;
	return 0;
      }

      if(args->key) keymap[0] += ({args->key});

      if (default_key) {
	// Include the form variables and the page path by default.
	keymap->form = id->real_variables + ([]);
	keymap["page.path"] = id->not_query;
      }

      if (subvariables) add_subvariables_to_keymap();

      timeout = Roxen.time_dequantifier (args);

#ifdef RXML_CACHE_TIMEOUT_IMPLIES_SHARED
      if(timeout)
	args->shared="yes";
#endif

      if (args->shared) {
	if(args->nohash)
	  // Always use the configuration in the key; noone really
	  // wants cache tainting between servers.
	  keymap[1] = id->conf->name;
	else {
	  if (!cache_id) {
	    // Include the content type in the hash since we cache the
	    // p-code which has static type inference.
	    if (!content) content = "";
	    if (String.width (content) != 8) content = encode_value_canonic (content);
	    cache_id = Crypto.MD5()->update ("................................")
				   ->update (content)
				   ->update (content_type->name)
				   ->digest();
	  }
	  keymap[1] = ({id->conf->name, cache_id});
	}
      }

      make_key_from_keymap (id, timeout);

      // Now we have the cache key.
      int removed;
      object(RXML.PCode)|array(int|RXML.PCode|string) entry;
      int retry_lookup;
      
      do {
	retry_lookup = 0;
	entry = args->shared ?
	  cache_lookup (cache_tag_eval_loc, key) :
	  get_alternative (key);
	removed = 0; // 0: not removed, 1: stale, 2: timeout, 3: pragma no-cache
	
      got_entry:
	if (entry) {
	check_entry_valid: {
	    if (arrayp (entry)) {
	      //  If this represents a two-level entry the second key must
	      //  match as well for the entry to be considered a hit. A miss
	      //  in that comparison is however not necessarily a sign that
	      //  the entry is stale so we treat it as a regular miss.
	      //
	      //  Finding an entry with a two-level keymap when none was
	      //  requested means whatever entry we got satisfies the
	      //  lookup.
	      if (key_level2 && (sizeof(entry) > 2) &&
		  (entry[2] != key_level2)) {
		entry = 0;
		break got_entry;
	      }
	      
	      if (entry[0] && (entry[0] < time (1))) {
		removed = 2;
		break check_entry_valid;
	      }
	      
	      evaled_content = entry[1];
	    } else {
	      if (key_level2) {
		//  Inconsistent use of cache variables since at least one
		//  generation variable was expected but none found. We'll
		//  consider it a miss and regenerate the entry so it gets
		//  stored with a proper two-level keymap.
		entry = 0;
		break got_entry;
	      }
	      
	      evaled_content = entry;
	    }
	    if (evaled_content->is_stale())
	      removed = 1;
	    else if (id->pragma["no-cache"] && args["flush-on-no-cache"])
	      removed = 3;
	  }
	  
	  if (removed) {
	    if (args->shared)
	      cache_remove (cache_tag_eval_loc, key);
	    else
	      remove_alternative (key);
	  }
	  
	  else {
	    do_iterate = -1;
	    TAG_TRACE_ENTER ("cache hit%s for key %s",
			     args->shared ?
			     (timeout ?
			      " (shared " + timeout + "s timeout cache)" :
			      " (shared cache)") :
			     (timeout ? " (" + timeout + "s timeout cache)" : ""),
			     RXML.utils.format_short (keymap, 200));
	    key = key_level2 = keymap = 0;
	    if (mutex_key) {
	      destruct(mutex_key);
	      
	      //  vvv Relying on interpreter lock
	      if (!--cache_mutex_concurrency[mutex_id])
		m_delete(cache_mutexes, mutex_id);
	      //  ^^^ and here vvv
	      if (!cache_mutex_concurrency[mutex_id])
		m_delete(cache_mutex_concurrency, mutex_id);
	      //  ^^^
	    }
	    return ({evaled_content});
	  }
	}
	
	//  Check for mutex synchronization during shared entry generation
	if (!mutex_key && args->shared) {
	  if (args->mutex) {
	    //  We use the serialized keymap as the mutex ID so that
	    //  generation of unrelated entries in the same cache won't
	    //  block each other. Note that cache_id is already incorporated
	    //  into key.
	    mutex_id = key;
	    
	    //  Signal that we're about to enter mutex handling. This will
	    //  prevent any other thread from deallocating the same mutex
	    //  prematurely.
	    //
	    //  vvv Relying on interpreter lock
	    cache_mutex_concurrency[mutex_id]++;
	    //  ^^^
	    
	    //  Find existing mutex or allocate a new one
	    Thread.Mutex mtx = cache_mutexes[mutex_id];
	  lock_mutex:
	    {
	      if (!mtx) {
		//  Prepare a new mutex and lock it before registering it so
		//  the weak mapping will retain it. We'll swap in the mutex
		//  atomically to avoid a race, and if we lose the race we
		//  can discard it and continue with the old one.
		Thread.Mutex new_mtx = Thread.Mutex();
		Thread.MutexKey new_key = new_mtx->lock();
		
		//  vvv Relying on interpreter lock here
		if (!(mtx = cache_mutexes[mutex_id])) {
		  //  We're first so store our new mutex
		  cache_mutexes[mutex_id] = new_mtx;
		  //  ^^^
		  mutex_key = new_key;
		  break lock_mutex;
		} else {
		  //  Someone created it first so dispose of our prepared mutex
		  //  and carry on with the existing one.
		  destruct(new_key);
		  new_mtx = 0;
		}
	      }
	      mutex_key = mtx->lock();
	    }

	    id->add_threadbound_session_object (mutex_key);
	    
	    retry_lookup = 1;
	  }
	}
      } while (retry_lookup);

      keymap += ([]);
      do_iterate = 1;
      persistent_cache = 0;
      TAG_TRACE_ENTER ("cache miss%s for key %s, %s",
		       args->shared ?
		       (timeout ?
			" (shared " + timeout + "s timeout cache)" :
			" (shared cache)") :
		       (timeout ? " (" + timeout + "s timeout cache)" : ""),
		       RXML.utils.format_short (keymap, 200),
		       removed == 1 ? "entry p-code is stale" :
		       removed == 2 ? "entry had timed out" :
		       removed == 3 ? "a pragma no-cache request removed the entry" :
		       "no matching entry");
      id->cache_status->cachetag = 0;
      id->misc->cache_tag_miss = 1;
      return 0;
    }

    array do_return (RequestID id)
    {
      if (key) {
	int key_updated;
	mapping(string|int:mixed) subkeymap = RXML_CONTEXT->misc->cache_key;
	if (sizeof (subkeymap) > sizeof (keymap)) {
	  // The test above assumes that no subtag removes entries in
	  // RXML_CONTEXT->misc->cache_key.
	  subvariables = filter (indices (subkeymap - keymap), stringp);
	  // subvariables is part of the persistent state, but we'll
	  // come to state_update later anyway if it should be called.
	  add_subvariables_to_keymap();
	  make_key_from_keymap (id, timeout);
	  key_updated = 1;
	}

	if (args->shared) {
	  if (object/*(RXML.PikeCompile)*/ comp = evaled_content->p_code_comp) {
	    // Don't cache the PikeCompile objects.
	    comp->compile();
	    evaled_content->p_code_comp = 0;
	  }
	  
	  object(RXML.PCode)|array(int|RXML.PCode|string) new_entry =
	    level2_keys ?
	    ({ 0, evaled_content, key_level2 }) :
	    evaled_content;
	  cache_set (cache_tag_eval_loc, key, new_entry, timeout);
	  TAG_TRACE_LEAVE ("added shared%s cache entry with key %s",
			   timeout ? " timeout" : "",
			   RXML.utils.format_short (keymap, 200));
	}

	else {
	  if (object/*(RXML.PikeCompile)*/ comp = evaled_content->p_code_comp)
	    comp->compile();
	  if (timeout) {
	    if (args["persistent-cache"] == "yes") {
	      persistent_cache = 1;
	      RXML_CONTEXT->state_update();
	    }
	    set_alternative (key,
			     ({ time() + timeout, evaled_content, key_level2 }),
			     timeout,
			     key_updated);
	    TAG_TRACE_LEAVE ("added%s %ds timeout cache entry with key %s",
			     persistent_cache ? " (possibly persistent)" : "",
			     timeout,
			     RXML.utils.format_short (keymap, 200));
	  }

	  else {
	    set_alternative (key,
			     key_level2 ?
			     ({ 0, evaled_content, key_level2 }) :
			     evaled_content,
			     UNDEFINED,
			     key_updated);

	    if (args["persistent-cache"] != "no") {
	      persistent_cache = 1;
	      RXML_CONTEXT->state_update();
	    }
	    TAG_TRACE_LEAVE ("added%s cache entry with key %s",
			     persistent_cache ? " (possibly persistent)" : "",
			     RXML.utils.format_short (keymap, 200));
	  }
	}
      }
      else
	TAG_TRACE_LEAVE ("");

      if (overridden_keymap) {
	RXML_CONTEXT->misc->cache_key = overridden_keymap;
	overridden_keymap = 0;
      }

      result += content;
      if (mutex_key) {
	destruct(mutex_key);
	
	//  Decrease parallel count for shared mutex. If we reach zero we
	//  know no other thread depends on the same mutex so drop it from
	//  global table.
	//
	//  vvv Relying on interpreter lock
	if (!--cache_mutex_concurrency[mutex_id])
	  m_delete(cache_mutexes, mutex_id);
	//  ^^^ and here vvv
	if (!cache_mutex_concurrency[mutex_id])
	  m_delete(cache_mutex_concurrency, mutex_id);
	//  ^^^
      }
      return 0;
    }

    array save()
    {
      mapping(string:RXML.PCode|array(int|RXML.PCode)) persistent_alts;
      if (alternatives) {
	if (persistent_cache) {
	  persistent_alts = ([]);
	  // Get the entries so we can store them persistently.
	  foreach (alternatives; string key;) {
	    object(RXML.PCode)|array(int|RXML.PCode) entry =
	      peek_alternative (key);
	    if (entry) {
	      persistent_alts[key] = entry;
	    }
	  }
	}
      }

      return ({cache_id, subvariables, persistent_cache, persistent_alts });
    }

    void restore (array saved)
    {
      mapping(string:RXML.PCode|array(int|RXML.PCode)) persistent_alts;
      [cache_id, subvariables, persistent_cache, persistent_alts] = saved;

      if (persistent_alts) {
	foreach (persistent_alts; string key; object|array entry) {
	  int timeout;
	  if (arrayp (entry) && entry[0]) {
	    timeout = entry[0] - time();
	    if (timeout <= 0)
	      continue;
	  }

	  // Put the persistently stored entries back into the RAM
	  // cache. They might get expired over time (and hence won't
	  // be encoded persistently if we're saved again), but then
	  // they probably weren't that hot anyways. This method makes
	  // sure we have control over memory usage.

	  // FIXME: Ugly hack to get a low cost (since it's
	  // reinstantiated from a persistent entry). Would be better
	  // to save the original creation cost of the entry to reuse
	  // here, but Roxen's cache doesn't have API's to get or set
	  // entry cost currently.
	  get_alternative (key);
	  set_alternative (key, entry, timeout);
	}
      }
    }

    void exec_array_state_update()
    {
      RXML_CONTEXT->state_update();
    }

    void destroy()
    {
      // If our entries are stored persistently and the frame is
      // destructed we can free some memory in the RAM cache. The
      // entries will be restored from persistent storage by the
      // restore() function above, when the frame is reinstantiated.
      if (persistent_cache && alternatives) {
	foreach (alternatives; string key;) {
	  cache_remove (cache_tag_alts_loc, key);
	}
      }
    }
  }

  protected void create()
  {
    cache.cache_register (cache_tag_eval_loc);
    cache.cache_register (cache_tag_alts_loc);
  }
}

class TagNocache
{
  inherit RXML.Tag;
  constant name = "nocache";
  constant flags = RXML.FLAG_DONT_CACHE_RESULT;
  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame
  {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (args["enable-protocol-cache"])
	;
      else {
	NO_PROTO_CACHE();
	if (!args["enable-client-cache"])
	  NOCACHE();
      }
      return 0;
    }
  }
}

class TagCrypt {
  inherit RXML.Tag;
  constant name = "crypt";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->compare) {
	_ok = verify_password(content,args->compare);
	return 0;
      }
      result = crypt_password(content);
      return 0;
    }
  }
}

class TagHashHMAC
{
  inherit RXML.Tag;
  constant name = "hash-hmac";

  mapping(string:RXML.Type) req_arg_types = ([
    "hash"     : RXML.t_string(RXML.PEnt),
    "password" : RXML.t_string(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;
    void do_return(RequestID id) {
      string password = args->password;
      args->password = "";
      object hash;
      hash = Crypto[upper_case(args->hash)] || Crypto[lower_case(args->hash)];
      if (!hash)
	RXML.parse_error ("Unknown hash algorithm %O.", args->hash);

      result = String.string2hex(Crypto.HMAC(hash)(password)(content));
    }
  }
}

class TagFor {
  inherit RXML.Tag;
  constant name = "for";
  int flags = cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame {
    inherit RXML.Frame;

    private int from,to,step,count;

    array do_enter(RequestID id) {
      from = (int)args->from;
      to = (int)args->to;
      step = (int)args->step!=0?(int)args->step:(to<from?-1:1);
      if((to<from && step>0)||(to>from && step<0)) {
#if 0
	// It's common that the limits are at the wrong side of each
	// other when no iteration should be done, so don't complain
	// about this.
	run_error("Step has the wrong sign.\n");
#endif
      }
      else
	from-=step;
      count=from;
      return 0;
    }

    int do_iterate() {
      if(!args->variable) {
	int diff = (to - from) / step;
	to=from;
	return diff > 0 && diff;
      }
      count+=step;
      RXML.user_set_var(args->variable, count, args->scope);
      if (step < 0) return count>=to;
      return count<=to;
    }

    array do_return(RequestID id) {
      if(args->variable) RXML.user_set_var(args->variable, count-step, args->scope);
      result=content;
      return 0;
    }
  }
}

string simpletag_apre(string tag, mapping m, string q, RequestID id)
{
  string href;

  if(m->href) {
    href=m_delete(m, "href");
    array(string) split = href/":";
    if ((sizeof(split) > 1) && (sizeof(split[0]/"/") == 1))
      return RXML.t_xml->format_tag("a", m, q);
    href=Roxen.strip_prestate(Roxen.fix_relative(href, id));
  }
  else
    href=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));

  if(!strlen(href))
    href="";

  multiset prestate = (< @indices(id->prestate) >);

  // FIXME: add and drop should handle t_array
  if(m->add)
    foreach((m_delete(m, "add") - " ")/",", string s)
      prestate[s]=1;

  if(m->drop)
    foreach((m_delete(m,"drop") - " ")/",", string s)
      prestate[s]=0;

  m->href = Roxen.add_pre_state(href, prestate);
  return RXML.t_xml->format_tag("a", m, q);
}

string simpletag_aconf(string tag, mapping m,
		       string q, RequestID id)
{
  string href;

  if(m->href) {
    href=m_delete(m, "href");
    if (search(href, ":") == search(href, "//")-1)
      RXML.parse_error("It is not possible to add configs to absolute URLs.\n");
    href=Roxen.fix_relative(href, id);    
  }
  else
    href=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));

  array cookies = ({});
  // FIXME: add and drop should handle t_array
  if(m->add)
    foreach((m_delete(m,"add") - " ")/",", string s)
      cookies+=({s});

  if(m->drop)
    foreach((m_delete(m,"drop") - " ")/",", string s)
      cookies+=({"-"+s});

  m->href = Roxen.add_config(href, cookies, id->prestate);
  return RXML.t_xml->format_tag("a", m, q);
}

class TagMaketag {
  inherit RXML.Tag;
  constant name = "maketag";
  mapping(string:RXML.Type) req_arg_types = ([ "type" : RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "noxml" : RXML.t_text(RXML.PEnt),
					       "name" : RXML.t_text(RXML.PEnt) ]);

  class TagAttrib {
    inherit RXML.Tag;
    constant name = "attrib";
    mapping(string:RXML.Type) req_arg_types = ([ "name" : RXML.t_text(RXML.PEnt) ]);

    class Frame {
      inherit RXML.Frame;
      TagMaketag.Frame parent_frame;

      array do_return(RequestID id) {
	parent_frame->makeargs[args->name] = content || "";
	return 0;
      }
    }
  }

  RXML.TagSet internal =
    RXML.shared_tag_set (global::this, "maketag", ({ TagAttrib() }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;
    mapping(string:mixed) makeargs;

    array do_enter (RequestID id)
    {
      makeargs = ([]);
    }

    array do_return(RequestID id) {
      if (!content) content = "";
      switch(args->type) {
      case "pi":
	if(!args->name) parse_error("Type 'pi' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, 0, content, RXML.FLAG_PROC_INSTR);
	break;
      case "container":
	if(!args->name) parse_error("Type 'container' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, makeargs, content, RXML.FLAG_RAW_ARGS);
	break;
      case "tag":
	if(!args->name) parse_error("Type 'tag' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, makeargs, 0,
					(args->noxml?RXML.FLAG_COMPAT_PARSE:0)|
					RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_RAW_ARGS);
	break;
      case "comment":
	result = "<!--" + replace (replace (content, "--", "- -"), "--", "- -") + "-->";
	break;
      case "cdata":
	result = "<![CDATA[" + content/"]]>"*"]]]]><![CDATA[>" + "]]>";
	break;
      }
      return 0;
    }
  }
}

class TagDoc {
  inherit RXML.Tag;
  constant name="doc";
  RXML.Type content_type = RXML.t_same;

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if(args->preparse) content_type = result_type(RXML.PXml);
      return 0;
    }

    array do_return(RequestID id) {
      array from;
      if(args->quote) {
	m_delete(args, "quote");
	from=({ "<", ">", "&" });
      }
      else
	from=({ "{", "}", "&" });

      result=replace(content, from, ({ "&lt;", "&gt;", "&amp;"}) );

      if(args->pre) {
	m_delete(args, "pre");
	result="\n"+RXML.t_xml->format_tag("pre", args, result)+"\n";
      }

      return 0;
    }
  }
}

class TagAutoformat {
  inherit RXML.Tag;

  constant name  = "autoformat";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string s=content || "";
      s-="\r";

      if (s == "") return ({""});

      if(!args->nonbsp)
	{
	  s = replace(s, "\n ", "\n&nbsp;"); // "|\n |"      => "|\n&nbsp;|"
	  s = replace(s, "  ", "&nbsp; ");  //  "|   |"      => "|&nbsp;  |"
	  s = replace(s, "  ", " &nbsp;"); //   "|&nbsp;  |" => "|&nbsp; &nbsp;|"
	}

      string dbl_nl;

      if(!args->nobr) {
	s = replace(s, "\n", "<br />\n");
	dbl_nl = "<br />\n<br />\n";
      }
      else
	dbl_nl = "\n\n";

      if(args->p) {
	s = replace (s, dbl_nl, "\n<p>\n");

	// Now fix balanced <p> tags.

	string ptag = args["class"]?"<p class=\""+args["class"]+"\"":"<p";
	int got_toplevel_data = 0;
	Parser.HTML p = Roxen.get_xml_parser();

	p->add_container (
	  "p", lambda (Parser.HTML p, mapping a, string c)
	       {
		 string ender = got_toplevel_data ? "</p>" : "";
		 got_toplevel_data = 0;
		 return ({ender,
			  ptag, Roxen.make_tag_attributes (a),
			  c == "" ? " />" : ">" + c + "</p>"});
	       });

	p->_set_data_callback (
	  lambda (Parser.HTML p, string c) {
	    if (!got_toplevel_data && sscanf (c, "%*[ \t\n]%*c") == 2) {
	      got_toplevel_data = 1;
	      return ({ptag, ">", c});
	    }
	    return ({c});
	  });

	s = p->finish (s)->read();
	p = 0;			// Avoid trampoline garbage.
	if (got_toplevel_data)
	  s += "</p>";
      }

      return ({ s });
    }
  }
}

class Smallcapsstr (string bigtag, string smalltag,
		    mapping bigarg, mapping smallarg)
{
  constant UNDEF=0, BIG=1, SMALL=2;
  protected string text="",part="";
  protected int last=UNDEF;

  string _sprintf() {
    return "Smallcapsstr("+bigtag+","+smalltag+")";
  }

  void add(string char) {
    part+=char;
  }

  void add_big(string char) {
    if(last!=BIG) flush_part();
    part+=char;
    last=BIG;
  }

  void add_small(string char) {
    if(last!=SMALL) flush_part();
    part+=char;
    last=SMALL;
  }

  void write(string txt) {
    if(last!=UNDEF) flush_part();
    part+=txt;
  }

  void flush_part() {
    switch(last){
    case UNDEF:
    default:
      text+=part;
      break;
    case BIG:
      text+=RXML.t_xml->format_tag(bigtag, bigarg, part);
      break;
    case SMALL:
      text+=RXML.t_xml->format_tag(smalltag, smallarg, part);
      break;
    }
    part="";
    last=UNDEF;
  }

  string value() {
    if(last!=UNDEF) flush_part();
    return text;
  }
}

string simpletag_smallcaps(string t, mapping m, string s)
{
  Smallcapsstr ret;
  string spc=m->space?"&nbsp;":"";
  m_delete(m, "space");
  mapping bm=([]), sm=([]);
  if(m["class"] || m->bigclass) {
    bm=(["class":(m->bigclass||m["class"])]);
    m_delete(m, "bigclass");
  }
  if(m["class"] || m->smallclass) {
    sm=(["class":(m->smallclass||m["class"])]);
    m_delete(m, "smallclass");
  }

  if(m->size) {
    bm+=(["size":m->size]);
    if(m->size[0]=='+' && (int)m->size>1)
      sm+=(["size":m->small||"+"+((int)m->size-1)]);
    else
      sm+=(["size":m->small||(string)((int)m->size-1)]);
    m_delete(m, "small");
    ret=Smallcapsstr("font","font", m+bm, m+sm);
  }
  else
    ret=Smallcapsstr("big","small", m+bm, m+sm);

  for(int i=0; i<strlen(s); i++)
    if(s[i]=='<') {
      int j;
      for(j=i; j<strlen(s) && s[j]!='>'; j++);
      ret->write(s[i..j]);
      i+=j-1;
    }
    else if(s[i]<=32)
      ret->add_small(s[i..i]);
    else if(lower_case(s[i..i])==s[i..i])
      ret->add_small(upper_case(s[i..i])+spc);
    else if(upper_case(s[i..i])==s[i..i])
      ret->add_big(s[i..i]+spc);
    else
      ret->add(s[i..i]+spc);

  return ret->value();
}

string simpletag_random(string tag, mapping m, string s, RequestID id)
{
  NOCACHE();
  if(m->range)
    return (string)random((int)m->range);
  array q = s/(m->separator || m->sep || "\n");
  int index;
  if(m->seed)
    index = array_sscanf(Crypto.MD5.hash(m->seed),
			 "%4c")[0]%sizeof(q);
  else
    index = random(sizeof(q));

  return q[index];
}

class TagGauge {
  inherit RXML.Tag;
  constant name = "gauge";

  class Frame {
    inherit RXML.Frame;
    int t;

    array do_enter(RequestID id) {
      NOCACHE();
      t=gethrtime();
    }

    array do_return(RequestID id) {
      t=gethrtime()-t;
      if(args->variable) RXML.user_set_var(args->variable, t/1000000.0, args->scope);
      if(args->silent) return ({ "" });
      if(args->timeonly) return ({ sprintf("%3.6f", t/1000000.0) });
      if(args->resultonly) return ({content});
      return ({ "<br /><font size=\"-1\"><b>Time: "+
		sprintf("%3.6f", t/1000000.0)+
		" seconds</b></font><br />"+content });
    }
  }
}

// Removes empty lines
string simpletag_trimlines( string tag_name, mapping args,
                           string contents, RequestID id )
{
  contents = replace(contents, ({"\r\n","\r" }), ({"\n","\n"}));
  return (contents / "\n" - ({ "" })) * "\n";
}

void container_throw( string t, mapping m, string c, RequestID id)
{
  if(c[-1]!='\n') c+="\n";
  throw( class(string tag_throw) {}( c ) );
}

// Internal methods for the default tag
private int|array internal_tag_input(string t, mapping m, string name, multiset(string) value)
{
  if (name && m->name!=name) return 0;
  if (m->type!="checkbox" && m->type!="radio") return 0;
  if (value[m->value||"on"]) {
    if (m->checked) return 0;
    m->checked = "checked";
  }
  else {
    if (!m->checked) return 0;
    m_delete(m, "checked" );
  }

  int xml=!m_delete(m, "noxml");

  return ({ Roxen.make_tag(t, m, xml) });
}

private int|array internal_tag_select(string t, mapping m, string c,
				      string name, multiset(string) value)
{
  if(name && m->name!=name) return ({ RXML.t_xml->format_tag(t, m, c) });

  string cur_tag;
  mapping(string:mixed) cur_args;
  string cur_data = "";

  string finish_tag()
  {
    string _cur_tag = cur_tag;
    cur_tag = 0;
    mapping(string:mixed) _cur_args = cur_args || ([]);
    cur_args = 0;
    string _cur_data = cur_data;
    cur_data = "";

    if (!_cur_args->selected && value[_cur_data])
      _cur_args->selected = "selected";

    if (_cur_tag)
      return RXML.t_xml->format_tag (_cur_tag, _cur_args, _cur_data);

    return _cur_data;
  };

  array process_tag (Parser.HTML p, mapping args)
  {
    string res = "";
    string tag_name = p->tag_name();

    m_delete (args, "/"); // Self-closed tag.

    if (tag_name[-1] == '/') tag_name = tag_name[..<1];

    res = finish_tag();

    if (tag_name[0] != '/') {
      cur_tag = tag_name;

      if (value[args->value])
	args->selected = "selected";
      else
	m_delete (args, "selected");

      cur_args = args;
    }

    return ({ res });
  };

  Parser.HTML parser = Parser.HTML();
  parser->xml_tag_syntax(0);

  // Register opening, closing and self-closed tags directly rather
  // than using add_container to be able to handle some odd cases in
  // the testsuite (opening tags without closing tags, but with
  // content, etc.)
  parser->add_tag ("option", process_tag);
  parser->add_tag ("/option", process_tag);
  parser->add_tag ("option/", process_tag);
  parser->_set_data_callback (lambda (Parser.HTML p, string c)
			      {
				cur_data += c;
				return "";
			      });
  parser->ignore_unknown (1);
  parser->case_insensitive_tag (1);
  string res = parser->finish(c)->read() + finish_tag();

  return ({ RXML.t_xml->format_tag (t, m, res) });
}

string simpletag_default( string t, mapping m, string c, RequestID id)
{
  multiset value=(<>);
  if(m->value) value=mkmultiset(((string)m->value)/(m->separator||","));
  if(m->variable) value+=(<RXML.user_get_var(m->variable, m->scope)>);
  if(value==(<>)) return c;

  return parse_html(c, (["input":internal_tag_input]),
		    (["select":internal_tag_select]),
		    m->name, value);
}

string simpletag_sort(string t, mapping m, string c, RequestID id)
{
  if(!m->separator)
    m->separator = "\n";

  string pre="", post="";
  array lines = c/m->separator;

  while(sizeof (lines) && lines[0] == "")
  {
    pre += m->separator;
    lines = lines[1..];
  }

  while(sizeof (lines) && lines[-1] == "")
  {
    post += m->separator;
    lines = lines[..<1];
  }

  lines=sort(lines);

  return pre + (m->reverse?reverse(lines):lines)*m->separator + post;
}

class TagReplace
{
  inherit RXML.Tag;
  constant name = "replace";

  class Frame
  {
    inherit RXML.Frame;

    array do_return (RequestID id)
    {
      if (content) {
	if (result_type->decode_charrefs && compat_level == 4.0)
	  content = result_type->decode_charrefs (content);
      
	else if (result_type->decode_xml_safe_charrefs &&
	    compat_level > 4.0)
	  content = result_type->decode_xml_safe_charrefs (content);
      }

      if (!args->from)
	result = content;

      else {
	if (content == RXML.nil)
	  content = "";
	
	switch(args->type)
	{
	  case "word":
	  default:
	    if(args->first || args->last) {
	      string res="";
	      int first = (int)args->first;
	      int last = (int)args->last;
	      array a = content / args->from;
	      for(int i=0; i< sizeof(a); i++) {
		res += a[i];
		if(i != sizeof(a)-1) {
		  if((first && (i+i) <= first) || (last && sizeof(a)-i-1 <= last))
		    res += (args->to || "");
		  else
		    res += args->from;
		}
	      }
	      result = res;
	    } else
	      result = replace(content,args->from,(args->to?args->to:""));
	    break;

	  case "words":
	    string s=args->separator?args->separator:",";
	    array from=(array)(args->from/s);
	    array to=(array)(args->to/s);

	    int balance=sizeof(from)-sizeof(to);
	    if(balance>0) to+=allocate(balance,"");
	    else if (balance < 0)
	      parse_error ("There are more elements in the \"to\" list (%d) "
			   "than in \"from\" (%d).", sizeof (to), sizeof (from));

	    result = replace(content,from,to);
	    break;
	}

	if (result_type->entity_syntax)
	  result = replace (result, "\0", "&#0;");
      }
    }
  }
}

class TagSubstring
{
  inherit RXML.Tag;
  constant name = "substring";

  mapping(string:RXML.Type) opt_arg_types = ([
    "from": RXML.t_int (RXML.PEnt),
    "to": RXML.t_int (RXML.PEnt),
    "index": RXML.t_int (RXML.PEnt),
  ]);

  RXML.Type content_type = RXML.t_any_text (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});
  constant flags = RXML.FLAG_DONT_RECOVER;

  class Frame
  {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (result_type == RXML.t_string)
	// Let's propagate t_string in favor of the default t_any_text.
	content_type = result_type (RXML.PXml);
      else if (result_type == RXML.t_array) {
	if (args->join ||
	    !(args->separator || args["separator-chars"] ||
	      args["separator-whites"]))
	  // Cannot return an array if there's a join attribute or no
	  // separator attribute.
	  result_type = RXML.t_string;
      }
      else
	result_type = RXML.t_string;
      return 0;
    }

#define IS_COMPL_SET(SET)						\
    (has_prefix ((SET), "^") && (!has_prefix ((SET), "^-") || (SET) == "^-"))

    protected string compl_sscanf_set (string set)
    {
      return IS_COMPL_SET (set) ? set[1..] : "^" + set;
    }

    protected void set_format_error (string attr, mixed err)
    {
#ifdef DEBUG
      parse_error ("Error in %O format: %s", attr, describe_error (err));
#else
      parse_error ("Error in %O format.\n", attr);
#endif
    }

    protected array(array(string)) split_on_set (string str, string set)
    // Returns ({v, s}) where v has the field values and s has the
    // separator(s) following each field in v.
    {
#ifdef DEBUG
      if (set == "") error ("The set cannot be empty.\n");
#endif
      array(array(string)) res;
      string compl_set = compl_sscanf_set (set);
      string tail;
      if (mixed err = catch {
	  sscanf (str, "%{%[" + compl_set + "]%1[" + set + "]%}%s",
		  res, tail);
	}) set_format_error ("separator-chars", err);
      if (tail != "")
	// The %{...%} bit won't match the last field because of
	// the length restriction on the sep_chars pattern.
	res += ({({tail, ""})});
      if (sizeof (res))
	return Array.transpose (res);
      else
	return ({({}), ({})});
    }

    protected array(array(string)) split_on_set_seq (string str, string set)
    // Note that only the first field value might be empty.
    {
#ifdef DEBUG
      if (set == "") error ("The set cannot be empty.\n");
#endif
      array(array(string)) res;
      string compl_set = compl_sscanf_set (set);
      if (mixed err = catch {
	  sscanf (str, "%{%[" + compl_set + "]%[" + set + "]%}", res);
	}) set_format_error ("separator-chars", err);
      if (sizeof (res))
	return Array.transpose (res);
      else
	return ({({}), ({})});
    }

    array do_return (RequestID id)
    {
      int beg, end;

      if (!zero_type (args->index)) {
	if (args->from || args->to)
	  parse_error ("\"index\" attribute cannot be used "
		       "together with \"from\" or \"to\".\n");
	if (args->after || args->before)
	  parse_error ("\"index\" attribute cannot be used "
		       "together with \"after\" or \"before\".\n");
	beg = end = args->index;
	if (!beg) parse_error ("\"index\" cannot be zero.\n");
      }
      else {
	beg = args->from;
	if (!beg && !zero_type (beg)) parse_error ("\"from\" cannot be zero.\n");
	end = args->to;
	if (!end && !zero_type (end)) parse_error ("\"to\" cannot be zero.\n");
      }

      if (content == RXML.nil) content = "";
      string search_str = content;

      string after = args->after;
      string before = args->before;
      string sep = args->separator;
      string sep_chars = args["separator-chars"];
      string trim_chars = args["trim-chars"];
      string joiner = args->join;
      int ignore_empty = !!args["ignore-empty"];
      int trimwhites = !!args->trimwhites;

      if (args["separator-whites"]) {
	if (!sep_chars)
	  sep_chars = " \t\n\r";
	else if (IS_COMPL_SET (sep_chars))
	  parse_error ("Cannot combine \"separator-whites\" "
		       "with a complemented set in \"separator-chars\".\n");
	else if (has_suffix (sep_chars, "-"))
	  sep_chars = sep_chars[..<1] + " \t\n\r-";
	else
	  sep_chars += " \t\n\r";
	ignore_empty = 1;
      }

      if (joiner) {
	if (!sep && !sep_chars)
	  parse_error ("\"join\" only useful together with "
		       "\"separator\", \"separator-chars\", "
		       "or \"separator-whites\".\n");
      }
      else joiner = sep;

      function(string,string:array(array(string))) char_sep_fn;
      if (sep_chars) {
	if (sep)
	  parse_error ("\"separator\" and \"separator-chars\"/"
		       "\"separator-whites\" cannot be used together.\n");
	if (!joiner)
	  joiner = IS_COMPL_SET (sep_chars) ? "" : sep_chars[..0];
	if (sep_chars == "")
	  parse_error ("\"separator-chars\" cannot be empty.\n");
	else {
	  if (ignore_empty) char_sep_fn = split_on_set_seq;
	  else char_sep_fn = split_on_set;
	}
      }

      if (args["case-insensitive"]) {
	search_str = lower_case (search_str);
	if (after) after = lower_case (after);
	if (before) before = lower_case (before);
	if (sep) sep = lower_case (sep);
	else if (sep_chars) {
	  // NB: This can make the set invalid in odd cases like
	  // "Z-a". We ignore that.
	  sep_chars = lower_case (sep_chars);
	}
	if (trim_chars) trim_chars = lower_case (trim_chars); // Same here.
      }

      if (after && !beg) beg = 1;
      if (before && !end) end = 1;

      // Zero based character positions into search_str and content.
      // -1 = undecided, -2 = calculate from beg_split using split and
      // split_sep.
      int beg_pos = beg && -1;
      int end_pos = end ? -1 : Int.NATIVE_MAX; // last char + 1.

      // If we need to split search_str for some reason, split is the
      // result and split_str is the split string used. split_str is
      // zero if search_str is split on sep_chars.
      array(string) split;
      string split_str;

      // Set if split is, and has the same length. Each element is the
      // separator(s) following the corresponding field in split.
      // Useful for sep_chars, but always set to avoid special cases.
      array(string) split_seps;

      // Like beg_pos and end_pos, but expressed as positions in the
      // split array.
      int beg_split = beg && -1, end_split = end ? -1 : Int.NATIVE_MAX;

      function(string:string) trim_for_empty;
      if (ignore_empty) {
	if (!sep && !sep_chars)
	  parse_error ("\"ignore-empty\" only useful together with "
		       "\"separator\", \"separator-chars\", "
		       "or \"separator-whites\".\n");
	if (trimwhites)
	  // Check for both trimwhites and trim-chars at the same time
	  // is done later.
	  trim_for_empty = String.trim_all_whites;
	else if (trim_chars)
	  trim_for_empty =
	    lambda (string trim) {
	      // This outer lambda doesn't access anything in the
	      // surrounding function frame, thereby avoiding garbage.
	      string fmt = "%*[" + trim + "]%s";
	      return
		lambda (string s) {
		  if (mixed err = catch (sscanf (s, fmt, s)))
		    set_format_error ("trim-chars", err);
		  return s;
		};
	    } (trim_chars);
	else
	  if (char_sep_fn == split_on_set_seq) {
	    // No need for extra trimming in this case since
	    // split_on_set_seq handles it internally, except for the
	    // case when separators occur before the first field. That
	    // requires some special care when counting by elements
	    // from the start.
	  }
	  else
	    trim_for_empty = lambda (string s) {return s;};
      }

      // Optimize by skipping past the beginning of the input string
      // using search(), or index directly on character position.

      string beg_skip_str;

      {
	string s = after || sep;
	if (s && s != "") {
	  if (beg > 0) {
	    beg_pos = 0;
	    int i = beg;
	    if (!after && !--i) {
	      // Using sep - first match is at the beginning of the string.
	    }

	    else {
	      if (!trim_for_empty ||
		  // Trimming doesn't affect after="..." splitting.
		  after)
		do {
		  int p = search (search_str, s, beg_pos);
		  if (p < 0) {beg_pos = Int.NATIVE_MAX; break;}
		  beg_pos = p + sizeof (s);
		} while (--i > 0);

	      else
		while (1) {
		  int p = search (search_str, s, beg_pos);
		  if (p < 0) {beg_pos = Int.NATIVE_MAX; break;}
		  if (beg_pos != p &&
		      trim_for_empty (search_str[beg_pos..p - 1]) != "")
		    // Continue looping when i == 0 to skip empty fields
		    // after the last nonempty match.
		    if (--i < 0) break;
		  beg_pos = p + sizeof (s);
		}

	      beg_skip_str = s;
	    }
	  }
	}

	else if (!sep_chars) {	// Index by character position.
	  if (beg > 0)
	    beg_pos = beg - 1;
	  else if (beg < 0)
	    beg_pos = max (sizeof (search_str) + beg, 0);
	}
      }

    end_skip: {
	string s = before || sep;
	if (s && s != "") {
	  if (end > 0) {
	    int i;

	    if (s == beg_skip_str) {
	      // Optimize by continuing the search where beg_skip left off.
	      i = end - beg;
	      if (sep) i++;
	      if (i <= 0 || beg_pos == Int.NATIVE_MAX) {
		end_pos = end_split = 0;
		break end_skip;
	      }
	      end_pos = beg_pos - sizeof (s);
	    }
	    else {
	      i = end;
	      end_pos = -sizeof (s);
	    }

	    if (before == after)	// True also when only sep is set.
	      // Set end_split in case split is created in the beg_pos == -1
	      // branch below.
	      end_split = end;

	    if (!trim_for_empty ||
		// Trimming doesn't affect before="..." splitting.
		before)
	      do {
		int p = search (search_str, s, end_pos + sizeof (s));
		if (p < 0) {end_pos = Int.NATIVE_MAX; break;}
		end_pos = p;
	      } while (--i > 0);

	    else {
	      int num_empty = 0;
	      while (1) {
		int b = end_pos + sizeof (s);
		int p = search (search_str, s, b);
		if (p < 0) {end_pos = Int.NATIVE_MAX; break;}
		end_pos = p;
		if (b != p &&
		    trim_for_empty (search_str[b..p - 1]) != "") {
		  if (--i <= 0) break;
		}
		else
		  num_empty++;
	      }
	      if (end_split >= 0) end_split += num_empty;
	    }
	  }
	}

	else if (!sep_chars) {	// Index by character position.
	  if (end > 0)
	    end_pos = end;
	  else if (end < 0)
	    end_pos = max (sizeof (search_str) + end + 1, 0);
	}
      }

      // Find beg_pos and end_pos in the remaining cases.

    beg_search:
      if (beg_pos == -1) {
	if (string s = after || sep) {
	  // Some simple testing shows that splitting performs best
	  // overall, compared to using search() in different ways.
	  // Could be improved a lot if we got an rsearch().
	  split = search_str / s;
	  split_str = s;
	  split_seps = allocate (sizeof (split) - 1, s) + ({""});
	}

	else {
#ifdef DEBUG
	  if (!sep_chars) error ("Code flow bonkers.\n");
#endif
	  [split, split_seps] = char_sep_fn (search_str, sep_chars);

	  if (beg >= 0) {
	    if (!trim_for_empty) {
	      beg_split = beg - 1;
	      if (char_sep_fn == split_on_set_seq)
		// split_on_set_seq handles the trimming for us,
		// except it might leave an empty field in front of
		// the first one. Compensate for it.
		if (sizeof (split) && split[0] == "")
		  beg_split++;
	      beg_pos = -2;
	    }

	    else {
	      int b = beg - 1, i = 0;
	      beg_pos = 0;
	      while (1) {
		if (i >= sizeof (split)) {
		  beg_split = beg_pos = Int.NATIVE_MAX;
		  break beg_search;
		}
		// Allow i to go past b as long as split[i] is empty,
		// so that we skip empty fields just after the last
		// nonempty one.
		if (trim_for_empty (split[i]) == "")
		  b++;
		else
		  if (i >= b) break;
		beg_pos += sizeof (split[i]) + sizeof (split_seps[i]);
		i++;
	      }
	      beg_split = i;
	    }

	    break beg_search;
	  }
	}

#ifdef DEBUG
	if (beg >= 0)
	  error ("Expecting only count-from-the-end cases here.\n");
#endif

	if (beg < -sizeof (split))
	  beg_pos = beg_split = 0;

	else {
	  int chars_from_end = 0;
	  if (!trim_for_empty ||
	      // Trimming doesn't affect after="..." splitting.
	      after) {
	    beg_split = sizeof (split) + beg;
	    for (int i = -1; i >= beg; i--)
	      chars_from_end += sizeof (split[i]) + sizeof (split_seps[i]);
	  }

	  else {
	    int b = beg, i = -1;
	    do {
	      chars_from_end += sizeof (split[i]) + sizeof (split_seps[i]);
	      if (trim_for_empty (split[i]) == "")
		if (--b < -sizeof (split)) {
		  beg_pos = beg_split = 0;
		  break beg_search;
		}
	    } while (--i >= b);
	    beg_split = sizeof (split) + b;
	  }

	  beg_pos = sizeof (search_str) - chars_from_end;
#ifdef DEBUG
	  if (beg_pos < 0)
	    error ("Ouch! %O %O %O\n",
		   sizeof (search_str), chars_from_end, beg);
#endif
	}
      }

#ifdef DEBUG
      if (split && beg_split == -1) error ("Failed to set beg_split.\n");
#endif

    end_search:
      if (end_pos == -1) {
	int e = end;
	if (!before && !++e)
	  // Using sep or sep_chars - last match is at the end of the string.
	  end_pos = end_split = Int.NATIVE_MAX;

	else {
	  string ss;
	  array(string) sp, sps;
	  int bias;

	  if (string s = before || sep) {
	    sp = s == split_str && split;
	    if (sp) {
	      ss = search_str;
	      sps = split_seps;
	    }
	    else {
	      // Since we count from the end we can optimize by
	      // chopping off the part before beg_pos first.
	      ss = search_str[beg_pos..];
	      bias = beg_pos;
	      sp = ss / s;
	      sps = allocate (sizeof (sp) - 1, s) + ({""});
	      if (!before && !beg_pos) {
		// Want to save it if we're splitting on sep.
		split = sp;
		split_str = s;
		split_seps = sps;
	      }
	    }
	  }

	  else {
#ifdef DEBUG
	    if (!sep_chars) error ("Code flow bonkers.\n");
#endif
	    if (!split)
	      [split, split_seps] = char_sep_fn (search_str, sep_chars);

	    if (end >= 0) {
	      if (!trim_for_empty) {
		end_split = end;
		if (char_sep_fn == split_on_set_seq)
		  // split_on_set_seq handles the trimming for us,
		  // except it might leave an empty field in front of
		  // the first one. Compensate for it.
		  if (sizeof (split) && split[0] == "")
		    end_split++;
		end_pos = -2;
	      }

	      else {
		e = end;
		end_pos = 0;
		for (int i = 0; i < e; i++) {
		  if (i >= sizeof (split)) {
		    end_split = end_pos = Int.NATIVE_MAX;
		    break end_search;
		  }
		  if (trim_for_empty (split[i]) == "")
		    e++;
		  end_pos += sizeof (split[i]) + sizeof (split_seps[i]);
		}
		end_pos -= sizeof (split_seps[e - 1]);
		end_split = e;
	      }

	      break end_search;
	    }

	    else {
	      ss = search_str;
	      sp = split;
	      sps = split_seps;
	    }
	  }

#ifdef DEBUG
	  if (end >= 0)
	    error ("Expecting only count-from-the-end cases here.\n");
#endif

	  if (e <= -sizeof (sp))
	    end_pos = end_split = 0;

	  else {
	    int chars_from_end;
	    if (!trim_for_empty ||
		// Trimming doesn't affect before="..." splitting.
		before) {
	      if (sp == split) end_split = sizeof (split) + e;
	      chars_from_end = sizeof (sps[e - 1]);
	      for (; e < 0; e++)
		chars_from_end += sizeof (sp[e]) + sizeof (sps[e]);
	    }

	    else {
	      int i = -1;
	      while (1) {
		// Allow i to go past e as long as sp[i] is empty,
		// so that we skip empty fields just before the last
		// nonempty one.
		if (trim_for_empty (sp[i]) == "")
		  e--;
		else
		  if (i < e) break;
		chars_from_end += sizeof (sp[i]) + sizeof (sps[i]);
		if (--i < -sizeof (sp)) {
		  end_pos = end_split = 0;
		  break end_search;
		}
	      }
	      if (sp == split) end_split = sizeof (split) + i + 1;
	    }

	    end_pos = sizeof (ss) - chars_from_end;
#ifdef DEBUG
	    if (end_pos < 0)
	      error ("Ouch! %O %O %O %O %O\n", sizeof (search_str),
		     chars_from_end, beg, beg_pos, bias);
#endif
	    end_pos += bias;
	  }
	}
      }

#ifdef DEBUG
      if (beg_pos == -1) error ("Failed to set beg_pos.\n");
      else if (beg_pos == -2) {
	if (beg_split == -1) error ("Failed to set beg_split.\n");
      }
      else if (beg_pos < 0) error ("Invalid beg_pos %d.\n", beg_pos);
      if (beg_split < -1) error ("Invalid beg_split %d.\n", beg_split);

      if (end_pos == -1) error ("Failed to set end_pos.\n");
      else if (end_pos == -2) {
	if (end_split == -1) error ("Failed to set end_split.\n");
      }
      else if (end_pos < 0) error ("Invalid end_pos %d.\n", end_pos);
      if (end_split < -1) error ("Invalid end_split %d.\n", end_split);
#endif

      // Got beg_pos and end_pos. Now finish up.

      function(string:string) trimmer;

      if (trimwhites) {
	if (trim_chars)
	  parse_error ("\"trimwhites\" and \"trim-chars\" "
		       "cannot be used at the same time.\n");
	trimmer = String.trim_all_whites;
      }

      else if (trim_chars) {
	if (args["case-insensitive"])
	  // NB: This can make the trim format invalid in odd cases
	  // like "Z-a". We ignore that.
	  trimmer =
	    lambda (string trim) {
	      // This outer lambda doesn't access anything in the
	      // surrounding function frame, thereby avoiding garbage.
	      string fmt = "%[" + lower_case (trim) + "]";
	      return
		lambda (string s) {
		  string t, lc = lower_case (s);
		  if (mixed err = catch (sscanf (lc, fmt, t)))
		    set_format_error ("trim-chars", err);
		  int b = sizeof (t);
		  sscanf (reverse (lc), fmt, t);
		  return s[b..<sizeof (t)];
		};
	    } (trim_chars);

	else
	  trimmer =
	    lambda (string trim) {
	      string fmt1 = "%*[" + trim + "]%s", fmt2 = "%[" + trim + "]";
	      return
		lambda (string s) {
		  if (mixed err = catch (sscanf (s, fmt1, s)))
		    set_format_error ("trim-chars", err);
		  sscanf (reverse (s), fmt2, string t);
		  return s[..<sizeof (t)];
		};
	    } (trim_chars);
      }

      if (result_type == RXML.t_array || sep_chars ||
	  (sep && (trim_chars || trimwhites || ignore_empty ||
		   joiner != sep || search_str != content))) {
	// Need to do things that require a split into an array.

#ifdef DEBUG
	if (result_type == RXML.t_array) {
	  // do_enter should make sure the following never happens.
	  if (args->join)
	    error ("Unexpected join attribute in array context.\n");
	  if (!sep && !sep_chars)
	    error ("Unexpected array context without separator attribute.\n");
	}
#endif

#if 0
	werror ("split %O, split_str %O, beg %O/%O, end %O/%O\n",
		!!split, split_str, beg_split, beg_pos, end_split, end_pos);
#endif

	if (split) {
#ifdef DEBUG
	  if (sep && split_str != sep)
	    error ("Didn't expect a split on %O when sep is %O.\n",
		   split_str, sep);
#endif
	  if (beg_split == -1 || end_split == -1 || search_str != content ||
	      // If sep is used then split_str must be the sep string.
	      // If sep isn't set then sep_chars is used and split_str
	      // must be zero.
	      split_str != sep) {
	    // Can't use the split array created earlier.
#if 0
	    werror ("Ditching split for args %O\n", args);
#endif

	    if (beg_pos == -2) {
	      beg_pos = 0;
	      for (int i = 0; i < beg_split; i++)
		beg_pos += sizeof (split[i]) + sizeof (split_seps[i]);
	    }

	    if (end_pos == -2) {
	      end_pos = sizeof (search_str);
	      int i = sizeof (split);
	      while (--i >= end_split)
		end_pos -= sizeof (split[i]) + sizeof (split_seps[i]);
	      if (i >= 0) end_pos -= sizeof (split_seps[i]);
	    }

	    split = 0;
	  }
	}

	if (split)
	  split = split[beg_split..end_split - 1];

	else {
#ifdef DEBUG
	  if (beg_pos < 0) error ("beg_pos must be valid here.\n");
	  if (end_pos < 0) error ("end_pos must be valid here.\n");
#endif

	  string s = content[beg_pos..end_pos - 1];

	  if (s == "")
	    split = ({});
	  else {
	    array(string) sp, sps;

	    if (sep) {
	      if (content == search_str)
		split = s / sep;
	      else {
		sp = search_str[beg_pos..end_pos - 1] / sep;
		sps = allocate (sizeof (sp) - 1, sep) + ({""});
	      }
	    }
	    else {
#ifdef DEBUG
	      if (!sep_chars) error ("Code flow bonkers.\n");
#endif
	      if (content == search_str)
		[split, split_seps] = char_sep_fn (s, sep_chars);
	      else
		[sp, sps] =
		  char_sep_fn (search_str[beg_pos..end_pos - 1], sep_chars);
	    }

	    if (sp) {
	      // content != search_str so we must split on search_str
	      // and then transfer the split to content.
	      split = allocate (sizeof (sp));
	      int p;
	      foreach (sp; int i; string s) {
		split[i] = content[p..p + sizeof (s) - 1];
		p += sizeof (s) + sizeof (sps[i]);
	      }
	    }
	  }
	}

	if (trimmer) split = map (split, trimmer);
	if (ignore_empty) split -= ({""});

	if (result_type == RXML.t_array)
	  result = split;
	else {
#ifdef DEBUG
	  if (!joiner) error ("Got no joiner.\n");
#endif
	  result = split * joiner;
	}
      }

      else {
	result = content[beg_pos..end_pos - 1];
	if (trimmer) result = trimmer (result);
      }

      return 0;
    }
  }
}

class TagRange
{
  inherit RXML.Tag;
  constant name = "range";

  mapping(string:RXML.Type) opt_arg_types = ([
    "from": RXML.t_int (RXML.PEnt),
    "to": RXML.t_int (RXML.PEnt),
    "variable": RXML.t_text (RXML.PEnt),
  ]);

  RXML.Type content_type = RXML.t_array (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});
  constant flags = RXML.FLAG_DONT_RECOVER;

  class Frame
  {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (!args->join)
	result_type = RXML.t_array;
      else
	result_type = RXML.t_string;

      if (args->variable)
	flags |= RXML.FLAG_EMPTY_ELEMENT;

      return 0;
    }

    array do_return (RequestID id)
    {
      int beg = args->from;
      if (!beg && !zero_type (beg)) parse_error ("\"from\" cannot be zero.\n");
      int end = args->to;
      if (!end && !zero_type (end)) parse_error ("\"to\" cannot be zero.\n");

      if (args->variable)
	content = RXML.user_get_var (args->variable);
      else if (content == RXML.nil)
	content = ({});

      if (!arrayp (content))
	parse_error ("Array required as input, got %t.\n", content);

      int beg_pos, end_pos;

    beg_search:
      if (string after = args->after) {
	if (!beg) beg = 1;

	if (beg > 0) {
	  int i = 0;
	  do {
	    i = search (content, after, i) + 1;
	    if (i == 0) {
	      beg_pos = Int.NATIVE_MAX;
	      break beg_search;
	    }
	  } while (--beg > 0);
	  beg_pos = i;
	}

	else {
	  for (int i = sizeof (content); --i >= 0;) {
	    if (content[i] == after)
	      if (!++beg) {
		beg_pos = i + 1;
		break beg_search;
	      }
	  }
	  beg_pos = 0;
	}
      }

      else {			// Index by position.
	if (beg > 0)
	  beg_pos = beg - 1;
	else if (beg < 0)
	  beg_pos = max (sizeof (content) + beg, 0);
	else
	  beg_pos = 0;
      }

    end_search:
      if (string before = args->before) {
	if (!end) end = 1;

	if (end > 0) {
	  int i = 0;
	  do {
	    i = search (content, before, i) + 1;
	    if (i == 0) {
	      end_pos = Int.NATIVE_MAX;
	      break end_search;
	    }
	  } while (--end > 0);
	  end_pos = i - 1;
	}

	else {
	  for (int i = sizeof (content); --i >= 0;) {
	    if (content[i] == before)
	      if (!++end) {
		end_pos = i;
		break end_search;
	      }
	  }
	  end_pos = 0;
	}
      }

      else {			// Index by position.
	if (end > 0)
	  end_pos = end;
	else if (end <= 0)
	  end_pos = max (sizeof (content) + end + 1, 0);
      }

#ifdef DEBUG
      if (beg_pos < 0) error ("Invalid beg_pos %d.\n", beg_pos);
      if (end_pos < 0) error ("Invalid end_pos %d.\n", end_pos);
#endif

      result = content[beg_pos..end_pos - 1];
      if (string joiner = args->join) {
	if (mixed err = catch (result = (array(string)) result))
	  parse_error ("Cannot convert %s to array of strings: %s",
		       RXML.utils.format_short (result),
		       describe_error (err));
	result *= joiner;
      }

      return 0;
    }
  }
}

class TagValue
{
  inherit RXML.Tag;
  constant name = "value";

  mapping(string:RXML.Type) opt_arg_types = ([
    "type": RXML.t_type (RXML.PEnt),
    "index": RXML.t_any (RXML.PEnt),
  ]);

  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});
  constant flags = RXML.FLAG_DONT_RECOVER;

  class Frame
  {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      RXML.Type type = args->type;
      if (type) content_type = type (RXML.PXml);

      if (args->index) {
	if (result_type != RXML.t_mapping)
	  parse_error ("\"index\" attribute only supported "
		       "in mapping contexts, got %O.\n", result_type);
      }

      else {
	if (result_type == RXML.t_mapping)
	  parse_error ("\"index\" attribute required in mapping context.\n");

	if (result_type == RXML.t_array)
	  // Avoid that an array value gets spliced into the
	  // surrounding array. This is the only case where we've got
	  // a splice/single-value ambiguity.
	  result_type = RXML.t_any;
      }

      if (args->from || args->expr)
	flags |= RXML.FLAG_EMPTY_ELEMENT;
    }

    array do_return (RequestID id)
    {
      if (string var = args->from) {
	// Get the value from another variable.
	if (zero_type (content = RXML.user_get_var(var, args->scope)))
	  parse_error ("From variable %q does not exist.\n", var);
      }

      else if (string expr = args->expr)
	content = sexpr_eval (expr);

      else if (content == RXML.nil) {
	if (content_type->sequential)
	  content = content_type->empty_value;
	else if (content_type == RXML.t_any)
	  content = RXML.empty;
	else
	  parse_error ("The value is missing for "
		       "non-sequential type %s.\n", content_type);
      }

      if (string ind = args->index)
	result = ([ind: content]);
      else if (result_type != content_type)
	result = result_type->encode (content, content_type);
      else
	result = content;
    }
  }
}

class TagJsonFormat
{
  inherit RXML.Tag;
  constant name = "json-format";

  mapping(string:RXML.Type) opt_arg_types = ([
    "variable": RXML.t_text (RXML.PEnt),
  ]);

  RXML.Type content_type = RXML.t_any (RXML.PXml);

  class Frame
  {
    inherit RXML.Frame;

    array do_return (RequestID id)
    {
      int encode_flags;

      if (args["ascii-only"])
	encode_flags |= Standards.JSON.ASCII_ONLY;
      if (args["human-readable"])
	encode_flags |= Standards.JSON.HUMAN_READABLE;
      if (string canon = args["canonical"]) {
	if (canon != "pike")
	  RXML.parse_error ("Unknown canonical form %q requested.\n", canon);
	encode_flags |= Standards.JSON.PIKE_CANONICAL;
      }

      if (args->value)
	content = args->value;
      else if (string var = args->variable) {
	if (zero_type (content = RXML.user_get_var (var)))
	  parse_error ("Variable %q does not exist.\n", var);
      }

      if (mixed err =
	  catch (result = Standards.JSON.encode (content, encode_flags)))
	RXML.run_error (describe_error (err));

      if (!args["no-xml-quote"])
	result = replace (result, ([
			    "&": "\\u0026",
			    "<": "\\u003c",
			    ">": "\\u003e",
			  ]));
    }
  }
}

class TagJsonParse
{
  inherit RXML.Tag;
  constant name = "json-parse";

  RXML.Type content_type = RXML.t_any_text (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame
  {
    inherit RXML.Frame;

    array do_return (RequestID id)
    {
      if (args->value)
	content = args->value;
      else if (string var = args->variable) {
	if (zero_type (content = RXML.user_get_var (var)))
	  parse_error ("Variable %q does not exist.\n", var);
      }

      if (mixed err = catch (result = Standards.JSON.decode (content)))
	RXML.run_error (describe_error (err));
    }
  }
}

class TagCSet {
  inherit RXML.Tag;
  constant name = "cset";

  // No result. Propagate the result type to the content for
  // compatibility, but allow placement in non-text contexts too.
  array(RXML.Type) result_types = ::result_types + ({RXML.t_nil});

  class Frame {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (!content_type->subtype_of (RXML.t_any_text) ||
	  content_type == RXML.t_nil)
	content_type = RXML.t_any_text (RXML.PXml);
    }

    array do_return(RequestID id) {
      if( !args->variable ) parse_error("Variable not specified.\n");
      if(!content) content="";
      if( args->quote != "none" )
	content = Roxen.html_decode_string( content );

      RXML.user_set_var(args->variable, content, args->scope);
      return 0;
    }
  }
}

class TagColorScope {
  inherit RXML.Tag;
  constant name = "colorscope";

  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame {
    inherit RXML.Frame;
    string link, alink, vlink;

#define LOCAL_PUSH(X) if(args->X) { X=RXML_CONTEXT->misc->X; RXML_CONTEXT->misc->X=args->X; }
    array do_enter(RequestID id) {
      Roxen.push_color("colorscope",args,id);
      LOCAL_PUSH(link);
      LOCAL_PUSH(alink);
      LOCAL_PUSH(vlink);
      return 0;
    }

#define LOCAL_POP(X) if(X) RXML_CONTEXT->misc->X=X
    array do_return(RequestID id) {
      Roxen.pop_color("colorscope",id);
      LOCAL_POP(link);
      LOCAL_POP(alink);
      LOCAL_POP(vlink);
      result=content;
      return 0;
    }
  }
}


// ------------------------- RXML Core tags --------------------------

class TagHelp {
  inherit RXML.Tag;
  constant name = "help";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string help_for = args->for || id->variables->_r_t_h;
      string ret="<h2>Roxen Interactive RXML Help</h2>";

      if(!help_for) {
	// FIXME: Is it actually needed to disable the cache?
	NOCACHE();
	array tags=map(indices(RXML_CONTEXT->tag_set->get_tag_names()),
		       lambda(string tag) {
			 if (!has_prefix (tag, "_"))
			   if(tag[..3]=="!--#" || !has_value(tag, "#"))
			     return tag;
			 return "";
		       } ) - ({ "" });
	tags += map(indices(RXML_CONTEXT->tag_set->get_proc_instr_names()),
		    lambda(string tag) { return "&lt;?"+tag+"?&gt;"; } );
	tags = Array.sort_array(tags,
				lambda(string a, string b) {
				  if(has_prefix (a, "&lt;?")) a=a[5..];
				  if(has_prefix (b, "&lt;?")) b=b[5..];
				  if(lower_case(a)==lower_case(b)) return a > b;
				  return lower_case (a) > lower_case (b);
				})-({"\x266a"});

	string char;
	ret += "<b>Here is a list of all defined tags. Click on the name to "
	  "receive more detailed information. All these tags are also availabe "
	  "in the \""+RXML_NAMESPACE+"\" namespace.</b><p>\n";
	array tag_links;

	foreach(tags, string tag) {
	  string tag_char =
	    lower_case (has_prefix (tag, "&lt;?") ? tag[5..5] : tag[0..0]);
	  if (tag_char != char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char = tag_char;
	    tag_links=({});
	  }
	  if(tag[0..sizeof(RXML_NAMESPACE)]!=RXML_NAMESPACE+":") {
	    string enc=tag;
	    if(enc[0..4]=="&lt;?") enc=enc[4..sizeof(enc)-6];
	    if(my_configuration()->undocumented_tags &&
	       my_configuration()->undocumented_tags[tag])
	      tag_links += ({ tag });
	    else
	      tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>\n",
				      id->url_base() + id->not_query[1..],
				      Roxen.http_encode_url(enc), tag) });

	  }
	}

	ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
	/*
	ret+="<p><b>This is a list of all currently defined RXML scopes and their entities</b></p>";

	RXML.Context context=RXML_CONTEXT;
	foreach(sort(context->list_scopes()), string scope) {
	  ret+=sprintf("<h3><a href=\"%s?_r_t_h=%s\">%s</a></h3>\n",
		       id->not_query, Roxen.http_encode_url("&"+scope+";"), scope);
	  ret+="<p>"+String.implode_nicely(Array.map(sort(context->list_var(scope)),
						       lambda(string ent) { return ent; }) )+"</p>";
	}
	*/
	return ({ ret });
      }

      result=ret+my_configuration()->find_tag_doc(help_for, id);
    }
  }
}

class TagNumber {
  inherit RXML.Tag;
  constant name = "number";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if(args->type=="roman") return ({ Roxen.int2roman((int)args->num) });
      if(args->type=="memory") return ({ Roxen.sizetostring((int)args->num) });
      result=roxen.language(args->lang||args->language||
                            RXML_CONTEXT->misc->theme_language,
			    args->type||"number",id)( (int)args->num );
    }
  }
}


class TagUse {
  inherit RXML.Tag;
  constant name = "use";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  private array(string) list_packages() { 
    return filter(((get_dir("../local/rxml_packages")||({}))
		   |(get_dir("rxml_packages")||({}))),
		  lambda( string s ) {
		    return s!=".cvsignore" &&
		      (Stdio.file_size("../local/rxml_packages/"+s)+
		       Stdio.file_size( "rxml_packages/"+s )) > 0;
		  });
  }

  private string read_package( string p ) {
    string data;
    p = combine_path("/", p);
    if(file_stat( "../local/rxml_packages/"+p ))
      catch(data=Stdio.File( "../local/rxml_packages/"+p, "r" )->read());
    if(!data && file_stat( "rxml_packages/"+p ))
      catch(data=Stdio.File( "rxml_packages/"+p, "r" )->read());
    return data;
  }

  private string use_file_doc(string f, string data) {
    string res, doc;
    int help; // If true, all tags support the 'help' argument.
    sscanf(data, "%*sdoc=\"%s\"", doc);
    sscanf(data, "%*shelp=%d", help);
    res = "<dt><b>"+f+"</b></dt><dd>"+(doc?doc+"<br />":"")+"</dd>";

    array defs = cache_lookup ("macrofiles", "|" + f);
    if (!defs) {
      defs = parse_use_package(data, RXML_CONTEXT);
      cache_set("macrofiles", "|"+f, defs, 300);
    }

    array(string) ifs = ({}), tags = ({});

    foreach (defs[1]; string defname;)
      if (has_prefix (defname, "if\0"))
	ifs += ({defname[sizeof ("if\0")..]});
      else if (has_prefix (defname, "tag\0"))
	tags += ({defname[sizeof ("tag\0")..]});

    constant types = ({ "if plugin", "tag", "form variable", "\"var\" scope variable" });

    array pack = ({ifs, tags, indices(defs[2]), indices(defs[3])});

    for(int i; i<3; i++)
      if(sizeof(pack[i])) {
	res += "Defines the following " + types[i] + (sizeof(pack[i])!=1?"s":"") +
	  ": " + String.implode_nicely( sort(pack[i]) ) + ".<br />";
      }

    if(help) res+="<br /><br />All tags accept the <i>help</i> attribute.";
    return res;
  }

  private array parse_use_package(string data, RXML.Context ctx) {
    RXML.Parser parser = Roxen.get_rxml_parser (ctx->id);
    parser->write_end (data);
    parser->eval();

    return ({
      global::this,
      parser->context->misc - ([" _extra_heads": 1, " _error": 1, " _stat": 1]),
      parser->context->get_scope ("form"),
      parser->context->get_scope ("var")
    });
  }

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->packageinfo) {
	NOCACHE();
	result ="<dl>";
	foreach(list_packages(), string f)
	  result += use_file_doc(f, read_package( f ));
	result += "</dl>";
	result_type = RXML.t_html;
	return 0;
      }

      if(!args->file && !args->package)
	parse_error("No file or package selected.\n");

      array res;
      string name, filename;
      int is_package;
      if(args->file)
      {
	filename = Roxen.fix_relative(args->file, id);
	name = id->conf->get_config_id() + "|" + filename;
      }
      else if( args->locate )
      {
	filename = VFS.find_above( id->not_query, args->locate, id, "locate" );
	name = id->conf->get_config_id() + "|" + filename;
      }
      else
      {
	name = "|" + args->package;
	is_package = 1;
      }
      RXML.Context ctx = RXML_CONTEXT;

      if(!(res=cache_lookup("macrofiles",name)) ||
	 args->info || id->pragma["no-cache"] ||
	 (is_package ? !res[0] : res[0] != global::this)) {

	string file;
	if(filename)
	  file = id->conf->try_get_file( filename, id );
	else
	  file = read_package( args->package );

	if(!file)
	  run_error("Failed to fetch "+(args->file||args->package)+".\n");

	if( args->info ) {
	  result = "<dl>"+
	    use_file_doc( args->file || args->package, file )+
	    "</dl>";
	  result_type = RXML.t_html;
	  return 0;
	}

	res = parse_use_package(file, ctx);
	// DEBUG_CACHE_SIZES note: These cache entries can become
	// larger, e.g. as more parts of the rxml tree gets compiled.
	cache_set("macrofiles", name, res);
      }

      [RoxenModule ignored,
       mapping(string:mixed) newdefs,
       mapping(string:mixed)|RXML.Scope formvars,
       mapping(string:mixed)|RXML.Scope varvars] = res;
      foreach (newdefs; string defname; mixed def) {
	if (defname == "scope_roxen" || defname == "scope_page") {
	  // The user override mappings for the "roxen" and "page"
	  // scopes. Merge with existing mappings.
	  mapping(string:mixed) tgt_map = ctx->misc[defname];
	  if (!tgt_map)		// Shouldn't happen.
	    ctx->misc[defname] = def + ([]);
	  else
	    foreach (def; string var; mixed val)
	      tgt_map[var] = val;
	}
	else {
	  ctx->misc[defname] = def;
	  if (has_prefix (defname, "tag\0")) ctx->add_runtime_tag (def[3]);
	}
      }
      ctx->extend_scope ("form", formvars);
      ctx->extend_scope ("var", varvars);

      return 0;
    }
  }
}

class UserTagContents
{
  inherit RXML.Tag;
  constant name = "contents";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_any (RXML.PXml)});

  class IdentityVar (string self)
  {
    mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
			 void|RXML.Type type)
    {
      return ENCODE_RXML_XML (self, type);
    }
  }

  // Got two frame types in this tag: First the normal frame which is
  // created when <contents/> is parsed. Second the ExpansionFrame
  // which is made by the normal frame with the actual content the
  // UserTag frame got.

  class Frame
  {
    inherit RXML.Frame;
    constant is_user_tag_contents_tag = 1;

    string scope;

    local RXML.Frame get_upframe()
    {
      RXML.Frame upframe = up;
      int nest = 1;
      for (; upframe; upframe = upframe->up)
	if (upframe->is_contents_nest_tag) {
	  if ((!scope || upframe->scope_name == scope) && !--nest)
	    return upframe;
	}
	else
	  if (upframe->is_user_tag_contents_tag &&
	      (!scope || upframe->scope == scope)) nest++;
      parse_error ("No associated defined tag to get contents from.\n");
    }

    // Note: The ExpansionFrame instances aren't saved and restored
    // here for p-code use, since they can't be shared between
    // evaluations (due to e.g. orig_ctx_scopes).

    array do_return()
    {
      if (args["copy-of"] && args["value-of"])
	parse_error ("Attributes copy-of and value-of are mutually exclusive.\n");

      scope = args->scope;
      RXML.Frame upframe = get_upframe();

      if (compat_level < 2.4 && !args["copy-of"] && !args["value-of"])
	// Must reevaluate the contents each time it's inserted to be
	// compatible in old <contents/> tags without copy-of or
	// value-of arguments.
	args->eval = "";

      // Note that args will be parsed again in the ExpansionFrame.

      if (upframe->is_define_tag) {
	// If upframe is a <define> tag and not the user tag then
	// we're being preparsed. Output an entity on the form
	// &_internal_.4711; so that we can find it again after the
	// preparse.
	if (mapping(string:ExpansionFrame) ctag = upframe->preparsed_contents_tags) {
	  RXML.Context ctx = RXML_CONTEXT;
	  string var = ctx->alloc_internal_var();
	  ctag[var] = ExpansionFrame (
	    0,
	    args["copy-of"] || args["value-of"] ?
	    RXML.t_xml (content_type->parser_prog) : content_type,
	    args);
	  // Install a value for &_internal_.4711; that expands to
	  // itself, in case something evaluates it during preparse.
	  // Don't use the proper ctx->set_var since these assigments
	  // doesn't need to be registered if p-code is created;
	  // they're only used temporarily during the preparse.
	  ctx->scopes->_internal_[var] = IdentityVar ("&_internal_." + var + ";");
	  result_type = result_type (RXML.PNone);
	  return ({"&_internal_." + var + ";"});
	}
	else
	  parse_error ("This tag is currently only supported in "
		       "<define tag='...'> and <define container='...'>.\n");
      }

      else {
	ExpansionFrame exp_frame =
	  ExpansionFrame (upframe,
			  args["copy-of"] || args["value-of"] ?
			  RXML.t_xml (content_type->parser_prog) : content_type,
			  args);
#ifdef DEBUG
	if (flags & RXML.FLAG_DEBUG) exp_frame->flags |= RXML.FLAG_DEBUG;
#endif
	return ({exp_frame});
      }
    }
  }

  protected function(:mapping) get_arg_function (mapping args)
  {
    return lambda () {return args;};
  }

  class ExpansionFrame
  {
    inherit RXML.Frame;
    int do_iterate;

    RXML.Frame upframe;

    protected void create (void|RXML.Frame upframe_,
			   void|RXML.Type type, void|mapping contents_args)
    {
      if (type) {		// Might be created from decode or _clone_empty.
	content_type = type, result_type = type (RXML.PNone);
	args = contents_args;
	if (args["copy-of"] || args["value-of"])
	  // If there's an error it'll typically be completely lost if
	  // we use copy-of or value-of, so propagate it instead.
	  flags |= RXML.FLAG_DONT_RECOVER;
	if ((upframe = upframe_)) {
	  // upframe is zero if we're called during preparse.
	  RXML.PCode compiled_content = upframe->compiled_content;
	  if (compiled_content && !compiled_content->is_stale()) {
	    content = compiled_content;
	    // The internal way to flag a compiled but unevaluated
	    // flag is to set args to a function returning the
	    // argument mapping. It'd be prettier with a flag for
	    // this.
	    args = (mixed) get_arg_function (args);
	  }
	  else {
	    content = upframe->content_text;
	    flags |= RXML.FLAG_UNPARSED;
	  }
	  if (upframe->compile) flags |= RXML.FLAG_COMPILE_INPUT;
	}
      }
    }

    protected mapping(string:mixed) get_input_attrs (RXML.Frame upframe)
    {
      mapping(string:mixed) res = ([]);
      foreach (upframe->vars; string var; mixed val)
	if (!(<"args", "rest-args", "contents">)[var] &&
	    !has_prefix (var, "__contents__"))
	  res[var] = val;
      return res;
    }

    local mixed get_content (RXML.Frame upframe, mixed content)
    {
      if (string expr = args["copy-of"] || args["value-of"]) {
	string insert_type = args["copy-of"] ? "copy-of" : "value-of";
	int result_set = !!args["result-set"];

	string|array|mapping value;

	if (sscanf (expr, "%*[ \t\n\r]@%*[ \t\n\r]%s", expr) == 3) {
	  // Special treatment to select attributes at the top level.
	  sscanf (expr, "%[^][ \t\n\r/@(){},]%*[ \t\n\r]%s", expr, string rest);
	  if (!sizeof (expr))
	    parse_error ("Error in %s attribute: No attribute name after @.\n",
			 insert_type);
	  if (sizeof (rest))
	    parse_error ("Error in %s attribute: "
			 "Unexpected subpath %O after attribute %s.\n",
			 insert_type, rest, expr);
	  if (expr == "*") {
	    if (insert_type == "copy-of")
	      if (result_set)
		value = get_input_attrs (upframe);
	      else
		value = upframe->vars->args;
	    else
	      if (result_set)
		value = values (get_input_attrs (upframe));
	      else
		value = Mapping.Iterator (get_input_attrs (upframe))->value();
	  }
	  else if (!(<"args", "rest-args", "contents">)[expr] &&
		   !has_prefix (expr, "__contents__"))
	    if (string val = upframe->vars[expr])
	      if (insert_type == "copy-of")
		if (result_set)
		  value = ([expr: val]);
		else
		  value = Roxen.make_tag_attributes (([expr: val]));
	      else
		value = val;
	}

	else {
	  if (!objectp (content) || content->node_type != SloppyDOM.Node.DOCUMENT_NODE)
	    content = upframe->content_result = SloppyDOM.parse ((string) content, 1);

	  mixed res = 0;
	  if (mixed err = catch (
		res = content->simple_path (
		  expr, !result_set && insert_type == "copy-of")))
	    // We're sloppy and assume that the error is some parse
	    // error regarding the expression.
	    parse_error ("Error in %s attribute: %s", insert_type,
			 describe_error (err));

	  if (insert_type == "copy-of") {
	    if (result_set) {
	      if (arrayp (res))
		value = map (res, lambda (mapping|SloppyDOM.Node elem) {
				    if (objectp (elem))
				      return elem->xml_format();
				    else
				      return Roxen.make_tag_attributes (elem);
				  });
	      else if (objectp (res))
		value = ({res->xml_format()});
	      else if (mappingp (res))
		value = res;
	      else
		value = ({});
	    }
	    else
	      value = res;
	  }

	  else {
	    if (result_set) {
	      if (arrayp (res)) {
		value = ({});
		foreach (res, mapping|SloppyDOM.Node elem) {
		  if (objectp (elem))
		    value += ({elem->get_text_content()});
		  else
		    value += values (elem);
		}
	      }
	      else if (objectp (res))
		value = ({res->get_text_content()});
	      else if (mappingp (res))
		value = values (res);
	      else
		value = ({});
	    }
	    else {
	      if (arrayp (res)) res = sizeof (res) && res[0];
	      if (objectp (res))
		value = res->get_text_content();
	      else if (mappingp (res))
		value = values (res)[0];
	      else
		value = "";
	    }
	  }
	}

#ifdef DEBUG
	if (TAG_DEBUG_TEST (flags & RXML.FLAG_DEBUG))
	  tag_debug ("%O:   Did %s %O in %s: %s\n", this,
		     insert_type, expr,
		     RXML.utils.format_short (
		       objectp (content) ? content->xml_format() : content),
		     RXML.utils.format_short (value));
#endif
	return value;
      }

      else
	if (objectp (content) &&
	    content->node_type == SloppyDOM.Node.DOCUMENT_NODE &&
	    result_type->empty_value == "")
	  // The content has been parsed into a SloppyDOM.Document by
	  // the code above in an earlier <contents/>. Format it again
	  // if the result type is string-like.
	  return content->xml_format();
	else
	  return content;
    }

    mapping(string:mixed) orig_ctx_scopes;
    mapping(RXML.Frame:array) orig_ctx_hidden;

    array do_enter()
    {
      if (!upframe->got_content_result || args->eval) {
	do_iterate = 1;
	// Switch to the set of scopes that were defined at entry of
	// the UserTag frame, to get static variable binding in the
	// content. This is poking in the internals; there ought to be
	// some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	orig_ctx_scopes = ctx->scopes, ctx->scopes = upframe->get_saved_scopes();
	orig_ctx_hidden = ctx->hidden, ctx->hidden = upframe->get_saved_hidden();
      }
      else
	// Already have the result of the content evaluation.
	do_iterate = -1;
      return 0;
    }

    array do_return()
    {
      if (do_iterate >= 0) {
	// Switch back the set of scopes. This is poking in the
	// internals; there ought to be some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	ctx->scopes = orig_ctx_scopes, orig_ctx_scopes = 0;
	ctx->hidden = orig_ctx_hidden, orig_ctx_hidden = 0;
	upframe->content_result = content;
	upframe->got_content_result = 1;
      }
      else
	content = upframe->content_result;

      result = get_content (upframe, content);
      return 0;
    }

    // The frame might be used as a variable value if preparsing is in
    // use (see the is_define_tag stuff in Frame.do_return). Note: The
    // frame is not thread local in this case.
    mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
			 void|RXML.Type type)
    {
      RXML.Frame upframe = ctx->frame;
#ifdef DEBUG
      if (!upframe || !upframe->is_user_tag)
	error ("Expected current frame to be UserTag, but it's %O.\n", upframe);
#endif

      mixed content;

      // Do the work in _eval, do_enter and do_return. Can't use the
      // do_* functions since the frame isn't thread local here.

      if (!upframe->got_content_result || args->eval) {
	// Switch to the set of scopes that were defined at entry of
	// the UserTag frame, to get static variable binding in the
	// content. This is poking in the internals; there ought to be
	// some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	mapping(string:mixed) orig_ctx_scopes = ctx->scopes;
	ctx->scopes = upframe->get_saved_scopes();
	mapping(RXML.Frame:array) orig_ctx_hidden = ctx->hidden;
	ctx->hidden = upframe->get_saved_hidden();

	RXML.PCode compiled_content = upframe->compiled_content;
	if (compiled_content && !compiled_content->is_stale())
	  content = compiled_content->eval (ctx);
	else if (upframe->compile)
	  [content, upframe->compiled_content] =
	    ctx->eval_and_compile (content_type, upframe->content_text);
	else
	  content = content_type->eval (upframe->content_text);

	// Switch back the set of scopes. This is poking in the
	// internals; there ought to be some sort of interface here.
	ctx->scopes = orig_ctx_scopes;
	ctx->hidden = orig_ctx_hidden;
	upframe->content_result = content;
	upframe->got_content_result = 1;
      }
      else
	content = upframe->content_result;

#if constant (_disable_threads)
      // If content is a SloppyDOM object, it's not thread safe when
      // it extends itself lazily, so a lock is necessary. We use the
      // interpreter lock since it's the cheapest one and since
      // get_content doesn't block anyway.
      Thread._Disabled threads_disabled = _disable_threads();
#endif
      mixed result = get_content (upframe, content);
#if constant (_disable_threads)
      threads_disabled = 0;
#endif

      // Note: result_type == content_type (except for the parser).
      return type && type != result_type ?
	type->encode (result, result_type) : result;
    }

    array _encode() {return ({content_type, upframe, args});}
    void _decode (array data) {create (@data);}

    string format_rxml_backtrace_frame (void|RXML.Context ctx)
    {
      if (ctx)
	// Used as an RXML.Value.
	return "<contents" + Roxen.make_tag_attributes (args) + ">";
      else
	// Used as a frame. The real contents frame is just above, so
	// suppress this one.
	return "";
    }

    string _sprintf (int flag)
    {
      return flag == 'O' && sprintf ("ExpansionFrame(contents in %O)", upframe);
    }
  }
}

// This tag set can't be shared since we look at compat_level in
// UserTagContents.
RXML.TagSet user_tag_contents_tag_set =
  RXML.TagSet (this_module(), "_user_tag", ({UserTagContents()}));

mapping(string:mapping(string:mixed)) usertag_saved_scopes = ([]);
mapping(string:mapping(RXML.Frame:array)) usertag_saved_hidden = ([]);

class CompDefCacheEntry (array(string|RXML.PCode) comp_def)
{
  int cache_count_memory (int|mapping opts)
  {
    return Pike.count_memory (opts, comp_def, @comp_def);
  }
}

class UserTag {
  inherit RXML.Tag;
  string name, lookup_name;
  int flags = RXML.FLAG_COMPILE_RESULT;
  RXML.Type content_type = RXML.t_xml;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });
  constant user_tag_comp_def_loc = "RXML UserTag PCode";

  // Note: We can't store the actual user tag definition directly in
  // this object; it won't work correctly in p-code since we don't
  // reparse the source and thus don't create a frame with the current
  // runtime tag definition. By looking up the definition in
  // RXML.Context.misc we can get the current definition even if it
  // changes in loops etc.

  void create(string _name, int moreflags) {
    if (_name) {
      name=_name;
      lookup_name = "tag\0" + name;
      flags |= moreflags;
    }
  }

  mixed _encode()
  {
    return ({ name, flags });
  }

  void _decode(mixed v)
  {
    [name, flags] = v;
    lookup_name = "tag\0" + name;
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags;
    RXML.TagSet local_tags;
    string scope_name;
    mapping vars;
    string raw_tag_text;
    int do_iterate;
#ifdef MODULE_LEVEL_SECURITY
    object check_security_object = this_module();
#endif

    constant is_user_tag = 1;
    constant is_contents_nest_tag = 1;

    string content_text;
    RXML.PCode compiled_content;

    mixed content_result;
    int got_content_result;

    protected string _saved_id;

    int compile;

    array tagdef;
    array(string|RXML.PCode) comp_def;

    string saved_id()
    {
      return _saved_id || (_saved_id = roxen.new_uuid_string());
    }

    mapping(string:mixed) get_saved_scopes()
    {
      string sid = saved_id();
      return usertag_saved_scopes[sid];
    }

    void set_saved_scopes(mapping(string:mixed) _scopes)
    {
      string sid = saved_id();
      usertag_saved_scopes[sid] = _scopes;
    }

    mapping(RXML.Frame:array) get_saved_hidden()
    {
      string sid = saved_id();
      return usertag_saved_hidden[sid];
    }

    void set_saved_hidden (mapping(RXML.Frame:array) _hidden)
    {
      string sid = saved_id();
      usertag_saved_hidden[sid] = ([]) || _hidden;
    }

    void create()
    {
      cache.cache_register (user_tag_comp_def_loc, "no_timings");
    }

    void destroy()
    {
      if (string sid = _saved_id) {
	m_delete (usertag_saved_scopes, sid);
	m_delete (usertag_saved_hidden, sid);
      }
    }

    array do_enter (RequestID id)
    {
      vars = 0;
      do_iterate = content_text ? -1 : 1;
      if ((tagdef = RXML_CONTEXT->misc[lookup_name]))
	if (tagdef[4]) {
	  local_tags = RXML.empty_tag_set;
	  additional_tags = 0;
	}
	else {
	  additional_tags = user_tag_contents_tag_set;
	  local_tags = 0;
	}
      return 0;
    }

    array do_return(RequestID id) {
      if (!tagdef) return ({propagate_tag()});
      RXML.Context ctx = RXML_CONTEXT;

      [array(string) src_def,
       mapping defaults,
       string def_scope_name,
       UserTag ignored,
       mapping(string:UserTagContents.ExpansionFrame) preparsed_contents_tags,
       RXML.Type comp_type,
       string comp_def_key] = tagdef;
      if (comp_def_key) {
	if (CompDefCacheEntry entry =
	    cache_lookup (user_tag_comp_def_loc, comp_def_key))
	  comp_def = entry->comp_def;
      }
      vars = defaults+args;
      scope_name = def_scope_name || name;

      if (!comp_def || comp_type != result_type)
	comp_def = src_def + ({});

      if (content_text)
	// A previously evaluated tag was restored.
	content = content_text;
      else {
	if(content && args->trimwhites)
	  content = String.trim_all_whites(content);

#if ROXEN_COMPAT <= 1.3
	if (stringp (comp_def[0])) {
	  if(id->conf->old_rxml_compat) {
	    array replace_from, replace_to;
	    if (flags & RXML.FLAG_EMPTY_ELEMENT) {
	      replace_from = map(indices(vars),Roxen.make_entity)+
		({"#args#"});
	      replace_to = values(vars)+
		({ Roxen.make_tag_attributes(vars)[1..] });
	    }
	    else {
	      replace_from = map(indices(vars),Roxen.make_entity)+
		({"#args#", "<contents>"});
	      replace_to = values(vars)+
		({ Roxen.make_tag_attributes(vars)[1..], content });
	    }
	    string c2;
	    c2 = replace(comp_def[0], replace_from, replace_to);
	    if(c2!=comp_def[0]) {
	      vars=([]);
	      return ({c2});
	    }
	  }
	}
#endif

	content_text = content || "";
	compile = ctx->make_p_code;
      }

      vars->args = Roxen.make_tag_attributes(vars)[1..];
      vars["rest-args"] = Roxen.make_tag_attributes(args - defaults)[1..];
      vars->contents = content;
      if (preparsed_contents_tags) vars += preparsed_contents_tags;
      ctx->set_id_misc ("last_tag_args", vars);
      got_content_result = 0;

      if (compat_level > 2.1) {
	// Save the scope state so that we can switch back in
	// <contents/>, thereby achieving static variable binding in
	// the content. This is poking in the internals; there ought
	// to be some sort of interface here.
	set_saved_scopes (ctx->scopes + ([]));
	set_saved_hidden (ctx->hidden + ([]));
      }
      else {
	set_saved_scopes (ctx->scopes);
	set_saved_hidden (ctx->hidden);
      }

      return comp_def;
    }

    array save() {return ({content_text, compiled_content});}
    void restore (array saved) {[content_text, compiled_content] = saved;}

    void exec_array_state_update()
    {
      tagdef[5] = result_type;

      if (string old_key = tagdef[6])
	cache_remove (user_tag_comp_def_loc, old_key);
      string comp_def_key = "cdk" + roxen.new_uuid_string();

      // Save comp_def in the RAM cache and use a string to reference
      // it. This avoids a circular reference involving PCode objects,
      // which in turn helps reduce garbage produced by user defined
      // tags by quite a lot.
      cache_set (user_tag_comp_def_loc, comp_def_key,
		 CompDefCacheEntry (comp_def));
      tagdef[6] = comp_def_key;

      RXML_CONTEXT->state_update();
    }

    string _sprintf ()
    {
      if (catch {return "UserTag.Frame(" + name + ")";})
	return "UserTag.Frame(?)";
    }
  }

  string _sprintf() {return "UserTag(" + name + ")";}
}

// A helper Scope class used when preparsing in TagDefine: Every
// variable in it has its own entity string as value, so that e.g.
// &_.contents; goes through the preparse step.
class IdentityVars
{
  inherit RXML.Scope;
  mixed `[] (string var, void|RXML.Context ctx,
	     void|string scope_name, void|RXML.Type type)
  {
    // Note: The fallback for scope_name here is not necessarily
    // correct, but this is typically only called from the rxml
    // parser, which always sets it.
    return ENCODE_RXML_XML ("&" + (scope_name || "_") + "." + var + ";", type);
  }
};
IdentityVars identity_vars = IdentityVars();

class TagDefine {
  inherit RXML.Tag;
  constant name = "define";
  constant flags = RXML.FLAG_DONT_RECOVER;
  RXML.Type content_type = RXML.t_xml (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags;

    constant is_define_tag = 1;
    constant is_contents_nest_tag = 1;
    array(string|RXML.PCode) def;
    mapping defaults;
    int do_iterate;

    // Used when we preparse.
    RXML.Scope|mapping vars;
    string scope_name;
    mapping(string:UserTagContents.ExpansionFrame) preparsed_contents_tags;

    array do_enter(RequestID id) {
      if (def)
	// A previously evaluated tag was restored.
	do_iterate = -1;
      else {
	preparsed_contents_tags = 0;
	do_iterate = 1;
	if(args->preparse) {
	  m_delete(args, "preparse");
	  if (compat_level >= 2.4) {
	    // Older rxml code might use the _ scope and don't expect
	    // it to be overridden in this situation.
	    if (args->tag || args->container) {
	      vars = identity_vars;
	      preparsed_contents_tags = ([]);
	    }
	    else
	      // Even though there won't be any postparse fill-in of
	      // &_.foo; etc we define a local scope for consistency.
	      // This way we can provide special values in the future,
	      // or perhaps fix postparse fill-in even for variables,
	      // if plugins, etc.
	      vars = ([]);
	    additional_tags = user_tag_contents_tag_set;
	    scope_name = args->scope;
	  }
	}
	else
	  content_type = RXML.t_xml;
      }
      return 0;
    }

    // Callbacks used by the <attrib> parser. These are intentionally
    // defined outside the scope of do_return to avoid getting dynamic
    // frames with cyclic references. This is only necessary for Pike
    // 7.2.

    private string add_default(Parser.HTML p, mapping m, string c,
			       mapping defaults, RequestID id)
    {
      if(m->name) defaults[m->name]=Roxen.parse_rxml(c, id);
      return "";
    };

    private array no_more_attrib (Parser.HTML p, void|string ignored)
    {
      p->add_container ("attrib", 0);
      p->_set_tag_callback (0);
      p->_set_data_callback (0);
      p->add_quote_tag ("?", 0, "?");
      p->add_quote_tag ("![CDATA[", 0, "]]");
      return 0;
    };

    private array data_between_attribs (Parser.HTML p, string d)
    {
      sscanf (d, "%[ \t\n\r]", string ws);
      if (d != ws) no_more_attrib (p);
      return 0;
    }

    private array quote_other_entities (Parser.HTML p, string s, void|string scope_name)
    {
      // We know that s ends with ";", so it must be
      // longer than the following prefixes if they match.
      if (sscanf (s, "&_.%c", int c) && c != '.' ||
	  (scope_name &&
	   sscanf (s, "&" + replace (scope_name, "%", "%%") + ".%c", c) &&
	   c != '.'))
	return 0;
      return ({"&:", s[1..]});
    }

    array do_return(RequestID id) {
      string n;
      RXML.Context ctx = RXML_CONTEXT;

      if(n=args->variable) {
	if(args->trimwhites) content=String.trim_all_whites((string)content);
	RXML.user_set_var(n, content, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
#if ROXEN_COMPAT <= 1.3
	n = id->conf->old_rxml_compat?lower_case(n):n;
#endif
	int moreflags=0;
	if(args->tag) {
	  moreflags = RXML.FLAG_EMPTY_ELEMENT;
	  m_delete(args, "tag");
	} else
	  m_delete(args, "container");

	if (!def) {
	  defaults=([]);

#if ROXEN_COMPAT <= 1.3
	  if(id->conf->old_rxml_compat)
	    foreach( args; string arg; string val )
	      if( arg[..7] == "default_" )
	      {
		defaults[arg[8..]] = val;
		old_rxml_warning(id, "define attribute "+arg,"attrib container");
		m_delete( args, arg );
	      }
#endif

	  if(!content) content = "";

	  Parser.HTML p;
	  if( compat_level > 2.1 ) {
	    p = Roxen.get_xml_parser();
	    p->add_container ("attrib", ({add_default, defaults, id}));
	    // Stop parsing for attrib tags when we reach something else
	    // than whitespace and comments.
	    p->_set_tag_callback (no_more_attrib);
	    p->_set_data_callback (data_between_attribs);
	    p->add_quote_tag ("?", no_more_attrib, "?");
	    p->add_quote_tag ("![CDATA[", no_more_attrib, "]]");
	  }
	  else
	    p = Parser.HTML()->add_container("attrib", ({add_default, defaults, id}));

	  if (preparsed_contents_tags) {
	    // Translate the &_internal_.4711; references to
	    // &_.__contents__17;. This is necessary since the numbers
	    // in the _internal_ scope is only unique within the
	    // current parse context. Otoh it isn't safe to use
	    // &_.__contents__17; during preparse since the current
	    // scope varies.
	    int id = 0;
	    foreach (preparsed_contents_tags;
		     string var; UserTagContents.ExpansionFrame frame) {
	      preparsed_contents_tags["__contents__" + ++id] = frame;
	      m_delete (preparsed_contents_tags, var);
	      p->add_entity ("_internal_." + var, "&_.__contents__" + id + ";");
	      m_delete (ctx->scopes->_internal_, var);
	    }

	    // Quote all entities except those handled above and those
	    // in the current scope, to avoid repeated evaluation of
	    // them in the expansion phase in UserTag. We use the rxml
	    // special "&:foo;" quoting syntax.
	    p->_set_entity_callback (quote_other_entities);
	    if (args->scope) p->set_extra (args->scope);
	  }

	  content = p->finish (content)->read();

	  if(args->trimwhites) {
	    content=String.trim_all_whites(content);
	    m_delete (args, "trimwhites");
	  }

#ifdef DEBUG
	  if (defaults->_debug_) {
	    moreflags |= RXML.FLAG_DEBUG;
	    m_delete (defaults, "_debug_");
	  }
#endif

#if ROXEN_COMPAT <= 1.3
	  if(id->conf->old_rxml_compat)
	    content = replace( content, indices(args), values(args) );
#endif
	  def = ({content});
	}

	string lookup_name = "tag\0" + n;
	array oldtagdef;
	UserTag user_tag;
	if ((oldtagdef = ctx->misc[lookup_name]) &&
	    !((user_tag = oldtagdef[3])->flags & RXML.FLAG_EMPTY_ELEMENT) ==
	    !(moreflags & RXML.FLAG_EMPTY_ELEMENT)) // Redefine.
	  ctx->set_misc (lookup_name, ({def, defaults, args->scope, user_tag,
					preparsed_contents_tags, 0, 0}));
	else {
	  user_tag = UserTag (n, moreflags);
	  ctx->set_misc (lookup_name, ({def, defaults, args->scope, user_tag,
					preparsed_contents_tags, 0, 0}));
	  ctx->add_runtime_tag(user_tag);
	}
	return 0;
      }

      if (n=args->if) {
	ctx->set_misc ("if\0" + n, UserIf (n, content));
	return 0;
      }

      if (n=args->name) {
	ctx->set_misc (n, content);
	old_rxml_warning(id, "attempt to define name ","variable");
	return 0;
      }

      parse_error("No tag, variable, if or container specified.\n");
    }

    array save() {return ({def, defaults, preparsed_contents_tags});}
    void restore (array saved) {[def, defaults, preparsed_contents_tags] = saved;}
  }
}

class TagUndefine {
  inherit RXML.Tag;
  int flags = RXML.FLAG_EMPTY_ELEMENT;
  constant name = "undefine";
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      string n;

      if(n=args->variable) {
	RXML_CONTEXT->user_delete_var(n, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
	m_delete (RXML_CONTEXT->misc, "tag\0" + n);
	RXML_CONTEXT->remove_runtime_tag(n);
	return 0;
      }

      if (n=args->if) {
	m_delete(RXML_CONTEXT->misc, "if\0" + n);
	return 0;
      }

      if (n=args->name) {
	m_delete(RXML_CONTEXT->misc, args->name);
	return 0;
      }

      parse_error("No tag, variable, if or container specified.\n");
    }
  }
}

class Tracer
{
  RequestID id;
  function(string,mixed,int:void) orig_trace_enter;
  function(string,int:void) orig_trace_leave;

  protected void create (RequestID id)
  {
    // NB: We're not using RXML_CONTEXT->set_id_misc here since that'd
    // give us unencodable function references in the p-code. The
    // effect is that if a <trace> tag gets completely cached, it
    // won't trace anything. It's unlikely to be a problem though,
    // since if there's an uncached tag inside it, it won't be cached.
    Tracer::id = id;
    orig_trace_enter = id->misc->trace_enter;
    orig_trace_leave = id->misc->trace_leave;
    id->misc->trace_enter = trace_enter_ol;
    id->misc->trace_leave = trace_leave_ol;
  }

  protected void destroy()
  {
    if (id) {
      id->misc->trace_enter = orig_trace_enter;
      id->misc->trace_leave = orig_trace_leave;
    }
  }

  // Note: \n is used sparingly in output to make it look nice even
  // inside <pre>.
  string resolv="<ol style='padding-left: 3ex'>";
  int level;

  string _sprintf()
  {
    return "Tracer()";
  }

#if constant(gethrtime) || constant(gethrvtime)
#define HAVE_CLOCKS

#if constant (gethrtime)
  mapping rtimes = ([]);
#endif
#if constant (gethrvtime)
  mapping vtimes = ([]);
#endif

  local void start_clock (int timestamp)
  {
#if constant (gethrvtime)
    // timestamp is cputime.
#if constant (gethrtime)
    rtimes[level] = gethrtime();
#endif
    vtimes[level] = (timestamp || gethrvtime()) - id->misc->trace_overhead;
#else
    // timestamp is realtime.
    rtimes[level] = (timestamp || gethrtime()) - id->misc->trace_overhead;
#endif
  }

  local string stop_clock (int timestamp)
  {
    int hrnow, hrvnow;

#if constant (gethrvtime)
    // timestamp is cputime.
#if constant (gethrtime)
    hrnow = gethrtime();
#endif
    hrvnow = (timestamp || gethrvtime()) - id->misc->trace_overhead;
#else
    // timestamp is realtime.
    hrnow = (timestamp || gethrtime()) - id->misc->trace_overhead;
#endif

    return ({
      hrvnow && ("CPU " + Roxen.format_hrtime (hrvnow - vtimes[level])),
      hrnow && ("real " + Roxen.format_hrtime (hrnow - rtimes[level]))
    }) * ", ";
  }
#endif	// constant (gethrtime) || constant (gethrvtime)

  void trace_enter_ol(string type, function|object thing, int timestamp)
  {
    if (orig_trace_enter) orig_trace_enter (type, thing, timestamp);

    level++;

    if (thing) {
      string name = Roxen.get_modfullname (Roxen.get_owning_module (thing));
      if (name)
	name = "module " + name;
      else if (Configuration conf = Roxen.get_owning_config (thing))
	name = "configuration " + conf->query_name();
      else
	name = sprintf ("object %O", thing);
      type += " in " + name;
    }

    resolv += "<li>" + Roxen.html_encode_string (type) +
      "<ol style='padding-left: 3ex'>";
#ifdef HAVE_CLOCKS
    start_clock (timestamp);
#endif
  }

  void trace_leave_ol(string desc, int timestamp)
  {
    resolv += "</ol>";
    if (sizeof (desc))
      resolv += Roxen.html_encode_string(desc);
#ifdef HAVE_CLOCKS
    if (sizeof (desc)) resolv += "<br />";
    resolv += "<i>Time: " + stop_clock (timestamp) + "</i>";
#endif
    resolv += "</li>\n";

    level--;

    if (orig_trace_leave) orig_trace_leave (desc, timestamp);
  }

  int endtime;

  string res()
  {
    endtime = HRTIME();
    while(level>0)
      trace_leave_ol("Trace nesting inconsistency!", endtime);
    return resolv + "</ol>";
  }
}

class TagTrace {
  inherit RXML.Tag;
  constant name = "trace";

  class Frame {
    inherit RXML.Frame;
    Tracer t;

    array do_enter(RequestID id) {
      NOCACHE();
      t = Tracer(id);
#ifdef HAVE_CLOCKS
      t->start_clock (HRTIME());
#endif
      return 0;
    }

    array do_return(RequestID id) {
      result = "<h3>Tracing</h3>" + content +
	"<h3>Trace report</h3>" + t->res();
#ifdef HAVE_CLOCKS
      result += "<h3>Total time: " + t->stop_clock (t->endtime) + "</h3>";
#endif
      destruct (t);
      return 0;
    }
  }
}

class TagNoParse {
  inherit RXML.Tag;
  constant name = "noparse";
  RXML.Type content_type = RXML.t_same;
  class Frame {
    inherit RXML.Frame;
  }
}

class TagPINoParse {
  inherit TagNoParse;
  constant flags = RXML.FLAG_PROC_INSTR;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      result = content[1..];
      return 0;
    }
  }
}

class TagPICData
{
  inherit RXML.Tag;
  constant name = "cdata";
  constant flags = RXML.FLAG_PROC_INSTR;
  RXML.Type content_type = RXML.t_text;
  class Frame
  {
    inherit RXML.Frame;
    array do_return (RequestID id)
    {
      result_type = RXML.t_text;
      result = content[1..];
      return 0;
    }
  }
}

class TagEval {
  inherit RXML.Tag;
  constant name = "eval";

  RXML.Type content_type = RXML.t_any_text (RXML.PXml);
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      return ({ content });
    }
  }
}

class TagNoOutput {
  inherit RXML.Tag;
  constant name = "nooutput";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  // RXML.t_ignore is a special type made only for this situation. It
  // accepts and ignores all content and allows free text but still
  // evaluates all rxml tags (for side effects).
  RXML.Type content_type =
    compat_level < 5.0 ? ::content_type : RXML.t_ignore (RXML.PXml);
  array(RXML.Type) result_types =
    compat_level < 5.0 ? ::result_types : ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_return() {
      return 0;
    }
  }
}

class TagStrLen {
  inherit RXML.Tag;
  constant name = "strlen";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type =
    compat_level < 5.0 ? RXML.t_xml (RXML.PXml) : RXML.t_any_text (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_int}) + ::result_types;

  class Frame {
    inherit RXML.Frame;

    array do_return() {
      if(!stringp(content)) {
	result=0;
      }
      else
	result = strlen(content);
      if (result_type != RXML.t_int)
	result = result_type->encode (result, RXML.t_int);
      return 0;
    }
  }
}

class TagElements
{
  inherit RXML.Tag;
  constant name = "elements";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = (["variable": RXML.t_text (RXML.PEnt)]);
  array(RXML.Type) result_types = ({RXML.t_int}) + ::result_types;

  class Frame
  {
    inherit RXML.Frame;
    array do_enter()
    {
      mixed var;
      if (zero_type (var = RXML.user_get_var (args->variable, args->scope)))
	parse_error ("Variable %O doesn't exist.\n", args->variable);
      if (objectp (var) && var->_sizeof)
	result = var->_sizeof();
      else if (arrayp (var) || mappingp (var) || multisetp (var))
	result = sizeof (var);
      else
	result = 1;
      if (result_type != RXML.t_int)
	result = result_type->encode (result, RXML.t_int);
      return 0;
    }
  }
}

class TagCase {
  inherit RXML.Tag;
  constant name = "case";

  class Frame {
    inherit RXML.Frame;
    int cap;
    array do_enter() {cap = 0; return 0;}
    array do_process(RequestID id) {
      if(args->case) {
	string op;
	switch(lower_case(args->case)) {
	  case "lower":
	    if (content_type->lower_case)
	      return ({content_type->lower_case (content)});
	    op = "lowercased";
	    break;
	  case "upper":
	    if (content_type->upper_case)
	      return ({content_type->upper_case (content)});
	    op = "uppercased";
	    break;
	  case "capitalize":
	    if (content_type->capitalize) {
	      if(cap) return ({content});
	      if (sizeof (content)) cap=1;
	      return ({content_type->capitalize (content)});
	    }
	    op = "capitalized";
	    break;
	  default:
	    if (compat_level > 2.1)
	      parse_error ("Invalid value %O to the case argument.\n", args->case);
	}
	if (compat_level > 2.1)
	  parse_error ("Content of type %s doesn't handle being %s.\n",
		       content_type->name, op);
      }
      else
	if (compat_level > 2.1)
	  parse_error ("Argument \"case\" is required.\n");

#if ROXEN_COMPAT <= 1.3
      if(args->lower) {
	content = lower_case(content);
	old_rxml_warning(id, "attribute lower","case=lower");
      }
      if(args->upper) {
	content = upper_case(content);
	old_rxml_warning(id, "attribute upper","case=upper");
      }
      if(args->capitalize){
	content = capitalize(content);
	old_rxml_warning(id, "attribute capitalize","case=capitalize");
      }
#endif
      return ({ content });
    }
  }
}

class FrameIf {
  inherit RXML.Frame;
  int do_iterate;

  array do_enter(RequestID id) {
    int and = 1;
    do_iterate = -1;

    if(args->not) {
      m_delete(args, "not");
      do_enter(id);
      do_iterate=do_iterate==1?-1:1;
      return 0;
    }

    if(args->or)  { and = 0; m_delete( args, "or" ); }
    if(args->and) { and = 1; m_delete( args, "and" ); }
    mapping plugins=get_plugins();
    mapping(string:mixed) defs = RXML_CONTEXT->misc;

    int ifval=0, plugin_found;
    foreach(args; string s; string argval)
      if (object(RXML.Tag)|object(UserIf) plugin =
	  plugins[s] || defs["if\0" + s]) {
	plugin_found = 1;
	TRACE_ENTER("Calling if#" + plugin->plugin_name, 0);
	ifval = plugin->eval( argval, id, args, and, s );
	TRACE_LEAVE("");
	if(ifval) {
	  if(!and) {
	    do_iterate = 1;
	    return 0;
	  }
	}
	else
	  if(and)
	    return 0;
      }

    if (!plugin_found && compat_level > 4.5)
      parse_error ("No known <if> plugin specified.\n");

    if(ifval) {
      do_iterate = 1;
      return 0;
    }
    return 0;
  }

  array do_return(RequestID id) {
    if(do_iterate==1) {
      _ok = 1;
      result = content;
    }
    else
      _ok = 0;
    return 0;
  }
}

class TagIf {
  inherit RXML.Tag;
  constant name = "if";
  int flags = RXML.FLAG_SOCKET_TAG | cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});
  class Frame {
    inherit FrameIf;
  }
}

class TagElse {
  inherit RXML.Tag;
  constant name = "else";
  int flags = cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});
  class Frame {
    inherit RXML.Frame;
    int do_iterate;
    array do_enter(RequestID id) {
      do_iterate= _ok ? -1 : 1;
      return 0;
    }
  }
}

class TagThen {
  inherit RXML.Tag;
  constant name = "then";
  int flags = cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});
  class Frame {
    inherit FrameIf;
    array do_enter(RequestID id) {
      do_iterate= _ok ? 1 : -1;
      return 0;
    }
  }
}

class TagElseif {
  inherit RXML.Tag;
  constant name = "elseif";
  int flags = cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame {
    inherit FrameIf;
    int last;

    array do_enter(RequestID id) {
      last=_ok;
      do_iterate = -1;
      if(last) return 0;
      return ::do_enter(id);
    }

    array do_return(RequestID id) {
      if(last) return 0;
      return ::do_return(id);
    }

    mapping(string:RXML.Tag) get_plugins() {
      return RXML_CONTEXT->tag_set->get_plugins ("if");
    }
  }
}

class TagTrue {
  inherit RXML.Tag;
  constant name = "true";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      _ok = 1;
    }
  }
}

class TagFalse {
  inherit RXML.Tag;
  constant name = "false";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      _ok = 0;
    }
  }
}

class TagCond
{
  inherit RXML.Tag;
  constant name = "cond";
  RXML.Type content_type = RXML.t_nil (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});

  class TagCase
  {
    inherit RXML.Tag;
    constant name = "case";
    array(RXML.Type) result_types = ({RXML.t_nil});

    class Frame
    {
      inherit FrameIf;

      array do_enter (RequestID id)
      {
	do_iterate = -1;
	if (up->matched) return 0;
	content_type = up->result_type (RXML.PXml);
	return ::do_enter (id);
      }

      array do_return (RequestID id)
      {
	::do_return (id);
	if (up->matched) return 0; // Does this ever happen?
	up->result = result;
	if(_ok) up->matched = 1;
	result = RXML.Void;
	return 0;
      }

      // Must override this since it's used by FrameIf.
      mapping(string:RXML.Tag) get_plugins()
	{return RXML_CONTEXT->tag_set->get_plugins ("if");}
    }
  }

  class TagDefault
  {
    inherit RXML.Tag;
    constant name = "default";
    array(RXML.Type) result_types = ({RXML.t_nil});

    class Frame
    {
      inherit RXML.Frame;
      int do_iterate;

      array do_enter()
      {
	if (up->matched) {
	  do_iterate = -1;
	  return 0;
	}
	do_iterate = 1;
	content_type = up->result_type (RXML.PNone);
	return 0;
      }

      array do_return()
      {
	up->default_data = content;
	return 0;
      }
    }
  }

  RXML.TagSet cond_tags =
    RXML.shared_tag_set (global::this, "cond", ({TagCase(), TagDefault()}));

  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet local_tags = cond_tags;
    string default_data;
    int(0..1) matched;

    array do_enter (RequestID id) {
      matched = 0;
      return 0;
    }

    array do_return (RequestID id)
    {
      if(matched)
	_ok = 1;
      else if (default_data) {
	_ok = 0;
	return ({RXML.parse_frame (result_type (RXML.PXml), default_data)});
      }
      return 0;
    }
  }
}

class TagEmit {
  inherit RXML.Tag;
  constant name = "emit";
  int flags = RXML.FLAG_SOCKET_TAG | cache_static_in_2_5();
  mapping(string:RXML.Type) req_arg_types = ([ "source":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "scope":RXML.t_text(RXML.PEnt),
					       "maxrows":RXML.t_int(RXML.PEnt),
					       "skiprows":RXML.t_int(RXML.PEnt),
					       "rowinfo":RXML.t_text(RXML.PEnt), // t_var
					       "do-once":RXML.t_text(RXML.PEnt), // t_bool
					       "filter":RXML.t_text(RXML.PEnt),  // t_list
					       "filter-exclude":RXML.t_text(RXML.PEnt),  // t_list
					       "sort":RXML.t_text(RXML.PEnt),    // t_list
					       "remainderinfo":RXML.t_text(RXML.PEnt), // t_var
  ]);
  array(string) emit_args = indices( req_arg_types+opt_arg_types );
  RXML.Type def_arg_type = RXML.t_text(RXML.PNone);
  array(RXML.Type) result_types = ({RXML.t_any});

  int(0..1) should_filter(mapping vs, mapping filter, mapping filter_exclude) {
    RXML.Context ctx = RXML_CONTEXT;
    if(filter) {
      foreach(filter; string v; string f) {
	string|object val = vs[v];
	if(objectp(val))
	  val = val->rxml_const_eval ? val->rxml_const_eval(ctx, v, "") :
	    val->rxml_var_eval(ctx, v, "", RXML.t_text);
	if(!val)
	  return 1;
	if(!glob(f, val))
	  return 1;
      }
    }
    if(filter_exclude) {
      foreach(filter_exclude; string v; string f) {
	string|object val = vs[v];
	if(objectp(val))
	  val = val->rxml_const_eval ? val->rxml_const_eval(ctx, v, "") :
	    val->rxml_var_eval(ctx, v, "", RXML.t_text);
	if(val && glob(f, val))
	  return 1;
      }
    }
    return 0;
  }

  class TagDelimiter {
    inherit RXML.Tag;
    constant name = "delimiter";
    int flags = cache_static_in_2_5();

    protected int(0..1) more_rows(TagEmit.Frame emit_frame) {
      object|array res = emit_frame->res;
      if(objectp(res)) {
	while(res->peek() && should_filter(res->peek(), emit_frame->filter, emit_frame->filter_exclude))
	  res->skip_row();
	return !!res->peek();
      }
      if(!sizeof(res)) return 0;
      foreach(res[emit_frame->real_counter..], mapping v) {
	if(!should_filter(v, emit_frame->filter, emit_frame->filter_exclude))
	  return 1;
      }
      return 0;
    }

    class Frame {
      inherit RXML.Frame;
      TagEmit.Frame parent_frame;

      int do_iterate;

      array do_enter (RequestID id) {
	do_iterate = -1;
	object|array res = parent_frame->res;
	if(!parent_frame->filter && !parent_frame->filter_exclude) {
	  if (objectp(res) ? res->peek() :
	      parent_frame->counter < sizeof(res))
	    do_iterate = 1;
	}
	else {
	  if (!(parent_frame->args->maxrows &&
		parent_frame->args->maxrows == parent_frame->counter) &&
	      more_rows(parent_frame))
	    do_iterate = 1;
	}
	return 0;
      }
    }
  }

  RXML.TagSet internal =
    RXML.shared_tag_set (global::this, "emit", ({ TagDelimiter() }) );

  protected class VarsCounterWrapper (RXML.Scope vars, int counter)
  // Used when the emit source returns a variable scope that is a
  // Scope object without `[]=. In that case we have to wrap it to
  // add the builtin _.counter variable.
  {
    inherit RXML.Scope;

    mixed `[] (string var, void|RXML.Context ctx,
	       void|string scope_name, void|RXML.Type type)
    {
      return var == "counter" ?
	ENCODE_RXML_INT (counter, type) :
	vars->`[] (var, ctx, scope_name, type);
    }

    array(string) _indices (void|RXML.Context ctx, void|string scope_name)
    {
      return vars->_indices (ctx, scope_name) | ({"counter"});
    }

    // No need to implement `[]= and _m_delete - the vars scope
    // doesn't implement them anyway (at least not `[]=) so we're
    // effectively read-only anyway.
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;
    string scope_name;
    mapping|RXML.Scope vars;

    int counter;
    // The visible counter.

    int real_counter;
    // The actual index of the current scope in res. Only used when
    // filtering an array result.

    object plugin;
    array(mapping(string:mixed))|object res;
    mapping filter;
    mapping filter_exclude;

    array expand(object res) {
      array ret = ({});
      do {
	ret += ({ res->get_row() });
      } while(ret[-1]!=0);
      return ret[..sizeof(ret)-2];
    }

    array do_enter(RequestID id) {
      if(!(plugin=get_plugins()[args->source]))
	parse_error("The emit source %O doesn't exist.\n", args->source);
      scope_name=args->scope||args->source;
      vars = (["counter":0]);
      counter = 0;

#if 0
#ifdef DEBUG
      tag_debug ("Got emit plugin %O for source %O\n", plugin, args->source);
#endif
#endif
      TRACE_ENTER("Fetch emit dataset for source "+args->source, 0);
      PROF_ENTER( args->source, "emit" );
      plugin->eval_args( args, 0, 0, emit_args );
      res = plugin->get_dataset(args, id);
      PROF_LEAVE( args->source, "emit" );
      TRACE_LEAVE("");
#if 0
#ifdef DEBUG
      if (objectp (res))
	tag_debug ("Emit plugin %O returned data set object %O\n",
		   plugin, res);
      else if (arrayp (res))
	tag_debug ("Emit plugin %O returned data set with %d items\n",
		   plugin, sizeof (res));
#endif
#endif

      if(args->skiprows && plugin->skiprows)
	m_delete(args, "skiprows");

      if(args->maxrows && plugin->maxrows)
	  m_delete(args, "maxrows");

      // Parse the filter and filter-exclude arguments
      if(args->filter) {
	array pairs = args->filter / ",";
	filter = ([]);
	foreach( pairs, string pair) {
	  string v,g;
	  if( sscanf(pair, "%s=%s", v,g) != 2)
	    continue;
	  v = String.trim_whites(v);
	  if(g != "*"*sizeof(g))
	    filter[v] = g;
	}
	if(!sizeof(filter)) filter = 0;
      }
      if(args["filter-exclude"]) {
 	array pairs = args["filter-exclude"] / ",";
 	filter_exclude = ([]);
 	foreach( pairs, string pair) {
 	  string v,g;
 	  if( sscanf(pair, "%s=%s", v,g) != 2)
 	    continue;
 	  v = String.trim_whites(v);
 	  if(g != "*"*sizeof(g))
 	    filter_exclude[v] = g;
 	}
 	if(!sizeof(filter_exclude)) filter_exclude = 0;
      }

      if(objectp(res))
	if(args->sort ||
	   (args->skiprows && args->skiprows<0) ||
	   args->rowinfo ||
	   args->remainderinfo ||
	   args->reverse)
	  // Expand the object into an array of mappings if sort,
	  // negative skiprows, rowinfo or reverse is used. These
	  // arguments should be intercepted, dealt with and removed
	  // by the plugin, should it have a more clever solution.
	  //
	  // Note that it would be possible to use a
	  // expand_on_demand-solution where a value object is stored
	  // as the rowinfo value and, if used inside the loop,
	  // triggers an expansion. That would however force us to
	  // jump to another iterator function. Let's save that
	  // complexity enhancement until later.
	  res = expand(res);
	else if(filter || filter_exclude) {
	  do_iterate = object_filter_iterate;
	  return 0;
	}
	else {
	  do_iterate = object_iterate;

	  if(args->skiprows) {
	    int loop = args->skiprows;
	    while(loop--)
	      res->skip_row();
	  }

	  return 0;
	}

      if(arrayp(res)) {
	if(args->sort && !plugin->sort)
	  res = Roxen.rxml_emit_sort (res, args->sort, compat_level);

	if(filter || filter_exclude) {

	  // If rowinfo or negative skiprows are used we have
	  // to do filtering in a loop of its own, instead of
	  // doing it during the emit loop.
	  if(args->rowinfo || (args->skiprows && args->skiprows<0)) {
	    for(int i; i<sizeof(res); i++)
	      if(should_filter(res[i], filter, filter_exclude)) {
		res = res[..i-1] + res[i+1..];
		i--;
	      }
	    filter = 0;
	    filter_exclude = 0;
	  }
	  else {

	    // If skiprows is to be used we must only count
	    // the rows that wouldn't be filtered in the
	    // emit loop.
	    if(args->skiprows) {
	      int skiprows = args->skiprows;
	      if(skiprows > sizeof(res))
		res = ({});
	      else {
		int i;
		for(; i<sizeof(res) && skiprows; i++)
		  if(!should_filter(res[i], filter, filter_exclude))
		    skiprows--;
		res = res[i..];
	      }
	    }

	    real_counter = 0;
	    do_iterate = array_filter_iterate;
	  }
	}

	// We have to check the filter again, since it
	// could have been zeroed in the last if statement.
	if(!filter && !filter_exclude) {

	  if(args->skiprows) {
	    if(args->skiprows<0) args->skiprows = sizeof(res) + args->skiprows;
	    res=res[args->skiprows..];
	  }

 	  if(args->remainderinfo)
	    RXML.user_set_var(args->remainderinfo, args->maxrows?
			      max(sizeof(res)-args->maxrows, 0): 0);

	  if(args->maxrows) res=res[..args->maxrows-1];
	  if(args->rowinfo)
	    RXML.user_set_var(m_delete(args, "rowinfo"), sizeof(res));
	  if(args["do-once"] && sizeof(res)==0) res=({ ([]) });

	  do_iterate = array_iterate;
	}

	if( args->reverse )
	  res = reverse( res );

	return 0;
      }

      parse_error("Wrong return type from emit source plugin.\n");
    }

    int(0..1) do_once_more() {
      if(counter || !args["do-once"]) return 0;
      vars = (["counter":1]);
      counter = 1;
      return 1;
    }

    function do_iterate;

    protected mapping|RXML.Scope vars_with_counter (mapping|RXML.Scope vars)
    {
      if (objectp (vars)) {
	if (vars->`[]=)
	  vars->`[]= ("counter", counter, RXML_CONTEXT, scope_name || "_");
	else
	  vars = VarsCounterWrapper (vars, counter);
      }
      else
	vars->counter = counter;
      return vars;
    }

    int(0..1) object_iterate(RequestID id) {
      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if ((vars = res->get_row())) {
	counter++;
	vars = vars_with_counter (vars);
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) object_filter_iterate(RequestID id) {
      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if(args->skiprows && args->skiprows>0)
	while(args->skiprows-->-1)
	  while((vars=res->get_row()) &&
		should_filter(vars, filter, filter_exclude));
      else
	while((vars=res->get_row()) &&
	      should_filter(vars, filter, filter_exclude));

      if (vars) {
	counter++;
	vars = vars_with_counter (vars);
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) array_iterate(RequestID id) {
      if(counter>=sizeof(res)) return 0;
      vars = vars_with_counter (res[counter++]);
      return 1;
    }

    int(0..1) array_filter_iterate(RequestID id) {
      if(real_counter>=sizeof(res)) return do_once_more();

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      while(should_filter(res[real_counter++], filter, filter_exclude))
	if(real_counter>=sizeof(res)) return do_once_more();

      counter++;
      vars = vars_with_counter (res[real_counter-1]);
      return 1;
    }

    array do_return(RequestID id) {
      result = content;

      int rounds = counter - !!args["do-once"];
      _ok = !!rounds;

      if(args->remainderinfo) {
	if(args->filter || args["filter-exclude"]) {
	  int rem;
	  if(arrayp(res)) {
	    foreach(res[real_counter+1..], mapping v)
	      if(!should_filter(v, filter, filter_exclude))
		rem++;
	  } else {
	    mapping v;
	    while( v=res->get_row() )
	      if(!should_filter(v, filter, filter_exclude))
		rem++;
	  }
	  RXML.user_set_var(args->remainderinfo, rem);
	}
	else if( do_iterate == object_iterate )
	  RXML.user_set_var(args->remainderinfo, res->num_rows_left());
      }

      do_iterate = 0;
      return 0;
    }
 
    protected void cleanup()
    {
      res = 0;
      ::cleanup();
    }
  }
}

class TagComment {
  inherit RXML.Tag;
  constant name = "comment";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  // This content type is relevant only with the old "preparse" attribute.
  RXML.Type content_type = RXML.t_ignore (RXML.PXml);

  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    int do_iterate;
    array do_enter() {
      if (args && args->preparse)
	do_iterate = 1;
      else {
	do_iterate = -1;
	// Argument existence can be assumed static, so we can set
	// FLAG_MAY_CACHE_RESULT here.
	flags |= RXML.FLAG_MAY_CACHE_RESULT;
      }
      return 0;
    }
    array do_return = ({});
  }
}

class TagPIComment {
  inherit TagComment;
  constant flags = RXML.FLAG_PROC_INSTR|RXML.FLAG_MAY_CACHE_RESULT;
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
}


// ---------------------- If plugins -------------------

class UserIf
{
  constant name = "if";
  string plugin_name;
  string|RXML.RenewablePCode rxml_code;

  void create(string pname, string code) {
    plugin_name = pname;
    rxml_code = code;
  }

  int eval(string ind, RequestID id) {
    int otruth, res;
    string tmp;

    TRACE_ENTER("user defined if argument "+plugin_name, UserIf);
    otruth = _ok;
    _ok = -2;
    if (objectp (rxml_code))
      tmp = rxml_code->eval (RXML_CONTEXT);
    else
      [tmp, rxml_code] =
	RXML_CONTEXT->eval_and_compile (RXML.t_html (RXML.PXml), rxml_code, 1);
    res = _ok;
    _ok = otruth;

    TRACE_LEAVE("");

    if(ind==plugin_name && res!=-2)
      return res;

    return (ind==tmp);
  }

  // These objects end up in RXML_CONTEXT->misc and might therefore be
  // cached persistently.
  constant is_RXML_encodable = 1;
  array _encode() {return ({plugin_name, rxml_code});}
  void _decode (array data) {[plugin_name, rxml_code] = data;}
}

class IfIs
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  constant case_sensitive = 0;
  string|array source (RequestID id, string s, void|int check_set_only);

  int(0..1) eval( string value, RequestID id, mapping args )
  {
    if (args["expr-cache"]) {
      CACHE((int) args["expr-cache"]);
    } else {
      if(cache != -1)
	CACHE(cache);
    }
    array arr=value/" ";
    mixed var;
    if (sizeof (arr) < 2) {
      var = source (id, arr[0], 1);
      if (!arrayp (var) && !mappingp (var) && !multisetp (var))
	return !!var;
    }
    else {
      var=source(id, arr[0]);
      if (!arrayp (var) && !mappingp (var) && !multisetp (var))
	return do_check(var, arr, id);
    }

    int(0..1) recurse_check(array|mapping|multiset var, array arr, RequestID id) {
      foreach(arrayp (var) ? var :
	      mappingp (var) ? values (var) :
	      indices (var),
	      mixed val) {
	if(arrayp(val) || mappingp (val) || multisetp (val)) {
	  if(recurse_check(val, arr, id)) return 1;
	  continue;
	}
	if(do_check(RXML.t_text->encode(val), arr, id))
	  return 1;
      }
      return 0;
    };

    return recurse_check(var, arr, id);
  }

  int(0..1) do_check( string var, array arr, RequestID id) {
    if(sizeof(arr)<2) return !!var;

    if(!var)
      if (compat_level == 2.2)
	// This makes unset variables be compared as if they had the
	// empty string as value. I can't understand the logic behind
	// it, but it makes the test <if variable="form.foo is "> be
	// true if form.foo is unset, a state very different from
	// having the empty string as a value. To be on the safe side
	// we're still bug compatible in 2.2 compatibility mode (but
	// both earlier and later releases does the correct thing
	// here). /mast
	var = "";
      else
	// If var is zero then it had no value. Thus it's always
	// different from any value it might be compared with.
	return arr[1] == "!=";

    string is;

    // FIXME: This code should be adapted to compare arbitrary values.

    if(case_sensitive) {
      is=arr[2..]*" ";
    }
    else {
      var = lower_case( var );
      is=lower_case(arr[2..]*" ");
    }

    if(arr[1]=="==" || arr[1]=="=" || arr[1]=="is")
      return ((is==var)||glob(is,var)||
            sizeof(filter( is/",", glob, var )));
    if(arr[1]=="!=") return is!=var;

    int|float n_var, n_is;
    if ((sscanf (var, "%d%*c", n_var) == 1 ||
	 sscanf (var, "%f%*c", n_var) == 1) &&
	(sscanf (is, "%d%*c", n_is) == 1 ||
	 sscanf (is, "%f%*c", n_is) == 1)) {
      if(arr[1]=="<") return n_var < n_is;
      if(arr[1]==">") return n_var > n_is;
      if(arr[1]=="<=") return n_var <= n_is;
      if(arr[1]==">=") return n_var >= n_is;
    }
    else {
      if(arr[1]=="<") return (var<is);
      if(arr[1]==">") return (var>is);
      if(arr[1]=="<=") return (var<=is);
      if(arr[1]==">=") return (var>=is);
    }

    return !!source(id, arr*" ");
  }
}

class IfMatch
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  string|array source(RequestID id);

  int eval( string is, RequestID id, mapping args ) {
    array|string value=source(id);
    if (args["expr-cache"]) {
      CACHE((int) args["expr-cache"]);
    } else {
      if(cache != -1)
	CACHE(cache);
    }
    if(!value) return 0;
    if(arrayp(value)) value=value*" ";
    value = lower_case( value );
    string in = lower_case( "*"+is+"*" );
    return glob(in,value) || sizeof(filter( in/",", glob, value ));
  }
}

class TagIfDebug {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "debug";

  int eval( string dbg, RequestID id, mapping m ) {
#ifdef DEBUG
    return 1;
#else
    return 0;
#endif
  }
}

class TagIfModuleDebug {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "module-debug";

  int eval( string dbg, RequestID id, mapping m ) {
#ifdef MODULE_DEBUG
    return 1;
#else
    return 0;
#endif
  }
}

class TagIfDate {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "date";

  int eval(string date, RequestID id, mapping m) {
    CACHE(60); // One minute accuracy is probably good enough...
    int a, b;
    mapping t = ([]);

    date = replace(date, "-", "");
    if(sizeof(date)!=8 && sizeof(date)!=6)
      RXML.run_error("If date attribute doesn't conform to YYYYMMDD syntax.");
    if(sscanf(date, "%04d%02d%02d", t->year, t->mon, t->mday)==3)
      t->year-=1900;
    else if(sscanf(date, "%02d%02d%02d", t->year, t->mon, t->mday)!=3)
      RXML.run_error("If date attribute doesn't conform to YYYYMMDD syntax.");

    if(t->year>70) {
      t->mon--;
      if (catch {
	  a = mktime(t);
	}) {
	RXML.run_error("Unsupported date.\n");
      }
    }

    if (catch {
	t = localtime(time(1));
	b = mktime(t - (["hour": 1, "min": 1, "sec": 1,
			 "isdst": 1, "timezone": 1]));
      }) {
      RXML.run_error("Unsupported date.\n");
    }

    // Catch funny guys
    if(m->before && m->after) {
      if(!m->inclusive)
	return 0;
      m_delete(m, "before");
      m_delete(m, "after");
    }

    if( (m->inclusive || !(m->before || m->after)) && a==b)
      return 1;

    if(m->before && a>b)
      return 1;

    if(m->after && a<b)
      return 1;

    return 0;
  }
}

class TagIfTime {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "time";

  int eval(string ti, RequestID id, mapping m) {
    CACHE(time(1)%60); // minute resolution...

    int|object a, b, d;
    
    if(sizeof(ti) <= 5 /* Format is hhmm or hh:mm. */)
    {
	    mapping c = localtime(time(1));
	    
	    b=(int)sprintf("%02d%02d", c->hour, c->min);
	    a=(int)replace(ti,":","");

	    if(m->until)
		    d = (int)m->until;
		    
    }
    else /* Format is ISO8601 yyyy-mm-dd or yyyy-mm-ddThh:mm etc. */
    {
	    if(has_value(ti, "T"))
	    {
		    /* The Calendar module can for some reason not
		     * handle the ISO8601 standard "T" extension. */
		    a = Calendar.ISO.dwim_time(replace(ti, "T", " "))->minute();
		    b = Calendar.ISO.Minute();
	    }
	    else
	    {
		    a = Calendar.ISO.dwim_day(ti);
		    b = Calendar.ISO.Day();
	    }

	    if(m->until)
		    if(has_value(m->until, "T"))
			    /* The Calendar module can for some reason not
			     * handle the ISO8601 standard "T" extension. */
			    d = Calendar.ISO.dwim_time(replace(m->until, "T", " "))->minute();
		    else
			    d = Calendar.ISO.dwim_day(m->until);
    }
    
    if(d)
    {
      if (d > a && (b > a && b < d) )
	return 1;
      if (d < a && (b > a || b < d) )
	return 1;
      if (m->inclusive && ( b==a || b==d ) )
	return 1;
      return 0;
    }
    else if( (m->inclusive || !(m->before || m->after)) && a==b )
      return 1;
    if(m->before && a>b)
      return 1;
    else if(m->after && a<b)
      return 1;
  }
}

class TagIfUser {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "user";

  int eval(string u, RequestID id, mapping m)
  {
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();

    if( u == "any" )
      if( m->file )
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user( id->auth, id->auth[1], m->file, !!m->wwwfile, id);
      else
	return !!u;
    else
      if(m->file)
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user(id->auth,u,m->file,!!m->wwwfile,id);
      else
	return has_value(u/",", uid->name());
  }

  private int match_user(array u, string user, string f, int wwwfile, RequestID id) {
    string s, pass;
    if(u[1]!=user)
      return 0;
    if(!wwwfile)
      s=Stdio.read_bytes(f);
    else
      s=id->conf->try_get_file(Roxen.fix_relative(f,id), id);
    return ((pass=simple_parse_users_file(s, u[1])) &&
	    (u[0] || match_passwd(u[2], pass)));
  }

  private int match_passwd(string try, string org) {
    if(!strlen(org)) return 1;
    if(verify_password(try, org)) return 1;
  }

  private string simple_parse_users_file(string file, string u) {
    if(!file) return 0;
    foreach(file/"\n", string line)
      {
	array(string) arr = line/":";
	if (arr[0] == u && sizeof(arr) > 1)
	  return(arr[1]);
      }
  }
}

class TagIfGroup {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "group";

  int eval(string u, RequestID id, mapping m) {
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();
    if( m->groupfile )
      return ((m->groupfile && sizeof(m->groupfile))
	      && group_member(id->auth, u, m->groupfile, id));
    return sizeof( uid->groups() & (u/"," )) > 0;
  }

  private int group_member(array auth, string group, string groupfile, RequestID id) {
    if(!auth)
      return 0; // No auth sent

    string s;
    catch { s = Stdio.read_bytes(groupfile); };

    if (!s)
      s = id->conf->try_get_file( Roxen.fix_relative( groupfile, id), id );

    if (!s) return 0;

    s = replace(s,({" ","\t","\r" }), ({"","","" }));

    multiset(string) members = simple_parse_group_file(s, group);
    return members[auth[1]];
  }

  private multiset simple_parse_group_file(string file, string g) {
    multiset res = (<>);
    array(string) arr ;
    foreach(file/"\n", string line)
      if(sizeof(arr = line/":")>1 && (arr[0] == g))
	res += (< @arr[-1]/"," >);
    return res;
  }
}

class TagIfExists {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "exists";

  int eval(string u, RequestID id) {
    //  For CMS installations we depend on the built-in dependency system
#if !constant(Sitebuilder)
    CACHE(5);
#endif
    
    return id->conf->is_file(Roxen.fix_relative(u, id), id);
  }
}

class TagIfInternalExists {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "internal-exists";

  int eval(string u, RequestID id) {
    //  For CMS installations we depend on the built-in dependency system
#if !constant(Sitebuilder)
    CACHE(5);
#endif
    
    return id->conf->is_file(Roxen.fix_relative(u, id), id, 1);
  }
}

class TagIfNserious {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "nserious";

  int eval() {
#ifdef NSERIOUS
    return 1;
#else
    return 0;
#endif
  }
}

class TagIfModule {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "module";

  int eval(string u, RequestID id) {
    if (!sizeof(u)) return 0;
    return sizeof(glob(u+"#*", indices(id->conf->enabled_modules)));
  }
}

class TagIfTrue {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "true";

  int eval(string u, RequestID id) {
    return _ok;
  }
}

class TagIfFalse {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "false";

  int eval(string u, RequestID id) {
    return !_ok;
  }
}

class TagIfAccept {
  inherit IfMatch;
  constant plugin_name = "accept";
  constant cache = -1;
  array source(RequestID id) {
    id->register_vary_callback("accept");
    if( !id->request_headers->accept ) // .. there might be no header
      return ({});
    if( arrayp(id->request_headers->accept) ) // .. there might be multiple
      id->request_headers->accept = id->request_headers->accept*",";
    // .. or there might be one.
    array data = id->request_headers->accept/",";
    array res = ({});
    foreach( data, string d )
    {
      sscanf( d, "%s;", d ); // Ignores the quality parameters etc.
      res += ({d});
    }
    return res;
  }
}

class TagIfConfig {
  inherit IfIs;
  constant plugin_name = "config";
  string source(RequestID id, string s) {
    if(id->config[s]) return "";
    return 0;
  }
}

class TagIfCookie {
  inherit IfIs;
  constant plugin_name = "cookie";
  constant cache = -1; //  Will get Vary header from cookie access
  string source(RequestID id, string s) {
    return id->cookies[s];
  }
}

class TagIfClient {
  inherit IfMatch;
  constant plugin_name = "client";
  constant cache = -1;
  array source(RequestID id) {
    id->register_vary_callback("user-agent");
    return id->client;
  }
}

#if ROXEN_COMPAT <= 1.3
class TagIfName {
  inherit TagIfClient;
  constant plugin_name = "name";
}
#endif

class TagIfDefined {
  inherit IfIs;
  constant plugin_name = "defined";
  string source(RequestID id, string s) {
    mixed val;
    if(zero_type(val=RXML_CONTEXT->misc[s])) return 0;
    if(stringp(val) || intp(val) || floatp(val)) return (string)val;
    return "";
  }
}

class TagIfDomain {
  inherit IfMatch;
  constant plugin_name = "domain";
  constant cache = -1;
  string source(RequestID id) {
    id->register_vary_callback(0, client_host_cb);
    return client_host_cb(UNDEFINED, id);
  }
}

class TagIfIP {
  inherit IfMatch;
  constant plugin_name = "ip";
  constant cache = -1;
  string source(RequestID id) {
    id->register_vary_callback(0, client_ip_cb);
    return client_ip_cb(UNDEFINED, id);
  }
}

#if ROXEN_COMPAT <= 1.3
class TagIfHost {
  inherit TagIfIP;
  constant plugin_name = "host";
}
#endif

class TagIfLanguage {
  inherit IfMatch;
  constant plugin_name = "language";
  constant cache = -1;
  array source(RequestID id) {
    id->register_vary_callback("accept-language");
    return id->misc->pref_languages->get_languages();
  }
}

class TagIfMatch {
  inherit IfIs;
  constant plugin_name = "match";
  constant cache = -1;
  string source(RequestID id, string s) {
    //  See comment in TagIfVariable
    if (id->method != "GET")
      NO_PROTO_CACHE();
    return s;
  }
}

class TagIfMaTcH {
  inherit TagIfMatch;
  constant plugin_name = "Match";
  constant case_sensitive = 1;
}

class TagIfPragma {
  inherit IfIs;
  constant plugin_name = "pragma";
  constant cache = -1;
  string source(RequestID id, string s) {
    id->register_vary_callback("pragma");
    if(id->pragma[s]) return "";
    return 0;
  }
}

class TagIfPrestate {
  inherit IfIs;
  constant plugin_name = "prestate";
  constant cache = -1;
  string source(RequestID id, string s) {
    if(id->prestate[s]) return "";
    return 0;
  }
}

class TagIfReferrer {
  inherit IfMatch;
  constant plugin_name = "referrer";
  constant cache = -1;
  array source(RequestID id) {
    id->register_vary_callback("referer");
    return id->referer;
  }
}

class TagIfSupports {
  inherit IfIs;
  constant plugin_name = "supports";
  constant cache = -1;
  string source(RequestID id, string s) {
    id->register_vary_callback("user-agent");
    if(id->supports[s]) return "";
    return 0;
  }
}

class TagIfScope {
  inherit IfIs;
  constant plugin_name = "scope";
  constant cache = -1;
  mixed source(RequestID id, string s, void|int check_set_only) {

    if (RXML_CONTEXT->get_scope (s)) return 1;

    return 0;
  }
}

class TagIfVariable {
  inherit IfIs;
  constant plugin_name = "variable";

  //  URL variables will be recognized in the protocol-level cache unless
  //  the page is POSTed (which we handle separately below). Any other
  //  variable internal to the page is considered invariant.
  constant cache = -1;
  
  mixed source(RequestID id, string s, void|int check_set_only) {
    //  The protocol-level cache doesn't see posted variables, only
    //  variables in the URL.
    if (id->method != "GET")
      NO_PROTO_CACHE();
    
    mixed var;
    if (compat_level == 2.2) {
      // The check below makes it impossible to tell the value 0 from
      // an unset variable. It's clearly a bug, but we still keep it
      // in 2.2 compatibility mode since fixing it would introduce an
      // incompatibility in (at least) this case:
      //
      //    <set variable="var.foo" expr="0"/>
      //    <if variable="var.foo"> <!-- This is expected to be false. -->
      if (!(var=RXML.user_get_var(s))) return 0;
    }
    else
      if (zero_type (var=RXML.user_get_var(s)) ||
	  objectp (var) && var->is_rxml_null_value) return 0;
    if(arrayp(var)) return var;
    return check_set_only ? 1 : RXML.t_text->encode (var);
  }
}

class TagIfVaRiAbLe {
  inherit TagIfVariable;
  constant plugin_name = "Variable";
  constant case_sensitive = 1;
}

class TagIfVariableExists
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "variable-exists";

  int(0..1) eval (string var, RequestID id, mapping args)
  {
    return !zero_type (RXML.user_get_var (var));
  }
}

class TagIfSizeof {
  inherit IfIs;
  constant plugin_name = "sizeof";
  constant cache = -1;
  string source(RequestID id, string s) {
    mixed var;
    if (compat_level == 2.2) {
      // See note in TagIfVariable.source.
      if (!(var=RXML.user_get_var(s))) return 0;
    }
    else
      if (zero_type (var=RXML.user_get_var(s)) ||
	  objectp (var) && var->is_rxml_null_value) return 0;
    if(stringp(var) || arrayp(var) ||
       multisetp(var) || mappingp(var)) return (string)sizeof(var);
    if(objectp(var) && var->_sizeof) return (string)sizeof(var);
    return (string)sizeof(RXML.t_string->encode (var));
  }
  int(0..1) do_check(string var, array arr, RequestID id) {
    if(sizeof(arr)>2 && !var) var = "0";
    return ::do_check(var, arr, id);
  }
}

class TagIfClientvar {
  inherit IfIs;
  constant plugin_name = "clientvar";
  constant cache = -1;
  string source(RequestID id, string s) {
    id->register_vary_callback("user-agent");
    return id->client_var[s];
  }
}

class TagIfExpr {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "expr";
  int eval(string u) {
    int|float|string res = sexpr_eval(u);
    return res && res != 0.0;
  }
}


class TagIfTestLicense {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "test-license";
  int eval(string u, RequestID id, mapping args)
  {
    License.Key key = id->conf->getvar("license")->get_key();
    if(!key)
      return 0;
    
    //  Expects a string on the form:
    //  * module::mode#feature
    //  * module#feature
    //  * module::mode
    //  * module
    if(sscanf(u, "%s::%s#%s", string module, string mode, string feature) == 3)
      return !!key->get_module_feature(module, feature, mode);
    if(sscanf(u, "%s#%s", string module, string feature) == 2)
      return !!key->get_module_feature(module, feature);
    if(sscanf(u, "%s::%s", string module, string mode) == 2)
      return key->is_module_unlocked(module, mode);
    return key->is_module_unlocked(u);
  }
}

class TagIfTypeFromData {
    inherit IfIs;
    constant plugin_name = "type-from-data";
    constant cache = -1;
    string source(RequestID id, string s) {
	if(RXML.user_get_var(s)) {
	    return try_decode_image(0, s);
	}
	RXML.run_error("Variable %s does not exist.\n",s);
    }
}

class TagIfTypeFromFilename {
    inherit IfIs;
    constant plugin_name = "type-from-filename";
    constant cache = -1;
    string source(RequestID id, string s) {
	if(RXML.user_get_var(s)) {
	    if (id->misc->sb)
		return id->misc->sb->find_content_type_from_filename(RXML.user_get_var(s));
	    else if(my_configuration()->type_from_filename) {
	      string|array(string) type =
		my_configuration()->type_from_filename(RXML.user_get_var(s));
	      if (arrayp(type))
		type = type[0];
	      return type;
	    }
	    RXML.parse_error("No Content type module loaded.\n");
	}
	RXML.run_error("Variable %s does not exist.\n",s);
    }
}


// --------------------- Emit plugins -------------------

class TagEmitSources {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="sources";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    return Array.map( indices(RXML_CONTEXT->tag_set->get_plugins("emit")),
		      lambda(string source) { return (["source":source]); } );
  }
}

class TagEmitScopes {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="scopes";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    return Array.map( RXML_CONTEXT->list_scopes(),
		      lambda(string scope) { return (["scope":scope]); } );
  }
}

class TagPathplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "path";

  array get_dataset(mapping m, RequestID id)
  {
    string fp = "";
    array res = ({});
    string p = m->path || id->not_query;
    if( m->trim )
      sscanf( p, "%s"+m->trim, p );
    if( has_suffix(p, "/") )
      p = p[..strlen(p)-2];
    array q = p / "/";
    if( m->skip )
      q = q[(int)m->skip..];
    if( m["skip-end"] )
      q = q[..sizeof(q)-((int)m["skip-end"]+1)];
    foreach( q, string elem )
    {
      fp += "/" + elem;
      fp = replace( fp, "//", "/" );
      res += ({
        ([
          "name":elem,
          "path":fp
        ])
      });
    }
    return res;
  }
}

class TagEmitValues {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="values";

  protected mixed post_process_value(mixed val, mapping(string:mixed) m)
  {
    if (arrayp(val)) {
      if (m->trimwhites || m->case) {
	return map(val, post_process_value, m);
      }
      return val;
    }
    if(m->trimwhites)
      val=String.trim_all_whites(RXML.t_string->encode (val));
    if(m->case=="upper")
      val=upper_case(RXML.t_string->encode (val));
    else if(m->case=="lower")
      val=lower_case(RXML.t_string->encode (val));
    return val;
  }

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    if(m["from-scope"]) {
      m->values=([]);
      RXML.Context context=RXML_CONTEXT;
      // Filter out undefined values if the compat level allows us.
      if (compat_level > 4.5)
	foreach (context->list_var(m["from-scope"]), string var) {
	  mixed val = context->get_var(var, m["from-scope"]);
	  if (!zero_type (val)) m->values[var] = val;
	}
      else
	foreach (context->list_var(m["from-scope"]), string var)
	  m->values[var] = context->get_var(var, m["from-scope"]);
    }

    if ((m->variable &&
	 // NOTE: Side-effect!
	 zero_type(m->values = RXML_CONTEXT->user_get_var( m->variable ))) ||
	zero_type(m->values))
      return ({});

    if(stringp(m->values)) {
      if(m->advanced) {
	switch(m->advanced) {
	case "chars":
	  m->split="";
	  break;
	case "lines":
	  m->values = replace(m->values, ({ "\n\r", "\r\n", "\r" }),
			      ({ "\n", "\n", "\n" }));
	  m->split = "\n";
	  break;
	case "words":
	  m->values = replace(m->values, ({ "\n\r", "\r\n", "\r" }),
			      ({ "\n", "\n", "\n" }));
	  m->values = replace(m->values, ({ "-\n", "\n", "\t" }),
			      ({ "", " ", " " }));
	  m->values = map(m->values/" " - ({""}),
			  lambda(string word) {
			    if(word[-1]=='.' || word[-1]==',' || word[-1]==';' ||
			       word[-1]==':' || word[-1]=='!' || word[-1]=='?')
			      return word[..sizeof(word)-2];
			    return word;
			  });
	  break;
	case "csv":
	  {
	    array out=({});
	    int i=0;
	    string values=m->values;
#define FETCHAR(c,buf,i)	(catch((c)=(buf)[(i)++])?((c)=-1):(c))
	    array(string) words=({});
	    int c,leadspace=1,inquotes=0;
	    String.Buffer word=String.Buffer();
	    FETCHAR(c,values,i);
	    while(c>=0) {
	      switch(c) {
	      case ',':case ';':
		if(!inquotes)
		{
		  words += ({ word->get() });
		  leadspace=1;
		  break;
		}
		word->putchar(c);
		break;
              case '"':
		leadspace=0;
                if(!inquotes)
                  inquotes=1;
                else if(FETCHAR(c,values,i)=='"')
                  word->putchar(c);
                else
                {
		  inquotes=0;
                  continue;
                }
                break;
              case ' ':case '\t':
		if (leadspace) break;
		// FALL_THROUGH
              default:
		leadspace=0;
		string s;
		sscanf(values[--i..],"%[^,;\"\r\x1a\n]",s);
		word->add(s);
		i+=sizeof(s);
                break;
              case '\r':case '\x1a':
		// Ignore these. NB: 0x1a is Ctrl-Z (EOF on CP/M and DOS).
                break;
              case '\n':
                if(!inquotes)
                {
		  if(!sizeof(words)&&!sizeof(word))
                    break;
                  out += ({ words + ({ word->get() }) });
	          words=({});
	          break;
                }
                word->putchar(c);
		break;
	      }
	      FETCHAR(c,values,i);
	    }
	    m->values = !sizeof(out)&&!sizeof(word) ? ""
	      :out + ({ words + ({ word->get() }) });
	    break;
	  }
	  break;
	}
      }
      if(stringp(m->values)) {
	if (m->nosplit)
	  m->values = ({m->values});
	else
	  m->values=m->values / (m->split || "\000");
      }
    }

    //  Randomize output order? (Can only be applied to arrays since other
    //  types are inherently random.)
    if (lower_case(m->randomize || "no") == "yes") {
      if (arrayp(m->values))
        Array.shuffle(m->values);
    }

    if(mappingp(m->values))
      return map( sort(indices(m->values)),
		  lambda(mixed ind, mapping(string:mixed) m) {
		    mixed val = post_process_value(m->values[ind], m);
		    return (["index":ind,"value":val]);
		  }, m);

    if(arrayp(m->values)) {
      if(m->distinct)
	m->values = Array.uniq(m->values);
      return map( m->values,
		  lambda(mixed val, mapping(string:mixed) m) {
		    val = post_process_value(val, m);
		    return (["value":val]);
		  }, m);
    }

    if(multisetp(m->values))
      return map( sort(m->values),
		  lambda(mixed val, mapping(string:mixed) m) {
		    val = post_process_value(val, m);
		    return (["index":val]);
		  }, m);

    RXML.run_error("Values variable has wrong type %t.\n", m->values);
  }
}

class TagEmitFonts
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "fonts";
  array get_dataset(mapping args, RequestID id)
  {
    return roxen.fonts->get_font_information(args->ttf_only);
  }
}


class TagEmitLicenseWarnings {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "license-warnings";
  array get_dataset(mapping args, RequestID id)
  {
    // This emit plugin can be used to list warnings in the loaded
    // license for a configuration. It can also be used within
    // <license> or emit#licenses.
    License.Key key = (( RXML.get_context()->current_scope() &&
			 RXML.get_context()->get_var("key") )||
		       id->conf->getvar("license")->get_key());
    if(!key) {
      RXML.parse_error("No license key defined in the configuration\n");
      return ({});
    }
    return key->get_warnings();
  }
}

inherit "emit_object";

#if constant(Parser.CSV)
#define PARSER_CSV	Parser.CSV
#else

// Based on Parser.CSV from Pike 8.0.
class PARSER_CSV
{
  // START Parser.Tabular from Pike 8.0.
  Stdio.FILE _in;
  int _eol;
  private int prefetch=1024;

  private String.Buffer alread=String.Buffer(prefetch);
  private mapping|array fms;
  private Regexp simple=Regexp("^[^[\\](){}<>^$|+*?\\\\]+$");
  private Regexp emptyline=Regexp("^[ \t\v\r\x1a]*$");
  private mixed severity=1;
  private int verb=0;
  private int recordcount=1;

  void
  create(void|string|Stdio.File|Stdio.FILE input,
	 void|array|mapping|string|Stdio.File|Stdio.FILE format,
	 void|int verbose)
  {
    if(zero_type(verbose)&&intp(format))
      verbose=format;
    else
      fms=stringp(format)||objectp(format)?compile(format):format;
    verb=verbose==1?70:verbose;
    if(!input)
      input=" ";
    if(stringp(input))
      input=Stdio.FakeFile(input);
    if(!input->unread)
      (_in=Stdio.FILE())->assign(input);
    else
      _in=input;
  }

  private string read(int n)
  {
    string s;
    s=_in->read(n);
    alread->add(s);
    if(sizeof(s)!=n)
      throw(severity);
    return s;
  }

  private string gets(int n)
  {
    string s;
    if(n)
    {
      s=read(n);
      if(has_value(s,"\n")||has_value(s,"\r"))
	throw(severity);
    } else {
      s=_in->gets();
      if(!s)
	throw(severity);
      if(has_value(s,"\r")) {
	array t;
	t=s/"\r";
	s=t[0];_in->unread(t[1..]*"\n");
      }
      alread->add(s);alread->putchar('\n');
      if(has_suffix(s,"\r"))
	s=s[..<1];
      _eol=1;
    }
    return s;
  }

  class _checkpoint
  {
    private string oldalread;

    void create()
    {
      oldalread=alread->get();
    }

    final void release()
    {
      string s=alread->get();
      alread->add(oldalread);
      alread->add(s);
      oldalread=0;
    }

    protected void destroy()
    {
      if(oldalread) {
	string back=alread->get();
	if(sizeof(back)) {
	  _in->unread(back);
	  if(verb<0) {
	    back-="\n";
	    if(sizeof(back))
	      werror("Backtracking %O\n",back);
	  }
	}
	alread->add(oldalread);
      }
    }
  }

#define FETCHAR(c,buf,i)	(catch((c)=(buf)[(i)++])?((c)=-1):(c))

  string _getdelimword(mapping m)
  {
    multiset delim=m->delim;
    int i,pref=m->prefetch || prefetch;
    String.Buffer word=String.Buffer(pref);
    string buf,skipclass;
    skipclass="%[^"+(string)indices(delim)+"\"\r\x1a\n]";
    if(sizeof(delim-(<',',';','\t',' '>))) {
delimready:
      for(;;) {
	i=0;
	buf=_in->read(pref);
	int c;
	FETCHAR(c,buf,i);
	while(c>=0) {
	  if(delim[c])
	    break delimready;
	  else switch(c) {
	    default:
	      {
		string s;
		sscanf(buf[--i..],skipclass,s);
		word->add(s);
		i+=sizeof(s);
		break;
	      }
	    case '\n':
	      FETCHAR(c,buf,i);
	      switch(c) {
	      default:i--;
	      case '\r':case '\x1a':;
	      }
	      _eol=1;
	      break delimready;
	    case '\r':
	      FETCHAR(c,buf,i);
	      if(c!='\n')
		i--;
	      _eol=1;
	      break delimready;
	    case '\x1a':;
	    }
	  FETCHAR(c,buf,i);
	}
	if(!sizeof(buf))
	  throw(severity);
	alread->add(buf);
      }
    } else {
      int leadspace=1,inquotes=0;
    csvready:
      for(;;) {
	i=0;
	buf=_in->read(pref);
	int c;
	FETCHAR(c,buf,i);
	while(c>=0) {
	  if(delim[c]) {
	    if(!inquotes)
	      break csvready;
	    word->putchar(c);
	  } else switch(c) {
	    case '"':leadspace=0;
              if(!inquotes)
                inquotes=1;
              else if(FETCHAR(c,buf,i)=='"')
                word->putchar(c);
              else {
		inquotes=0;
                continue;
              }
              break;
            default:leadspace=0;
            case ' ':case '\t':
              if(!leadspace) {
		string s;
                sscanf(buf[--i..],skipclass,s);
                word->add(s);
                i+=sizeof(s);
              }
              break;
            case '\n':
	      FETCHAR(c,buf,i);
	      switch(c) {
	      default:i--;
	      case '\r':case '\x1a':;
	      }
              if(!inquotes) {
		_eol=1;
                break csvready;
              }
              word->putchar('\n');
	      break;
            case '\r':
	      FETCHAR(c,buf,i);
	      if(c!='\n')
		i--;
              if(!inquotes) {
		_eol=1;
                break csvready;
              }
              word->putchar('\n');
            case '\x1a':;
	    }
	  FETCHAR(c,buf,i);
	}
	if(!sizeof(buf))
	  throw(severity);
	alread->add(buf);
      }
    }
    alread->add(buf[..i-1]);
    _in->unread(buf[i..]);
    return word->get();
  }

  private mapping getrecord(array fmt,int found)
  {
    mapping ret=([]),options;
    if(stringp(fmt[0])) {
      options=(["name":fmt[0]]);
      if(fmt[1])
	options+=fmt[1];
      else
	fmt[1]=0;
    } else
      options=fmt[0];
    if(found) {
      if(options->single)
	throw(severity);		// early exit, already found one
    }
    else if(options->mandatory)
      severity=2;
    if(verb<0)
      werror("Checking record %d for %O\n",recordcount,options->name);
    _eol=0;
    foreach(fmt;int fi;array|mapping m) {
      if(fi<2)
	continue;
      string value;
      if(arrayp(m)) {
	array field=m;
	fmt[fi]=m=(["name":field[0]]);
	mixed nm=field[1];
	if(!mappingp(nm)) {
	  if(arrayp(nm))
	    ret+=getrecord(nm,found);
	  else
	    m+=([(intp(nm)?"width":(stringp(nm)?"match":"delim")):nm]);
	  if(sizeof(field)>2)
	    m+=field[2];
	}
	fmt[fi]=m;
      }
      if(_eol)
	throw(severity);
      if(!zero_type(m->width))
	value=gets(m->width);
      if(m->delim)
	value=_getdelimword(m);
      if(m->match) {
	Regexp rgx;
	if(stringp(m->match)) {
	  if(!value && simple->match(m->match)) {
	    m->width=sizeof(m->match);
	    value=gets(m->width);
	  }
	  m->match=Regexp("^("+m->match+")"+(value?"$":""));
	}
	rgx=m->match;
	if(value) {
	  if(!rgx->match(value)) {
	    if(verb<-3)
	      werror(sprintf("Mismatch %O!=%O\n",value,rgx)
		     -"Regexp.SimpleRegexp");
	    throw(severity);
	  }
	} else {
	  string buf=_in->read(m->prefetch || prefetch);
	  array spr;
          if(!buf || !(spr=rgx->split(buf))) {
	    alread->add(buf);
            if(verb<-3)
              werror(sprintf("Mismatch %O!=%O\n",buf[..32],rgx)
               -"Regexp.SimpleRegexp");
            throw(severity);
          }
          _in->unread(buf[sizeof(value=spr[0])..]);
	  alread->add(value);
	  value-="\r";
	  if(has_suffix(value,"\n"))
	    value=value[..<1];
	}
      }
      if(!m->drop)
	ret[m->name]=value;
    }
    if(!_eol && gets(0)!="")
      throw(severity);
    severity=1;
    if(verb&&verb!=-1) {
      array s=({options->name,"::"});
      foreach(sort(indices(ret)),string name) {
	string value=ret[name];
	if(sizeof(value)) {
	  if(verb<-2)
	    s+=({name,":"});
	  s+=({value,","});
	}
      }
      string out=replace(s[..<1]*"",({"\n","  ","   "}),({""," "," "}));
      out=string_to_utf8(out);	// FIXME Debugging output defaults to UTF-8
      if(verb>0)
	werror("%d %.*s\r",recordcount,verb,out);
      else
	werror("%d %s\n",recordcount,out);
    }
    recordcount++;
    return options->fold?ret:([options->name:ret]);
  }

  private void add2map(mapping res,string name,mixed entry)
  {
    mapping|array tm = res[name];
    if(tm)
    {
      if(arrayp(tm))
	tm+=({entry});
      else
	tm=({tm,entry});
      res[name]=tm;
    }
    else
      res[name]=entry;
  }

  int skipemptylines()
  {
    string line; int eof=1;
    while((line=_in->gets()) && String.width(line)==8 && emptyline->match(line))
      recordcount++;
    if(line)
      eof=0,_in->unread(line+"\n");
    return eof;
  }

  mapping fetch(void|array|mapping format)
  {
    mapping ret=([]);
    int skipempty=0;
    if(!format)
    {
      if(skipemptylines())
	return UNDEFINED;
      skipempty=1;format=fms;
    }
ret:
    {
      if(arrayp(format)) {
	mixed err=catch {
	    _checkpoint checkp=_checkpoint();
	    foreach(format;;array|mapping fmt)
	      if(arrayp(fmt))
		for(int found=0;;found=1) {
		  mixed err=catch {
		      _checkpoint checkp=_checkpoint();
		      mapping rec=getrecord(fmt,found);
		      foreach(rec;string name;mixed value)
			add2map(ret,name,value);
		      checkp->release();
		      continue;
		    };
		  severity=1;
		  switch(err) {
		  case 2:
		    err=1;
		  default:
		    throw(err);
		  case 1:;
		  }
		  break;
		}
	      else if(fmt=fetch(fmt))
		ret+=fmt;
	    checkp->release();
	    break ret;
	  };
	switch(err) {
	default:
	  throw(err);
        case 1:
          return 0;
	}
	if(skipempty)
	  skipemptylines();
      } else {
	int found;
	do {
	  found=0;
	  if(!mappingp(format))
	    error("Empty format definition\n");
	  foreach(format;string name;array|mapping subfmt)
	    for(;;) {
	      if(verb<0)
		werror("Trying format %O\n",name);
	      mapping m;
	      if(m=fetch(subfmt)) {
		found=1;
		add2map(ret,name,m);
		continue;
	      }
	      break;
	    }
	  if(skipempty && skipemptylines())
	    break;
	}
	while(found);
      }
    }
    return sizeof(ret) && ret;
  }

  object feed(string content)
  {
    _in->unread(content);
    return this;
  }

  array|mapping setformat(array|mapping format)
  {
    array|mapping oldfms=fms;
    fms=format;
    return oldfms;
  }

  private Regexp descrx=Regexp(
   "^([ :]*)([^] \t:;#]*)[ \t]*([0-9]*)[ \t]*(\\[([^]]+)\\]|)"
   "[ \t]*(\"(([^\"]|\\\\\")*)\"|)[ \t]*([a-z][a-z \t]*[a-z]|)[ \t]*([#;].*|)$"
  );
  private Regexp tokenise=Regexp("^[ \t]*([^ \t]+)[ \t]*(.*)$");
  array|mapping compile(string|Stdio.File|Stdio.FILE input)
  {
    if(!input)
      input="";
    if(stringp(input))
      input=Stdio.FakeFile(input);
    if(!input->unread) {
      Stdio.FILE tmpf = Stdio.FILE();
      tmpf->assign(input);
      input = tmpf;
    }
    int started=0;
    int lineno=0;
    string beginend="Tabular description ";
    array fields=
      ({"level","name","width",0,"delim",0,"match",0,"options","comment"});
    array strip=({"name","width","delim","match","options","comment"});
    int garbage=0;

    mapping getline()
    {
      mapping m;
      if(started>=0)
	for(;;) {
	  string line=input->gets();
	  if(!line)
	    error("Missing begin record\n");
	  array res=descrx->split(line);
	  lineno++;
	  if(!res)
	    if(!started) {
	      if(!garbage) {
		garbage=1;
		werror("Skipping garbage lines... %O\n",line);
	      }
	      continue;
	    }
	    else
	      error("Line %d parse error: %O\n",lineno,line);
	  m=mkmapping(fields,res);
	  m_delete(m,0);
	  m->level=sizeof(m->level);
	  foreach(strip,string s)
	    if(m[s]&&!sizeof(m[s])||!m[s]&&intp(m[s]))
	      m_delete(m,s);
	  if(!started) {
	    if(!m->level&&!m->name&&m->delim&&m->delim==beginend+"begin")
	      started=1;
	    continue;
	  }
	  if(!m->level&&!m->name) {
	    if(m->delim==beginend+"end") {
	      started=-1;
	      break;
	    }
	    if(!m->comment||m->comment&&
	       (has_prefix(m->comment,"#")||has_prefix(m->comment,";")))
	      continue;	      // skip comments and empty lines
	  }
	  if(m->options) {
	    mapping options=([]);
	    array sp;
	    string left=m->options;
	    m_delete(m,"options");
	    while(sp=tokenise->split(left))
	      options[sp[0]]=1, left=sp[1];
	    m+=options;
	  }
	  if(m->match)
	    m->match=parsecstring(m->match);
	  if(m->delim) {
	    multiset delim=(<>);
	    foreach(parsecstring(replace(m->delim,"\"","\\\""))/"", string cs)
	      delim[cs[0]]=1;
	    m->delim=delim;
	  }
	  if(m->width)
	    m->width=(int)m->width;
	  m_delete(m,"comment");
	  break;
	}
      return m;
    };

    mapping m;

    array|mapping getlevel()
    {
      array|mapping cur=({});
      cur=({m-(<"level">),0});
      int lastlevel=m->level+1;
      m=0;
      for(;(m || (m=getline())) && lastlevel<=m->level;)
	if(lastlevel==m->level && sizeof(m&(<"delim","match","width">)))
	  cur+=({m-(<"level">)}),m=0;
	else {
	  array|mapping res=getlevel();
	  if(mappingp(res)) {
	    if(mappingp(cur[sizeof(cur)-1])) {
	      cur[sizeof(cur)-1]+=res;
	      continue;
	    }
	    res=({res});
	  }
	  cur+=res;
	}
      catch {
	if(arrayp(cur) && arrayp(cur[2]))
	  return ([cur[0]->name:cur[2..]]);
      };
      return ({cur});
    };

    array|mapping ret;
    m=getline();
    while(started>=0 && m) {
      array|mapping val=getlevel();
      catch {
	ret+=val;
	continue;
      };
      ret=val;
    }
    return ret;
  }

  private string parsecstring(string s)
  {
    return compile_string("string s=\""+s+"\";")()->s;
  }

  // END Parser.Tabular from Pike 8.0.

  // START Parser.CSV from Pike 8.0

  int parsehead(void|string delimiters,void|string|object matchfieldname)
  {
    if(skipemptylines())
      return 0;
    string line=_in->gets();
    if(!delimiters||!sizeof(delimiters))
    {
      int countcomma,countsemicolon,counttab;
      countcomma=countsemicolon=counttab=0;
      foreach(line;;int c)
	switch(c)
	{
	case ',':countcomma++;
	  break;
	case ';':countsemicolon++;
	  break;
	case '\t':counttab++;
	  break;
        }
      delimiters=countcomma>countsemicolon?countcomma>counttab?",":"\t":
	countsemicolon>counttab?";":"\t";
    }
    _in->unread(line+"\n");

    multiset delim=(<>);
    foreach(delimiters;;int c)
      delim+=(<c>);

    array res=({ (["single":1]),0 });
    mapping m=(["delim":delim]);

    if(!objectp(matchfieldname))
      matchfieldname=Regexp(matchfieldname||"");
    _eol=0;
    if(mixed err = catch {
	_checkpoint checkp=_checkpoint();
	do {
	  string field=_getdelimword(m);
	  res+=({ m+(["name":field]) });
	  if(String.width(field)>8)
	    field=string_to_utf8(field);  // FIXME dumbing it down for Regexp()
	  if(!matchfieldname->match(field))
	    throw(1);
	}
	while(!_eol);
      })
      switch(err) {
      default:
	throw(err);
      case 1:
	return 0;
      }
    setformat( ({res}) );
    return 1;
  }

  mapping fetchrecord(void|array|mapping format)
  {
    mapping res=fetch(format);
    if(!res)
      return UNDEFINED;
    foreach(res;;mapping v)
      return v;
  }

  // END Parser.CSV from Pike 8.0.
}

#endif

class TagEmitCSV {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "csv";

  class CSVResult(PARSER_CSV csv)
  {
    inherit EmitObject;

    protected mapping(string:mixed) really_get_row()
    {
      return csv->fetchrecord();
    }
  }

  mapping(string:RXML.Type) opt_arg_types =
    ([
      "path": RXML.t_text(RXML.PEnt),
      "realpath": RXML.t_text(RXML.PEnt),
      "header": RXML.t_text(RXML.PEnt),
      "delimiter": RXML.t_text(RXML.PEnt),
    ]);

  array|EmitObject get_dataset(mapping args, RequestID id)
  {
    PARSER_CSV csv;
    if (args->path) {
      string data = id->conf->try_get_file(args->path, id);
      if (stringp(data)) {
	csv = PARSER_CSV(data);
      } else {
	werror("Try get file failed with %O\n", data);
      }
    } else if (args->realpath) {
      Stdio.File file = Stdio.File();
      if (file->open(args->realpath, "r")) {
	csv = PARSER_CSV(file);
      }
    } else if (!args->quiet) {
      RXML.run_error("Path to data not specified.\n");
    }
    if (!csv) {
      if (!args->quiet) {
	RXML.run_error("Data file not found.\n");
      }
      return ({});
    }

    if (args->header) {
      // Explicit headerline.
      if (!has_suffix(args->header, "\n")) args->header += "\n";
      csv->_in->unread(args->header);
    }

    if (!csv->parsehead(args->delimiter)) {
      if (!args->quiet) {
	RXML.run_error("Failed to parse csv header.\n");
      }
      return ({});
    }
    // Trow away the header row.
    csv->fetchrecord();
    return CSVResult(csv);
  }
}

// ---------------- API registration stuff ---------------

string api_query_modified(RequestID id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  return tag_modified("modified", m, id, id);
}


// --------------------- Documentation -----------------------

mapping tagdocumentation() {
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  mapping doc=compile_string("#define manual\n"+file->read(), __FILE__)->tagdoc;
  file->close();
  if(!file->open("etc/supports","r")) return doc;

  Parser.HTML()->
    add_container("flags", format_support)->
    add_container("vars", format_support)->
    set_extra(doc)->
    finish(file->read())->read();

  return doc;
}

protected int format_support(Parser.HTML p, mapping m, string c, mapping doc) {
  string key = ([ "flags":"if#supports",
		  "vars":"if#clientvar" ])[p->tag_name()];
  c=Roxen.html_encode_string(c)-"#! ";
  c=(Array.map(c/"\n", lambda(string row) {
			 if(sscanf(row, "%*s - %*s")!=2) return "";
			 return "<li>"+row+"</li>";
		       }) - ({""})) * "\n";
  doc[key]+="<ul>\n"+c+"</ul>\n";
  return 0;
}


//  FIXME: Move this to intrawise.pike if possible
class TagIWCache {
  inherit TagCache;
  constant name = "__iwcache";

  //  Place all cache data in a specific cache which we can clear when
  //  the layout files are updated.
  constant cache_tag_location = "iwcache";
  
  class Frame {
    inherit TagCache::Frame;
    
    array do_enter(RequestID id) {
      //  Compute a cache key which depends on the state of the user's
      //  Platform cookie. Get user ID from id->misc->sbobj which in
      //  turn gets initialized in find_file(). This ID will be 0 for
      //  all users (even when authenticated in IW) as long as they
      //  haven't logged in into Platform.
      //  Enable protocol caching since our key is shared and thus
      //  in essence only dependent on &page.path;. Aside from that the
      //  user ID is part of the key, but all authenticated users will
      //  fall through the protocol cache anyway.
      object sbobj = id->misc->sbobj;
      int userid = sbobj && sbobj->get_userid();
      args = ([ "shared" : "yes-please",
		"key"    : ("userid:" + userid +
			    "|tmpl:" + (id->misc->iw_template_set || "")),
		"enable-client-cache"   : "yes-please",
		"enable-protocol-cache" : "yes-please",
      ]);
      if(id->supports->robot||id->variables->__print)
	args += ([ "nocache" : "yes" ]);
      
      return ::do_enter(id);
    }
  }
}



#ifdef manual
constant tagdoc=([
  // NOTE: The implementation of the &roxen; scope is in
  //        etc/modules/Roxen.pmod.
"&roxen;":#"<desc type='scope'><p><short>
 This scope contains information specific to this Roxen
 WebServer.</short> It is not possible to write any information to
 this scope.
</p></desc>",

"&roxen.auto-charset-value;":#"<desc type='entity'><p>
 The value of the URL variable which is inserted by
 <tag>roxen-automatic-charset-variable</tag>. Can be used together with
 <ent>roxen.auto-charset-variable</ent> in custom links when you want Roxen
 to automatically detect the character set in the URL.
</p></desc>",

"&roxen.auto-charset-variable;":#"<desc type='entity'><p>
 The name of the URL variable which is inserted by
 <tag>roxen-automatic-charset-variable</tag>. Can be used together with
 <ent>roxen.auto-charset-value</ent> in custom links when you want Roxen
 to automatically detect the character set in the URL.
</p></desc>",

"&roxen.domain;":#"<desc type='entity'><p>
 The domain name of this site. The information is taken from the
 client request, so a request to \"http://community.roxen.com/\" would
 give this entity the value \"community.roxen.com\", while a request
 for \"http://community/\" would give the entity value \"community\".
</p></desc>",

"&roxen.hits;":#"<desc type='entity'><p>
 The number of hits, i.e. requests the webserver has accumulated since
 it was last started.
</p></desc>",

"&roxen.hits-per-minute;":#"<desc type='entity'><p>
 The average number of requests per minute since the webserver last
 started.
</p></desc>",

"&roxen.nodename;":#"<desc type='entity'><p>
 The node name of the machine that the webserver is running on.
</p></desc>",

"&roxen.version;":#"<desc type='entity'><p>                                     
 The version of the webserver.                                                  
</p></desc>",

"&roxen.build;":#"<desc type='entity'><p>                                       
</p></desc>",

"&roxen.base-version;":#"<desc type='entity'><p>                                
</p></desc>",

"&roxen.dist-version;":#"<desc type='entity'><p>                                
</p></desc>",

"&roxen.dist-os;":#"<desc type='entity'><p>                                
</p></desc>",

"&roxen.product-name;":#"<desc type='entity'><p>                                
</p></desc>",

"&roxen.pike-version;":#"<desc type='entity'><p>
 The version of Pike the webserver is using, e.g. \"Pike v7.2 release 140\".
</p></desc>",

"&roxen.sent;":#"<desc type='entity'><p>
 The total amount of data the webserver has sent since it last started.
</p></desc>",

"&roxen.sent-kbit-per-second;":#"<desc type='entity'><p>
 The average amount of data the webserver has sent, in Kibibits.
</p></desc>",

"&roxen.sent-mb;":#"<desc type='entity'><p>
 The total amount of data the webserver has sent, in Mebibits.
</p></desc>",

"&roxen.sent-per-minute;":#"<desc type='entity'><p>
 The average number of bytes that the webserver sends during a
 minute. Based on the sent amount of data and uptime since last server start.
</p></desc>",

"&roxen.server;":#"<desc type='entity'><p>
 The URL of the webserver. The information is taken from the client request,
 so a request to \"http://community.roxen.com/index.html\" would give this
 entity the value \"http://community.roxen.com/\", while a request for
 \"http://community/index.html\" would give the entity the value
 \"http://community/\".
</p></desc>",

"&roxen.ssl-strength;":#"<desc type='entity'><p>
 Contains the maximum number of bits encryption strength that the SSL is capable of.
 Note that this is the server side capability, not the client capability.
 Possible values are 0, 40, 128 or 168.
</p></desc>",

"&roxen.true;":#"<desc type='entity'><p>
 The value is true in boolean tests and yields 1 or 1.0, as appropriate, in
 a numeric context.</p>

 <p>This is used for the special 'true' value in JSON (see
 <tag>json-parse</tag> and <tag>json-format</tag>).
</p></desc>",

"&roxen.false;":#"<desc type='entity'><p>
 The value is false in boolean tests, and yields 0 or 0.0, as
 appropriate, in a numeric context.</p>

 <p>This is used for the special 'false' value in JSON (see
 <tag>json-parse</tag> and <tag>json-format</tag>).
</p></desc>",

"&roxen.null;":#"<desc type='entity'><p>
 NULL value. It's false in boolean tests, yields \"\" in a string
 context and 0 or 0.0, as appropriate, in a numeric context.</p>

 <p>This is used for SQL NULL in the SQL tags, and also for the
 special 'null' value in JSON (see <tag>json-parse</tag> and
 <tag>json-format</tag>).
</p></desc>",

"&roxen.time;":#"<desc type='entity'><p>
 The current posix time. An example output: \"244742740\".
</p></desc>",

"&roxen.unique-id;":#"<desc type='entity'><p>
 Returns a unique id that can be used for e.g. session
 identification. An example output: \"7fcda35e1f9c3f7092db331780db9392\".
 Note that a new id will be generated every time this entity is used,
 so you need to store the value in another variable if you are going
 to use it more than once.
</p></desc>",

"&roxen.uptime;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in seconds.
</p></desc>",

"&roxen.uptime-days;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in days.
</p></desc>",

"&roxen.uptime-hours;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in hours.
</p></desc>",

"&roxen.uptime-minutes;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in minutes.
</p></desc>",

//----------------------------------------------------------------------

"&client;":#"<desc type='scope'><p><short>
 This scope contains information specific to the client/browser that
 is accessing the page. All support variables defined in the support
 file is added to this scope.</short>
</p></desc>",

"&client.ip;":#"<desc type='entity'><p>
 The client is located on this IP-address. An example output: \"194.52.182.15\".
</p></desc>",

"&client.host;":#"<desc type='entity'><p>
 The host name of the client, if possible to resolve.
 An example output: \"www.roxen.com\".
</p></desc>",

"&client.name;":#"<desc type='entity'><p>
 The name of the client, i.e. the sent user agent string up until the
 first space character. An example output: \"Mozilla/4.7\".
</p></desc>",

"&client.Fullname;":#"<desc type='entity'><p>
 The full user agent string, i.e. name of the client and additional
 info like; operating system, type of computer, etc. An example output:
 \"Mozilla/4.7 [en] (X11; I; SunOS 5.7 i86pc)\".
</p></desc>",

"&client.fullname;":#"<desc type='entity'><p>
 The full user agent string, i.e. name of the client and additional
 info like; operating system, type of computer, etc. Unlike <ent>client.fullname</ent>
 this value is lowercased. An example output:
 \"mozilla/4.7 [en] (x11; i; sunos 5.7 i86pc)\".
</p></desc>",

"&client.referrer;":#"<desc type='entity'><p>
 Prints the URL of the page on which the user followed a link that
 brought her to this page. The information comes from the referrer
 header sent by the browser. An example output: \"http://www.roxen.com/index.xml\".
</p></desc>",

"&client.accept-language;":#"<desc type='entity'><p>
 The client prefers to have the page contents presented in this
 language, according to the accept-language header. An example output: \"en\".
</p></desc>",

"&client.accept-languages;":#"<desc type='entity'><p>
 The client prefers to have the page contents presented in these
 languages, according to the accept-language header.</p>

 <p>If used in an array context, an array of language codes are
 returned. Otherwise they are returned as a comma-separated string,
 e.g. \"en, sv\".
</p></desc>",

"&client.language;":#"<desc type='entity'><p>
 The client's most preferred language. Usually the same value as
 <ent>client.accept-language</ent>, but is possibly altered by
 a customization module like the Preferred language analyzer.
 It is recommended that this entity is used over the <ent>client.accept-language</ent>
 when selecting languages. An example output: \"en\".
</p></desc>",

"&client.languages;":#"<desc type='entity'><p>
 An ordered list of the client's most preferred languages. Usually the
 same value as <ent>client.accept-language</ent>, but is possibly altered
 by a customization module like the Preferred language analyzer, or
 reorganized according to quality identifiers according to the HTTP
 specification.</p>

 <p>Like <ent>client.accept-language</ent>, this returns an array of
 language codes in an array context, and a comma-separated string
 otherwise.
</p></desc>",

"&client.authenticated;":#"<desc type='entity'><p>
 Returns the name of the user logged on to the site, i.e. the login
 name, if any exists.
</p></desc>",

"&client.user;":#"<desc type='entity'><p>
 Returns the name the user used when he/she tried to log on the site,
 i.e. the login name, if any exists.
</p></desc>",

"&client.password;":#"<desc type='entity'><p>
 Returns the password the user used when he/she tried to log on the site.
</p></desc>",

"&client.height;":#"<desc type='entity'><p>
 The presentation area height in pixels. For WAP-phones.
</p></desc>",

"&client.width;":#"<desc type='entity'><p>
 The presentation area width in pixels. For WAP-phones.
</p></desc>",

"&client.robot;":#"<desc type='entity'><p>

 Returns the name of the webrobot. Useful if the robot requesting
 pages is to be served other contents than most visitors. Use
 <ent>client.robot</ent> together with <xref href='../if/if.tag'
 />.</p>

 <p>Possible webrobots are: ms-url-control, architex, backrub,
 checkbot, fast, freecrawl, passagen, gcreep, getright, googlebot,
 harvest, alexa, infoseek, intraseek, lycos, webinfo, roxen,
 altavista, scout, slurp, url-minder, webcrawler, wget, xenu and
 yahoo.</p>
</desc>",

"&client.javascript;":#"<desc type='entity'><p>
 Returns the highest version of javascript supported.
</p></desc>",

"&client.tm;":#"<desc type='entity'><p><short>
 Generates a trademark sign in a way that the client can
 render.</short> Possible outcomes are \"&amp;trade;\",
 \"&lt;sup&gt;TM&lt;/sup&gt;\", and \"&amp;gt;TM&amp;lt;\".</p>
</desc>",

//----------------------------------------------------------------------

"&page;":#"<desc type='scope'><p><short>
 This scope contains information specific to this page.</short></p>
</desc>",

"&page.realfile;":#"<desc type='entity'><p>
 Path to this file in the file system. An example output:
 \"/home/joe/html/index.html\".
</p></desc>",

"&page.virtroot;":#"<desc type='entity'><p>
 The root of the present virtual filesystem, usually \"/\".
</p></desc>",

"&page.mountpoint;":#"<desc type='entity'><p>
 The root of the present virtual filesystem without the ending slash,
 usually \"\".
</p></desc>",

//  &page.virtfile; is same as &page.path; but deprecated since we want to
//  harmonize with SiteBuilder entities.
"&page.path;":#"<desc type='entity'><p>
 Absolute path to this file in the virtual filesystem. E.g. with the
 URL \"http://www.roxen.com/partners/../products/index.xml\", as well
 as \"http://www.roxen.com/products/index.xml\", the value will be
 \"/products/index.xml\", given that the virtual filsystem was mounted
 on \"/\".
</p></desc>",

"&page.virtfile;":#"<desc type='entity'><p>
 This tag is deprecated. Use <ent>page.path</ent> instead.
</p></desc>",

"&page.pathinfo;":#"<desc type='entity'><p>
 The \"path info\" part of the URL, if any. Can only get set if the
 \"Path info support\" module is installed. For details see the
 documentation for that module.
</p></desc>",

"&page.query;":#"<desc type='entity'><p>
 The query part of the page URL. If the page URL is
 \"http://www.server.com/index.html?a=1&amp;b=2\"
 the value of this entity is \"a=1&amp;b=2\".
</p></desc>",

"&page.url;":#"<desc type='entity'><p>
 The absolute path for this file from the web server's root
 view including query variables.
</p></desc>",

"&page.last-true;":#"<desc type='entity'><p>
 Is \"1\" if the last <tag>if</tag>-statement succeeded, otherwise 0.
 (<xref href='../if/true.tag' /> and <xref href='../if/false.tag' />
 is considered as <tag>if</tag>-statements here) See also: <xref
 href='../if/' />.</p>
</desc>",

"&page.language;":#"<desc type='entity'><p>
 What language the contents of this file is written in. The language
 must be given as metadata to be found.
</p></desc>",

"&page.scope;":#"<desc type='entity'><p>
 The name of the current scope, i.e. the scope accessible through the
 name \"_\".
</p></desc>",

"&page.filesize;":#"<desc type='entity'><p>
 This file's size, in bytes.
</p></desc>",

"&page.ssl-strength;":#"<desc type='entity'><p>
 The number of bits used in the key of the current SSL connection.
</p></desc>",

"&page.self;":#"<desc type='entity'><p>
 The name of this file, derived from the URL. If the URL is
 \"http://community.roxen.com/articles/index.html\", then the
 value of this entity is \"index.html\".
</p></desc>",

"&page.dir;":#"<desc type='entity'><p>
 The name of the directory in the virtual filesystem where the file resides,
 as derived from the URL. If the URL is
 \"http://community.roxen.com/articles/index.html\", then the
 value of this entity is \"/articles/\".
</p></desc>",

//----------------------------------------------------------------------

"&form;":#"<desc type='scope'><p><short hide='hide'>
 This scope contains form variables.</short> This scope contains the
 form variables, i.e. the answers to HTML forms sent by the client.
 Both variables resulting from POST operations and GET operations gets
 into this scope. There are no predefined entities for this scope.
</p></desc>",

//----------------------------------------------------------------------

"&request-header;":#"<desc type='scope'><p><short hide='hide'>
 This scope contains request header variables.</short> This scope contains the
 request header variables, i.e. the request headers sent by the client.
 There are no predefined entities for this scope.
</p></desc>",

//----------------------------------------------------------------------

"&cookie;":#"<desc type='scope'><p><short>
 This scope contains the cookies sent by the client.</short> Adding,
 deleting or changing in this scope updates the client's cookies. There
 are no predefined entities for this scope. When adding cookies to
 this scope they are automatically set to expire after two years.
</p></desc>",

//----------------------------------------------------------------------

"&header;":#"<desc type='scope'><p><short>
 This scope is deprecated.</short> Please use the
 <xref href='../protocol/header.tag'/> tag instead to create HTTP headers.
</p></desc>",

//----------------------------------------------------------------------

"&var;":#"<desc type='scope'><p><short>
 General variable scope.</short> This scope is always empty when the
 page parsing begins and is therefore suitable to use as storage for
 all variables used during parsing.
</p></desc>",

//----------------------------------------------------------------------

"roxen-automatic-charset-variable":#"<desc type='tag'><p>
 If put inside a form, the right character encoding of the submitted
 form can be guessed by Roxen WebServer. The tag will insert another
 tag that forces the client to submit the string \"едц<ent>#x829f</ent>\". Since the
 WebServer knows the name and the content of the form variable it can
 select the proper character decoder for the requests variables.
</p>

<ex-box><form>
  <roxen-automatic-charset-variable/>
  Name: <input name='name'/><br />
  Mail: <input name='mail'/><br />
  <input type='submit'/>
</form></ex-box>

<p>See also <ent>roxen.auto-charset-variable</ent> and
  <ent>roxen.auto-charset-value</ent>.</p>
</desc>",

//----------------------------------------------------------------------

"colorscope":#"<desc type='cont'><p><short>
 Makes it possible to change the autodetected colors within the tag.</short>
 Useful when out-of-order parsing occurs, e.g.</p>

<ex-box><define tag=\"hello\">
  <colorscope bgcolor=\"red\">
    <gtext>Hello</gtext>
  </colorscope>
</define>

<table><tr>
  <td bgcolor=\"red\">
    <hello/>
  </td>
</tr></table></ex-box>

 <p>It can also successfully be used when the wiretap module is turned off
 for e.g. performance reasons.</p>
</desc>

<attr name='text' value='color'><p>
 Set the text color to this value within the scope.</p>
</attr>

<attr name='bgcolor' value='color'><p>
 Set the background color to this value within the scope.</p>
</attr>

<attr name='link' value='color'><p>
 Set the link color to this value within the scope.</p>
</attr>

<attr name='alink' value='color'><p>
 Set the active link color to this value within the scope.</p>
</attr>

<attr name='vlink' value='color'><p>
 Set the visited link color to this value within the scope.</p>
</attr>",

//----------------------------------------------------------------------

"aconf":#"<desc type='cont'><p><short>
 Creates a link that can modify the config states in the cookie
 RoxenConfig.</short> In practice it will add &lt;keyword&gt;/ right
 after the server in the URL. E.g. if you want to remove the config
 state bacon and add config state egg the
 first \"directory\" in the path will be &lt;-bacon,egg&gt;. If the
 user follows this link the WebServer will understand how the
 RoxenConfig cookie should be modified and will send a new cookie
 along with a redirect to the given url, but with the first
 \"directory\" removed. The presence of a certain config state can be
 detected by the <xref href='../if/if_config.tag'/> tag.</p>
</desc>

<attr name='href' value='uri'>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name='add' value='string'>
 <p>The config state, or config states that should be added, in a comma
 separated list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The config state, or config states that should be dropped, in a comma
 separated list.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>

 <p>All other attributes will be inherited by the generated <tag>a</tag> tag.</p>
</attr>",

//----------------------------------------------------------------------

"append":#"<desc type='both'><p><short>
 Appends a value to a variable.</short></p>

 <p>If the variable has a value of a sequential type (i.e. string,
 array or mapping), then the new value is converted to that type and
 appended. Otherwise both values are promoted to arrays and
 concatenated to one array.</p>

 <ex any-result=''>
<set variable=\"var.x\">a,b</set>
<append variable=\"var.x\">,c</append>
&var.x;
 </ex>

 <ex any-result=''>
<set variable=\"var.x\" split=\",\">a,b</set>
<append variable=\"var.x\">c</append>
&var.x;
 </ex>

 <ex any-result=''>
<set variable=\"var.x\" type=\"int\">1</set>
<append variable=\"var.x\" type=\"int\">2</append>
&var.x;
 </ex>

 <p>It is not an error if the variable doesn't have any value already.
 In that case the new value is simply assigned to the variable, but it
 is still promoted to an array if necessary, as described above.</p>

 <ex any-result=''>
<append variable=\"var.x\" type=\"int\">1</append>
&var.x;
 </ex>

 <p>Note that strings are sequential but numbers are not. It is
 therefore crucial to not mix them up, especially since it is fairly
 common that numbers actually are in string form. C.f:</p>

 <ex any-result=''>
<set variable=\"var.x\" value=\"1\"/>
<append variable=\"var.x\" type=\"int\">2</append>
&var.x;
 </ex>

 <ex any-result=''>
<set variable=\"var.x\" type=\"int\" value=\"1\"/>
<append variable=\"var.x\" type=\"int\">2</append>
&var.x;
 </ex>

 <p>To avoid confusion, use \"type\" attributes liberally.</p>

 " // FIXME: Refer to a compatibility notes document.
 #"<p>Compatibility note: Before 5.0 this tag had a bit quirky
 behavior in various corner cases of its type handling. That behavior
 is retained if the compatibility level is less than 5.0.</p>
</desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable to set.</p>
</attr>

<attr name='value' value='string'>
 <p>A value to append. This is an alternative to specifying the value
 in the content, and the content must be empty if this is used.</p>

 <p>The difference is that the value always is parsed as text here.
 Even if a type is specified with the \"type\" attribute this is still
 parsed as text, and then converted to that type.</p>
</attr>

<attr name='from' value='string'>
 <p>Get the value to append from this variable. The content must be
 empty if this is used.</p>
</attr>

<attr name='expr' value='string'>
 <p>An expression that gets evaluated to produce the value for the
 variable. See the \"expr\" attribute in the <tag>set</tag> tag for
 details. The content must be empty if this is used.</p>
</attr>

<attr name='type' value='type'>
 <p>The type of the value. If the value is taken from the content then
 this is the context type while evaluating it. If \"value\", \"from\"
 or \"expr\" is used then the value is converted to this type.
 Defaults to \"any\".</p>
</attr>",

//----------------------------------------------------------------------

"apre":#"<desc type='cont'><p><short>

 Creates a link that can modify prestates.</short> Prestates can be
 seen as valueless cookies or toggles that are easily modified by the
 user. The prestates are added to the URL. If you set the prestate
 \"no-images\" on \"http://www.demolabs.com/index.html\" the URL would
 be \"http://www.demolabs.com/(no-images)/\". Use <xref
 href='../if/if_prestate.tag' /> to test for the presence of a
 prestate. <tag>apre</tag> works just like the <tag>a href='...'</tag>
 container, but if no \"href\" attribute is specified, the current
 page is used. </p>

</desc>

<attr name='href' value='uri'>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name='add' value='string'>
 <p>The prestate or prestates that should be added, in a comma
 separated list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The prestate or prestates that should be dropped, in a comma-separated
 list.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>
</attr>",

//----------------------------------------------------------------------

"auth-required":#"<desc type='tag'><p><short>
 Adds an HTTP auth required header and return code (401), that will
 force the user to supply a login name and password.</short> This tag
 is needed when using access control in RXML in order for the user to
 be prompted to login.
</p></desc>

<attr name='realm' value='string' default='document access'>
 <p>The realm you are logging on to, i.e \"Demolabs Intranet\".</p>
</attr>

<attr name='message' value='string'>
 <p>Returns a message if a login failed or cancelled.</p>
</attr>",

//----------------------------------------------------------------------

"autoformat":#"<desc type='cont'><p><short hide='hide'>
 Replaces newlines with <tag>br/</tag>:s'.</short>Replaces newlines with
 <tag>br /</tag>:s'.</p>

<ex><autoformat>
It is almost like
using the pre tag.
</autoformat></ex>
</desc>

<attr name='p'>
 <p>Replace empty lines with <tag>p</tag>:s and also ensure there are
 balanced <tag>p</tag> tags at the top level.</p>
<ex><autoformat p=''>
It is almost like

using the pre tag.
</autoformat></ex>
</attr>

<attr name='nobr'>
 <p>Do not replace newlines with <tag>br /</tag>:s.</p>
</attr>

<attr name='nonbsp'><p>
 Do not turn consecutive spaces into interleaved
 breakable/nonbreakable spaces. When this attribute is not given, the
 tag will behave more or less like HTML:s <tag>pre</tag> tag, making
 whitespace indention work, without the usually unwanted effect of
 really long lines extending the browser window width.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the
 p elements.</p>
</attr>",

//----------------------------------------------------------------------

"cache":#"<desc type='cont'><p><short>
 This tag caches the evaluated result of its contents.</short> When
 the tag is encountered again in a later request, it can thus look up
 and return that result without evaluating the content again.</p>

 <p>Nested <tag>cache</tag> tags are normally cached separately, and
 they are also recognized so that the enclosing <tag>cache</tag> tags
 don't cache their contents too. It's thus possible to change the
 cache parameters or completely disable caching of a certain part of
 the content inside a <tag>cache</tag> tag.</p>
 
 <note><p>This implies that many RXML tags that enclose the inner
 <tag>cache</tag> tag(s) won't be cached. The reason is that those
 enclosing tags use the result of the inner <tag>cache</tag> tag(s),
 which can only be established when the actual context in each request
 is compared to the cache parameters. See the section below about
 cache static tags, though.</p></note>

 <p>Besides the value produced by the content, all assignments to RXML
 variables in any scope are cached. I.e. an RXML code block which
 produces a value in a variable may be cached, and the same value will
 be assigned again to that variable when the cached entry is used.</p>

 <p>When the content is evaluated, the produced result is associated
 with a key that is specified by the optional attributes \"variable\",
 \"key\" and \"profile\". This key is what the the cached data depends
 on. If none of the attributes are used, the tag will have a single
 cache entry that always matches.</p>

 <note><p>It is easy to create huge amounts of cached values if the
 cache parameters are chosen badly. E.g. to depend on the contents of
 the form scope is typically only acceptable when combined with a
 fairly short cache time, since it's otherwise easy to fill up the
 memory on the server simply by making many requests with random
 variables.</p></note>

 <h1>Shared caches</h1>

 <p>The cache can be shared between all <tag>cache</tag> tags with
 identical content, which is typically useful in <tag>cache</tag> tags
 used in templates included into many pages. The drawback is that
 cache entries stick around when the <tag>cache</tag> tags change in
 the RXML source, and that the cache cannot be persistent (see below).
 Only shared caches have any effect if the RXML pages aren't compiled
 and cached as p-code.</p>

 <p>If the cache isn't shared, and the page is compiled to p-code
 which is saved persistently then the produced cache entries can also
 be saved persistently. See the \"persistent-cache\" attribute for
 more details.</p>

 <note><p>For non-shared caches, this tag depends on the caching in
 the RXML parser to work properly, since the cache is associated with
 the specific tag instance in the compiled RXML code. I.e. there must
 be some sort of cache on the top level that can associate the RXML
 source to an old p-code entry before the cache in this tag can have
 any effect. E.g. if the RXML parser module in WebServer is used, you
 have to make sure page caching is turned on in it. So if you don't
 get cache hits when you think there should be, the cache miss might
 not be in this tag but instead in the top level cache that maps the
 RXML source to p-code.</p>

 <p>Also note that non-shared timeout caches are only effective if the
 p-code is cached in RAM. If it should work for p-code that is cached
 on disk but not in RAM, you need to add the attribute
 \"persistent-cache=yes\".</p>

 <p>Note to Roxen CMS (a.k.a. SiteBuilder) users: The RXML parser
 module in WebServer is <i>not</i> used by Roxen CMS. See the CMS
 documentation for details about how to control RXML p-code
 caching.</p></note>

 <h1>Cache static tags</h1>

 <note><p>Note that this is only applicable if the compatibility level
 is set to 2.5 or higher.</p></note>

 <p>Some common tags, e.g. <tag>if</tag> and <tag>emit</tag>, are
 \"cache static\". That means that they are cached even though there
 are nested <tag>cache</tag> tag(s). That can be done since they
 simply let their content pass through (repeated zero or more
 times).</p>

 <p>Cache static tags are always evaluated when the enclosing
 <tag>cache</tag> generates a new entry. Other tags are evaluated when
 the entry is used, providing they contain or might contain nested
 <tag>cache</tag> or <tag>nocache</tag>. This can give side effects;
 consider this example:</p>

<ex-box>
<cache>
  <registered-user>
    <nocache>Your name is &registered-user.name;</nocache>
  </registered-user>
</cache>
</ex-box>

 <p>Assume the tag <tag>registered-user</tag> is a custom tag that
 ignores its content whenever the user isn't registered. If it isn't
 cache static, the nested <tag>nocache</tag> tag causes it to stay
 unevaluated in the enclosing cache, and the test of the user is
 therefore kept dynamic. If it on the other hand is cache static, that
 test is cached and the cache entry will either contain the
 <tag>nocache</tag> block and a cached assignment to
 <ent>registered-user.name</ent>, or none of the content inside
 <tag>registered-user</tag>. The dependencies of the outer cache must
 then include the user for it to work correctly.</p>

 <p>Because of this, it's important to know whether a tag is cache
 static or not, and it's noted in the doc for all such tags.</p>

 <h1>Compatibility</h1>

 <p>If the compatibility level of the site is lower than 2.2 and there
 is no \"variable\" or \"profile\" attribute, the cache depends on the
 contents of the form scope and the path of the current page (i.e.
 <ent>page.path</ent>). This is often a bad policy since it's easy for
 a client to generate many cache entries.</p>

 <p>None of the standard RXML tags are cache static if the
 compatibility level is 2.4 or lower.</p>
</desc>

<attr name='variable' value='string'>
 <p>This is a comma-separated list of variables and scopes that the
 cache should depend on. The value can be an empty string, which is
 useful to only disable the default dependencies in compatibility
 mode.</p>

 <p>Since it's important to keep down the size of the cache, this
 should typically be kept to only a few variables with a limited set
 of possible values, or else the cache should have a timeout.</p>
</attr>

<attr name='generation-variable' value='string'>
 <p>Similar to the \"variable\" attribute with the difference that the
 cache only keeps the most recently stored value for the combination of
 all referenced generation variables. This is particularly suitable for
 generation counters where old entries become garbage once a counter is
 bumped (though there is no requirement that variable values are numeric).
 </p>

 <p>In the current implementation a cache entry associated with at least
 one generation variable can be returned in lookups specifying zero
 generation variables if all other variables match. The inverse is however
 not true; a lookup including generation variables will never return entries
 stored without the same \"generation-variable\" attribute.</p>
</attr>

<attr name='key' value='string'>
 <p>Use the value of this attribute directly in the key. This
 attribute mainly exist for compatibility; it's better to use the
 \"variable\" attribute instead.</p>

 <p>It is an error to use \"key\" together with \"propagate\", since
 it wouldn't do what you'd expect: The value for \"key\" would not be
 reevaluated when an entry is chosen from the cache, since the nested,
 propagating <tag>cache</tag> isn't reached at all then.</p>
</attr>

<attr name='profile' value='string'>
 <p>A comma-separated list to choose one or more profiles from a set
 of preconfigured cache profiles. Which cache profiles are available
 depends on the RXML parser module in use; the standard RXML parser
 currently has none.</p>
</attr>

<attr name='shared'>
 <p>Share the cache between different instances of the
 <tag>cache</tag> with identical content, wherever they may appear on
 this page or some other in the same server. See the tag description
 for details about shared caches.</p>
</attr>

<attr name='persistent-cache' value='yes|no'>
  <p>If the value is \"yes\" then the cache entries are saved
  persistently, providing the RXML p-code is saved. If it's \"no\"
  then the cache entries are not saved. If it's left out then the
  default is to save if there's no timeout on the cache, otherwise
  not. This attribute has no effect if the \"shared\" attribute is
  used; shared caches can not be saved persistently.</p>
</attr>

<attr name='nocache'>
 <p>Do not cache the content in any way. Typically useful to disable
 caching of a section inside another cache tag.</p>
</attr>

<attr name='propagate'>
 <p>Propagate the cache dependencies to the surrounding
 <tag>cache</tag> tag, if there is any. Useful to locally add
 dependencies to a cache without introducing a new cache level. If
 there is no surrounding <tag>cache</tag> tag, this attribute is
 ignored.</p>

 <p>Note that only the dependencies are propagated, i.e. the settings
 in the \"variable\" and \"profile\" attributes. The other attributes
 are used only if there's no surrounding <tag>cache</tag> tag.</p>
</attr>

<attr name='nohash'>
 <p>If the cache is shared, then the content won't be made part of the
 cache key. Thus the cache entries can be mixed up with other
 <tag>cache</tag> tags.</p>
</attr>

<attr name='not-post-method'>
 <p>By adding this attribute all HTTP requests using the POST method will
 be unaffected by the caching. The result will be calculated every time,
 and the result will not be stored in the cache. The contents of the cache
 will however remain unaffected by the POST request.</p>
</attr>

<attr name='flush-on-no-cache'>
 <p>If this attribute is used the cache will be flushed every time a client
 sends a pragma no-cache header to the server. These are e.g. sent when
 shift+reload is pressed in Netscape Navigator.</p>
</attr>

<attr name='enable-client-cache'>
 <p>Mark output as cachable by clients. Note that this is likely to
 introduce overcaching - see the \"enable-protocol-cache\"
 attribute for details.</p>
</attr>

<attr name='enable-protocol-cache'>
 <p>Mark output as cachable by clients and in server-side protocol
 cache. Note that this is likely to introduce overcaching since
 neither the cache key(s) nor any timeout attributes are taken into
 account by those caches. You can use <xref href='set-max-cache.tag'/>
 to set a timeout for the protocol cache and for the client-side
 caching.</p>
</attr>

<attr name='mutex'>
 <p>For use in shared caches only. Following a cache miss for a shared
 entry, prevent reundant generation of a new result in concurrent threads.
 Only the first request will compute the value and all other threads will
 wait for this to complete, thereby saving CPU resources.</p>

 <p>The mutex protecting a particular <tag>cache</tag> tag depends on
 the variables given as cache key. This ensures unrestricted execution
 for entries where keys differ. Different <tag>cache</tag> instances will
 be protected by independent mutexes unless they 1) are given identical
 cache keys, and 2) have identical tag bodies (or uses the \"nohash\"
 attribute).</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the time this entry is valid.</p>
</attr>
<attr name='months' value='number'>
 <p>Add this number of months to the time this entry is valid.</p>
</attr>
<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time this entry is valid.</p>
</attr>
<attr name='days' value='number'>
 <p>Add this number of days to the time this entry is valid.</p>
</attr>
<attr name='hours' value='number'>
 <p>Add this number of hours to the time this entry is valid.</p>
</attr>
<attr name='beats' value='number'>
 <p>Add this number of beats to the time this entry is valid.</p>
</attr>
<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time this entry is valid.</p>
</attr>
<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time this entry is valid.</p>
</attr>",

// Intentionally left undocumented:
//
// <attr name='disable-key-hash'>
//  Do not hash the key used in the cache entry. Normally the
//  produced key is hashed to reduce memory usage and improve speed,
//  but since that makes it theoretically possible that two cache
//  entries clash, this attribute may be used to avoid it.
// </attr>

//----------------------------------------------------------------------

"nocache": #"<desc type='cont'><p><short>
 Avoid caching of a part inside a <tag>cache</tag> tag.</short> This
 is the same as using the <tag>cache</tag> tag with the \"nocache\"
 attribute.</p>

 <p>Note that when a part inside a <tag>cache</tag> tag isn't cached,
 it implies that any RXML tags that enclose the <tag>nocache</tag> tag
 inside the <tag>cache</tag> tag also aren't cached.</p>
</desc>

<attr name='enable-client-cache'>
 <p>Mark output as cachable in browsers.</p>
</attr>

<attr name='enable-protocol-cache'>
 <p>Mark output as cachable in server-side protocol cache and browser
    cache.</p>
</attr>",

//----------------------------------------------------------------------

"catch":#"<desc type='cont'><p><short>
 Evaluates the RXML code, and, if nothing goes wrong, returns the
 parsed contents.</short> If something does go wrong, the error
 message is returned instead. See also <xref
 href='throw.tag' />.
</p>
</desc>",

//----------------------------------------------------------------------

"charset":#"<desc type='both'><p>
 <short>Set output character set.</short>
 The tag can be used to decide upon the final encoding of the resulting page.
 All character sets listed in <a href='http://rfc.roxen.com/1345'>RFC 1345</a>
 are supported.
</p>
</desc>

<attr name='in' value='Character set'><p>
 Converts the contents of the charset tag from the character set indicated
 by this attribute to the internal text representation.</p>

 <note><p>This attribute is deprecated, use &lt;recode
 from=\"\"&gt;...&lt;/recode&gt; instead.</p></note>
</attr>

<attr name='out' value='Character set'><p>
 Sets the output conversion character set of the current request. The page
 will be sent encoded with the indicated character set.</p>
</attr>
",



//----------------------------------------------------------------------

"recode":#"<desc type='cont'><p>
 <short>Converts between character sets.</short>
 The tag can be used both to decode texts encoded in strange character
 encoding schemas, and encode internal data to a specified encoding
 scheme. All character sets listed in <a
 href='http://rfc.roxen.com/1345'>RFC 1345</a> are supported.
</p>
</desc>

<attr name='from' value='Character set'><p>
 Converts the contents of the charset tag from the character set indicated
 by this attribute to the internal text representation. Useful for decoding
 data stored in a database. The special character set called \"safe-utf8\"
 will try to decode utf8, and silently revert back in case the content is
 not valid utf8 (for example iso-8859-1); this is useful when the content
 is not always valid utf8.</p>
</attr>

<attr name='to' value='Character set'><p>
 Converts the contents of the charset tag from the internal representation
 to the character set indicated by this attribute. Useful for encoding data
 before storing it into a database.</p>

 <p>Any characters that cannot be represented in the selected encoding will
 generate a run-time error unless the <tt>entity-fallback</tt> or
 <tt>string-fallback</tt> attributes are provided.</p>
</attr>

<attr name='string-fallback' value='string'><p>
 Only applicable together with the <tt>to</tt> attribute. This string
 will be used for characters falling outside the target encoding instead of
 generating a run-time error.</p>

 <p>This example shows the HTML output for 7-bit US ASCII encoding which
 cannot represent the Swedish <tt>ц</tt> character:</p>

 <ex-src><p><recode to='ASCII' string-fallback='?'>Bjцrn Borg</recode></p></ex-src>
</attr>

<attr name='entity-fallback' value='yes|no'><p>
 Only applicable together with the <tt>to</tt> attribute. Default is
 <tt>no</tt>, but if set to <tt>yes</tt> any characters falling outside the
 target encoding will be output as numerical HTML entities instead of
 generating a run-time error. If both this and <tt>string-fallback</tt> are
 used at the same time this attribute will take precedence.</p>

 <p>This example shows the HTML output for 7-bit US ASCII encoding which
 cannot represent the Swedish <tt>ц</tt> character:</p>

 <ex-src><p><recode to='ASCII' entity-fallback='yes'>Bjцrn Borg</recode></p></ex-src>
</attr>
",

//----------------------------------------------------------------------

"configimage":#"<desc type='tag'><p><short>
 Returns one of the internal Roxen configuration images.</short> The
 src attribute is required. It is possible to pass attributes, such as 
 the title attribute, to the resulting tag by including them in the 
 configimage tag.
</p></desc>

<attr name='src' value='string'>
 <p>The name of the picture to show.</p>
</attr>

<attr name='border' value='number' default='0'>
 <p>The image border when used as a link.</p>
</attr>

<attr name='alt' value='string' default='The src string'>
 <p>The picture description.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will be applied to
 the image.</p>

 <p>All other attributes will be inherited by the generated img tag.</p>
</attr>",

//----------------------------------------------------------------------

"configurl":#"<desc type='tag'><p><short>
 Returns a URL to the administration interface.</short>
</p></desc>",

//----------------------------------------------------------------------

"cset":#"<desc type='cont'><p>
 Sets a variable with its content. The type of the content is always
 text. This is deprecated in favor of using <tag>set</tag> with
 content.</p>
</desc>

<attr name='variable' value='name'>
 <p>The variable to be set.</p>
</attr>

<attr name='quote' value='html|none'>
 <p>How the content should be quoted before assigned to the variable.
 Default is html.</p>
</attr>",

//----------------------------------------------------------------------

"crypt":#"<desc type='cont'><p><short>
 Encrypts the contents as a Unix style password.</short> Useful when
 combined with services that use such passwords.</p>

 <p>Unix style passwords are one-way encrypted, to prevent the actual
 clear-text password from being stored anywhere. When a login attempt
 is made, the password supplied is also encrypted and then compared to
 the stored encrypted password.</p>

 <p>Depending on the version of Roxen and Pike this tag supports
    several different encryption schemes.</p>
</desc>

<attr name='compare' value='string'>
 <p>Compares the encrypted string with the contents of the tag. The tag
 will behave very much like an <xref href='../if/if.tag' /> tag.</p>
<ex><crypt compare=\"LAF2kkMr6BjXw\">Roxen</crypt>
<then>Yepp!</then>
<else>Nope!</else>
</ex>
</attr>",

//----------------------------------------------------------------------

"hash-hmac":#"<desc type='cont'><p><short>
 Keyed-Hashing for Message Authentication (HMAC) tag.</short></p>

<ex-box><hash-hmac hash='md5' password='key'>The quick brown fox jumps over the lazy dog</hash-hmac>
  Result: 80070713463e7749b90c2dc24911e275
</ex-box>
</desc>

<attr name='hash' value='string'>
 <p>The hash algorithm to use (e.g. MD5, SHA1, SHA256 etc.) All hash algorithms
supported by Pike can be used.</p>
</attr>

<attr name='password' value='string'>
 <p>The password to use.</p>
</attr>",

//----------------------------------------------------------------------

"date":#"<desc type='tag'><p><short>
 Inserts the time and date.</short> Does not require attributes.
</p>

<ex><date/></ex>
</desc>

<attr name='unix-time' value='number of seconds'>
 <p>Display this time instead of the current. The time is taken as a
 unix timestamp (i.e. the number of seconds since 00:00:00 Jan 1 1970
 UTC).</p>

<ex><date unix-time='946684800'/></ex>
</attr>

<attr name='http-time' value='http time stamp'>
 <p>Display this time instead of the current. This attribute uses the
 specified http-time, instead of the current time.</p>
 <p>All three http-time formats are supported:</p>

<ex><p>RFC 822, updated by RFC 1123:
<date http-time='Sun, 06 Nov 1994 08:49:37 GMT'/></p>

<p>RFC 850, obsoleted by RFC 1036:
<date http-time='Sunday, 06-Nov-94 08:49:37 GMT' /></p>

<p>ANSI C's asctime() format:
<date http-time='Sun Nov  6 08:49:37 1994' /></p></ex>
</attr>

<attr name='iso-time' value='{yyyy-mm-dd, yyyy-mm-dd hh:mm, yyyy-mm-dd hh:mm:ss}'>
 <p>Display this time instead of the current. This attribute uses the specified
ISO 8601 time as the starting time, instead of the current time. The character
between the date and the time can be either \" \" (space) or \"T\" (the letter T).</p>

<ex><date iso-time='2002-09-03 16:06'/></ex>
</attr>

<attr name='timezone' value='local|GMT' default='local'>
 <p>Display the time from another timezone.</p>
</attr>

<attr name='to-timezone' value='local|GMT|Europe/Stockholm|...' default='local'>
 <p>Display the time in another timezone.</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the result.</p>
 <ex><date date='' years='2'/></ex>
</attr>

<attr name='months' value='number'>
 <p>Add this number of months to the result.</p>
 <ex><date date='' months='2'/></ex>
</attr>

<attr name='weeks' value='number'>
 <p>Add this number of weeks to the result.</p>
 <ex><date date='' weeks='2'/></ex>
</attr>

<attr name='days' value='number'>
 <p>Add this number of days to the result.</p>
</attr>

<attr name='hours' value='number'>
 <p>Add this number of hours to the result.</p>
 <ex><date time='' hours='2' type='iso'/></ex>
</attr>

<attr name='beats' value='number'>
 <p>Add this number of beats to the result.</p>
 <ex><date time='' beats='10' type='iso'/></ex>
</attr>

<attr name='minutes' value='number'>
 <p>Add this number of minutes to the result.</p>
</attr>

<attr name='seconds' value='number'>
 <p>Add this number of seconds to the result.</p>
</attr>

<attr name='adjust' value='number'>
 <p>Add this number of seconds to the result.</p>
</attr>

<attr name='brief'>
 <p>Show in brief format.</p>
<ex><date brief=''/></ex>
</attr>

<attr name='time'>
 <p>Show only time.</p>
<ex><date time=''/></ex>
</attr>

<attr name='date'>
 <p>Show only date.</p>
<ex><date date=''/></ex>
</attr>

<attr name='type' value='number|ordered|string|discordian|http|iso|stardate|unix'>
 <p>Defines in which format the date should be displayed in.</p>

 <p>The following types are only useful together with the \"part\"
 attribute:</p>

<xtable>
<row><c><p><i>type=number</i></p></c><c><ex><date part='day' type='number'/></ex></c></row>
<row><c><p><i>type=ordered</i></p></c><c><ex><date part='day' type='ordered'/></ex></c></row>
<row><c><p><i>type=string</i></p></c><c><ex><date part='day' type='string'/></ex></c></row>
</xtable>

 <p>The following types are only useful without the \"part\"
 attribute:</p>

<xtable>
  <row>
    <c><p><i>type=discordian</i></p></c>
    <c><ex><date type='discordian'/><br/>
<date type='discordian' year='' holiday=''/></ex></c>
  </row>
  <row>
    <c><p><i>type=http</i></p></c>
    <c><ex><date type='http'/> </ex></c>
  </row>
  <row>
    <c><p><i>type=iso</i></p></c>
    <c><ex><date type='iso' time=''/><br/>
<date type='iso' date=''/><br/>
<date type='iso'/></ex></c>
  </row>
  <row>
    <c><p><i>type=stardate</i></p></c>
    <c><ex><date type='stardate' prec='5'/></ex></c>
  </row>
  <row>
    <c><p><i>type=unix</i></p></c>
    <c><ex><date type='unix'/></ex></c>
  </row>
</xtable>

 <p>'http' is the format specified for use in the HTTP protocol
 (useful for headers etc).</p>

 <p>'stardate' has a separate companion attribute \"prec\" which sets
 the precision.</p>
</attr>

<attr name='part' value='year|month|day|wday|date|mday|hour|minute|second|yday|beat|week|seconds'>
 <p>Defines which part of the date should be displayed. Day and wday is
 the same. Date and mday is the same. Yday is the day number of the
 year. Seconds is unix time type. Only the types string, number and
 ordered applies when the part attribute is used.</p>

<xtable><row><h>Part</h><h>Meaning</h></row>
<row><c><p>year</p></c>
  <c><p>Display the year.</p>
     <ex><date part='year' type='number'/></ex></c></row>
<row><c><p>month</p></c>
  <c><p>Display the month.</p>
     <ex><date part='month' type='ordered'/></ex></c></row>
<row><c><p>day</p></c>
  <c><p>Display the weekday, starting with Sunday.</p>
     <ex><date part='day' type='ordered'/></ex></c></row>
<row><c><p>wday</p></c>
  <c><p>Display the weekday. Same as 'day'.</p>
     <ex><date part='wday' type='string'/></ex></c></row>
<row><c><p>date</p></c>
  <c><p>Display the day of this month.</p>
     <ex><date part='date' type='ordered'/></ex></c></row>
<row><c><p>mday</p></c>
  <c><p>Display the number of days since the last full month.</p>
     <ex><date part='mday' type='number'/></ex></c></row>
<row><c><p>hour</p></c>
  <c><p>Display the numbers of hours since midnight.</p>
     <ex><date part='hour' type='ordered'/></ex></c></row>
<row><c><p>minute</p></c>
  <c><p>Display the numbers of minutes since the last full hour.</p>
     <ex><date part='minute' type='number'/></ex></c></row>
<row><c><p>second</p></c>
  <c><p>Display the numbers of seconds since the last full minute.</p>
     <ex><date part='second' type='string'/></ex></c></row>
<row><c><p>yday</p></c>
  <c><p>Display the number of days since the first of January.</p>
     <ex><date part='yday' type='ordered'/></ex></c></row>
<row><c><p>beat</p></c>
  <c><p>Display the number of beats since midnight Central European
  Time(CET). There is a total of 1000 beats per day. The beats system
  was designed by <a href='http://www.swatch.com'>Swatch</a> as a
  means for a universal time, without time zones and day/night
  changes.</p>
     <ex><date part='beat' type='number'/></ex></c></row>
<row><c><p>week</p></c>
  <c><p>Display the number of the current week.</p>
     <ex><date part='week' type='number'/></ex></c></row>
<row><c><p>seconds</p></c>
  <c><p>Display the total number of seconds this year.</p>
     <ex><date part='seconds' type='number'/></ex></c></row>
</xtable></attr>

<attr name='strftime' value='string'>
 <p>If this attribute is given to date, it will format the result
 according to the argument string.</p>

 <p>The <tt>!</tt> or <tt>-</tt> (dash) modifier can be inserted to
 get rid of extra field padding in any of the formatters below. For
 instance, use <tt>%!m</tt> to get the month value without zero
 padding. The <tt>E</tt> modifier accessses alternative forms of month
 names, e.g. <tt>%EB</tt> which in Russian locale gives a genitive
 form. The <tt>^</tt> modifier can be used to convert the result
 string to uppercase, while <tt>~</tt> capitalizes the result
 string.</p>

<xtable>
 <row><h>Format</h><h>Meaning</h></row>
 <row><c><p>%%</p></c><c><p>Percent character</p></c></row>
 <row><c><p>%a</p></c><c><p>Abbreviated weekday name, e.g. \"Mon\"</p></c></row>
 <row><c><p>%A</p></c><c><p>Weekday name</p></c></row>
 <row><c><p>%b</p></c><c><p>Abbreviated month name, e.g. \"Jan\"</p></c></row>
 <row><c><p>%B</p></c><c><p>Month name</p></c></row>
 <row><c><p>%c</p></c><c><p>Date and time, e.g. \"%a %b %d  %H:%M:%S %Y\"</p></c></row>
 <row><c><p>%C</p></c><c><p>Century number, zero padded to two charachters.</p></c></row>
 <row><c><p>%d</p></c><c><p>Day of month (1-31), zero padded to two characters.</p></c></row>
 <row><c><p>%D</p></c><c><p>Date as \"%m/%d/%y\"</p></c></row>
 <row><c><p>%e</p></c><c><p>Day of month (1-31), space padded to two characters.</p></c></row>
 <row><c><p>%H</p></c><c><p>Hour (24 hour clock, 0-23), zero padded to two characters.</p></c></row>
 <row><c><p>%h</p></c><c><p>See %b</p></c></row>
 <row><c><p>%I</p></c><c><p>Hour (12 hour clock, 1-12), zero padded to two charcters.</p></c></row>
 <row><c><p>%j</p></c><c><p>Day numer of year (1-366), zero padded to three characters.</p></c></row>
 <row><c><p>%k</p></c><c><p>Hour (24 hour clock, 0-23), space padded to two characters.</p></c></row>
 <row><c><p>%l</p></c><c><p>Hour (12 hour clock, 1-12), space padded to two characters.</p></c></row>
 <row><c><p>%m</p></c><c><p>Month number (1-12), zero padded to two characters.</p></c></row>
 <row><c><p>%M</p></c><c><p>Minute (0-59), zero padded to two characters.</p></c></row>
 <row><c><p>%n</p></c><c><p>Newline</p></c></row>
 <row><c><p>%p</p></c><c><p>\"a.m.\" or \"p.m.\"</p></c></row>
 <row><c><p>%P</p></c><c><p>\"am\" or \"pm\"</p></c></row>
 <row><c><p>%r</p></c><c><p>Time in 12 hour clock format with %p</p></c></row>
 <row><c><p>%R</p></c><c><p>Time as \"%H:%M\"</p></c></row>
 <row><c><p>%S</p></c><c><p>Seconds (0-60), zero padded to two characters. 60 only occurs in case of a leap second.</p></c></row>
 <row><c><p>%t</p></c><c><p>Tab</p></c></row>
 <row><c><p>%T</p></c><c><p>Time as \"%H:%M:%S\"</p></c></row>
 <row><c><p>%u</p></c><c><p>Weekday as a decimal number (1-7), 1 is Sunday.</p></c></row>
 <row><c><p>%U</p></c><c><p>Week number of year as a decimal number (0-53), with sunday as the first day of week 1,
    zero padded to two characters.</p></c></row>
 <row><c><p>%V</p></c><c><p>ISO week number of the year as a decimal number (1-53), zero padded to two characters.</p></c></row>
 <row><c><p>%w</p></c><c><p>Weekday as a decimal number (0-6), 0 is Sunday.</p></c></row>
 <row><c><p>%W</p></c><c><p>Week number of year as a decimal number (0-53), with sunday as the first day of week 1,
    zero padded to two characters.</p></c></row>
 <row><c><p>%x</p></c><c><p>Date as \"%a %b %d %Y\"</p></c></row>
 <row><c><p>%X</p></c><c><p>See %T</p></c></row>
 <row><c><p>%y</p></c><c><p>Year (0-99), zero padded to two characters.</p></c></row>
 <row><c><p>%Y</p></c><c><p>Year (0-9999), zero padded to four characters.</p></c></row>
</xtable>

<ex><date strftime=\"%B %e %Y, %A %T\"/></ex>
</attr>

<attr name='lang' value='langcode'>
 <p>Defines in what language a string will be presented in. Used together
 with <att>type=string</att> and the <att>part</att> attribute to get
 written dates in the specified language.</p>

<ex><date part='day' type='string' lang='de'/></ex>
</attr>

<attr name='case' value='upper|lower|capitalize'>
 <p>Changes the case of the output to upper, lower or capitalize.</p>
 <ex><date date='' lang='&client.language;' case='upper'/></ex>
</attr>

<attr name='prec' value='number'>
 <p>The number of decimals in the stardate.</p>
</attr>",

//----------------------------------------------------------------------

"debug":#"<desc type='tag'><p><short>
 Helps debugging RXML-pages as well as modules.</short> When debugging mode is
 turned on, all error messages will be displayed in the HTML code.
</p></desc>

<attr name='on'>
 <p>Turns debug mode on.</p>
</attr>

<attr name='off'>
 <p>Turns debug mode off.</p>
</attr>

<attr name='toggle'>
 <p>Toggles debug mode.</p>
</attr>

<attr name='showvar' value='variable'>
 <p>Shows the value of the given variable in a generic debug format
 that works regardless of the type.</p>
</attr>

<attr name='showscope' value='scope'>
 <p>Shows all the variables in the given scope in a generic debug
 format.</p>
</attr>

<attr name='showlog'>
 <p>Shows the debug log.</p>
</attr>

<attr name='showid' value='string'>
 <p>Shows a part of the id object. E.g. showid=\"id->request_headers\".</p>
</attr>

<attr name='sleep' value='int|float'>
 <p>Delays RXML execution for the current request the specified number of
    seconds.</p>
</attr>

<attr name='werror' value='string'>
  <p>When you have access to the server debug log and want your RXML
     page to write some kind of diagnostics message or similar, the
     werror attribute is helpful.</p>

  <p>This can be used on the error page, for instance, if you'd want
     such errors to end up in the debug log:</p>

  <ex-box><debug werror='File &page.url; not found!
\(linked from &client.referrer;)'/></ex-box>

  <p>The message is also shown the request trace, e.g. when
  \"Tasks\"/\"Debug information\"/\"Resolve path...\" is used in the
  configuration interface.</p>
</attr>",

//----------------------------------------------------------------------

"dec":#"<desc type='tag'><p><short>
 Decrements an integer variable.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The variable to be decremented.</p>
</attr>

<attr name='value' value='number' default='1'>
 <p>The value to be subtracted.</p>
</attr>",

//----------------------------------------------------------------------

"default":#"<desc type='cont'><p><short hide='hide'>
 Used to set default values for form elements.</short> This tag makes it easier
 to give default values to \"<tag>select</tag>\" and \"<tag>input</tag>\" form elements.
 Simply put the <tag>default</tag> tag around the form elements to which it should give
 default values.</p>

 <p>This tag is particularly useful in combination with generated forms or forms with
 generated default values, e.g. by database tags.</p>
</desc>

<attr name='value' value='string'>
 <p>The value or values to set. If several values are given, they are separated with the
 separator string.</p>
</attr>

<attr name='separator' value='string' default=','>
 <p>If several values are to be selected, this is the string that
 separates them.</p>
</attr>

<attr name='name' value='string'>
 <p>If used, the default tag will only affect form element with this name.</p>
</attr>

<ex-box><default name='my-select' value='&form.preset;'>
  <select name='my-select'>
    <option value='1'>First</option>
    <option value='2'>Second</option>
    <option value='3'>Third</option>
  </select>
</default></ex-box>

<ex-box><form>
<default value=\"&form.opt1;,&form.opt2;,&form.opt3;\">
  <input name=\"opt1\" value=\"yes1\" type=\"checkbox\" /> Option #1
  <input name=\"opt2\" value=\"yes2\" type=\"checkbox\" /> Option #2
  <input name=\"opt3\" value=\"yes3\" type=\"checkbox\" /> Option #3
  <input type=\"submit\" />
</default>
</form></ex-box>",

"doc":#"<desc type='cont'><p><short hide='hide'>
 Eases code documentation by reformatting it.</short>Eases
 documentation by replacing \"{\", \"}\" and \"&amp;\" with
 \"&amp;lt;\", \"&amp;gt;\" and \"&amp;amp;\". No attributes required.
</p></desc>

<attr name='quote'>
 <p>Instead of replacing with \"{\" and \"}\", \"&lt;\" and \"&gt;\"
 is replaced with \"&amp;lt;\" and \"&amp;gt;\".</p>

<ex><doc quote=''>
<table>
 <tr>
    <td> First cell </td>
    <td> Second cell </td>
 </tr>
</table>
</doc></ex>
</attr>

<attr name='pre'><p>
 The result is encapsulated within a <tag>pre</tag> container.</p>

<ex><doc pre=''>
\{table}
 {tr}
    {td} First cell {/td}
    {td} Second cell {/td}
 {/tr}
\{/table}
</doc></ex>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the pre element.</p>
</attr>",

//----------------------------------------------------------------------

"expire-time":#"<desc type='tag'><p><short hide='hide'>
 Sets client cache expire time for the document.</short>
 Sets client cache expire time for the document by sending the HTTP header
 \"Expires\". Note that on most systems the time can only be set to dates
 before 2038 due to operating software limitations.
</p></desc>

<attr name='now'>
 <p>Notify the client that the document expires now. The headers
 \"Pragma: no-cache\" and \"Cache-Control: no-cache\"
 will also be sent, besides the \"Expires\" header.</p>
</attr>

<attr name='unix-time' value='number'>
 <p>The exact time of expiration, expressed as a posix time integer.</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the result.</p>
</attr>

<attr name='months' value='number'>
  <p>Add this number of months to the result.</p>
</attr>

<attr name='weeks' value='number'>
  <p>Add this number of weeks to the result.</p>
</attr>

<attr name='days' value='number'>
  <p>Add this number of days to the result.</p>
</attr>

<attr name='hours' value='number'>
  <p>Add this number of hours to the result.</p>
</attr>

<attr name='beats' value='number'>
  <p>Add this number of beats to the result.</p>
</attr>

<attr name='minutes' value='number'>
  <p>Add this number of minutes to the result.</p>
</attr>

<attr name='seconds' value='number'>
   <p>Add this number of seconds to the result.</p>

</attr>",

//----------------------------------------------------------------------

"for":#"<desc type='cont'><p><short>
 Makes it possible to create loops in RXML.</short>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</p></desc>

<attr name='from' value='number'>
 <p>Initial value of the loop variable.</p>
</attr>

<attr name='step' value='number'>
 <p>How much to increment the variable per loop iteration. By default one.</p>
</attr>

<attr name='to' value='number'>
 <p>How much the loop variable should be incremented to.</p>
</attr>

<attr name='variable' value='name'>
 <p>Name of the loop variable.</p>
</attr>",

//----------------------------------------------------------------------

"fsize":#"<desc type='tag'><p><short>
 Prints the size of the specified file.</short></p>

 <p>In a text/* context, the size is returned in a pretty-print
 format, like \"42.2 kb\". Otherwise it is returned as a plain
 integer.</p>
</desc>

<attr name='file' value='string'>
 <p>Show size for this file.</p>
</attr>",

//----------------------------------------------------------------------

"gauge":#"<desc type='cont'><p><short>
 Measures how much CPU time it takes to run its contents through the
 RXML parser.</short> Returns the number of seconds it took to parse
 the contents.
</p></desc>

<attr name='variable' value='string'>
 <p>The result will be put into a variable. E.g. variable=\"var.gauge\" will
 put the result in a variable that can be reached with <ent>var.gauge</ent>.</p>
</attr>

<attr name='silent'>
 <p>Don't print anything.</p>
</attr>

<attr name='timeonly'>
 <p>Only print the time.</p>
</attr>

<attr name='resultonly'>
 <p>Only print the result of the parsing. Useful if you want to put the time in
 a database or such.</p>
</attr>",

//----------------------------------------------------------------------

"header":#"<desc type='tag'><p><short>
 Adds an HTTP header to the page sent back to the client.</short> For
 more information about HTTP headers please steer your browser to
 chapter 14, 'Header field definitions' in <a href='http://community.roxen.com/developers/idocs/rfc/rfc2616.html'>RFC 2616</a>, available at Roxen Community.
</p>

<note><p>If not both name and value attributes are present, the tag is
passed on to the output HTML assuming the intention is to make the HTML5
header tag.</p></note>

</desc>

<attr name='name' value='string' required='required'>
 <p>The name of the header.</p>
</attr>

<attr name='value' value='string' required='required'>
 <p>The value of the header.</p>
</attr>

<attr name='mode' value='add|set|auto' default='auto'>
 <p>How to add the header to the response: The value \"add\" appends
 another value to the header, after any values it got already (not all
 response headers allow this). \"set\" sets the header to the given
 value, overriding any existing value(s). \"auto\" uses \"add\" mode
 for all headers which are specified to accept multiple values in RFC
 2616, and \"set\" mode for all other headers. \"auto\" is the default
 if this attribute is left out.</p>
</attr>",

//----------------------------------------------------------------------

"imgs":#"<desc type='tag'><p><short>
 Generates an image tag with the correct dimensions in the width and height
 attributes.</short> These dimensions are read from the image itself, so the
 image must exist when the tag is generated. The image must also be in GIF,
 JPEG/JFIF, PNG, PSD or TIFF format. It is possible to pass attributes, such 
 as the alt attribute, to the resulting tag by including them in the imgs tag. 
 Note that the image content is not converted.</p>

 <p>See also the <tag>emit source=\"imgs\"</tag> for retrieving
 the same image information without generating the output tag.
</p></desc>

<attr name='src' value='string' required='required'>
 <p>The path to the file that should be shown.</p>
</attr>

<attr name='alt' value='string'>
 <p>Description of the image. If no description is provided, the filename
 (capitalized, without extension and with some characters replaced) will
 be used.</p>
 </attr>

<attr name='quiet' value='string'>
 <p>If provided, silently ignore run-time errors such as image not found.</p>
</attr>

 <p>All other attributes will be inherited by the generated img tag.</p>",

//----------------------------------------------------------------------

"emit#imgs": ({ #"<desc type='plugin'><p><short>
 Similar to <tag>imgs</tag> but works as a emit plugin. This emit source
 returns dimensions and type for a given image file.</short>
</p></desc>

<attr name='src' value='string' required='required'>
 <p>The path to the file that should be inspected.</p>
</attr>

<attr name='quiet' value='string'>
 <p>If provided, silently ignore run-time errors such as image not found.</p>
</attr>",

  ([ "&_.xsize;":#"<desc type='entity'><p>
         The width of the image.</p></desc>",
     "&_.ysize;":#"<desc type='entity'><p>
         The height of the image.</p></desc>",
     "&_.type;":#"<desc type='entity'><p>
         The type of the image. Supported types are \"gif\", \"jpeg\", \"png\",
         \"psd\"and \"tiff\".</p></desc>" ])
  }),

//----------------------------------------------------------------------

"combine-path":#"<desc type='tag'><p><short>
 Combines paths.</short>
</p></desc>

<attr name='base' value='string' required='required'>
 <p>The base path.</p>
</attr>

<attr name='path' value='string' required='required'>
 <p>The path to be combined (appended) to the base path.</p>
</attr>",

//----------------------------------------------------------------------

"inc":#"<desc type='tag'><p><short>
 Increments an integer variable.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The variable to be incremented.</p>
</attr>

<attr name='value' value='number' default='1'>
 <p>The value to be added.</p>
</attr>",

//----------------------------------------------------------------------

"insert":#"<desc type='tag'><p><short>
 Inserts a file, variable or other object into a webpage.</short>
</p></desc>

<attr name='quote' value='html|none'>
 <p>How the inserted data should be quoted. Default is \"html\", except for
 the file plugin where it's \"none\".</p>
</attr>",

//----------------------------------------------------------------------

"insert#variable":#"<desc type='plugin'><p><short>
 Inserts the value of a variable.</short>
</p></desc>

<attr name='variable' value='string'>
 <p>The name of the variable.</p>
</attr>

<attr name='scope' value='string'>
 <p>The name of the scope, unless given in the variable attribute.</p>
</attr>

<attr name='index' value='number'>
 <p>If the value of the variable is an array, the element with this
 index number will be inserted. 1 is the first element. -1 is the last
 element.</p>
</attr>

<attr name='split' value='string'>
 <p>A string with which the variable value should be split into an
 array, so that the index attribute may be used.</p>
</attr>",

//----------------------------------------------------------------------

"insert#variables":#"<desc type='plugin'><p><short>
 Inserts a listing of all variables in a scope.</short> In a string or
 text context, the variables are formatted according to the
 \"variables\" attribute. Otherwise the scope is returned as-is, i.e.
 as a mapping.</p>

 " // FIXME: Moved the following to some intro chapter.
 #"<note><p>It is possible to create a scope with an infinite number
 of variables. When such a scope is listed in string form (or iterated
 over with <tag>emit source=\"values\"</tag>), it is up to the
 implementation which variables are included in the list, i.e. it will
 not cause any problem except that all variables will not be listed.
 An implementation of a limited scope might also hide variables so
 that they don't get listed by this tag.</p></note>

 <p>Compatibility note: If the compatibility level is less than 5.0
 then a string list is always returned.</p>
</desc>

<attr name='variables' value='full|plain'>
 <p>Specifies how the output will be formatted in a string context, as
 shown by the following example. The default is \"plain\".</p>

 <ex>
<set variable=\"var.a\">hello</set>
<set variable=\"var.b\" type=\"int\">4711</set>
<set variable=\"var.c\" split=\" \">x y z</set>
<pre><insert source=\"variables\" variables=\"full\" scope=\"var\"/></pre>
<hr />
<pre><insert source=\"variables\" variables=\"plain\" scope=\"var\"/></pre></ex>
</attr>

<attr name='scope'>
 <p>The name of the scope that should be listed, if not the present scope.</p>
</attr>",

//----------------------------------------------------------------------

"insert#scopes":#"<desc type='plugin'><p><short>
 Inserts a listing of all present variable scopes.</short>
</p></desc>

<attr name='scopes' value='full|plain'>
 <p>Sets how the output should be formatted.</p>

 <ex><insert scopes='plain'/></ex>
</attr>",

//----------------------------------------------------------------------

"insert#file":#"<desc type='plugin'><p><short>
 Inserts the contents of a file.</short> It reads files in a way
 similar to if you fetched the file with a browser, so the file may be
 parsed before it is inserted, depending on settings in the RXML
 parser. Most notably which kinds of files (extensions) that should be
 parsed. Since it reads files like a normal request, e.g. generated
 pages from location modules can be inserted. Put the tag
 <xref href='../programming/eval.tag' /> around <tag>insert</tag> if the file should be
 parsed after it is inserted in the page. This enables RXML defines
 and scope variables to be set in the including file (as opposed to
 the included file). You can also configure the file system module so
 that files with a certain extension can not be downloaded, but still
 inserted into other documents.
</p></desc>

<attr name='file' value='string'>
 <p>The virtual path to the file to be inserted.</p>

 <ex-box><eval><insert file='html_header.inc'/></eval></ex-box>
</attr>

<attr name='decode-charset'><p>
 Decode the character encoding before insertion.</p>

 <p>Used to decode the transport encoding for the inserted file.</p>
</attr>

<attr name='language' value='string'>
  <p>Optionally add this language at the top of the list of
     preferred languages.</p>
</attr>",

//----------------------------------------------------------------------

"insert#realfile":#"<desc type='plugin'><p><short>
 Inserts a raw, unparsed file.</short> The disadvantage with the
 realfile plugin compared to the file plugin is that the realfile
 plugin needs the inserted file to exist, and can't fetch files from e.g.
 an arbitrary location module. Note that the realfile insert plugin
 can not fetch files from outside the virtual file system or files in a
 CMS filesystem.
</p></desc>

<attr name='realfile' value='string'>
 <p>The virtual path to the file to be inserted.</p>
</attr>",

//----------------------------------------------------------------------

"maketag":({ #"<desc type='cont'><p><short hide='hide'>
 Makes it possible to create tags.</short>This tag creates tags.
 The content is used as content of the produced container.
</p></desc>

<attr name='name' value='string'>
 <p>The name of the tag that should be produced. This attribute is required for tags,
 containers and processing instructions, i.e. for the types 'tag', 'container' and 'pi'.</p>
<ex-src><maketag name='one' type='tag'></maketag>
<maketag name='one' type='tag' noxml='noxml'></maketag></ex-src>
</attr>

<attr name='noxml'>
 <p>Tags should not be terminated with a trailing slash. Only makes a difference for
 the type 'tag'.</p>
</attr>

<attr name='type' value='tag|container|pi|comment|cdata'>
 <p>What kind of tag should be produced. The argument 'Pi' will produce a processing instruction tag.</p>
<ex-src><maketag type='pi' name='PICS'>l gen true r (n 0 s 0 v 0 l 2)</maketag></ex-src>
<ex-src><maketag type='comment'>Menu starts here</maketag></ex-src>
<ex-box><maketag type='comment'>Debug: &form.res; &var.sql;</maketag></ex-box>
<ex-src><maketag type='cdata'>Exact   words</maketag></ex-src>
</attr>",

 ([
   "attrib":#"<desc type='cont'><p>
   Inside the maketag container the container
   <tag>attrib</tag> is defined. It is used to add attributes to the produced
   tag. The contents of the attribute container will be the
   attribute value. E.g.</p>
   </desc>

<ex><eval>
<maketag name=\"replace\" type=\"container\">
 <attrib name=\"from\">A</attrib>
 <attrib name=\"to\">U</attrib>
 MAD
</maketag>
</eval>
</ex>

   <attr name='name' value='string' required='required'>
   <p>The name of the attribute.</p>
   </attr>"
 ])
   }),

//----------------------------------------------------------------------

"modified":#"<desc type='tag'><p><short hide='hide'>
 Prints when or by whom a page was last modified.</short> Prints when
 or by whom a page was last modified, by default the current page.
 In addition to the attributes below, it also handles the same
 attributes as <xref href='date.tag'/> for formating date output.
</p></desc>

<attr name='by'>
 <p>Print by whom the page was modified. Takes the same attributes as
 <xref href='user.tag' />. This attribute requires a user database.
 </p>

 <ex-box>This page was last modified by <modified by='1'
 realname='1'/>.</ex-box>
</attr>

<attr name='file' value='path'>
 <p>Get information about this file rather than the current page.</p>
</attr>

<attr name='realfile' value='path'>
 <p>Get information from this file in the computer's filesystem rather
 than Roxen Webserver's virtual filesystem.</p>
</attr>",

//----------------------------------------------------------------------

"random":#"<desc type='cont'><p><short>
 Randomly chooses a message from its contents, or
 returns an integer within a given range.</short>
</p></desc>

<attr name='range' value='integer'>
 <p>The random range, from 0 up to but not including the range integer.</p>

 <ex><random range='10'/></ex>
</attr>

<attr name='separator' value='string'>
 <p>The separator used to separate the messages, by default newline.</p>

<ex><random separator='#'>Foo#Bar#Baz</random></ex>
</attr>

<attr name='seed' value='string'>
 <p>Enables you to use a seed that determines which message to choose.</p>

<ex-box>Tip of the day:
<set variable='var.day'><date type='iso' date=''/></set>
<random seed='var.day'><insert file='tips.txt'/></random></ex-box>
</attr>",

//----------------------------------------------------------------------

"redirect":#"<desc type='tag'><p><short hide='hide'>
 Redirects the user to another page.</short> Redirects the user to
 another page by sending a HTTP redirect header to the client. If the
 redirect is local, i.e. within the server, all prestates are preserved.
 E.g. \"/index.html\" and \"index.html\" preserves the prestates, while
 \"http://server.com/index.html\" does not.
</p></desc>

<attr name='to' value='URL' required='required'>
 <p>The location to where the client should be sent.</p>
</attr>

<attr name='type' value='string'>
  <p>The type of redirect, i.e. the http status code. This can be one
  of the strings \"permanent\" (301), \"found\" (302), \"see-other\"
  (303), or \"temporary\" (307). It can also be an integer code. The
  default is 302.</p>
</attr>

<attr name='add' value='string'>
 <p>The prestate or prestates that should be added, in a comma-separated
 list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The prestate or prestates that should be dropped, in a comma-separated
 list.</p>
</attr>

<attr name='drop-all'>
 <p>Removes all prestates from the redirect target.</p>
</attr>

<attr name='text' value='string'>
 <p>Sends a text string to the browser, that hints from where and why the
 page was redirected. Not all browsers will show this string. Only
 special clients like Telnet uses it.</p>

<p>Arguments prefixed with \"add\" or \"drop\" are treated as prestate
 toggles, which are added or removed, respectively, from the current
 set of prestates in the URL in the redirect header (see also <xref href='apre.tag' />). Note that this only works when the
 to=... URL is absolute, i.e. begins with a \"/\", otherwise these
 state toggles have no effect.</p>
</attr>",

//----------------------------------------------------------------------

"remove-cookie":#"<desc type='tag'><p><short>
 Sets the expire-time of a cookie to a date that has already occured.
 This forces the browser to remove it.</short>
 This tag won't remove the cookie, only set it to the empty string, or
 what is specified in the value attribute and change
 it's expire-time to a date that already has occured. This is
 unfortunutaly the only way as there is no command in HTTP for
 removing cookies. We have to give a hint to the browser and let it
 remove the cookie.
</p></desc>

<attr name='name' required='required'>
 <p>Name of the cookie the browser should remove.</p>
</attr>

<attr name='value' value='text'>
 <p>Even though the cookie has been marked as expired some browsers
 will not remove the cookie until it is shut down. The text provided
 with this attribute will be the cookies intermediate value.</p>

 <p>Note that removing a cookie won't take effect until the next page
 load.</p>
</attr>

<attr name='domain'>
 <p>Domain of the cookie the browser should remove.</p>
</attr>

<attr name='path' value='string' default=\"\">
  <p>Path of the cookie the browser should remove</p>
</attr>",

//----------------------------------------------------------------------

"replace":#"<desc type='cont'><p><short>
 Replaces strings in the content with other strings.</short>
</p></desc>

<attr name='from' value='string' required='required'>
 <p>String to be replaced.</p>

 <p>When the \"type\" argument is \"words\", this is a list of strings
 separated according to the \"separator\" argument.</p>
</attr>

<attr name='to' value='string'>
 <p>Replacement string. The default is \"\" (the empty string).</p>

 <p>When the \"type\" argument is \"words\", this is a list of strings
 separated according to the \"separator\" argument. The first string
 in the \"from\" list will be replaced with the first one in the
 \"to\" list, etc. If there are fewer \"to\" than \"from\" elements,
 the remaining ones in the \"from\" list will be replaced with the
 empty string. All replacements are done in parallel, i.e. the result
 of one replacement is not replaced again with another.</p>
</attr>

<attr name='first' value='integer'>
 <p>If specified, only replace the first number of specified occurances. Works only together with type='word'</p>
</attr>

<attr name='last' value='integer'>
 <p>If specified, only replace the last number of specified occurances. Works only together with type='word'</p>
</attr>

<attr name='type' value='word|words' default='word'>
 <p>\"word\" means that a single string is replaced. \"words\"
 replaces several strings, and the \"from\" and \"to\" values are
 interpreted as string lists.</p>
</attr>

<attr name='separator' value='string' default=','>
 <p>The separator between words in the \"from\" and \"to\" arguments.
 This is only relevant when the \"type\" argument is \"words\".</p>
</attr>",

//----------------------------------------------------------------------

"substring": #"<desc type='cont'>
 <p><short>Extract a part of a string.</short> The part to extract can
 be specified using character positions, substring occurrences, and/or
 fields separated by a set of characters. Some examples:</p>

 <p>To pick out substrings based on character positions:</p>

 <ex><substring index=\"2\">abcdef</substring></ex>
 <ex><substring index=\"-2\">abcdef</substring></ex>
 <ex><substring from=\"2\" to=\"-2\">abcdef</substring></ex>

 <p>To pick out substrings based on string occurrences:</p>

 <ex><substring after=\"the\">
  From the past to the future via the present.
</substring></ex>
 <ex><substring after=\"the\" from=\"2\">
  From the past to the future via the present.
</substring></ex>
 <ex><substring after=\"the\" from=\"-1\">
  From the past to the future via the present.
</substring></ex>
 <ex><substring after=\"to\" before=\"the\" to=\"3\">
  From the past to the future via the present.
</substring></ex>

 <p>To pick out substrings based on separated fields:</p>

 <ex><substring separator-chars=\",:\" index=\"4\">a, , b:c, d::e, : f</substring></ex>
 <ex>[<substring separator-whites=\"\" from=\"3\" to=\"4\">
   These   are  some
 words  separated by   different amounts of  whitespace.
</substring>]</ex>
 <ex>[<substring separator-chars=\",:\" trimwhites=\"\" from=\"3\">
  a, , b:c, d::e, : f
</substring>]</ex>
 <ex>[<substring separator=\",\" trimwhites=\"\" from=\"3\" before=\"::\">
   a, , b: c, d::e, : f
</substring>]</ex>

 <p>To use just the separator/join attributes to replace sets of
 characters:</p>

 <ex><substring separator-chars=\",|:;\" join=\", \">a,b:c|f</substring></ex>
 <ex>[<substring separator-whites=\"\" join=\"\">
Remove   all whitespace,
	please.
</substring>]</ex>
 <ex>[<substring separator-whites=\"\">
Normalize   all whitespace,
	please.
</substring>]</ex>
 <ex><substring separator-chars=\"^0-9\" join=\" \">:bva2de 44:3</substring></ex>

 <p>The \"from\", \"to\" and \"index\" attributes specifies positions
 in the input string. What is considered a position depends on other
 attributes:</p>

 <list type='ul'>
   <item><p>If the \"after\" attribute is given then \"from\" counts the
   occurrences of that string.</p></item>

   <item><p>Similarly, if the \"before\" attribute is given then \"to\"
   counts the occurrences of that string.</p></item>

   <item><p>Otherwise, if the \"separator\", \"separator-chars\", or
   \"separator-whites\" attribute is given then the input string is
   split into fields according to the separator, and the position
   counts the fields. \"ignore-empty\" can be used to not count empty
   fields.</p></item>

   <item><p>If neither of the above apply then positions are counted by
   characters.</p></item>
 </list>

 <p>Positive positions count from the start of the input string,
 beginning with 1. Negative positions counts from the end.</p>

 <p>It is not an error if a position count goes past the string limit
 (in either direction). The position gets capped by the start or end
 if that happens. E.g. if a \"from\" position counts from the
 beginning and goes past the end then the result is an empty string,
 and if it counts from the end and goes past the beginning then the
 result starts at the beginning of the input string.</p>

 <p>It is also not an error if the start position ends up after the
 end position. In that case the result is simply the empty string.</p>

 <p>If neither \"from\", \"index\", nor \"after\" is specified then
 the returned substring starts at the beginning of the input string.
 If neither \"to\", \"index\", nor \"before\" is specified then the
 returned substring ends at the end of the input string.</p>

 <p>If <tag>substring</tag> is used in an array context with
 \"separator\", \"separator-chars\", or \"separator-whites\" then the
 fields are returned as an array of strings instead of a single
 string. An example:</p>

 <ex any-result=''><set variable=\"var.list\" type=\"array\">
  <substring separator-chars=\",:\" trimwhites=\"\">
    a, , b:c, d::e: f
  </substring>
</set>
&var.list;</ex>

 <p>Performance notes: Character indexing is efficient on arbitrarily
 large input. The special case with a large positive
 \"from\"/\"to\"/\"index\" position in combination with
 \"before\"/\"after\"/\"separator\" is also handled reasonably
 efficiently.</p>
</desc>

<attr name='from' value='integer'>
 <p>The position of the start of the substring to return.</p>
</attr>

<attr name='to' value='integer'>
 <p>The position of the end of the substring to return.</p>
</attr>

<attr name='index' value='integer'>
 <p>The single position to return. This is simply a shorthand for
 writing \"from\" and \"to\" attributes with the same value. This
 attribute is not allowed together with \"after\" or \"before\".</p>
</attr>

<attr name='after' value='string'>
 <p>The substring to return begins after the first occurrence of this
 string. Together with the \"from\" attribute, it specifies the
 <i>n</i>th occurrence.</p>
</attr>

<attr name='before' value='string'>
 <p>The substring to return ends before the first occurrence of this
 string. Together with the \"to\" attribute, it specifies the
 <i>n</i>th occurrence.</p>
</attr>

<attr name='separator' value='string'>
 <p>The input string is read as an array of fields separated by this
 string, and the \"from\", \"to\", and \"index\" attributes count
 those fields.</p>

 <p>If the separator string is empty (i.e. \"\") then the input string
 is treated as an array of single character fields. Besides being
 significantly slower, the only difference from indexing directly by
 characters (i.e. by leaving out the separator attributes altogether)
 is that \"trim-chars\", \"trimwhites\" and \"ignore-empty\" can be
 used.</p>

 <p>If the \"join\" attribute isn't given then this separator string
 is also used to join together several fields in a string result.</p>
</attr>

<attr name='separator-chars' value='string'>
 <p>The input string is read as an array of fields separated by any
 character in this string, and the \"from\", \"to\", and \"index\"
 attributes count those fields.</p>

 <p>The syntax of this string is the same as in a \"%[...]\" format to
 Pikes sscanf() function. That means:</p>

 <list type='ul'>
   <item><p>Ranges of characters can be defined by using a '-' between the
   first and the last character to be included in the range. Example:
   \"0-9H\" means any digit or 'H'.</p></item>

   <item><p>If the first character is '^', and this character does not
   begin a range, it means that the set is complemented, which is to
   say that any character except those in the set is matched.</p></item>

   <item><p>To include the character '-', you must have it first (not
   possible in complemented sets, see below) or last to avoid having a
   range defined. To include the character ']', it must be first too.
   If both '-' and ']' should be included then put ']' first and '-'
   last.</p></item>

   <item><p>It is not possible to make a range that ends with ']'; make the
   range end with '\\' instead and put ']' at the beginning. Likewise
   it is generally not possible to have a range start with '-'; make
   the range start with '.' instead and put '-' at the end of the
   set.</p></item>

   <item><p>To include '-' in a complemented set, it must be put last, not
   first. To include '^' in a non-complemented set, it can be put
   anywhere but first, or be specified as a range (\"^-^\").</p></item>
 </list>

 <p>If \"separator-chars\" is an empty string (i.e. \"\") then the
 input string is treated as an array of single character fields.
 Besides being significantly slower, the only difference from indexing
 directly by characters (i.e. by leaving out the separator attributes
 altogether) is that \"trim-chars\", \"trimwhites\" and
 \"ignore-empty\" can be used.</p>

 <p>If a string containing several fields is returned, the first
 character in \"separator-chars\" is used by default to join the
 fields. However, if the set is complemented then the fields are
 joined without anything in between. In any case, you can use the
 \"join\" attribute to override the join string.</p>

 <p>Performance note: The \"separator\" attribute is much more
 efficient than this one, so use \"separator\" if you have a single
 separator character.</p>
</attr>

<attr name='separator-whites'>
 <p>The input string is read as an array of fields separated by
 arbitrary amounts of whitespace, and the \"from\", \"to\", and
 \"index\" attributes count those fields.</p>

 <p>In other words, this is a shorthand for specifying
 <tt>ignore-empty=\"\"</tt> together with
 <tt>separator-chars=\"&nbsp;&amp;#9;&amp;#13;&amp;#10;\"</tt>. It can
 be combined with more characters in another \"separator-chars\"
 attribute.</p>
</attr>

<attr name='ignore-empty'>
 <p>Only used together with \"separator\", \"separator-chars\", or
 \"separator-whites\". Ignore all fields that are empty (after
 trimming if \"trim-chars\" or \"trimwhites\" is given). In other
 words, fields are considered to be separated by a sequence of the
 given separator (and trim characters), instead of a single
 separator.</p>
</attr>

<attr name='join' value='string'>
 <p>Only used together with \"separator\", \"separator-chars\", or
 \"separator-whites\". If several fields are joined together to a
 result string, then this string is used as delimiter between the
 fields.</p>
</attr>

<attr name='case-insensitive'>
 <p>Be case insensitive when matching the \"after\", \"before\",
 \"separator\", \"separator-chars\" and \"trim-chars\" strings. Case
 is still preserved in the returned result.</p>
</attr>

<attr name='trim-chars' value='string'>
 <p>Trim any sequence of the characters in this string from the start
 and end of the result before returning it. If \"separator\",
 \"separator-chars\", or \"separator-whites\" is specified then the
 trimming is done on each field.</p>

 <p>The format in this attribute is the same as in a \"%[...]\" to
Pikes sscanf() function. See the \"separator-chars\" attribute for a
 description.</p>
</attr>

<attr name='trimwhites'>
 <p>Shorthand for specifying \"trim-chars\" with all whitespace
 characters, and also slightly faster.</p>
</attr>",

//----------------------------------------------------------------------

"range": #"<desc type='cont'>
 <p><short>Extract a range of an array.</short> The part to extract
 can be specified using positions or by searching for matching
 elements. Some examples:</p>

 <p>Given a variable var.x containing an array like this:</p>

<ex any-result=''><set variable=\"var.x\" split=\",\">a,b,c,d,e,f</set>
&var.x;</ex>

 <p>To pick out ranges based on positions:</p>

 <ex any-result='' keep-var-scope=''>
<range variable=\"var.x\" from=\"2\"/></ex>
 <ex any-result='' keep-var-scope=''>
<range variable=\"var.x\" from=\"-2\"/></ex>
 <ex any-result='' keep-var-scope=''>
<range variable=\"var.x\" from=\"2\" to=\"-2\"/></ex>

 <p>Given a variable var.x containing an array like this:</p>

 <ex any-result=''><set variable=\"var.x\" type=\"array\">
  <substring separator-whites=\"\">
    From the past to the future via the present.
  </substring>
</set>
&var.x;</ex>

 <p>To pick out ranges based on matching elements:</p>

 <ex any-result='' keep-var-scope=''>
<range variable=\"var.x\" after=\"the\"/></ex>
 <ex any-result='' keep-var-scope=''>
<range variable=\"var.x\" after=\"the\" from=\"2\"/></ex>
 <ex any-result='' keep-var-scope=''>
<range variable=\"var.x\" after=\"the\" from=\"-1\"/></ex>
 <ex any-result='' keep-var-scope=''>
<range variable=\"var.x\" after=\"to\" before=\"the\" to=\"3\"/></ex>

 <p>The \"from\" and \"to\" attributes specifies positions in the
 input array. What is considered a position depends on other
 attributes:</p>

 <list type='ul'>
   <item><p>If the \"after\" attribute is given then \"from\" counts the
   occurrences of that element.</p></item>

   <item><p>Similarly, if the \"before\" attribute is given then \"to\"
   counts the occurrences of that element.</p></item>

   <item><p>If neither of the above apply then positions are counted
   directly by index.</p></item>
 </list>

 <p>Positive positions count from the start of the input array,
 beginning with 1. Negative positions count from the end.</p>

 <p>It is not an error if a position count goes past the array limit
 (in either direction). The position gets capped by the start or end
 if that happens. E.g. if a \"from\" position counts from the
 beginning and goes past the end then the result is an empty array,
 and if it counts from the end and goes past the beginning then the
 result starts at the beginning of the input array.</p>

 <p>It is also not an error if the start position ends up after the
 end position. In that case the result is simply an empty array.</p>

 <p>If neither \"from\", nor \"after\" is specified then the returned
 range starts at the beginning of the input array. If neither \"to\"
 nor \"before\" is specified then the returned range ends at the end
 of the input array.</p>

 <p>If \"join\" is given then the result is returned as a string,
 otherwise it is an array.</p>
</desc>

<attr name='variable'>
 <p>The variable to get the input array from. If this is left out then
 the array is taken from the content, which is evaluated in an array
 context.</p>
</attr>

<attr name='from' value='integer'>
 <p>The position of the start of the range to return.</p>
</attr>

<attr name='to' value='integer'>
 <p>The position of the end of the range to return.</p>
</attr>

<attr name='after'>
 <p>The range to return begins after the first occurrence of this
 element. Together with the \"from\" attribute, it specifies the
 <i>n</i>th occurrence.</p>
</attr>

<attr name='before'>
 <p>The range to return ends before the first occurrence of this
 element. Together with the \"to\" attribute, it specifies the
 <i>n</i>th occurrence.</p>
</attr>

<attr name='join' value='string'>
 <p>Join together the elements of the range to a string, using the
 value of this attribute as delimiter between the elements.</p>
</attr>",

//----------------------------------------------------------------------

"value": #"<desc type='cont'>
 <p><short>Creates a single value from its contents or some other
 source.</short> This is mainly useful to build the elements in array
 or mapping contexts. E.g:</p>

 <ex any-result=''>
<set variable=\"var.arr\" type=\"array\">
  <value>apple</value>
  <value>orange</value>
  <value>banana</value>
</set>
&var.arr;</ex>

 <p>This tag takes a \"type\" attribute to set the type of its
 content, just like e.g. <tag>set</tag>. That can be useful e.g. to
 build arrays inside arrays:</p>

 <ex any-result=''>
<value type=\"array\">
  <value>1</value>
  <value type=\"array\">
    <value>1.1</value>
    <value>1.2</value>
  </value>
  <value>2</value>
</value></ex>

 <p>Note that a variable with an array value is normally spliced into
 an array context. Here too an extra <tag>value</tag> tag is useful to
 make it a nested array:</p>

 <ex any-result=''>
<set variable=\"var.x\" split=\",\">a,b</set>
<value type=\"array\">
  <!-- Insert all the elements in var.x -->
  &var.x;
  <!-- Compare to the following that adds
       the var.x array as a single element. -->
  <value>&var.x;</value>
</value></ex>
</desc>

<attr name='type' value='type'>
 <p>The type of the content and the result (except if it's \"array\" -
 then the result is \"any\" to avoid splicing the array into the
 surrounding array, as shown above). Defaults to \"any\".</p>
</attr>

<attr name='index'>
 <p>Used when the surrounding type is a mapping. This specifies the
 index for the value. E.g:</p>

 <ex any-result=''>
<value type=\"mapping\">
  <value index=\"1\">first</value>
  <value index=\"2\">second</value>
  <value index=\"3\">third</value>
</value></ex>

 <p>This attribute cannot be left out when a mapping is constructed,
 and it must not be given otherwise.</p>
</attr>

<attr name='from' value='string'>
 <p>Get the value from this variable. The content must be empty if
 this is used.</p>
</attr>

<attr name='expr' value='string'>
 <p>An expression that gets evaluated to produce the value. The
 content must be empty if this is used.</p>
</attr>",

"json-parse": #"<desc type='cont'>
 <p><short>Parses a JSON-formatted string.</short> This returns a
 value of the same type as the top level JSON object, typically an
 array or a mapping.</p>
 </desc>

<attr name='value' value='string'>
 <p>The JSON-formatted value to parse.</p>
</attr>

<attr name='variable' value='string'>
 <p>Get the JSON-formatted value to parse from this variable, unless
 <tt>value</tt> is provided. If neither is specified the content of
 the container is used.</p>
</attr>",

"json-format": #"<desc type='cont'>
 <p><short>Formats a JSON string.</short> The input value may be a
 number, string, array, mapping, or one of the special values
 <ent>roxen.true</ent>, <ent>roxen.false</ent>, or
 <ent>roxen.null</ent>.</p>

 <p>Note: In some cases it may be easier to write the JSON answer as a
 plain string and substitute some values into it. In that case, the
 \"json\" encoding is more useful:</p>

 <ex-box>
{\"user\": \"&var.username:json;\",
 \"name\": \"&var.fullname:json;\"}
</ex-box>
</desc>

<attr name='value' value='string'>
 <p>The value to format.</p>
</attr>

<attr name='variable' value='string'>
 <p>Get the value to format from this variable, unless <tt>value</tt> has been
 provided. If neither is specified the content of the container is used.</p>
</attr>

<attr name='ascii-only'>
 <p>Set to generate JSON output where all non-ASCII characters are escaped.
    If not set only required characters are escaped.</p>
</attr>

<attr name='human-readable'>
 <p>Set to generate JSON output with extra whitespace for easier reading.</p>
</attr>

<attr name='canonical' value='pike'>
 <p>Use <tt>canonical=\"pike\"</tt> to generate JSON output where the same
    input always gives consistent output with regards to e.g. mapping
    sorting. If not provided the order is undefined.</p>
</attr>

<attr name='no-xml-quote'>
 <p>Set to skip escaping of XML markup characters (<tt>&amp;</tt>,
    <tt>&lt;</tt> and <tt>&gt;</tt>). The standard behavior is to escape
    these characters using \\uXXXX encoding.</p>
</attr>",

//----------------------------------------------------------------------

"return":#"<desc type='tag'><p><short>
 Changes the HTTP return code for this page. </short>
 <!-- See the Appendix for a list of HTTP return codes. (We have no appendix) -->
</p></desc>

<attr name='code' value='integer'>
 <p>The HTTP status code to return.</p>
</attr>

<attr name='text'>
 <p>The HTTP status message to set. If you don't provide one, a default
 message is provided for known HTTP status codes, e g \"No such file
 or directory.\" for code 404.</p>
</attr>",

//----------------------------------------------------------------------

"roxen":#"<desc type='tag'><p><short>
 Returns a nice Roxen logo.</short>
</p></desc>

<attr name='size' value='small|medium|large' default='medium'>
 <p>Defines the size of the image.</p>
<ex><roxen size='small'/>
<roxen/>
<roxen size='large'/></ex>
</attr>

<attr name='color' value='black|white' default='white'>
 <p>Defines the color of the image.</p>
<ex><roxen color='black'/></ex>
</attr>

<attr name='alt' value='string' default='\"Powered by Roxen\"'>
 <p>The image description.</p>
</attr>

<attr name='border' value='number' default='0'>
 <p>The image border.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the img element.</p>
</attr>

<attr name='target' value='string'>
 <p>Names a target frame for the link around the image.</p>

 <p>All other attributes will be inherited by the generated img tag.</p>
</attr> ",

//----------------------------------------------------------------------

"scope":#"<desc type='cont'><p><short>
 Creates a new variable scope.</short> Variable changes inside the scope
 container will not affect variables in the rest of the page.
</p></desc>

<attr name='extend' value='name'>
 <p>If set, all variables in the selected scope will be copied into
 the new scope. NOTE: if the source scope is \"magic\", as e.g. the
 roxen scope, the scope will not be copied, but rather linked and will
 behave as the original scope. It can be useful to create an alias or
 just for the convenience of referring to the scope as \"_\".</p>
</attr>

<attr name='scope' value='name' default='form'>
 <p>The name of the new scope, besides \"_\".</p>
</attr>",

//----------------------------------------------------------------------

"set":#"<desc type='both'><p><short>
 Sets a variable in any scope that isn't read-only.</short></p>

 <ex>
Before: &var.language;<br />
<set variable=\"var.language\">Pike</set>
After: &var.language;<br /></ex>
</desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable to set.</p>
</attr>

<attr name='value' value='string'>
 <p>The value the variable should have. This is an alternative to
 specifying the value in the content, and the content must be empty if
 this is used.</p>

 <p>The difference is that the value always is parsed as text here.
 Even if a type is specified with the \"type\" attribute this is still
 parsed as text, and then converted to that type.</p>
</attr>

<attr name='from' value='string'>
 <p>Get the value from this variable. The content must be empty if
 this is used.</p>
</attr>

<attr name='expr' value='string'>
 <p>An expression that gets evaluated to produce the value for the
 variable. The content must be empty if this is used.</p>

 " // FIXME: Moved the following to some intro chapter.
 #"<p>Expression values can take any of the following forms:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt><i>scope</i>.<i>var[</i>.<i>var...]</i></tt></p></c>
     <c><p>The value of the given RXML variable. This follows the
     usual RXML variable reference syntax, e.g. \".\" in a variable
     name is quoted as \"..\". The scope and variable names may only
     contain pike identifier chars, i.e. letters, numbers (except at
     the start of a scope name), and \"_\". An exception is that a
     <i>var</i> may be a positive or negative integer.</p>

     <p>To reference an RXML variable that doesn't obey these
     restrictions, e.g. when a variable name contains \"-\", use the
     <tt>var()</tt> or <tt>index()</tt> functions.</p>

     <p>Note that the variable is not written as an entity reference.
     I.e. it is written without the surrounding \"&amp;\" and \";\".
     Using e.g. \"&amp;form.x;\" instead of \"form.x\" works most of
     the time, but it is more susceptible to parse errors if form.x
     contains funny things, and it is slower since Roxen cannot cache
     the compiled expression very well.</p></c></row>

   <row valign='top'>
     <c><p><tt>49</tt></p></c>
     <c><p>A decimal integer.</p></c></row>

   <row valign='top'>
     <c><p><tt>0xFE</tt>, <tt>0xfe</tt></p></c>
     <c><p>A hexadecimal integer is preceded by \"0x\".</p></c></row>

   <row valign='top'>
     <c><p><tt>040</tt></p></c>
     <c><p>An octal integer is preceded by \"0\".</p></c></row>

   <row valign='top'>
     <c><p><tt>0b10100110</tt></p></c>
     <c><p>A binary integer is preceded by \"0b\".</p></c></row>

   <row valign='top'>
     <c><p><tt>1.43</tt>, <tt>1.6e-5</tt></p></c>
     <c><p>A floating point number contains \".\" and/or
     \"E\"/\"e\".</p></c></row>

   <row valign='top'>
     <c><p><tt>\"hello\"</tt></p></c>
     <c><p>A string inside double quotes. C-style backslash escapes can
     be used in the string, e.g. a double quote can be included using
     \\\".</p></c></row>

   <row valign='top'>
     <c><p><tt>(<i>expr</i>)</tt></p></c>
     <c><p>Parentheses can be used around an expression for grouping
     inside a larger expression.</p></c></row>
 </xtable>

 <p>Value conversion expressions:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt>(int) <i>expr</i></tt></p></c>
     <c><p>Casts a numeric or string expression (containing a formatted
     number on one of the formats above) to an integer.</p></c></row>

   <row valign='top'>
     <c><p><tt>(float) <i>expr</i></tt></p></c>
     <c><p>Casts a numeric or string expression (containing a formatted
     number on one of the formats above) to a floating point
     number.</p></c></row>

   <row valign='top'>
     <c><p><tt>(string) <i>expr</i></tt></p></c>
     <c><p>Casts a numeric or string expression to a string. If it is an
     integer then it is formatted as a decimal number. If it is a
     floating point number then it is formatted on the form
     <i>[-]XX[.XX][e[-]XX]</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>INT(<i>expr</i>)</tt>, <tt>FLOAT(<i>expr</i>)</tt>,
     <tt>STRING(<i>expr</i>)</tt></p></c>
     <c><p>These functions cast their arguments to integer, float, or
     string, respectively. They behave like the cast operators above
     except that they do not generate any error if <i>expr</i> cannot
     be cast successfully. Instead a zero number or an empty string is
     returned as appropriate. This is useful if <i>expr</i> is a value
     from the client that may be bogus.</p></c></row>
 </xtable>

 <p>Note that values in the RXML form scope often are strings even
 though they may appear as (formatted) numbers. It is therefore a good
 idea to use the <tt>INT()</tt> or <tt>FLOAT()</tt> functions on them
 before you do math.</p>

 <p>Expressions for checking types:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt>arrayp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is an array,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>callablep(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is a function
	or similar, and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>floatp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is a floating point number,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>functionp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is a function,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>intp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is an integer,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>mappingp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is a mapping,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>multisetp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is a multiset,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>objectp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is an object,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>programp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is a program,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>stringp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is a string,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>undefinedp(<i>expr</i>)</tt></p></c>
     <c><p>Returns 1 if the value of <i>expr</i> is UNDEFINED,
	and 0 otherwise.</p></c></row>
 </xtable>

 <p>Expressions for checking contents:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt>has_index(<i>haystack</i>, <i>index</i>)</tt></p></c>
     <c><p>Returns 1 if <i>index</i> is in the index domain of <i>haystack</i>,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>has_prefix(<i>string</i>, <i>prefix</i>)</tt></p></c>
     <c><p>Returns 1 if <i>string</i> starts with <i>prefix</i>,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>has_suffix(<i>string</i>, <i>suffix</i>)</tt></p></c>
     <c><p>Returns 1 if <i>string</i> ends with <i>suffix</i>,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>has_value(<i>haystack</i>, <i>value</i>)</tt></p></c>
     <c><p>Returns 1 if <i>value</i> is in the value domain of <i>haystack</i>,
	and 0 otherwise.</p></c></row>
   <row valign='top'>
     <c><p><tt>indices(<i>expr</i>)</tt></p></c>
     <c><p>Returns an array with all indices present in <i>expr</i>.</p></c></row>
   <row valign='top'>
     <c><p><tt>values(<i>expr</i>)</tt></p></c>
     <c><p>Returns an array with all values present in <i>expr</i>.</p></c></row>
 </xtable>

 <p>Expressions for numeric operands:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt><i>expr1</i> * <i>expr2</i></tt></p></c>
     <c><p>Multiplication.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> / <i>expr2</i></tt></p></c>
     <c><p>Division.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> % <i>expr2</i></tt></p></c>
     <c><p>Modulo.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> + <i>expr2</i></tt></p></c>
     <c><p>Addition.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> - <i>expr2</i></tt></p></c>
     <c><p>Subtraction.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> &lt; <i>expr2</i></tt></p></c>
     <c><p>Less than.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> &gt; <i>expr2</i></tt></p></c>
     <c><p>Greater than.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> &lt;= <i>expr2</i></tt></p></c>
     <c><p>Less than or equal.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> &gt;= <i>expr2</i></tt></p></c>
     <c><p>Greater than or equal.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> &amp; <i>expr2</i></tt></p></c>
     <c><p>Bitwise AND (integer operands only).</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> ^ <i>expr2</i></tt></p></c>
     <c><p>Bitwise XOR (integer operands only).</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> | <i>expr2</i></tt></p></c>
     <c><p>Bitwise OR (integer operands only).</p></c></row>

   <row valign='top'>
     <c><p><tt>pow(<i>expr1</i>, <i>expr2</i>)</tt></p></c>
     <c><p>Returns the value <i>expr1</i> raised to the power of
     <i>expr2</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>log(<i>expr</i>)</tt></p></c>
     <c><p>Returns the natural logarithm of the value <i>expr</i>. To get
        the logarithm in another base, divide the result with
        <tt>log(<i>base</i>)</tt>.
	This is the inverse operation of <tt>exp()</tt>.</p></c></row>

   <row valign='top'>
     <c><p><tt>exp(<i>expr</i>)</tt></p></c>
     <c><p>Returns the natural exponential of the value <i>expr</i>.
	This is the inverse operation of <tt>log()</tt>.</p></c></row>

   <row valign='top'>
     <c><p><tt>abs(<i>expr</i>)</tt></p></c>
     <c><p>Returns the absolute value of <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>floor(<i>expr</i>)</tt></p></c>
     <c><p>Returns the closest integer value less than or equal to the
        value <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>ceil(<i>expr</i>)</tt></p></c>
     <c><p>Returns the closest integer value greater than or equal to the
        value <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>round(<i>expr</i>)</tt></p></c>
     <c><p>Returns the closest integer value to the value <i>expr</i>.
        </p></c></row>

   <row valign='top'>
     <c><p><tt>max(<i>expr</i>, ...)</tt></p></c>
     <c><p>Returns the maximum value of the arguments.</p></c></row>

   <row valign='top'>
     <c><p><tt>min(<i>expr</i>, ...)</tt></p></c>
     <c><p>Returns the minimum value of the arguments.</p></c></row>
 </xtable>

 <p>Expressions for string operands:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt><i>expr</i> * <i>num</i></tt></p></c>
     <c><p>Returns <i>expr</i> repeated <i>num</i> times.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> / <i>expr2</i></tt></p></c>
     <c><p>Returns an array with <i>expr1</i> split on <i>expr2</i>.
     E.g. the string \"a,b,c\" split on \",\" is an array with the
     three elements \"a\", \"b\", and \"c\".</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> + <i>expr2</i></tt></p></c>
     <c><p>Returns <i>expr1</i> concatenated with <i>expr2</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> - <i>expr2</i></tt></p></c>
     <c><p>Returns <i>expr1</i> without any occurrences of <i>expr2</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>var(<i>expr</i>)</tt></p></c>
     <c><p>Parses the string <i>expr</i> as an RXML variable reference
     and returns its value. Useful e.g. if the immediate
     <tt><i>scope</i>.<i>var</i></tt> form cannot be used due to
     strange characters in the scope or variable names.</p></c></row>

   <row valign='top'>
     <c><p><tt>sizeof(<i>expr</i>)</tt></p></c>
     <c><p>Returns the number of characters in <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>strlen(<i>expr</i>)</tt></p></c>
     <c><p>Returns the number of characters in <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>search(<i>expr1</i>, <i>expr2</i>)</tt></p></c>
     <c><p>Returns the starting position of the first occurrence of the
     substring <i>expr2</i> inside <i>expr1</i>, counting from 1, or 0
     if <i>expr2</i> does not occur in <i>expr1</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>reverse(<i>expr</i>)</tt></p></c>
     <c><p>Returns the reverse of <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>regexp_split(<i>regexp</i>, <i>expr</i>)</tt></p></c>
     <c><p>Matches <i>regexp</i> against the string <i>expr</i>. If it
     matches then an array is returned that has the full match in the
     first element, followed by what the corresponding submatches (if
     any) match. Returns <ent>roxen.false</ent> if the regexp doesn't
     match. The regexp follows
     <a href='http://www.pcre.org/'>PCRE</a> syntax.</p></c></row>

   <row valign='top'>
     <c><p><tt>basename(<i>expr</i>)</tt></p></c>
     <c><p>Returns the basename of the path in <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>dirname(<i>expr</i>)</tt></p></c>
     <c><p>Returns the dirname of the path in <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>combine_path(<i>base</i>, <i>relative_path</i>, ...)</tt></p></c>
     <c><p>Returns the combined path <i>base</i> + <tt>\"/\"</tt> +
     <i>relative_path</i>, with any path-segments of <tt>'.'</tt> and
     <tt>'..'</tt> handled and removed.</p></c></row>
 </xtable>

 <p>Expressions for array operands:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt><i>expr</i> * <i>num</i></tt></p></c>
     <c><p>Returns <i>expr</i> repeated <i>num</i> times.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> + <i>expr2</i></tt></p></c>
     <c><p>Returns <i>expr1</i> concatenated with <i>expr2</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> - <i>expr2</i></tt></p></c>
     <c><p>Returns <i>expr1</i> without any of the elements in
     <i>expr2</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> &amp; <i>expr2</i></tt></p></c>
     <c><p>Returns the elements that exist in both <i>expr1</i> and
     <i>expr2</i>, ordered according to <i>expr1</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> ^ <i>expr2</i></tt></p></c>
     <c><p>Returns the elements that exist in either <i>expr1</i> or
     <i>expr2</i> but not in both. The order is <i>expr1</i> followed
     by <i>expr2</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> | <i>expr2</i></tt></p></c>
     <c><p>Returns the elements that exist in either <i>expr1</i> or
     <i>expr2</i>. The order is <i>expr1</i> followed by <i>expr2</i>.
     (The difference from <i>expr1</i> + <i>expr2</i> is that elements
     in <i>expr2</i> aren't repeated if they occur in
     <i>expr1</i>.)</p></c></row>

   <row valign='top'>
     <c><p><tt>sizeof(<i>expr</i>)</tt></p></c>
     <c><p>Returns the number of elements in <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>search(<i>arr</i>, <i>expr</i>)</tt></p></c>
     <c><p>Returns the position of the first occurrence of the element
     <i>expr</i> inside the array <i>arr</i>, counting from 1, or 0
     if <i>expr</i> does not exist in <i>arr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>reverse(<i>expr</i>)</tt></p></c>
     <c><p>Returns the reverse of <i>expr</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt>uniq(<i>expr</i>)</tt></p></c>
     <c><p>Returns <i>expr</i> with all duplicate elements removed. The
     order among the remaining elements is kept intact; it is always
     the first of several duplicate elements that is
     retained.</p></c></row>
 </xtable>

 <p>Expressions for all types of operands:</p>

 <xtable>
   <row valign='top'>
     <c><p><tt>!<i>expr</i></tt></p></c>
     <c><p>Logical negation: 1 (true) if <i>expr</i> is the integer 0
     (zero), otherwise 0 (false).</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> == <i>expr2</i></tt></p></c>
     <c><p>1 (true) if <i>expr1</i> and <i>expr2</i> are the same, 0
     (false) otherwise. Note that arrays may be different even
     though they contain the same sequence of elements.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> != <i>expr2</i></tt></p></c>
     <c><p>1 (true) if <i>expr1</i> and <i>expr2</i> are different, 0
     (false) otherwise. This is the inverse of the ==
     operator.</p></c></row>

   <row valign='top'>
     <c><p><tt>equal(<i>expr1</i>, <i>expr2</i>)</tt></p></c>
     <c><p>1 (true) if <i>expr1</i> and <i>expr2</i> are structurally
     equal, 0 (false) otherwise. As opposed to the == operator above,
     this returns 1 if two arrays contain the same sequence of
     elements.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> &amp;&amp; <i>expr2</i></tt></p></c>
     <c><p>Nonzero (true) if both expressions are nonzero (true), 0
     (false) otherwise. A true return value is actually the value of
     <i>expr2</i>.</p></c></row>

   <row valign='top'>
     <c><p><tt><i>expr1</i> || <i>expr2</i></tt></p></c>
     <c><p>Nonzero (true) if either expression is nonzero (true), 0
     (false) otherwise. A true return value is actually the value of
     the last true expression.</p></c></row>

   <row valign='top'>
     <c><p><tt>index(<i>scope</i>, <i>expr</i>, ...)</tt></p></c>
     <c><p>Indexes the RXML scope specified by the string <i>scope</i>
     with <i>expr</i>, and then continue to index the result
     successively with the remaining arguments. The indexing is done
     according to RXML rules, so e.g. the first index in an array is
     1.</p></c></row>
 </xtable>
</attr>

<attr name='type' value='type'>
 <p>The type of the value. If the value is taken from the content then
 this is the context type while evaluating it. If \"value\", \"from\"
 or \"expr\" is used then the value is converted to this type.
 Defaults to \"any\".</p>

 <p>Tip: The <tag>value</tag> tag is useful to construct nonstring
 values, such as arrays and mappings:</p>

 <ex any-result=''>
<set variable=\"var.x\" type=\"array\">
  <value>alpha</value>
  <value>beta</value>
</set>
&var.x;
 </ex>
</attr>

<attr name='split' value='string'>
 <p>Split the value on this string to form an array which is set. The
 value gets converted to a string if it isn't one already.</p>

 <ex any-result=''>
<set variable=\"var.x\" split=\",\">a,b,c</set>
&var.x;
 </ex>
</attr>",

//----------------------------------------------------------------------

"copy-scope":#"<desc type='tag'><p><short>
 Copies the content of one scope into another scope</short></p></desc>

<attr name='from' value='scope name' required='1'>
 <p>The name of the scope the variables are copied from.</p>
</attr>

<attr name='to' value='scope name' required='1'>
 <p>The name of the scope the variables are copied to.</p>
</attr>",

//----------------------------------------------------------------------

"set-cookie":#"<desc type='tag'><p><short>
 Sets a cookie that will be stored by the user's browser.</short> This
 is a simple and effective way of storing data that is local to the
 user. If no arguments specifying the time the cookie should survive
 is given to the tag, it will live until the end of the current browser
 session. Otherwise, the cookie will be persistent, and the next time
 the user visits  the site, she will bring the cookie with her.
</p>

<p>Note that the change of a cookie will not take effect until the
 next page load.</p></desc>

<attr name='name' value='string' required='required'>
 <p>The name of the cookie.</p>
</attr>

<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time the cookie is kept.</p>
</attr>

<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time the cookie is kept.</p>
</attr>

<attr name='hours' value='number'>
 <p>Add this number of hours to the time the cookie is kept.</p>
</attr>

<attr name='days' value='number'>
 <p>Add this number of days to the time the cookie is kept.</p>
</attr>

<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time the cookie is kept.</p>
</attr>

<attr name='months' value='number'>
 <p>Add this number of months to the time the cookie is kept.</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the time the cookie is kept.</p>
</attr>

<attr name='persistent'>
 <p>Keep the cookie for five years.</p>
</attr>

<attr name='domain'>
 <p>The domain for which the cookie is valid.</p>
</attr>

<attr name='value' value='string'>
 <p>The value the cookie will be set to.</p>
</attr>

<attr name='path' value='string' default=\"\"><p>
 The path in which the cookie should be available.</p>
</attr>

<attr name='secure'>
  <p>If this attribute is present the cookie will be set with the Secure
  attribute. The Secure flag instructs the user agent to use only
  (unspecified) secure means to contact the origin server whenever it
  sends back the cookie. If the browser supports the secure flag, it will not send the cookie when the request is going to an HTTP page.</p>
</attr>

<attr name='httponly'>
  <p>If this attribute is present the cookie will be set with the HttpOnly attribute. If the browser supports the HttpOnly flag, the cookie will be secured from being accessed by a client side script.</p>
</attr>
",

//----------------------------------------------------------------------

"set-max-cache":#"<desc type='tag'><p><short>
 Sets the maximum time this document can be cached in the protocol
 cache or client-side.</short></p>

 <p>Default is to get this time from the other tags in the document
 (as an example, <xref href='../if/if_supports.tag' /> sets the time to
 0 seconds since the result of the test depends on the client used.</p>

 <p>You must use this tag at the end of the document, since many of
 the normal tags will override the cache value.</p>
</desc>

<attr name='years' value='number'>
 <p>Add this number of years to the time this page was last loaded.</p>
</attr>
<attr name='months' value='number'>
 <p>Add this number of months to the time this page was last loaded.</p>
</attr>
<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time this page was last loaded.</p>
</attr>
<attr name='days' value='number'>
 <p>Add this number of days to the time this page was last loaded.</p>
</attr>
<attr name='hours' value='number'>
 <p>Add this number of hours to the time this page was last loaded.</p>
</attr>
<attr name='beats' value='number'>
 <p>Add this number of beats to the time this page was last loaded.</p>
</attr>
<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time this page was last loaded.</p>
</attr>
<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time this page was last loaded.</p>
</attr>
<attr name='force-protocol-cache'>
 <p>Try to force the page into the protocol cache.</p>
</attr>",

//----------------------------------------------------------------------

"smallcaps":#"<desc type='cont'><p><short>
 Prints the contents in smallcaps.</short> If the size attribute is
 given, font tags will be used, otherwise big and small tags will be
 used.</p>

<ex><smallcaps>Roxen WebServer</smallcaps></ex>
</desc>

<attr name='space'>
 <p>Put a space between every character.</p>
<ex><smallcaps space=''>Roxen WebServer</smallcaps></ex>
</attr>

<attr name='class' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all elements.</p>
</attr>

<attr name='smallclass' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all small elements.</p>
</attr>

<attr name='bigclass' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all big elements.</p>
</attr>

<attr name='size' value='number'>
 <p>Use font tags, and this number as big size.</p>
</attr>

<attr name='small' value='number' default='size-1'>
 <p>Size of the small tags. Only applies when size is specified.</p>

 <ex><smallcaps size='6' small='2'>Roxen WebServer</smallcaps></ex>
</attr>",

//----------------------------------------------------------------------

"sort":#"<desc type='cont'><p><short>
 Sorts the contents.</short></p>

 <ex><sort>Understand!
I
Wee!
Ah,</sort></ex>
</desc>

<attr name='separator' value='string'>
 <p>Defines what the strings to be sorted are separated with. The sorted
 string will be separated by the string.</p>

 <ex><sort separator='#'>way?#perhaps#this</sort></ex>
</attr>

<attr name='reverse'>
 <p>Reversed order sort.</p>

 <ex><sort reverse=''>backwards?
or
:-)
maybe</sort></ex>
</attr>",

//----------------------------------------------------------------------

"throw":#"<desc type='cont'><p><short>
 Throws a text to be caught by <xref href='catch.tag' />.</short>
 Throws an exception, with the enclosed text as the error message.
 This tag has a close relation to <xref href='catch.tag' />. The
 RXML parsing will stop at the <tag>throw</tag> tag.
 </p></desc>",

//----------------------------------------------------------------------

"trimlines":#"<desc type='cont'><p><short>
 Removes all empty lines from the contents.</short></p>

  <ex><pre><trimlines>
See how all this junk


just got zapped?

</trimlines></pre></ex>
</desc>",

//----------------------------------------------------------------------

"unset":#"<desc type='tag'><p><short>
 Unsets a variable, i.e. removes it.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable.</p>

 <ex><set variable='var.jump' value='do it'/>
&var.jump;
<unset variable='var.jump'/>
&var.jump;</ex>
</attr>",

//----------------------------------------------------------------------

"user":#"<desc type='tag'><p><short>
 Prints information about the specified user.</short> By default, the
 full name of the user and her e-mail address will be printed, with a
 mailto link and link to the home page of that user.</p>

 <p>The <tag>user</tag> tag requires an authentication module to work.</p>
</desc>

<attr name='email'>
 <p>Only print the e-mail address of the user, with no link.</p>
 <ex-box>Email: <user name='foo' email='1'/></ex-box>
</attr>

<attr name='link'>
 <p>Include links. Only meaningful together with the realname or email attribute.</p>
</attr>

<attr name='name'>
 <p>The login name of the user. If no other attributes are specified, the
 user's realname and email including links will be inserted.</p>
<ex-box><user name='foo'/></ex-box>
</attr>

<attr name='nolink'>
 <p>Don't include the links.</p>
</attr>

<attr name='nohomepage'>
 <p>Don't include homepage links.</p>
</attr>

<attr name='realname'>
 <p>Only print the full name of the user, with no link.</p>
<ex-box><user name='foo' realname='1'/></ex-box>
</attr>",

//----------------------------------------------------------------------

"if#expr":#"<desc type='plugin'><p><short>
 This plugin evaluates an expression and returns true if the result is
 anything but an integer or floating point zero.</short></p>
</desc>

<attr name='expr' value='expression'>
 <p>The expression to test. See the expr attribute to <xref
 href='../variable/set.tag'/> for a description of the syntax.</p>
</attr>",

//----------------------------------------------------------------------

"emit#fonts":({ #"<desc type='plugin'><p><short>
 Prints available fonts.</short> This plugin makes it easy to list all
 available fonts in Roxen WebServer.
</p></desc>

<attr name='type' value='ttf|all'>
 <p>Which font types to list. ttf means all true type fonts, whereas all
 means all available fonts.</p>
</attr>",
		([
"&_.name;":#"<desc type='entity'><p>
 Returns a font identification name.</p>

<p>This example will print all available ttf fonts in gtext-style.</p>
<ex-box><emit source='fonts' type='ttf'>
  <gtext font='&_.name;'>&_.expose;</gtext><br />
</emit></ex-box>
</desc>",
"&_.copyright;":#"<desc type='entity'><p>
 Font copyright notice. Only available for true type fonts.
</p></desc>",
"&_.expose;":#"<desc type='entity'><p>
 The preferred list name. Only available for true type fonts.
</p></desc>",
"&_.family;":#"<desc type='entity'><p>
 The font family name. Only available for true type fonts.
</p></desc>",
"&_.full;":#"<desc type='entity'><p>
 The full name of the font. Only available for true type fonts.
</p></desc>",
"&_.path;":#"<desc type='entity'><p>
 The location of the font file.
</p></desc>",
"&_.postscript;":#"<desc type='entity'><p>
 The fonts postscript identification. Only available for true type fonts.
</p></desc>",
"&_.style;":#"<desc type='entity'><p>
 Font style type. Only available for true type fonts.
</p></desc>",
"&_.format;":#"<desc type='entity'><p>
 The format of the font file, e.g. ttf.
</p></desc>",
"&_.version;":#"<desc type='entity'><p>
 The version of the font. Only available for true type fonts.
</p></desc>",
"&_.trademark;":#"<desc type='entity'><p>
 Font trademark notice. Only available for true type fonts.
</p></desc>",
		])
	     }),

//----------------------------------------------------------------------

"case":#"<desc type='cont'><p><short>
 Alters the case of the contents.</short>
</p></desc>

<attr name='case' value='upper|lower|capitalize' required='required'><p>
 Changes all characters to upper or lower case letters, or
 capitalizes the first letter in the content.</p>

<ex><set variable='var.lipsum' value='lOrEm iPsUm' />
<case case='upper'>&var.lipsum;</case><br/>
<case case='lower'>&var.lipsum;</case><br/>
<case case='capitalize'>&var.lipsum;</case></ex>
</attr>",

//----------------------------------------------------------------------

"cond":({ #"<desc type='cont'><p><short>
 This tag makes a boolean test on a specified list of cases.</short>
 This tag is almost eqvivalent to the <xref href='../if/if.tag'
 />/<xref href='../if/else.tag' /> combination. The main difference is
 that the <tag>default</tag> tag may be put whereever you want it
 within the <tag>cond</tag> tag. This will of course affect the order
 the content is parsed. The <tag>case</tag> tag is required.</p>

 <p>Performance note: In the current implementation, this tag does not
 get optimized very well when RXML is compiled. It is recommended that
 <tag>if</tag> ... <tag>elseif</tag> sequences are used instead.</p>
</desc>",

	  (["case":#"<desc type='cont'><p>
 This tag takes the argument that is to be tested and if it's true,
 it's content is executed before exiting the <tag>cond</tag>. If the
 argument is false the content is skipped and the next <tag>case</tag>
 tag is parsed.</p></desc>

<ex-box><cond>
 <case variable='form.action = edit'>
  some database edit code
 </case>
 <case variable='form.action = delete'>
  some database delete code
 </case>
 <default>
  view something from the database
 </default>
</cond></ex-box>",

	    "default":#"<desc type='cont'><p>
 The <tag>default</tag> tag is eqvivalent to the <tag>else</tag> tag
 in an <tag>if</tag> statement. The difference between the two is that
 the <tag>default</tag> may be put anywhere in the <tag>cond</tag>
 statement. This affects the parseorder of the statement. If the
 <tag>default</tag> tag is put first in the statement it will allways
 be executed, then the next <tag>case</tag> tag will be executed and
 perhaps add to the result the <tag>default</tag> performed.</p></desc>"
	    ])
	  }),

//----------------------------------------------------------------------

"comment":#"<desc type='cont'><p><short>
 The enclosed text will be removed from the document.</short> The
 difference from a normal SGML (HTML/XML) comment is that the text is
 removed from the document, and can not be seen even with <i>view
 source</i> in the browser.</p>

 <p>Note that since this is a normal tag, it requires that the content
 is properly formatted. Therefore it's often better to use the
 &lt;?comment&nbsp;...&nbsp;?&gt; processing instruction tag to
 comment out arbitrary text (which doesn't contain '?&gt;').</p>

 <p>Just like any normal tag, the <tag>comment</tag> tag nests inside
 other <tag>comment</tag> tags. E.g:</p>

 <ex-box><comment> a <comment> b </comment> c </comment></ex-box>

 <p>Here 'c' is not output since the comment starter before 'a'
 matches the ender after 'c' and not the one before it.</p>
</desc>

<attr name='preparse'>
 <p>Parse and execute any RXML inside the comment tag. This can be used
 to do stuff without producing any output in the response. This is a
 compatibility argument; the recommended way is to use
 <tag>nooutput</tag> instead.</p>
</attr>",

//----------------------------------------------------------------------

"?comment":#"<desc type='pi'><p><short>
 Processing instruction tag for comments.</short> This tag is similar
 to the RXML <tag>comment</tag> tag but should be used
 when commenting arbitrary text that doesn't contain '?&gt;'.</p>

<ex-box><?comment
  This comment will not ever be shown.
?></ex-box>
</desc>",

//----------------------------------------------------------------------

"define":({ #"<desc type='cont'><p><short>
Defines new tags, containers and if-callers. Can also be used to set
variable values.</short></p>

<p>The attributes \"tag\", \"container\", \"if\" and \"variable\"
specifies what is being defined. Exactly one of them are required. See
the respective attributes below for further information.</p></desc>

<attr name='variable' value='name'><p>
 Sets the value of the variable to the contents of the container.</p>
</attr>

<attr name='tag' value='name'><p>
 Defines a tag with the given name that doesn't take any content. When
 the defined tag is used, the content of this <tag>define</tag> is
 RXML parsed and the result is inserted in place of the defined tag.
 The arguments to the defined tag are available in the current scope
 in the <tag>define</tag>. An example:

 <ex><define tag='my-tag'>
  <inc variable='var.counter'/>
  A counter: &var.counter;<br />
  The 'foo' argument is: &_.foo;<br />
</define>
<my-tag/>
<my-tag foo='bar'/></ex>
</p>
</attr>

<attr name='container' value='name'><p>
 Like the 'tag' attribute, but the defined tag may also take content.
 The unevaluated content is available in <ent>_.contents</ent> inside
 the <tag>define</tag> (see the scope description below). You can also
 get the content after RXML evaluation with the <tag>contents</tag>
 tag - see below for further details.</p>
</attr>

<attr name='if' value='name'><p>
 Defines an if-caller that compares something with the contents of the
 container.</p>
</attr>

<attr name='trimwhites'><p>
 Trim all white space characters from the beginning and the end of the
 contents.</p>
</attr>

<attr name='preparse'><p>
 Sends the definition through the RXML parser when the
 <tag>define</tag> is executed instead of when the defined tag is
 used.</p>

 <p>Compatibility notes: If the compatibility level is 2.2 or earlier,
 the result from the RXML parse is parsed again when the defined tag
 is used, which can be a potential security problem. Also, if the
 compatibility level is 2.2 or earlier, the <tag>define</tag> tag does
 not set up a local scope during the preparse pass, which means that
 the enclosed code will still use the closest surrounding \'_\'
 scope.</p>
</attr>",

	    ([
"attrib":#"<desc type='cont'><p>
 When defining a tag or a container the tag <tag>attrib</tag>
 can be used to define default values of the attributes that the
 tag/container can have. The attrib tag must be the first tag(s)
 in the define tag.</p>
</desc>

 <attr name='name' value='name'><p>
  The name of the attribute which default value is to be set.</p>
 </attr>",

"&_.args;":#"<desc type='entity'><p>
 The full list of the attributes, and their arguments, given to the
 tag.
</p></desc>",

"&_.rest-args;":#"<desc type='entity'><p>
 A list of the attributes, and their arguments, given to the tag,
 excluding attributes with default values defined.
</p></desc>",

"&_.contents;":#"<desc type='entity'><p>
 The unevaluated contents of the container.
</p></desc>",

"contents":#"<desc type='tag'><p>
 Inserts the whole or some part of the arguments or the contents
 passed to the defined tag or container.</p>

 <p>The passed contents are RXML evaluated in the first encountered
 <tag>contents</tag>; the later ones reuses the result of that.
 (However, if it should be compatible with 2.2 or earlier then it\'s
 reevaluated each time unless there\'s a \'copy-of\' or \'value-of\'
 attribute.)</p>

 <p>Note that when the preparse attribute is used, this tag is
 converted to a special variable reference on the form
 \'<ent>_.__contents__<i>n</i></ent>\', which is then substituted with
 the real value when the defined tag is used. It\'s that way to make
 the expansion work when the preparsed code puts it in an attribute
 value. (This is mostly an internal implementation detail, but it can
 be good to know since the variable name might show up.)
</p></desc>

<attr name='scope' value='scope'><p>
 Associate this <tag>contents</tag> tag with the innermost
 <tag>define</tag> container with the given scope. The default is to
 associate it with the innermost <tag>define</tag>.</p>
</attr>

<attr name='eval'><p>
 When this attribute exists, the passed content is (re)evaluated
 unconditionally before being inserted. Normally the evaluated content
 from the preceding <tag>contents</tag> tag is reused, and it\'s only
 evaluated if this is the first encountered <tag>contents</tag>.</p>
</attr>

<attr name='copy-of' value='expression'><p>
 Selects a part of the content node tree to copy. As opposed to the
 value-of attribute, all the selected nodes are copied, with all
 markup.</p>

 <p>If the result-set attribute is not used then the selected nodes
 are returned as a string, otherwise they are returned as an array
 with one node per element (see the result-set attribute for
 details).</p>

 " // FIXME: Moved the following to some intro chapter.
 #"<p>The expression is a simplified variant of an XPath location path:
 It consists of one or more steps delimited by \'<tt>/</tt>\' or
 \'<tt>//</tt>\'. Each step selects some part(s) of the tree starting
 from the current node. The first step operates on the defined tag or
 container itself.</p>

 <p>A step preceded by \'<tt>/</tt>\' is only matched against the
 immediate children of the node currently selected by the preceding
 step. A step preceded by \'<tt>//</tt>\' is matched against any node
 in the tree below that node.</p>

 <p>Note: An expression cannot begin with \'<tt>/</tt>\' or
 \'<tt>//</tt>\'. Use \'<tt>./</tt>\' or \'<tt>.//</tt>\' instead.</p>

 <p>A step may be any of the following:</p>

 <list type=\"ul\">
   <item><p>\'<i>name</i>\' selects all elements (i.e. tags or
   containers) with the given name in the content. The name can be
   \'<tt>*</tt>\' to select all.</p></item>

   <item><p>\'<tt>@</tt><i>name</i>\' selects the element attribute
   with the given name. The name can be \'<tt>*</tt>\' to select
   all.</p></item>

   <item><p>\'<tt>comment()</tt>\' selects all comments in the
   content.</p></item>

   <item><p>\'<tt>text()</tt>\' selects all text pieces in the
   content.</p></item>

   <item><p>\'<tt>processing-instruction(<i>name</i>)</tt>\' selects
   all processing instructions with the given name in the content. The
   name may be left out to select all.</p></item>

   <item><p>\'<tt>node()</tt>\' selects all the different sorts of
   nodes in the content, i.e. the whole content.</p></item>

   <item><p>\'.\' selects the currently selected element
   itself.</p></item>
 </list>

 <p>A step may be followed by \'<tt>[<i>test</i>]</tt>\' to filter the
 selected set in various ways. The test may be any of the
 following:</p>

 <list type=\"ul\">
   <item><p>If <i>test</i> is an integer then the item on that
   position in the set is selected. The index n may be negative to
   select an element in reverse order, i.e. -1 selects the last
   element, -2 the second-to-last, etc.</p></item>

   <item><p>If <i>test</i> is a path on the form described above then
   that path is evaluated for each node in the selected set, and only
   the nodes where the path finds a match remain in the set.</p>

   <p>E.g. a test on the form \'<tt>@<i>name</i></tt>\' accepts only
   elements that have an attribute with the given name.</p></item>

   <item><p>If <i>test</i> is on the form
   \'<i>path</i>=<i>value</i>\' then <i>path</i> is evaluated for
   each node in the selected set, and only the nodes where at least
   one path result matches <i>value</i> remain in the set.
   <i>value</i> is a string literal delimited by either <tt>\"</tt> or
   <tt>\'</tt>.</p>

   <p>E.g. \'<tt>@<i>name</i>=<i>value</i></tt>\' filters out the
   elements that have an attribute with the given name and
   value.</p></item>
 </list>

 <p>An example: The expression \'<tt>p/*[2]/@href</tt>\' first
 selects all <tag>p</tag> elements in the content. In the content of
 each of these, the second element with any name is selected. It\'s
 not an error if some of the <tag>p</tag> elements have less than two
 child elements; those who haven\'t are simply ignored. Lastly, all
 \'href\' attributes of all those elements are selected. Again it\'s
 not an error if some of the elements lack \'href\' attributes.</p>

 <p>Note that an attribute node is both the name and the value, so in
 the example above the result might be
 \'<tt>href=\"index.html\"</tt>\' and not
 \'<tt>index.html</tt>\'. If you only want the value, use the
 value-of attribute instead.</p>
</attr>

<attr name='value-of' value='expression'><p>
 Selects a part of the content node tree and inserts its text value.
 As opposed to the copy-of attribute, only the node values are
 inserted. The expression is the same as for the copy-of
 attribute.</p>

 <p>If the result-set attribute is not used then only the first node
 value in the selected set is returned, otherwise all values are
 returned as an array (see the result-set attribute for details).</p>

 <p>The text value of an element node is all the text in it and all
 its subelements, without the elements themselves or any processing
 instructions.</p>
</attr>

<attr name='result-set'><p>
 Used together with the copy-of or value-of attributes. Add this
 attribute to make them return the selected nodes or values as a set
 instead of a plain string.</p>

 <p>The result can not be inserted directly into the page in this
 case, but it can be assigned to a variable and manipulated further,
 e.g. fed to <tag>emit</tag> to iterate over the elements in the
 set. An example:</p>

 <ex><define container='sort-items'>
  <set variable='_.item'><contents copy-of='item' result-set=''/></set>
  <emit source='values' variable='_.item' sort='value'>&_.value;</emit>
</define>
<sort-items>
  <item>one</item>
  <item>two</item>
  <item>three</item>
</sort-items></ex>

 <p>The set is normally an array (in document order), but if used with
 copy-of and the expression selects an attribute set then that set is
 returned as a mapping.</p>
</attr>"
	    ])

}),

//----------------------------------------------------------------------

"else":#"<desc type='cont'><p><short>

 Execute the contents if the previous <xref href='if.tag'/> tag didn't,
 or if there was a <xref href='false.tag'/> tag above.</short> This
 tag also detects if the page's truth value has been set to false, which
 occurrs whenever a runtime error is encountered. The <xref
 href='../output/emit.tag'/> tag, for one, signals this way when it did
 not loop a single time.</p>

 <p>The result is undefined if there has been no <xref href='if.tag'/>,
 <xref href='true.tag'/>, <xref href='false.tag' /> or other tag that
 touches the page's truth value earlier in the page.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>",

//----------------------------------------------------------------------

"elseif":#"<desc type='cont'><p><short>
 Same as the <xref href='if.tag' />, but it will only evaluate if the
 previous <tag>if</tag> returned false.</short></p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>",

//----------------------------------------------------------------------

"false":#"<desc type='tag'><p><short>
 Internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag' /> tag
 will show its contents. It can be useful if you are writing your own
 <xref href='if.tag' /> lookalike tag. </p>
</desc>",

//----------------------------------------------------------------------

"guess-content-type":#"<desc type='tag'><p><short>
 Tries to find a content type from content, filename or file path.</short>
 Either \"content\" or \"filename\" attributes must be supplied.
</p>
</desc>

<attr name='content' value='string'><p>
   Guess the content type from the content. This function is currently
   only capable of recognizing several common image formats. If the
   content format isn't recognized then the fallback content type in the
   Content Types module is returned. That type is
   \"application/octet-stream\" by default.
 </p>
<ex-box><guess-content-type content='&form.image;'/></ex-box>
</attr>

<attr name='filename' value='filename|path'><p>
 The tag makes its guess from the filename suffix, but you may provide a
 full path for convenience. If you want it to verify that the file is an
 image by its file content use the \"content\" attribute instead.
 </p>
<ex><guess-content-type filename='/foo/bar.jpg'/></ex>
</attr>",

//----------------------------------------------------------------------

"help":#"<desc type='tag'><p><short>
 Gives help texts for tags.</short> If given no arguments, it will
 list all available tags. By inserting <tag>help/</tag> in a page, a
 full index of the tags available in that particular Roxen WebServer
 will be presented. If a particular tag is missing from that index, it
 is not available at that moment. Since all tags are available through
 modules, that particular tag's module hasn't been added to the
 Roxen WebServer yet. Ask an administrator to add the module.
</p>
</desc>

<attr name='for' value='tag'><p>
 Gives the help text for that tag.</p>
<ex><help for='roxen'/></ex>
</attr>",

//----------------------------------------------------------------------

"if":#"<desc type='cont'><p><short>
 The <tag>if</tag> tag is used to conditionally include its
 contents.</short> <xref href='else.tag'/> or <xref
 href='elseif.tag'/> can be used afterwards to include alternative
 content if the test is false.</p>

 <p>The tag itself is useless without its plugins. Its main
 functionality is to provide a framework for the plugins. It is
 mandatory to add a plugin as one attribute. The other provided
 attributes are 'and', 'or' and 'not', used for combining different
 plugins with logical operations.</p>

 <p>Note: Since XML mandates that tag attributes must be unique, it's
 not possible to use the same plugin more than once with a logical
 operator. E.g. this will not work:</p>

 <ex-box><if variable='var.x' and='' variable='var.y'>
   This does not work.
 </if></ex-box>

 <p>You have to use more than one tag in such cases. The example above
 can be rewritten like this to work:</p>

 <ex-box><if variable='var.x'>
   <if variable='var.y'>
     This works.
   </if>
 </if></ex-box>

 <p>The If plugins are sorted according to their function into five
 categories: Eval, Match, State, Utils and SiteBuilder.</p>

 <h1>Eval plugins</h1>

 <p>The Eval category is the one corresponding to the regular tests made
 in programming languages, and perhaps the most used. They evaluate
 expressions containing variables, entities, strings etc and are a sort
 of multi-use plugins.</p>

 <ex-box><if variable='var.foo > 0' and='' match='var.bar is No'>
    ...
  </if></ex-box>

 <ex-box><if variable='var.foo > 0' not=''>
  &var.foo; is less than 0
</if><else>
  &var.foo; is greater than 0
</else></ex-box>

 <p>The tests are made up either of a single operand or two operands
 separated by an operator surrounded by single spaces. The value of
 the single or left hand operand is determined by the If plugin.</p>

 <p>If there is only a single operand then the test is successful if
 it has a value different from the integer 0. I.e. all string values,
 including the empty string \"\" and the string \"0\", make the test
 succeed.</p>

 <p>If there is an operator then the right hand is treated as a
 literal value (with some exceptions described below). Valid operators
 are \"=\", \"==\", \"is\", \"!=\", \"&lt;\", \"&gt;\", \"&lt;=\", and
 \"&gt;=\".</p>

 <ex><set variable='var.x' value='6'/>
<if variable='var.x > 5'>More than one hand</if></ex>

 <p>The three operators \"=\", \"==\" and \"is\" all test for
 equality. They can furthermore do pattern matching with the right
 operand. If it doesn't match the left one directly then it's
 interpreted as a glob pattern with \"*\" and \"?\". If it still
 doesn't match then it's split on \",\" and each part is tried as a
 glob pattern to see if any one matches.</p>

 <p>In a glob pattern, \"*\" means match zero or more arbitrary
 characters, and \"?\" means match exactly one arbitrary character.
 Thus \"t*f??\" will match \"trainfoo\" as well as \"tfoo\" but not
 \"trainfork\" or \"tfo\". It is not possible to use regexps together
 with any of the if-plugins.</p>

 <ex><set variable='var.name' value='Sesame'/>
<if variable='var.name is e*,*e'>\"&var.name;\" begins or ends with an 'e'.</if></ex>

 <h1>Match plugins</h1>

 <p>The Match category contains plugins that match contents of
 something, e.g. an IP package header, with arguments given to the
 plugin as a string or a list of strings.</p>

 <ex>Your domain <if ip='130.236.*'> is </if>
<else> isn't </else> liu.se.</ex>

 <h1>State plugins</h1>

 <p>State plugins check which of the possible states something is in,
 e.g. if a flag is set or not, if something is supported or not, if
 something is defined or not etc.</p>

 <ex>
   Your browser
  <if supports='javascript'>
   supports Javascript version &client.javascript;
  </if>
  <else>doesn't support Javascript</else>.
 </ex>

 <h1>Utils plugins</h1>

 <p>Utils are additonal plugins specialized for certain tests, e.g.
 date and time tests.</p>

 <ex-box>
  <if time='1700' after=''>
    Are you still at work?
  </if>
  <elseif time='0900' before=''>
     Wow, you work early!
  </elseif>
  <else>
   Somewhere between 9 to 5.
  </else>
 </ex-box>

 <h1>SiteBuilder plugins</h1>

 <p>SiteBuilder plugins requires a Roxen Platform SiteBuilder
 installed to work. They are adding test capabilities to web pages
 contained in a SiteBuilder administrated site.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>

<attr name='not'><p>
 Inverts the result (true-&gt;false, false-&gt;true).</p>
</attr>

<attr name='or'><p>
 If any criterion is met the result is true.</p>
</attr>

<attr name='and'><p>
 If all criterions are met the result is true. And is default.</p>
</attr>",

//----------------------------------------------------------------------

"if#type-from-data":#"<desc type='plugin'><p><short>
 Compares if the variable's data is known content type and tries to match
 that content type with the content type pattern.
</short>
 </p><p>
 This test is currently only capable of recognizing several common image
 formats. If the content format isn't recognized then the fallback content
 type in the  Content Types module is tested against the pattern. That type
 is \"application/octet-stream\" by default. That also means that if the
 variable content is unknown and there is nothing to test the content type
 from, it will always return true:
</p>
 <ex>
   <set variable='var.fake-image' value='fakedata here'/>
   <if type-from-data='var.fake-image'>It is an image</if>
 </ex>
<p>While the correct way would be:
</p>
<ex>
   <set variable='var.fake-image' value='fakedata here'/>
   <if type-from-data='var.fake-image is application/octet-stream'>
     Not known content type!
   </if>
</ex>
<p> This is an <i>Eval</i> plugin.</p>
<p>Related tags: <tag>if#type-from-filename</tag>, <tag>cimg</tag>, <tag>guess-content-type</tag>,
   <tag>emit#dir</tag>.</p>
<ex-box>
<nocache>
  <form method='post' enctype='multipart/form-data'>
    <input type='file' name='image' />
    <input type='submit' name='upload' />
  </form>
  <if variable='form.image' and='' sizeof='form.image < 2048000'>
    File is less than 2MB
    <if type-from-data='form.image is image/*'>
      It's an image!
    </if>
    <elseif type-from-filename='form.image is text/*'>
      It is a text file of some sort.
    </elseif>
    <elseif type-from-filename='form.image is application/msword,application/pdf'>
      The image is a MS word- or pdf file.
    </elseif>
    <elseif type-from-filename='form.image is application/octet-stream'>
      Invalid content type, type is unknown!
    </elseif>
  </if>
  <else>File larger than 2MB</else>
</nocache>
</ex-box>
</desc>
",

//----------------------------------------------------------------------

"if#type-from-filename":#"<desc type='plugin'><p><short>
 Compares if the variable contains a path that match the
 content type pattern.
</short></p>
<p>
 This is an <i>Eval</i> plugin.
</p>
<p>Related tags: <tag>if#type-from-data</tag>, <tag>cimg</tag>, <tag>guess-content-type</tag>,
   <tag>emit#dir</tag>.</p>
<p>See a lengthier example under <tag>if#type-from-data</tag>.</p>
<ex>
  <set variable='var.path' value='/a-path/to somthing/wordfile.doc'/>
  <if type-from-filename='var.path is application/msword'>
    It is a word document.
  </if>
  <else>
    It is other document type that I do not want.
  </else>
</ex>
</desc>
",

//----------------------------------------------------------------------

"if#true":#"<desc type='plugin'><p><short>
 This will always be true if the truth value is set to be
 true.</short> Equivalent with <xref href='then.tag' />.
 This is a <i>State</i> plugin.
</p></desc>

<attr name='true' required='required'><p>
 Show contents if truth value is false.</p>
</attr>",

//----------------------------------------------------------------------

"if#false":#"<desc type='plugin'><p><short>
 This will always be true if the truth value is set to be
 false.</short> Equivalent with <xref href='else.tag' />.
 This is a <i>State</i> plugin.</p>
</desc>

<attr name='false' required='required'><p>
 Show contents if truth value is true.</p>
</attr>",

//----------------------------------------------------------------------

"if#module":#"<desc type='plugin'><p><short>
 Returns true if the selected module is enabled in the current
 server.</short> This is useful when you are developing RXML applications
 that you plan to move to other servers, to ensure that all required
 modules are added. This is a <i>State</i> plugin.</p>
</desc>

<attr name='module' value='name'><p>
 The \"real\" name of the module to look for, i.e. its filename
 without extension and without directory path.</p>
</attr>",

//----------------------------------------------------------------------

"if#accept":#"<desc type='plugin'><p><short>
 Returns true if the browser accepts certain content types as specified
 by it's Accept-header, for example image/jpeg or text/html.</short> If
 browser states that it accepts */* that is not taken in to account as
 this is always untrue. This is a <i>Match</i> plugin.
</p></desc>

<attr name='accept' value='type1[,type2,...]' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#config":#"<desc type='plugin'><p><short>
 Has the config been set by use of the <xref href='../protocol/aconf.tag'
 /> tag?</short> This is a <i>State</i> plugin.</p>
</desc>

<attr name='config' value='name' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#cookie":#"<desc type='plugin'><p><short>
 Does the cookie exist and if a value is given, does it contain that
 value?</short> This is an <i>Eval</i> plugin.
</p></desc>
<attr name='cookie' value='name[ is value]' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#client":#"<desc type='plugin'><p><short>
 Compares the user agent string with a pattern.</short> This is a
 <i>Match</i> plugin.
</p></desc>
<attr name='client' value='' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#date":#"<desc type='plugin'><p><short>
 Is the date yyyymmdd?</short> The attributes before, after and
 inclusive modifies the behavior. This is a <i>Utils</i> plugin.
</p></desc>
<attr name='date' value='yyyymmdd | yyyy-mm-dd' required='required'><p>
 Choose what date to test.</p>
</attr>

<attr name='after'><p>
 The date after todays date.</p>
</attr>

<attr name='before'><p>
 The date before todays date.</p>
</attr>

<attr name='inclusive'><p>
 Adds todays date to after and before.</p>

 <ex>
  <if date='19991231' before='' inclusive=''>
     - 19991231
  </if>
  <else>
    20000101 -
  </else>
 </ex>
</attr>",

//----------------------------------------------------------------------

"if#defined":#"<desc type='plugin'><p><short>
 Tests if a certain RXML define is defined by use of the <xref
 href='../variable/define.tag' /> tag, and in that case tests its
 value.</short> This is an <i>Eval</i> plugin. </p>
</desc>

<attr name='defined' value='define' required='required'><p>
 Choose what define to test.</p>
 <p>The define should be provided as
    <i>type</i>&amp;#0;<i>name-of-define</i>, i.e. the type
    and the name separated by a NUL (ASCII 0) character. Currently there
    are two alternatives:</p>
 <list type='ul'>
   <item><p>tag&amp;#0;<i>name-of-define</i></p></item>
   <item><p>if&amp;#0;<i>name-of-define</i></p></item>
 </list>
 <ex>
   <define tag=\"hello-world\">Hello world</define>
   <define container=\"say-hello\">Hello, <contents/></define>
   <define if=\"person\">Matt</define>

   <if defined=\"tag&#0;hello-world\">
     <div><hello-world/>!!</div>
   </if>

   <if defined=\"tag&#0;say-hello\">
     <div><say-hello>Matt</say-hello></div>
   </if>

   <if defined=\"if&#0;person\">
     <div>
       <if person=\"Matt\">Yes, it's Matt!</if>
       <else>No Matt</else>
    </div>
   </if>

   <if defined=\"tag&#0;non-defined-thing\"><non-defined-thing/></if>
   <else><div>&lt;non-defined-thing/&gt; is not defined</div></else>
 </ex>
</attr>",

//----------------------------------------------------------------------

"if#domain":#"<desc type='plugin'><p><short>
 Does the user's computer's DNS name match any of the
 patterns?</short> Note that domain names are resolved asynchronously,
 and that the first time someone accesses a page, the domain name will
 probably not have been resolved. This is a <i>Match</i> plugin.
</p></desc>

<attr name='domain' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

// If eval is deprecated. This information is to be put in a special
// 'deprecated' chapter in the manual, due to many persons asking
// about its whereabouts.

"if#eval":#"<desc type='plugin'><p><short>
 Deprecated due to non-XML compliancy.</short> The XML standard says
 that attribute-values are not allowed to contain any markup. The
 <tag>if eval</tag> tag was deprecated in Roxen 2.0.</p>

<ex-box><!-- If eval statement -->
<if eval=\"<foo>\">x</if>

<!-- Compatible statement -->
<define variable=\"var.foo\" preparse=\"preparse\"><foo/></define>
<if sizeof=\"var.foo\">x</if></ex-box>

 <p>A similar but more XML compliant construct is a combination of
 <tag>set variable</tag> and an apropriate <tag>if</tag> plugin.
</p></desc>",

"if#exists":#"<desc type='plugin'><p><short> Returns true if the named page is
 viewable.</short> A nonviewable page is e.g. a file that matches the
 internal files patterns in the filesystem module. If the path does
 not begin with /, it is assumed to be a URL relative to the directory
 containing the page with the <tag>if</tag>-statement. 'Magic' files
 like /internal-roxen-unit will evaluate as true. This is a
 <i>State</i> plugin.</p>

<p>To check if a path supplied via e.g. a
 form exists you could combine the -exists plugin with e.g. the
 sizeof-plugin:</p>

<ex>
  <if exists='&form.path;' and='' sizeof='form.path > 0'>
    The path &form.path; exists in the virtual filesystem.
  </if>
</ex>
</desc>

<attr name='exists' value='path' required='1'>
 <p>Choose what path in the virtual filesystem to test.</p>
</attr>
",

"if#internal-exists":#"<desc type='plugin'><p><short>
 Returns true if the named page exists.</short> If the page at the given path
 is nonviewable, e.g. matches the internal files patterns in the filesystem module,
 it will still be detected by this if plugin. If the path does not begin with /, it
 is assumed to be a URL relative to the directory containing the page with the if statement.
 'Magic' files like /internal-roxen-unit will evaluate as true.
 This is a <i>State</i> plugin.</p></desc>

<attr name='internal-exists' value='path' required='1'>
 <p>Choose what path in the virtual filesystem to test.</p>
</attr>",

//----------------------------------------------------------------------

"if#group":#"<desc type='plugin'><p><short>
 Checks if the current user is a member of the group according
 the groupfile.</short> This is a <i>Utils</i> plugin.
</p></desc>
<attr name='group' value='name' required='required'><p>
 Choose what group to test.</p>
</attr>

<attr name='groupfile' value='path' required='required'><p>
 Specify where the groupfile is located.</p>
</attr>",

//----------------------------------------------------------------------

"if#ip":#"<desc type='plugin'><p><short>
 Does the users computers IP address match any of the
 patterns?</short> This plugin replaces the Host plugin of earlier
 RXML versions. This is a <i>Match</i> plugin.
</p></desc>
<attr name='ip' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what IP-adress pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#language":#"<desc type='plugin'><p><short>
 Does the client prefer one of the languages listed, as specified by the
 Accept-Language header?</short> This is a <i>Match</i> plugin.
</p></desc>

<attr name='language' value='language1[,language2,...]' required='required'><p>
 Choose what language to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#match":#"<desc type='plugin'><p><short>
 Evaluates patterns.</short> More information can be found in the
 <xref href='../../tutorial/'>If tags tutorial</xref>. Match is an
 <i>Eval</i> plugin.</p></desc>

<attr name='match' value='pattern' required='required'><p>
 Choose what pattern to test. The pattern could be any expression.</p>
 <p>Note! The pattern content is treated as strings. Compare how 
 <tag>if variable</tag> tag works.</p>

<ex>
 <set variable='var.ten' value='10' />
 <if match='&var.ten; is 10'>true</if>
 <else>false</else>
</ex>

</attr>
",

//----------------------------------------------------------------------

"if#Match":#"<desc type='plugin'><p><short>
 Case sensitive version of the <tag>if match</tag> plugin.</short></p>
</desc>",

//----------------------------------------------------------------------

"if#pragma":#"<desc type='plugin'><p><short>
 Compares the HTTP header pragma with a string.</short> This is a
 <i>State</i> plugin.
</p></desc>

<attr name='pragma' value='string' required='required'><p>
 Choose what pragma to test.</p>

<ex>
 <if pragma='no-cache'>The page has been reloaded!</if>
 <else>Reload this page!</else>
</ex>
</attr>
",

//----------------------------------------------------------------------

"if#prestate":#"<desc type='plugin'><p><short>
 Are all of the specified prestate options present in the URL?</short>
 This is a <i>State</i> plugin.
</p></desc>
<attr name='prestate' value='option1[,option2,...]' required='required'><p>
 Choose what prestate to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#referrer":#"<desc type='plugin'><p><short>
 Does the referrer header match any of the patterns?</short> This
 is a <i>Match</i> plugin.
</p></desc>
<attr name='referrer' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#supports":#"<desc type='plugin'><p><short>
 Does the browser support this feature?</short> This is a
 <i>State</i> plugin.
</p></desc>

<attr name='supports' value='feature' required='required'>
 <p>Choose what supports feature to test.</p>
</attr>

<p>The following features are supported:</p> <supports-flags-list/>",

//----------------------------------------------------------------------

"if#time":#"<desc type='plugin'><p><short>
 Is the time hhmm, hh:mm, yyyy-mm-dd or yyyy-mm-ddThh:mm?</short> The attributes before, after,
 inclusive and until modifies the behavior. This is a <i>Utils</i> plugin.
</p></desc>
<attr name='time' value='hhmm|yyyy-mm-dd|yyyy-mm-ddThh:mm' required='required'><p>
 Choose what time to test.</p>
</attr>

<attr name='after'><p>
 The time after present time.</p>
</attr>

<attr name='before'><p>
 The time before present time.</p>
</attr>

<attr name='until' value='hhmm|yyyy-mm-dd|yyyy-mm-ddThh:mm'><p>
 Gives true for the time range between present time and the time value of 'until'.</p>
</attr>

<attr name='inclusive'><p>
 Adds present time to after and before.</p>

<ex-box>
  <if time='1200' before='' inclusive=''>
    ante meridiem
  </if>
  <else>
    post meridiem
  </else>
</ex-box>
</attr>",

//----------------------------------------------------------------------

"if#user":#"<desc type='plugin'><p><short>
 Has the user been authenticated as one of these users?</short> If any
 is given as argument, any authenticated user will do. This is a
 <i>Utils</i> plugin.
</p></desc>

<attr name='user' value='name1[,name2,...]|any' required='required'><p>
 Specify which users to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#scope":#"<desc type='plugin'><p><short>
 Does the scope exists.
</short></p></desc>

<attr name='scope' value='name' required='required'><p>
Specify scope to test for existence.</p>
</attr>",

//----------------------------------------------------------------------

"if#variable":#"<desc type='plugin'><p><short>
 Does the variable exist and have a non-null value? And optionally,
 does its content match the pattern?</short> This is an <i>Eval</i>
 plugin.
</p></desc>

<attr name='variable' value='name[ operator pattern]' required='required'><p>
 Choose variable to test. Valid operators are '=', '==', 'is', '!=',
 '&lt;' and '&gt;'.</p>
 <p>Examples of how this <i>Eval</i> plugin exists in <tag>if</tag>
    documentation and the <xref href='../../tutorial/'>If tags
    tutorial</xref>.</p>
</attr>",

//----------------------------------------------------------------------

"if#Variable":#"<desc type='plugin'><p><short>
 Case sensitive version of the <tag>if variable</tag> plugin.</short></p>
</desc>",

//----------------------------------------------------------------------

"if#variable-exists": #"<desc type='plugin'><p><short>
 Does the given variable exist?</short> I.e. is it bound to any value,
 be it null or something else?</p>

 <p>The difference from the <tag>if variable</tag> plugin is that this
 one returns true for variables with a null value (typically produced
 by the <tag>emit source=\"sql\"</tag> for columns containing an SQL
 NULL value).</p>

 <p><i>Compatibility note:</i> When the compatibility level is 4.5 or
 lower, <tag>emit source=\"sql\"</tag> assigns the undefined value for
 SQL NULLs instead of a proper null value. This test is therefore
 false for such values too unless the compatibility level is higher
 than 4.5.</p>
</desc>

<attr name='variable' value='name' required='required'><p>
 Name of the variable to test.</p>
</attr>",

//----------------------------------------------------------------------

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#clientvar":#"<desc type='plugin'><p><short>
 Evaluates expressions with client specific values.</short> This
 is an <i>Eval</i> plugin.
</p></desc>

<attr name='clientvar' value='variable [is value]' required='required'><p>
 Choose which variable to evaluate against. Valid operators are '=',
 '==', 'is', '!=', '&lt;' and '&gt;'.</p>
</attr>",
// <p>Available variables are:</p>

//----------------------------------------------------------------------

"if#sizeof":#"<desc type='plugin'><p><short>
 Compares the size of a variable with a number.</short>
 This is an <i>Eval</i> plugin.</p>

<ex>
<set variable=\"var.x\" value=\"hello\"/>
<set variable=\"var.y\" value=\"\"/>
<if sizeof=\"var.x == 5\">Five</if>
<if sizeof=\"var.y > 0\">Nonempty</if>
</ex>
</desc>",

//----------------------------------------------------------------------

"nooutput":#"<desc type='cont'><p><short>
 The contents will not be sent through to the page.</short> Side
 effects, for example sending queries to databases, will take effect.
</p></desc>",

//----------------------------------------------------------------------

"noparse":#"<desc type='cont'><p><short>
 The contents of this container tag won't be RXML parsed.</short>
</p></desc>",

//----------------------------------------------------------------------

"?noparse": #"<desc type='pi'><p><short>
 The content is inserted as-is, without any parsing or
 quoting.</short> The first whitespace character (i.e. the one
 directly after the \"noparse\" name) is discarded.</p>
</desc>",

//----------------------------------------------------------------------

"?cdata": #"<desc type='pi'><p><short>
 The content is inserted as a literal.</short> I.e. any XML markup
 characters are encoded with character references. The first
 whitespace character (i.e. the one directly after the \"cdata\" name)
 is discarded.</p>

 <p>This processing instruction is just like the &lt;![CDATA[ ]]&gt;
 directive but parsed by the RXML parser, which can be useful to
 satisfy browsers that does not handle &lt;![CDATA[ ]]&gt; correctly.</p>
</desc>",

//----------------------------------------------------------------------

"number":#"<desc type='tag'><p><short>
 Prints a number as a word.</short>
</p></desc>

<attr name='num' value='number' required='required'><p>
 Print this number.</p>
<ex><number num='4711'/></ex>
</attr>

<attr name='language' value='langcodes'><p>
 The language to use.</p>
 <p><lang/></p>
 <ex>Mitt favoritnummer дr <number num='11' language='sv'/>.</ex>
 <ex>Il mio numero preferito и <number num='15' language='it'/>.</ex>
</attr>

<attr name='type' value='number|ordered|roman|memory' default='number'><p>
 Sets output format.</p>

 <ex>It was his <number num='15' type='ordered'/> birthday yesterday.</ex>
 <ex>Only <number num='274589226' type='memory'/> left on the Internet.</ex>
 <ex>Spock Garfield <number num='17' type='roman'/> rests here.</ex>
</attr>",

//----------------------------------------------------------------------

"strlen":#"<desc type='cont'><p><short>
 Returns the length of the content, which is treated as
 text/plain.</short></p>

 <ex>There are <strlen>foo bar gazonk</strlen> characters
 inside the tag.</ex>

 <p>See also the <xref href='../variable/elements.tag'/> tag for use
 with non-string types.</p>

 <p>Compatibility note: Before 5.0, this tag HTML encoded values from
 variable entities in the content. If you e.g. had the single
 character <tt>&lt;</tt> in the variable var.a then
 <tt><tag>strlen</tag><ent>var.a</ent><tag>/strlen</tag></tt> would
 produce 4 instead of 1 because it converted the <tt>&lt;</tt> to
 <tt>&amp;lt;</tt> first. That no longer occurs, which makes this tag
 consistent with e.g. <tag>if sizeof</tag> and the sizeof() expression
 operator. The old behavior is retained if the compatibility level is
 4.5 or less.</p>
</desc>",

//----------------------------------------------------------------------

"elements": #"<desc type='tag'><p><short>
 Returns the number of elements in a variable.</short> If the variable
 isn't of a type which contains several elements (includes strings), 1
 is returned. That makes it consistent with variable indexing, e.g.
 var.foo.1 takes the first element in var.foo if it's an array, and if
 it isn't then it's the same as var.foo.</p>

 <p>See also the <xref href='../text/strlen.tag'/> tag for use with
 strings.</p>
</desc>

<attr name='variable' value='string'>
 <p>The name of the variable.</p>
</attr>

<attr name='scope' value='string'>
 <p>The name of the scope, unless given in the variable attribute.</p>
</attr>",

//----------------------------------------------------------------------

"then":#"<desc type='cont'><p><short>
 Shows its content if the truth value is true.</short> This is useful in
 conjunction with tags that leave status data there, such as the <xref
 href='../output/emit.tag'/> or <xref href='../programming/crypt.tag'/>
 tags.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>",

//----------------------------------------------------------------------

"trace":#"<desc type='cont'><p><short>
 Executes the contained RXML code and makes a trace report about how
 the contents are parsed by the RXML parser.</short>
</p></desc>",

//----------------------------------------------------------------------

"true":#"<desc type='tag'><p><short>
 An internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag'
 /> tag will not show its contents. It can be useful if you are
 writing your own <xref href='if.tag' /> lookalike tag.</p>
</desc>",

//----------------------------------------------------------------------

"undefine":#"<desc type='tag'><p><short>
 Removes a definition made by the define container.</short> One
 attribute is required.
</p></desc>

<attr name='variable' value='name'><p>
 Undefines this variable.</p>

 <ex>
  <define variable='var.hepp'>hopp</define>
  &var.hepp;
  <undefine variable='var.hepp'/>
  &var.hepp;
 </ex>
</attr>

<attr name='tag' value='name'><p>
 Undefines this tag.</p>
</attr>

<attr name='container' value='name'><p>
 Undefines this container.</p>
</attr>

<attr name='if' value='name'><p>
 Undefines this if-plugin.</p>
</attr>",

//----------------------------------------------------------------------

"use":#"<desc type='cont'><p><short>
 Reads <i>tag definitions</i>, user defined <i>if plugins</i> and 
 <i>variables</i> from a file or package and includes into the 
 current page.</short></p>
 <note><p>The file itself is not inserted into the page. This only 
 affects the environment in which the page is parsed. The benefit is 
 that the package file needs only be parsed once, and the compiled 
 versions of the user defined tags can then be used, thus saving time. 
 It is also a fairly good way of creating templates for your website. 
 Just define your own tags for constructions that appears frequently 
 and save both space and time. Since the tag definitions are cached 
 in memory, make sure that the file is not dependent on anything dynamic, 
 such as form variables or client settings, at the compile time. Also 
 note that the use tag only lets you define variables in the form 
 and var scope in advance. Variables with the same name will be 
 overwritten when the use tag is parsed.</p></note>
</desc>

<attr name='packageinfo'><p>
 Show a list of all available packages.</p>
</attr>

<attr name='package' value='name'><p>
 Reads all tags, container tags and defines from the given package.
 Packages are files located by default in <i>../rxml_packages/</i>.</p>
</attr>

<attr name='file' value='path'><p>
 Reads all tags and container tags and defines from the file.</p>

 <p>This file will be fetched just as if someone had tried to fetch it
 with an HTTP request. This makes it possible to use Pike script
 results and other dynamic documents. Note, however, that the results
 of the parsing are heavily cached for performance reasons. If you do
 not want this cache, use <tag>insert file='...'
 nocache='1'</tag> instead.</p>
</attr>

<attr name='info'><p>
 Show a list of all defined tags/containers and if arguments in the
 file.</p>
</attr>",

//----------------------------------------------------------------------

"eval":#"<desc type='cont'><p><short>
 Postparses its content.</short> Useful when an entity contains
 RXML-code. <tag>eval</tag> is then placed around the entity to get
 its content parsed.</p>
</desc>",

//----------------------------------------------------------------------

"emit#csv":#"<desc type='plugin'><p><short>
 Emit the fields from a file containing a comma-separated list of
 values.</short>
</p></desc>

<attr name='path' value='string'><p>
 Path in the virtual filesystem to the csv-file.
</p></attr>
<attr name='realpath' value='string'><p>
 Path in the real filesystem to the csv-file.
</p></attr>
<attr name='header' value='string'><p>
 Header line containing the field names for the csv-file.</p>

 <p>CSV-files usually have a first line that contains the names for the
 fields, but in some cases the file only contains data, in which case
 this attribute needs to be set.</p>

 <p>Note that the header line fields must be separated with the same
 delimiter as the csv-file data.</p>
</attr>
<attr name='delimiter' value='string'><p>
 Delimiter used to separate the fields in the csv-file.</p>

 <p>The tag defaults to trying the delimiters <tt><b>,</b></tt>,
 <tt><b>;</b></tt> and <b>TAB</b>. If it selects the wrong delimiter
 the correct one can be explicitly specified by setting this attribute.</p>
</attr>
",

//----------------------------------------------------------------------

"emit#path":({ #"<desc type='plugin'><p><short>
 Prints paths.</short> This plugin traverses over all directories in
 the path from the root up to the current one.</p>
</desc>

<attr name='path' value='string'><p>
   Use this path instead of the document path</p>
</attr>

<attr name='trim' value='string'><p>
 Removes all of the remaining path after and including the specified
 string.</p>
</attr>

<attr name='skip' value='number'><p>
 Skips the 'number' of slashes ('/') specified, with beginning from
 the root.</p>
</attr>

<attr name='skip-end' value='number'><p>
 Skips the 'number' of slashes ('/') specified, with beginning from
 the end.</p>
</attr>",
	       ([
"&_.name;":#"<desc type='entity'><p>
 Returns the name of the most recently traversed directory.</p>
</desc>",

"&_.path;":#"<desc type='entity'><p>
 Returns the path to the most recently traversed directory.</p>
</desc>"
	       ])
}),

//----------------------------------------------------------------------

"emit#sources":({ #"<desc type='plugin'><p><short>
 Provides a list of all available emit sources.</short>
</p></desc>",
  ([ "&_.source;":#"<desc type='entity'><p>
  The name of the source.</p></desc>" ]) }),

//----------------------------------------------------------------------

"emit#scopes":({ #"<desc type='plugin'><p><short>
 Provides a list of all available RXML scopes.</short>
</p></desc>",
  ([ "&_.scope;":#"<desc type='entity'><p>
  The name of the scope.</p></desc>" ]) }),

//----------------------------------------------------------------------

"emit#values":({ #"<desc type='plugin'><p><short>
 Iterates over the component values of a string or a compound
 value.</short> If it's a string, it's split into pieces using a
 separator string, and the plugin then iterates over the pieces. If
 it's a compound value like an array then the plugin iterates over its
 elements.
</p></desc>

<attr name='values' value='mixed'><p>
 The value to iterate over. This attribute is required unless the
 \"variable\" or \"from-scope\" attribute is used.</p>
</attr>

<attr name='variable' value='name'><p>
 Name of a variable from which the value are taken.</p>
</attr>

<attr name='split' value='string' default='NULL'><p>
 The string to split a string value with. Supplying an empty string
 results in the string being split between every single character.
 This has no effect if the value isn't a string.</p>
</attr>

<attr name='nosplit'><p>
 If specified then the value isn't split, even when it is a string.
 Instead the plugin only evaluates its contents once using the whole
 string.</p>

 <p>This is useful if a value might either be a single string or
 multiple strings as an array, and you want to iterate over each full
 string.</p>
</attr>

<attr name='advanced' value='lines|words|csv|chars'><p>
 If the value is a string it can be split into multiple fields
 by using this attribute:</p>
 <list type='dl'>
  <item name='lines'>
    <p>The input is split on individual line-feed and carriage-return
    characters and in combination. Note that the separator characters
    are not kept in the output values.</p></item>
  <item name='words'>
    <p>The input is split on the common white-space characters (line-feed,
    carriage-return, space and tab). White-space is not retained in
    the fields. Note that if a field ends with one of the punctuation
    marks <tt>'.'</tt>, <tt>','</tt>, <tt>':'</tt>, <tt>';'</tt>,
    <tt>'!'</tt> or <tt>'?'</tt>, the punctuation mark will be removed.</p></item>
  <item name='chars'>
    <p>(Characters) The input is split into individual characters.</p></item>
  <item name='csv'>
    <p>(Comma-separated values) This input is first split into lines,
    and the lines then split into fields on
    <tt>','</tt> and <tt>';'</tt> according to CSV quoting rules.
    Note that this results in a two-dimensional result.</p></item>
 </list>
</attr>

<attr name='case' value='upper|lower'><p>
 Change the case of each returned value.</p>
</attr>

<attr name='trimwhites'><p>
 Trim away all leading and trailing white space charachters from each
 returned value.</p>
</attr>

<attr name='randomize' value='yes|no'><p>
  Outputs the values in random order if it has the value 'yes'.</p>
</attr>

<attr name='distinct'><p>
  If specified, values are only output once even if they occur several times.</p>
</attr>

<attr name='from-scope' value='name'>
 <p>Iterate over a scope like a mapping. <ent>_.index</ent> gets the
 name of each variable in it and <ent>_.value</ent> gets the
 corresponding value.</p>
</attr>
",

([
"&_.value;":#"<desc type='entity'><p>
 The value of one element or substring if a string is being split.</p>
</desc>",

"&_.index;":#"<desc type='entity'><p>
 The index of one element. This is set if the value being iterated
 over is a mapping/scope or a multiset.</p>
</desc>"
])
	      }),

//----------------------------------------------------------------------

"emit":({ #"<desc type='cont'><p><short hide='hide'>
 Provides data, fetched from different sources, as entities. </short>

 <tag>emit</tag> is a generic tag used to fetch data from a
 provided source, loop over it and assign it to RXML variables
 accessible through entities.</p>

 <p>Occasionally an <tag>emit</tag> operation fails to produce output.
 This might happen when <tag>emit</tag> can't find any matches or if
 the developer has made an error. When this happens the truth value of
 that page is set to <i>false</i>. By using <xref
 href='../if/else.tag' /> afterwards it's possible to detect when an
 <tag>emit</tag> operation fails.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>

<attr name='source' value='plugin' required='required'><p>
 The source from which the data should be fetched.</p>
</attr>

<attr name='scope' value='name' default='The emit source'><p>
 The name of the scope within the emit tag.</p>
</attr>

<attr name='maxrows' value='number'><p>
 Limits the number of rows to this maximum. Note that it is
 often better to restrict the number of rows emitted by
 modifying the arguments to the emit plugin, if possible.
 E.g. when quering a MySQL database the data can be restricted
 to the first 100 entries by adding \"LIMIT 100\".</p>
</attr>

<attr name='skiprows' value='number'><p>
 Makes it possible to skip the first rows of the result. Negative
 numbers means to skip everything execept the last n rows. Note
 that it is often better to make the plugin skip initial rows,
 if possible.</p>
</attr>

<attr name='rowinfo' value='variable'><p>
 The number of rows in the result, after it has been filtered and
 limited by maxrows and skiprows, will be put in this variable,
 if given. Note that this may not be the same value as the number
 of emit iterations that the emit tag will perform, since it will
 always make one iteration when the attribute do-once is set.</p>
</attr>

<attr name='remainderinfo' value='variable'><p>
 The number of rows left to output, when the emit is restricted
 by the maxrows attribute. Rows excluded by other means such as
 skiprows or filter are not included in hte remainderinfo value.
 The rows counted in the remainderinfo are also filtered if the
 filter attribute is used, so the value represents the actual
 number of rows that should have been outputed, had emit not
 been restriced.</p>
</attr>

<attr name='do-once'><p>
 Indicate that at least one loop should be made. All variables in the
 emit scope will be empty, except for the counter variable.</p>
</attr>

<attr name='filter' value='list'><p>
 The filter attribute is used to block certain 'rows' from the
 source from being emitted. The filter attribute should be set
 to a list with variable names in the emitted scope and glob patterns
 the variable value must match in order to not get filtered.
 A list might look like <tt>name=a*,id=??3?45</tt>. Note that
 it is often better to perform the filtering in the plugin, by
 modifying its arguments, if possible. E.g. when querying an SQL
 database the use of where statements is recommended, e.g.
 \"WHERE name LIKE 'a%' AND id LIKE '__3_45'\" will perform the
 same filtering as above.</p>

<ex><emit source='values' values='foo,bar,baz' split=',' filter='value=b*'>
&_.value;
</emit></ex>
</attr>

<attr name='filter-exclude' value='list'><p>The filter exclude attribute is
 used to filter out unwanted rows that would otherwise be emitted. 
 Uses the same syntax as the filter attribute.</p>
</attr>

<attr name='sort' value='list'><p>
  The emit result can be sorted by the emit tag before being output.
  Just list the variable names in the scope that the result should
  be sorted on, in prioritized order, e.g. \"lastname,firstname\".
  By adding a \"-\" sign in front of a name, that entry will be
  sorted in the reversed order.</p>

  <p>The sort order is case sensitive, but by adding \"^\" in front of
  the variable name the order will be case insensitive.</p>

  <p>The sort algorithm will treat numbers as complete numbers and not
  digits in a string, hence \"foo8bar\" will be sorted before
  \"foo11bar\". If a variable name is prefixed by \"*\", then a
  stricter sort algorithm is used which will compare fields containing
  floats and integers numerically and all other values as strings,
  without trying to detecting numbers etc inside them.</p>

  <p>Compatibility notes: In 2.1 compatibility mode the default sort
  algorithm is the stricter one. In 2.2 compatibility mode the \"*\"
  flag is disabled.</p>
</attr>

<attr name='reverse'><p>
  The results will be output in reverse order.</p>
<ex>
<emit source='path' path='/path/to/file' reverse=''>
  &_.path;<br/>
</emit>
</ex>
</attr>",

	  ([

	    "delimiter": #"<desc type='cont'><p>
  The content is inserted in the result except in the last iteration
  through the <tag>emit</tag> tag. It's therefore useful to insert
  stuff that only should delimit the entries, i.e. not occur before
  the first one or after the last.</p>
</desc>",

"&_.counter;":#"<desc type='entity'><p>
 Gives the current number of loops inside the <tag>emit</tag> tag,
 starting from zero.
</p>
</desc>"

	  ])
       }),

//----------------------------------------------------------------------

    ]);
#endif
