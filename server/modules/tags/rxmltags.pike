// This is a ChiliMoon module. Copyright © 1996 - 2001, Roxen IS.
//

#define _stat RXML_CONTEXT->misc[" _stat"]
#define _error RXML_CONTEXT->misc[" _error"]
//#define _extra_heads RXML_CONTEXT->misc[" _extra_heads"]
#define _rettext RXML_CONTEXT->misc[" _rettext"]
#define _ok RXML_CONTEXT->misc[" _ok"]

constant cvs_version = "$Id: rxmltags.pike,v 1.432 2004/06/09 00:17:41 _cvs_stephen Exp $";
constant thread_safe = 1;

#include <module.h>
#include <config.h>
#include <request_trace.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Tags: RXML 2 tags";
constant module_doc  = "This module provides the common RXML tags.";

void start()
{
  query_tag_set()->prepare_context=set_entities;
}

private mapping(string:mixed) sexpr_constants = ([
  "this_program":0,

  "`+":`+,
  "`-":`-,
  "`*":`*,
  "`/":`/,
  "`%":`%,

  "`!":`!,
  "`!=":`!=,
  "`&":`&,
  "`|":`|,
  "`^":`^,

  "`<":`<,
  "`>":`>,
  "`==":`==,
  "`<=":`<=,
  "`>=":`>=,

  "sizeof": sizeof,

  "INT":lambda(void|mixed x) {
	  return intp (x) || floatp (x) || stringp (x) ? (int) x : 0;
	},
  "FLOAT":lambda(void|mixed x) {
	    return intp (x) || floatp (x) || stringp (x) ? (float) x : 0;
	  },
]);

private class SExprCompileHandler
{
  string errmsg;

  mapping(string:mixed) get_default_module() {
    return sexpr_constants;
  }

  mixed resolv(string id, void|string fn, void|string ch) {
    if (mapping|object scope = RXML_CONTEXT->get_scope (id))
      return scope;
    error ("Unknown identifier %O.\n", id);
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

string|int|float sexpr_eval(string what)
{
  what -= "lambda";
  what -= "\"";
  what -= ";";
  SExprCompileHandler handler = SExprCompileHandler();
  string|int|float res;
  if (mixed err = catch {
      res = compile_string( "int|string|float foo=(" + what + ");",
			    0, handler )()->foo;
    })
    RXML.parse_error ("Error in expr attribute: %s\n",
		      handler->errmsg || describe_error (err));
  return res;
}


// ----------------- Entities ----------------------

class EntityClientReferrer {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    array referrer=c->id->referer;
    return referrer && sizeof(referrer)? referrer[0] :RXML.nil;
  }
}

class EntityClientName {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    array client=c->id->client;
    return client && sizeof(client)? client[0] :RXML.nil;
  }
}

class EntityClientIP {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    return c->id->remoteaddr;
  }
}

class EntityClientAcceptLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return RXML.nil;
    return c->id->misc["accept-language"][0];
  }
}

class EntityClientAcceptLanguages {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return RXML.nil;
    // FIXME: Should this be an array instead?
    return c->id->misc["accept-language"]*", ";
  }
}

class EntityClientLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return RXML.nil;
    return c->id->misc->pref_languages->get_language();
  }
}

class EntityClientLanguages {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return RXML.nil;
    // FIXME: Should this be an array instead?
    return c->id->misc->pref_languages->get_languages()*", ";
  }
}

class EntityClientHost {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    if(c->id->host) return c->id->host;
    return c->id->host=core->quick_ip_to_host(c->id->remoteaddr);
  }
}

class EntityClientAuthenticated {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    // Actually, it is cacheable, but _only_ if there is no authentication.
    c->id->misc->cacheable=0;
    User u = c->id->conf->authenticate(c->id);
    if (!u) return RXML.nil;
    return u->name();
  }
}

class EntityClientUser {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    c->id->misc->cacheable=0;
    if (c->id->realauth) {
      // Extract the username.
      return (c->id->realauth/":")[0];
    }
    return RXML.nil;
  }
}

class EntityClientPassword {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    array tmp;
    c->id->misc->cacheable=0;
    if( c->id->realauth
       && (sizeof(tmp = c->id->realauth/":") > 1) )
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
]);

void set_entities(RXML.Context c) {
  c->extend_scope("client", client_scope);
  if (!c->id->misc->cache_tag_miss)
    c->id->cache_status->cachetag = 1;
}


// ------------------- Tags ------------------------

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
  int flags;

  class Frame {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (args->value || args->from) flags |= RXML.FLAG_EMPTY_ELEMENT;
      if (args->type) content_type = args->type (RXML.PXml);
    }

    array do_return(RequestID id) {
      mixed value=RXML.user_get_var(args->variable, args->scope);
      if (args->value) {
	content = args->value;
	if (args->type) content = args->type->encode (content);
      }
      else if (args->from) {
	// Append the value of another entity variable.
	mixed from=RXML.user_get_var(args->from, args->scope);
	if(!from) parse_error("From variable %O doesn't exist.\n", args->from);
	if (value)
	  value+=from;
	else
	  value=from;
	RXML.user_set_var(args->variable, value, args->scope);
	return 0;
      }

      // Append a value to an entity variable.
      if (value)
	value+=content;
      else
	value=content;
      RXML.user_set_var(args->variable, value, args->scope);
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
				 args->message);
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

class TagHeader {
  inherit RXML.Tag;
  constant name = "header";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "name": RXML.t_text(RXML.PEnt),
					       "value": RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->name == "WWW-Authenticate") {
	string r;
	if(args->value) {
	  if(!sscanf(args->value, "Realm=%s", r))
	    r=args->value;
	} else
	  r="Users";
	args->value="basic realm=\""+r+"\"";
      } else if(args->name=="URI")
	args->value = "<" + args->value + ">";

      if(args->name == "Content-Type")
        id->set_response_header(args->name, args->value);
      else
        id->add_response_header(args->name, args->value);
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

      mapping r = Roxen.http_redirect(args->to, id, prestate);

      if (r->error)
	RXML_CONTEXT->set_misc (" _error", r->error);
      if (r->extra_heads)
	RXML_CONTEXT->extend_scope ("header", r->extra_heads);
      // We do not need this as long as r only contains strings and numbers
      //    foreach(indices(r->extra_heads), string tmp)
      //      id->add_response_header(tmp, r->extra_heads[tmp]);
      if (args->text)
	RXML_CONTEXT->set_misc (" _rettext", args->text);

      return 0;
    }
  }
}

class TagUnset {
  inherit RXML.Tag;
  constant name = "unset";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if(!args->variable && !args->scope)
	parse_error("Neither variable nor scope specified.\n");
      if(!args->variable && args->scope!="roxen") {
	RXML_CONTEXT->add_scope(args->scope, ([]) );
	return 0;
      }
      RXML_CONTEXT->user_delete_var(args->variable, args->scope);
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
  int flags = RXML.FLAG_DONT_RECOVER;

  class Frame {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (args->value || args->expr || args->from) flags |= RXML.FLAG_EMPTY_ELEMENT;
      if (args->type) content_type = args->type (RXML.PXml);
    }

    array do_return(RequestID id) {
      if (args->value) {
	content = args->value;
	if (args->type) content = args->type->encode (content);
      }
      else {
	if (args->expr) {
	  // Set an entity variable to an evaluated expression.
	  mixed val=sexpr_eval(args->expr);
	  RXML.user_set_var(args->variable, val, args->scope);
	  return 0;
	}
	if (args->from) {
	  // Copy a value from another entity variable.
	  mixed from;
	  if (zero_type (from = RXML.user_get_var(args->from, args->scope)))
	    run_error("From variable doesn't exist.\n");
	  RXML.user_set_var(args->variable, from, args->scope);
	  return 0;
	}
      }

      // Set an entity variable to a value.
      if(args->split && content)
	RXML.user_set_var(args->variable, (string)content/args->split, args->scope);
      else if (content == RXML.nil) {
	if (content_type->sequential)
	  RXML.user_set_var (args->variable, content_type->empty_value, args->scope);
	else if (content_type == RXML.t_any)
	  RXML.user_set_var (args->variable, RXML.empty, args->scope);
	else
	  parse_error ("The value is missing for non-sequential type %O.\n",
		 content_type);
      }
      else
	RXML.user_set_var(args->variable, content, args->scope);
      return 0;
    }
  }
}

class TagCopyScope {
  inherit RXML.Tag;
  constant name = "copy-scope";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "from":RXML.t_text,
					       "to":RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      RXML.Context ctx = RXML_CONTEXT;
      foreach(ctx->list_var(args->from), string var)
	ctx->set_var(var, ctx->get_var(var, args->from), args->to);
    }
  }
}

class TagInc {
  inherit RXML.Tag;
  constant name = "inc";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "variable":RXML.t_text ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int val=(int)args->value;
      if(!val && !args->value) val=1;
      inc(args, val, id);
      return 0;
    }
  }
}

class TagDec {
  inherit RXML.Tag;
  constant name = "dec";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "variable":RXML.t_text ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int val=-(int)args->value;
      if(!val && !args->value) val=-1;
      inc(args, val, id);
      return 0;
    }
  }
}

static void inc(mapping m, int val, RequestID id)
{
  RXML.Context context=RXML_CONTEXT;
  array entity=context->parse_user_var(m->variable, m->scope);
  if(!context->exist_scope(entity[0])) RXML.parse_error("Scope "+entity[0]+" does not exist.\n");
  context->user_set_var(m->variable, (int)context->user_get_var(m->variable, m->scope)+val, m->scope);
}

class TagImgs {
  inherit RXML.Tag;
  constant name = "imgs";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "src":RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string src=Roxen.html_decode_string(args->src);
      string|object file=id->conf->real_file(Roxen.fix_relative(src, id), id);
      if(!file) {
	file=id->conf->try_get_file(src,id);
	if(file) file = Stdio.FakeFile(file);
      }

      if(file) {
	array(int) xysize;
	if(xysize=Image.Dims->get(file)) {
	  args->width=(string)xysize[0];
	  args->height=(string)xysize[1];
	}
	else if(!args->quiet)
	  RXML.run_error("Dimensions quering failed.\n");
      }
      else if(!args->quiet)
	RXML.run_error("Image file not found.\n");

      if(!args->alt) {
	src=(args->src/"/")[-1];
	args->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src), ".")-2], "_"," "));
      }

      int xml=!m_delete(args, "noxml");

      result = Roxen.make_tag("img", args, xml);
      return 0;
    }
  }
}

class TagChili {
  inherit RXML.Tag;
  constant name = "chili";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string size = m_delete(args, "size") || "small";
      string color = m_delete(args, "color") || "white";
      mapping aargs = (["href": "http://www.chilimoon.org/"]);

      args->src = "/$/chili-"+size+"-"+color;
      args->width =  (["small":"36", "medium":"57", "large":"151"])[size];
      args->height = (["small":"40", "medium":"64", "large":"169"])[size];

      if(!args->alt) args->alt="ChiliMoon";
      if(!args->title) args->title="Powered by ChiliMoon";
      if(!args->border) args->border="0";
      int xml=!m_delete(args, "noxml");
      if(args->target) aargs->target = m_delete (args, "target");
      result = RXML.t_xml->format_tag ("a", aargs, Roxen.make_tag("img", args, xml));
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
      int t=(int)args["unix-time"] || time(1);

      if(args["iso-time"])
      {
	int year, month, day, hour, minute, second;
	if(sscanf(args["iso-time"], "%d-%d-%d%*c%d:%d:%d", year, month, day, hour, minute, second) < 3)
	  // Format yyyy-mm-dd{|{T| }hh:mm|{T| }hh:mm:ss}
	  RXML.parse_error("Attribute iso-time needs at least yyyy-mm-dd specified.\n");
	t = mktime(([
	  "sec":second,
	  "min":minute,
	  "hour":hour,
	  "mday":day,
	  "mon":month-1,
	  "year":year-1900
	]));
      }
      
      if(args->timezone=="GMT") t += localtime(t)->timezone;
      t = Roxen.time_dequantifier(args, t);

      if(!(args->brief || args->time || args->date))
	args->full=1;
      else if( args->time && args->date ) {
	args->full=1;
	m_delete(args, "time");
	m_delete(args, "date");
      }

      if(args->part=="second" || args->part=="beat" || args->strftime ||
	 (args->type=="iso" && !args->date))
	NOCACHE();
      else
	CACHE(60);

      result = Roxen.tagtime(t, args, id);
      return 0;
    }
  }
}

class TagSprintf {
  inherit RXML.Tag;
  constant name = "sprintf";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      array in;
      if(args->split)
	in=content/args->split;
      else
	in=({content});

      array f=((args->format-"%%")/"%")[1..];
      if(sizeof(in)!=sizeof(f))
	RXML.run_error("Indata hasn't the same size as format data (%d, %d).\n", sizeof(in), sizeof(f));

      // Do some casting
      for(int i; i<sizeof(in); i++) {
	int quit;
	foreach(f[i]/1, string char) {
	  if(quit) break;
	  switch(char) {
	  case "d":
	  case "u":
	  case "o":
	  case "x":
	  case "X":
	  case "c":
	  case "b":
	    in[i]=(int)in[i];
	    quit=1;
	    break;
	  case "f":
	  case "g":
	  case "e":
	  case "G":
	  case "E":
	  case "F":
	    in[i]=(float)in[i];
	    quit=1;
	    break;
	  case "s":
	  case "O":
	  case "n":
	  case "t":
	    quit=1;
	    break;
	  }
	}
      }

      result=sprintf(args->format, @in);
      return 0;
    }
  }
}

class TagSscanf {
  inherit RXML.Tag;
  constant name = "sscanf";

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      array(string) vars=args->variables/",";
      array(string) vals=array_sscanf(content, args->format);
      if(sizeof(vars)<sizeof(vals))
	RXML.run_error("Too few variables.\n");

      int var=0;
      foreach(vals, string val)
	RXML.user_set_var(vars[var++], val, args->scope);

      if(args->return)
	RXML.user_set_var(args->return, sizeof(vals), args->scope);
      return 0;
    }
  }
}

class TagInsert {
  inherit RXML.Tag;
  constant name = "insert";
  constant flags = RXML.FLAG_EMPTY_ELEMENT | RXML.FLAG_SOCKET_TAG;
  // FIXME: result_types needs to be updated with all possible outputs
  // from the plugins.

  class Frame {
    inherit RXML.Frame;

    void do_insert(RXML.Tag plugin, string name, RequestID id) {
      result=plugin->get_data(args[name], args, id);

      if(plugin->get_type)
	result_type=plugin->get_type(args, result);
      else if(args->quote=="none")
	result_type=RXML.t_xml;
      else if(args->quote=="html")
	result_type=RXML.t_text;
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
      foreach((array)get_plugins(), [string name, RXML.Tag plugin]) {
	if(args[name]) {
	  do_insert(plugin, name, id);
	  return 0;
	}
      }

      parse_error("No correct insert attribute given.\n");
    }
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

    result=id->conf->try_get_file(var, id);

    // Restore previous language state.
    if (args->langauge && pl) {
      pl->set_sorted(old_lang, old_qualities);
    }

    if( !result )
      RXML.run_error("No such file ("+Roxen.fix_relative( var, id )+").\n");

    return result;
  }
}

class TagReturn {
  inherit RXML.Tag;
  constant name = "return";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

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

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t;
      if(args->persistent) t=-1; else t=Roxen.time_dequantifier(args);
      Roxen.set_cookie( id,  args->name, (args->value||""), t, 
                        args->domain, args->path );
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

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
//    really... is this error a good idea?  I don't think so, it makes
//    it harder to make pages that use cookies. But I'll let it be for now.
//       /Per
//
//    Run errors are not shown by default, but sets the truth state to
//    false. Hence it is possible to do
//    <true/><remove-cookie><then>...</then><else>...</else>
//       /Nilsson


      if(!id->cookies[args->name])
        RXML.run_error("That cookie does not exist.\n");
      Roxen.remove_cookie( id, args->name,
                           (args->value||id->cookies[args->name]||""), 
                           args->domain, args->path );
      return 0;
    }
  }
}

// ------------------- Containers ----------------

class TagScope {
  inherit RXML.Tag;

  constant name = "scope";
  mapping(string:RXML.Type) opt_arg_types = ([ "extend" : RXML.t_text(RXML.PEnt) ]);

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
      if(args->extend)
	vars=copy_value(RXML_CONTEXT->get_scope (scope_name));
      else
	vars=([]);
      return 0;
    }

    array do_return(RequestID id) {
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

class TagFor {
  inherit RXML.Tag;
  constant name = "for";
  int flags = RXML.FLAG_IS_CACHE_STATIC;

  class Frame {
    inherit RXML.Frame;

    private int from,to,step,count;

    array do_enter(RequestID id) {
      from = (int)args->from;
      to = (int)args->to;
      step = (int)args->step!=0?(int)args->step:(to<from?-1:1);
      if((to<from && step>0)||(to>from && step<0))
	run_error("Step has the wrong sign.\n");
      from-=step;
      count=from;
      return 0;
    }

    int do_iterate() {
      if(!args->variable) {
	int diff=abs(to-from);
	to=from;
	return diff;
      }
      count+=step;
      RXML.user_set_var(args->variable, count, args->scope);
      if(to<from) return count>=to;
      return count<=to;
    }

    array do_return(RequestID id) {
      if(args->variable) RXML.user_set_var(args->variable, count-step, args->scope);
      result=content;
      return 0;
    }
  }
}

// Removes empty lines
// NGSERVER: whitespacesucker, this, and trim_whites; what is for what?
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
array split_on_option( string what, Regexp r )
{
  string whatwhatwhat = string_to_utf8(what);
  array a = r->split( whatwhatwhat );
  if( !a )
    return ({ what });
  return split_on_option( utf8_to_string(a[0]), r ) + map(a[1..],utf8_to_string);
}
private int|array internal_tag_select(string t, mapping m, string c, string name
, multiset(string) value)
{
  if(name && m->name!=name) return ({ RXML.t_xml->format_tag(t, m, c) });

  // Split input into an array with the layout
  // ({ "option", option_args, stuff_before_next_option })*n
  // e.g. "fox<OPtioN foo='bar'>gazink</option>" will yield
  // tmp=({ "OPtioN", " foo='bar'", "gazink</option>" }) and
  // ret="fox"
  Regexp r = Regexp( "(.*)<([Oo][Pp][Tt][Ii][Oo][Nn])([^>]*)>(.*)" );
  array(string) tmp=split_on_option(c,r);
  string ret=tmp[0],nvalue;
  int selected,stop;
  tmp=tmp[1..];

  while(sizeof(tmp)>2) {
    stop=search(tmp[2],"<");
    if(sscanf(tmp[1],"%*svalue=%s",nvalue)!=2 &&
       sscanf(tmp[1],"%*sVALUE=%s",nvalue)!=2)
      nvalue=tmp[2][..stop==-1?sizeof(tmp[2]):stop];
    else if(!sscanf(nvalue, "\"%s\"", nvalue) && !sscanf(nvalue, "'%s'", nvalue))
      sscanf(nvalue, "%s%*[ >]", nvalue);
    selected=Regexp(".*[Ss][Ee][Ll][Ee][Cc][Tt][Ee][Dd].*")->match(string_to_utf8(tmp[1]));
    ret+="<"+tmp[0]+tmp[1];
    if(value[nvalue] && !selected) ret+=" selected=\"selected\"";
    ret+=">"+tmp[2];
    if(!Regexp(".*</[Oo][Pp][Tt][Ii][Oo][Nn]")->match(string_to_utf8(tmp[2]))) ret+="</"+tmp[0]+">";
    tmp=tmp[3..];
  }
  return ({ RXML.t_xml->format_tag(t, m, ret) });
}

string simpletag_default( string t, mapping m, string c, RequestID id)
{
  multiset value=(<>);
  if(m->value) value=mkmultiset((m->value||"")/(m->separator||","));
  if(m->variable) value+=(<RXML.user_get_var(m->variable, m->scope)>);
  if(value==(<>)) return c;

  return parse_html(c, (["input":internal_tag_input]),
		    (["select":internal_tag_select]),
		    m->name, value);
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
      if (content && result_type->decode_charrefs)
	content = result_type->decode_charrefs (content);

      if (!args->from || content==RXML.nil)
	result = content;

      else {
	switch(args->type)
	{
	  case "word":
	  default:
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

// NGSERVER: Move this tag to a more sensible module
class TagColorScope {
  inherit RXML.Tag;
  constant name = "colorscope";

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

class TagEval {
  inherit RXML.Tag;
  constant name = "eval";
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

  class Frame {
    inherit RXML.Frame;
    array do_process() {
      return ({""});
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
	    parse_error ("Invalid value %O to the case argument.\n", args->case);
	}
	parse_error ("Content of type %s doesn't handle being %s.\n",
		       content_type->name, op);
      }
      else
	parse_error ("Argument \"case\" is required.\n");

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

    int ifval=0;
    foreach(indices (args), string s)
      if (object plugin =
	  plugins[s] || defs["if\0" + s]) {
	ifval = plugin->eval( args[s], id, args, and, s );
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
  int flags = RXML.FLAG_SOCKET_TAG | RXML.FLAG_IS_CACHE_STATIC;
  array(RXML.Type) result_types = ({RXML.t_any});
  class Frame {
    inherit FrameIf;
  }
}

class TagElse {
  inherit RXML.Tag;
  constant name = "else";
  int flags = RXML.FLAG_IS_CACHE_STATIC;
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
  int flags = RXML.FLAG_IS_CACHE_STATIC;
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
  int flags = RXML.FLAG_IS_CACHE_STATIC;
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
    RXML.shared_tag_set (0, "/rxmltags/cond", ({TagCase(), TagDefault()}));

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
  int flags = RXML.FLAG_SOCKET_TAG | RXML.FLAG_IS_CACHE_STATIC;
  mapping(string:RXML.Type) req_arg_types = ([ "source":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "scope":RXML.t_text(RXML.PEnt),
					       "maxrows":RXML.t_int(RXML.PEnt),
					       "skiprows":RXML.t_int(RXML.PEnt),
					       "rowinfo":RXML.t_text(RXML.PEnt), // t_var
					       "do-once":RXML.t_text(RXML.PEnt), // t_bool
					       "filter":RXML.t_text(RXML.PEnt),  // t_list
					       "sort":RXML.t_text(RXML.PEnt),    // t_list
					       "remainderinfo":RXML.t_text(RXML.PEnt), // t_var
  ]);
  array(string) emit_args = indices( req_arg_types+opt_arg_types );
  RXML.Type def_arg_type = RXML.t_text(RXML.PNone);
  array(RXML.Type) result_types = ({RXML.t_any});

  int(0..1) should_filter(mapping vs, mapping filter) {
    RXML.Context ctx = RXML_CONTEXT;
    foreach(indices(filter), string v) {
      string|object val = vs[v];
      if(objectp(val))
	val = val->rxml_const_eval ? val->rxml_const_eval(ctx, v, "") :
	  val->rxml_var_eval(ctx, v, "", RXML.t_text);
      if(!val)
	return 1;
      if(!glob(filter[v], val))
	return 1;
    }
    return 0;
  }

  class TagDelimiter {
    inherit RXML.Tag;
    constant name = "delimiter";

    static int(0..1) more_rows(array|object res, mapping filter) {
      if(objectp(res)) {
	while(res->peek() && should_filter(res->peek(), filter))
	  res->skip_row();
	return !!res->peek();
      }
      if(!sizeof(res)) return 0;
      foreach(res[RXML.get_var("real-counter")..], mapping v) {
	if(!should_filter(v, filter))
	  return 1;
      }
      return 0;
    }

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	object|array res = id->misc->emit_rows;
	if(!id->misc->emit_filter) {
	  if( objectp(res) ? res->peek() :
	      RXML.get_var("counter") < sizeof(res) )
	    result = content;
	  return 0;
	}
	if(id->misc->emit_args->maxrows &&
	   id->misc->emit_args->maxrows == RXML.get_var("counter"))
	  return 0;
	if(more_rows(res, id->misc->emit_filter))
	  result = content;
	return 0;
      }
    }
  }

  RXML.TagSet internal =
    RXML.shared_tag_set (0, "/rxmltags/emit", ({ TagDelimiter() }) );

  // A slightly modified Array.dwim_sort_func
  // used as emits sort function.
  static int dwim_compare(mixed a0, mixed b0, string v) {
    RXML.Context ctx;

    if(objectp(a0) && a0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      a0 = a0->rxml_const_eval ? a0->rxml_const_eval(ctx, v, "") :
	a0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }
    else
      a0 = (string)a0;

    if(objectp(b0) && b0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      b0 = b0->rxml_const_eval ? b0->rxml_const_eval(ctx, v, "") :
	b0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }
    else
      b0 = (string)b0;

    return dwim_compare_iter(a0, b0);
  }

  static int dwim_compare_iter(string a0,string b0) {
    if (!a0) {
      if (b0)
	return -1;
      return 0;
    }

    if (!b0)
      return 1;

    string a2="",b2="";
    int a1,b1;
    sscanf(a0,"%[^0-9]%d%s",a0,a1,a2);
    sscanf(b0,"%[^0-9]%d%s",b0,b1,b2);
    if (a0>b0) return 1;
    if (a0<b0) return -1;
    if (a1>b1) return 1;
    if (a1<b1) return -1;
    if (a2==b2) return 0;
    return dwim_compare_iter(a2,b2);
  }

  static int strict_compare (mixed a0, mixed b0, string v)
  // This one does a more strict compare than dwim_compare. It only
  // tries to convert values from strings to floats or ints if they
  // are formatted exactly as floats or ints. That since there still
  // are places where floats and ints are represented as strings (e.g.
  // in sql query results). Then it compares the values with `<.
  //
  // This more closely resembles how 2.1 and earlier compared values.
  {
    RXML.Context ctx;

    if(objectp(a0) && a0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      a0 = a0->rxml_const_eval ? a0->rxml_const_eval(ctx, v, "") :
	a0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }

    if(objectp(b0) && b0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      b0 = b0->rxml_const_eval ? b0->rxml_const_eval(ctx, v, "") :
	b0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }

    if (stringp (a0)) {
      if (sscanf (a0, "%d%*[ \t]%*c", int i) == 2) a0 = i;
      else if (sscanf (a0, "%f%*[ \t]%*c", float f) == 2) a0 = f;
    }
    if (stringp (b0)) {
      if (sscanf (b0, "%d%*[ \t]%*c", int i) == 2) b0 = i;
      else if (sscanf (b0, "%f%*[ \t]%*c", float f) == 2) b0 = f;
    }

    int res;
    if (mixed err = catch (res = b0 < a0)) {
      // Assume we got a "cannot compare different types" error.
      // Compare the types instead.
      a0 = sprintf ("%t", a0);
      b0 = sprintf ("%t", b0);
      res = b0 < a0;
    }
    if (res)
      return 1;
    else if (a0 < b0)
      return -1;
    else
      return 0;
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;
    string scope_name;
    mapping vars;

    // These variables are used to store id->misc-variables
    // that otherwise would be overwritten when emits are
    // nested.
    array(mapping(string:mixed))|object outer_rows;
    mapping outer_filter;
    mapping outer_args;

    object plugin;
    array(mapping(string:mixed))|object res;
    mapping filter;

    array expand(object res) {
      array ret = ({});
      do {
	ret += ({ res->get_row() });
      } while(ret[-1]!=0);
      destruct(res);
      return ret[..sizeof(ret)-2];
    }

    array do_enter(RequestID id) {
      if(!(plugin=get_plugins()[args->source]))
	parse_error("The emit source %O doesn't exist.\n", args->source);
      scope_name=args->scope||args->source;
      vars = (["counter":0]);

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

      // Parse the filter argument
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

      outer_args = id->misc->emit_args;
      outer_rows = id->misc->emit_rows;
      outer_filter = id->misc->emit_filter;
      id->misc->emit_args = args;
      id->misc->emit_filter = filter;

      if(objectp(res))
	if(args->sort ||
	   (args->skiprows && args->skiprows<0) ||
	   args->rowinfo ||
	   args->remainderinfo )
	  // Expand the object into an array of mappings if sort,
	  // negative skiprows or rowinfo is used. These arguments
	  // should be intercepted, dealt with and removed by the
	  // plugin, should it have a more clever solution. Note that
	  // it would be possible to use a expand_on_demand-solution
	  // where a value object is stored as the rowinfo value and,
	  // if used inside the loop, triggers an expansion. That
	  // would however force us to jump to another iterator function.
	  // Let's save that complexity enhancement until later.
	  res = expand(res);
	else if(filter) {
	  do_iterate = object_filter_iterate;
	  id->misc->emit_rows = res;
	  return 0;
	}
	else {
	  do_iterate = object_iterate;
	  id->misc->emit_rows = res;

	  if(args->skiprows) {
	    int loop = args->skiprows;
	    while(loop--)
	      res->skip_row();
	  }

	  return 0;
	}

      if(arrayp(res)) {
	if(args->sort && !plugin->sort)
	{
	  array(string) raw_fields = (args->sort - " ")/"," - ({ "" });

	  class FieldData {
	    string name;
	    int order;
	    function compare;
	    function lcase;
	  };

	  array(FieldData) fields = allocate (sizeof (raw_fields));

	  for (int idx = 0; idx < sizeof (raw_fields); idx++) {
	    string raw_field = raw_fields[idx];
	    FieldData field = fields[idx] = FieldData();
	    int i;

	  field_flag_scan:
	    for (i = 0; i < sizeof (raw_field); i++)
	      switch (raw_field[i]) {
		case '-':
		  if (field->order) break field_flag_scan;
		  field->order = '-';
		  break;
		case '+':
		  if (field->order) break field_flag_scan;
		  field->order = '+';
		  break;
		case '*':
		  if (field->compare) break field_flag_scan;
		  field->compare = strict_compare;
		  break;
		case '^':
		  if (field->lcase) break field_flag_scan;
		  field->lcase = lower_case;
		  break;
		default:
		  break field_flag_scan;
	      }
	    field->name = raw_field[i..];

	    if (!field->compare)
	      field->compare = dwim_compare;
	    if (!field->lcase)
	      field->lcase = lambda(mixed m){return m;};
	  }

	  res = Array.sort_array(
	    res,
	    lambda (mapping(string:mixed) m1,
		    mapping(string:mixed) m2,
		    array(FieldData) fields)
	    {
	      foreach (fields, FieldData field)
	      {
		int tmp;
		switch (field->order) {
		  case '-':
		    tmp = field->compare (field->lcase(m2[field->name]),
					  field->lcase(m1[field->name]),
					  field->name);
		    break;
		  default:
		  case '+':
		    tmp = field->compare (field->lcase(m1[field->name]),
					  field->lcase(m2[field->name]),
					  field->name);
		}

		if (tmp == 1)
		  return 1;
		else if (tmp == -1)
		  return 0;
	      }
	      return 0;
	    },
	    fields);
	}

	if(filter) {

	  // If rowinfo or negative skiprows are used we have
	  // to do filtering in a loop of its own, instead of
	  // doing it during the emit loop.
	  if(args->rowinfo || (args->skiprows && args->skiprows<0)) {
	    for(int i; i<sizeof(res); i++)
	      if(should_filter(res[i], filter)) {
		res = res[..i-1] + res[i+1..];
		i--;
	      }
	    filter = 0;
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
		  if(!should_filter(res[i], filter))
		    skiprows--;
		res = res[i..];
	      }
	    }

	    vars["real-counter"] = 0;
	    do_iterate = array_filter_iterate;
	  }
	}

	// We have to check the filter again, since it
	// could have been zeroed in the last if statement.
	if(!filter) {

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

	id->misc->emit_rows = res;

	return 0;
      }

      parse_error("Wrong return type from emit source plugin.\n");
    }

    int(0..1) do_once_more() {
      if(vars->counter || !args["do-once"]) return 0;
      vars = (["counter":1]);
      return 1;
    }

    function do_iterate;

    int(0..1) object_iterate(RequestID id) {
      int counter = vars->counter;

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if(mappingp(vars=res->get_row())) {
	vars->counter = ++counter;
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) object_filter_iterate(RequestID id) {
      int counter = vars->counter;

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if(args->skiprows && args->skiprows>0)
	while(args->skiprows-->-1)
	  while((vars=res->get_row()) &&
		should_filter(vars, filter));
      else
	while((vars=res->get_row()) &&
	      should_filter(vars, filter));

      if(mappingp(vars)) {
	vars->counter = ++counter;
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) array_iterate(RequestID id) {
      int counter=vars->counter;
      if(counter>=sizeof(res)) return 0;
      vars=res[counter++];
      vars->counter=counter;
      return 1;
    }

    int(0..1) array_filter_iterate(RequestID id) {
      int real_counter = vars["real-counter"];
      int counter = vars->counter;

      if(real_counter>=sizeof(res)) return do_once_more();

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      while(should_filter(res[real_counter++], filter))
	if(real_counter>=sizeof(res)) return do_once_more();

      vars=res[real_counter-1];

      vars["real-counter"] = real_counter;
      vars->counter = counter+1;
      return 1;
    }

    array do_return(RequestID id) {
      result = content;

      id->misc->emit_rows = outer_rows;
      id->misc->emit_filter = outer_filter;
      id->misc->emit_args = outer_args;

      int rounds = vars->counter - !!args["do-once"];
      _ok = !!rounds;

      if(args->remainderinfo) {
	if(args->filter) {
	  int rem;
	  if(arrayp(res)) {
	    foreach(res[vars["real-counter"]+1..], mapping v)
	      if(!should_filter(v, filter))
		rem++;
	  } else {
	    mapping v;
	    while( v=res->get_row() )
	      if(!should_filter(v, filter))
		rem++;
	  }
	  RXML.user_set_var(args->remainderinfo, rem);
	}
	else if( do_iterate == object_iterate )
	  RXML.user_set_var(args->remainderinfo, res->num_rows_left());
      }

      if(objectp(res))
        destruct(res);
      res = 0;
      return 0;
    }

  }
}

class TagComment {
  inherit RXML.Tag;
  constant name = "comment";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  class Frame {
    inherit RXML.Frame;
    int do_iterate;
    array do_enter() {
      do_iterate = -1;
      // Argument existence can be assumed static, so we can set
      // FLAG_MAY_CACHE_RESULT here.
      flags |= RXML.FLAG_MAY_CACHE_RESULT;
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
      // Compatibility kludge: Empty arrays are considered false. This
      // is probably the result of that multiple values are
      // represented by arrays. We don't want to escalate that to
      // other types, though (empty strings are already considered
      // true).
      if (!arrayp (var))
	return !!var;
    }
    else {
      var=source(id, arr[0]);
      if(!arrayp(var))
	return do_check(var, arr, id);
    }

    int(0..1) recurse_check(array var, array arr, RequestID id) {
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

    string trash;
    if(sscanf(var,"%f%s",float f_var,trash)==2 && trash=="" &&
       sscanf(is ,"%f%s",float f_is ,trash)==2 && trash=="") {
      if(arr[1]=="<") return f_var<f_is;
      if(arr[1]==">") return f_var>f_is;
    }
    else {
      if(arr[1]=="<") return (var<is);
      if(arr[1]==">") return (var>is);
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

class TagIfExists {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "exists";

  int eval(string u, RequestID id) {
    CACHE(5);
    return id->conf->is_file(Roxen.fix_relative(u, id), id);
  }
}

class TagIfAccept {
  inherit IfMatch;
  constant plugin_name = "accept";
  array source(RequestID id) {
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

class TagIfCookie {
  inherit IfIs;
  constant plugin_name = "cookie";
  string source(RequestID id, string s) {
    return id->cookies[s];
  }
}

class TagIfClient {
  inherit IfMatch;
  constant plugin_name = "client";
  array source(RequestID id) {
    return id->client;
  }
}

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
  string source(RequestID id) {
    return id->host;
  }
}

class TagIfIP {
  inherit IfMatch;
  constant plugin_name = "ip";
  string source(RequestID id) {
    return id->remoteaddr;
  }
}

class TagIfLanguage {
  inherit IfMatch;
  constant plugin_name = "language";
  array source(RequestID id) {
    return id->misc->pref_languages->get_languages();
  }
}

class TagIfMatch {
  inherit IfIs;
  constant plugin_name = "match";
  string source(RequestID id, string s) {
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
  string source(RequestID id, string s) {
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
  array source(RequestID id) {
    return id->referer;
  }
}

class TagIfSupports {
  inherit IfIs;
  constant plugin_name = "supports";
  string source(RequestID id, string s) {
    if(id->supports[s]) return "";
    return 0;
  }
}

class TagIfVariable {
  inherit IfIs;
  constant plugin_name = "variable";
  constant cache = 1;
  mixed source(RequestID id, string s, void|int check_set_only) {
    mixed var;
    if (zero_type (var=RXML.user_get_var(s))) return 0;
    if(arrayp(var)) return var;
    return check_set_only ? 1 : RXML.t_text->encode (var);
  }
}

class TagIfVaRiAbLe {
  inherit TagIfVariable;
  constant plugin_name = "Variable";
  constant case_sensitive = 1;
}

class TagIfSizeof {
  inherit IfIs;
  constant plugin_name = "sizeof";
  constant cache = -1;
  string source(RequestID id, string s) {
    mixed var;
    if (zero_type (var=RXML.user_get_var(s))) return 0;
    if(stringp(var) || arrayp(var) ||
       multisetp(var) || mappingp(var)) return (string)sizeof(var);
    if(objectp(var) && var->_sizeof) return (string)sizeof(var);
    return (string)sizeof((string)var);
  }
  int(0..1) do_check(string var, array arr, RequestID id) {
    if(sizeof(arr)>2 && !var) var = "0";
    return ::do_check(var, arr, id);
  }
}

class TagIfClientvar {
  inherit IfIs;
  constant plugin_name = "clientvar";
  string source(RequestID id, string s) {
    return id->client_var[s];
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

class TagIfExpr {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "expr";
  int eval(string u) {
    int|float|string res = sexpr_eval(u);
    return res && res != 0.0;
  }
}

// --------------------- Emit plugins -------------------

class TagEmitValues {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="values";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    if(m["from-scope"]) {
      m->values=([]);
      RXML.Context context=RXML_CONTEXT;
      map(context->list_var(m["from-scope"]),
	  lambda(string var){ m->values[var]=context->get_var(var, m["from-scope"]);
	  return ""; });
    }

    if( m->variable )
      m->values = RXML_CONTEXT->user_get_var( m->variable );

    if(!m->values)
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
         { array out=({});
           int i=0;
	   string values=m->values;
#define GETCHAR()	(si->next(),si->value())
           array(string) words=({});
           int c,leadspace=1,inquotes=0;
           string word="";
           String.Iterator si=get_iterator(values);
           for(c=si->value();si;)
            { switch(c)
               { case ',':
                    if(!inquotes)
                     { words+=({word});word="";leadspace=1;
                       break;
                     }
                    word+=sprintf("%c",c);
                    break;
                 case '"':leadspace=0;
                    if(!inquotes)
                       inquotes=1;
                    else if((c=GETCHAR())=='"')
                       word+=sprintf("%c",c);
                    else
                     { inquotes=0;
                       continue;
                     }
                    break;
                 default:leadspace=0;
                 case ' ':case '\t':
                    if(!leadspace)
                       word+=sprintf("%c",c);
                    break;
                 case -1:case '\r':case '\x1a':
                    break;
                 case '\n':
                    if(!inquotes)
                     { if(!sizeof(words)&&word=="")
                          break;
                       out+=({words+({word})});
		       word="";words=({});
		       break;
                     }
                    word+=sprintf("%c",c);
               }
              c=GETCHAR();
            }
           m->values=!sizeof(out)&&word==""?"":out+({words+({word})});
	   break;
         }
	}
      }
      if(stringp(m->values))
	m->values=m->values / (m->split || "\000");
    }

    if(mappingp(m->values))
      return map( indices(m->values),
		  lambda(mixed ind) {
		    mixed val = m->values[ind];
		    if(m->trimwhites) val=String.trim_all_whites((string)val);
		    if(m->case=="upper") val=upper_case(val);
		    else if(m->case=="lower") val=lower_case(val);
		    return (["index":ind,"value":val]);
		  });

    if(arrayp(m->values))
      return map( m->values,
		  lambda(mixed val) {
		    if(m->trimwhites) val=String.trim_all_whites((string)val);
		    if(m->case=="upper") val=upper_case(val);
		    else if(m->case=="lower") val=lower_case(val);
		    return (["value":val]);
		  } );

    if(multisetp(m->values))
      return map( m->values,
		  lambda(mixed val) {
		    if(m->trimwhites) val=String.trim_all_whites((string)val);
		    if(m->case=="upper") val=upper_case(val);
		    else if(m->case=="lower") val=lower_case(val);
		    return (["index":val]);
		  } );

    RXML.run_error("Values variable has wrong type %t.\n", m->values);
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
      p = p[..sizeof(p)-2];
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

// --------------------- Documentation -----------------------

mapping tagdocumentation() {
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  mapping doc=compile_string("#define manual\n"+file->read())->tagdoc;
  file->close();
  if(!file->open("data/supports","r")) return doc;

  Parser.HTML()->
    add_container("flags", format_support)->
    add_container("vars", format_support)->
    set_extra(doc)->
    finish(file->read())->read();

  return doc;
}

static int format_support(Parser.HTML p, mapping m, string c, mapping doc) {
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

#ifdef manual
constant tagdoc=([
"&system;":#"<desc type='scope'><p><short>
 This scope contains information specific to this ChiliMoon server.</short>
 It is not possible to write any information to this scope.
</p></desc>",

"&server.domain;":#"<desc type='entity'><p>
 The domain name of this site. The information is taken from the
 client request, so a request to \"http://www.chilimoon.org/\" would
 give this entity the value \"www.chilimoon.org\", while a request
 for \"http://www/\" would give the entity value \"www\".
</p></desc>",

"&server.hits;":#"<desc type='entity'><p>
 The number of hits, i.e. requests the webserver has accumulated since
 it was last started.
</p></desc>",

"&server.hits-per-minute;":#"<desc type='entity'><p>
 The average number of requests per minute since the webserver last
 started.
</p></desc>",

"&server.pike-version;":#"<desc type='entity'><p>
 The version of Pike the webserver is using, e.g. \"Pike v7.2 release 140\".
</p></desc>",

"&server.sent;":#"<desc type='entity'><p>
 The total amount of data the webserver has sent since it last started.
</p></desc>",

"&server.sent-kbit-per-second;":#"<desc type='entity'><p>
 The average amount of data the webserver has sent, in Kibibits.
</p></desc>",

"&server.sent-mb;":#"<desc type='entity'><p>
 The total amount of data the webserver has sent, in Mebibits.
</p></desc>",

"&server.sent-per-minute;":#"<desc type='entity'><p>
 The average number of bytes that the webserver sends during a
 minute. Based on the sent amount of data and uptime since last server start.
</p></desc>",

"&server.server;":#"<desc type='entity'><p>
 The URL of the webserver. The information is taken from the client request,
 so a request to \"http://www.chilimoon.org/index.html\" would give this
 entity the value \"http://www.chilimoon.org/\", while a request for
 \"http://www/index.html\" would give the entity the value
 \"http://www/\".
</p></desc>",

"&server.ssl-strength;":#"<desc type='entity'><p>
 Contains the maximum number of bits encryption strength that the SSL is capable of.
 Note that this is the server side capability, not the client capability.
 Possible values are 0, 40, 128 or 168.
</p></desc>",

"&server.time;":#"<desc type='entity'><p>
 The current posix time. An example output: \"244742740\".
</p></desc>",

"&server.unique-id;":#"<desc type='entity'><p>
 Returns a unique id that can be used for e.g. session
 identification. An example output: \"7fcda35e1f9c3f7092db331780db9392\".
 Note that a new id will be generated every time this entity is used,
 so you need to store the value in another variable if you are going
 to use it more than once.
</p></desc>",

"&server.uptime;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in seconds.
</p></desc>",

"&server.uptime-days;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in days.
</p></desc>",

"&server.uptime-hours;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in hours.
</p></desc>",

"&server.uptime-minutes;":#"<desc type='entity'><p>
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
 languages, according to the accept-language header. An example output: \"en, sv\".
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
 specification. An example output: \"en, sv\".
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

//  &page.virtfile; is same as &page.path; but deprecated.

"&page.path;":#"<desc type='entity'><p>
 Absolute path to this file in the virtual filesystem. E.g. with the
 URL \"http://www.roxen.com/partners/../products/index.xml\", as well
 as \"http://www.roxen.com/products/index.xml\", the value will be
 \"/products/index.xml\", given that the virtual filsystem was mounted
 on \"/\".
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
 \"http://www.chilimoon.org/articles/index.html\", then the
 value of this entity is \"index.html\".
</p></desc>",

"&page.dir;":#"<desc type='entity'><p>
 The name of the directory in the virtual filesystem where the file resides,
 as derived from the URL. If the URL is
 \"http://www.chilimoon.org/articles/index.html\", then the
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

"&var;":#"<desc type='scope'><p><short>
 General variable scope.</short> This scope is always empty when the
 page parsing begins and is therefore suitable to use as storage for
 all variables used during parsing.
</p></desc>",

//----------------------------------------------------------------------

"roxen-automatic-charset-variable":#"<desc type='tag'><p>
 If put inside a form, the right character encoding of the submitted
 form can be guessed by ChiliMoon. The tag will insert another
 tag that forces the client to submit the string \"едц\". Since the
 WebServer knows the name and the content of the form variable it can
 select the proper character decoder for the requests variables.
</p>

<ex-box><form>
  <roxen-automatic-charset-variable/>
  Name: <input name='name'/><br />
  Mail: <input name='mail'/><br />
  <input type='submit'/>
</form></ex-box>
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

"append":#"<desc type='both'><p><short>
 Appends a value to a variable. The variable attribute and one more is
 required.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable.</p>
</attr>

<attr name='value' value='string'>
 <p>The value the variable should have appended.</p>

 <ex>
 <set variable='var.cm' value='Chili'/>
 <append variable='var.cm' value='Moon'/>
 &var.ris;
 </ex>
</attr>

<attr name='from' value='string'>
 <p>The name of another variable that the value should be copied
 from.</p>
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

"catch":#"<desc type='cont'><p><short>
 Evaluates the RXML code, and, if nothing goes wrong, returns the
 parsed contents.</short> If something does go wrong, the error
 message is returned instead. See also <xref
 href='throw.tag' />.
</p>
</desc>",

//----------------------------------------------------------------------

"date":#"<desc type='tag'><p><short>
 Inserts the time and date.</short> Does not require attributes.
</p>

<ex><date/></ex>
</desc>

<attr name='unix-time' value='number of seconds'>
 <p>Display this time instead of the current. This attribute uses the
 specified Unix 'time_t' time as the starting time (which is
 <i>01:00, January the 1st, 1970</i>), instead of the current time.
 This is mostly useful when the <tag>date</tag> tag is used from a
 Pike-script or ChiliMoon module.</p>

<ex><date unix-time='120'/></ex>
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

<attr name='type' value='discordian|http|iso|number|ordered|stardate|string|unix'>
 <p>Defines in which format the date should be displayed in. 'http' is
 the format specified for use in the HTTP protocol (useful for headers
 etc). Discordian and stardate only make a difference when not using
 part. Note that type='stardate' has a separate companion attribute,
 prec, which sets the precision.</p>

<xtable>
<row><c><p><i>type=discordian</i></p></c><c><ex><date date='' type='discordian'/> </ex></c></row>
<row><c><p><i>type=http</i></p></c><c><ex><date date='' type='http'/> </ex></c></row>
<row><c><p><i>type=iso</i></p></c><c><ex><date date='' type='iso'/></ex></c></row>
<row><c><p><i>type=number</i></p></c><c><ex><date date='' type='number'/></ex></c></row>
<row><c><p><i>type=ordered</i></p></c><c><ex><date date='' type='ordered'/></ex></c></row>
<row><c><p><i>type=stardate</i></p></c><c><ex><date date='' type='stardate'/></ex></c></row>
<row><c><p><i>type=string</i></p></c><c><ex><date date='' type='string'/></ex></c></row>
<row><c><p><i>type=unix</i></p></c><c><ex><date date='' type='unix'/></ex></c></row>
</xtable>
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
 <row><c><p>%r</p></c><c><p>Time in 12 hour clock format with %p</p></c></row>
 <row><c><p>%R</p></c><c><p>Time as \"%H:%M\"</p></c></row>
 <row><c><p>%S</p></c><c><p>Seconds (0-61), zero padded to two characters.</p></c></row>
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

"dec":#"<desc type='tag'><p><short>
 Subtracts 1 from a variable.</short>
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
{table}
 {tr}
    {td} First cell {/td}
    {td} Second cell {/td}
 {/tr}
{/table}
</doc></ex>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the pre element.</p>
</attr>",

//----------------------------------------------------------------------

"for":#"<desc type='cont'><p><short>
 Makes it possible to create loops in RXML.</short>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag).</p></note>
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

"header":#"<desc type='tag'><p><short>
 Adds a HTTP header to the page sent back to the client.</short> For
 more information about HTTP headers please steer your browser to
 chapter 14, 'Header field definitions' in <a href='http://community.roxen.com/developers/idocs/rfc/rfc2616.html'>RFC 2616</a>, available at Roxen Community.
</p></desc>

<attr name='name' value='string'>
 <p>The name of the header.</p>
</attr>

<attr name='value' value='string'>
 <p>The value of the header.</p>
</attr>",

//----------------------------------------------------------------------

"imgs":#"<desc type='tag'><p><short>
 Generates a image tag with the correct dimensions in the width and height
 attributes. These dimensions are read from the image itself, so the image
 must exist when the tag is generated. The image must also be in GIF, JPEG/JFIF
 or PNG format.</short>
</p></desc>

<attr name='src' value='string' required='required'>
 <p>The path to the file that should be shown.</p>
</attr>

<attr name='alt' value='string'>
 <p>Description of the image. If no description is provided, the filename
 (capitalized, without extension and with some characters replaced) will
 be used.</p>
 </attr>

 <p>All other attributes will be inherited by the generated img tag.</p>",

//----------------------------------------------------------------------

"inc":#"<desc type='tag'><p><short>
 Adds 1 to a variable.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The variable to be incremented.</p>
</attr>

<attr name='value' value='number' default='1'>
 <p>The value to be added.</p>
</attr>",

//----------------------------------------------------------------------

"sscanf":#"<desc type='cont'><p><short>
 Extract parts of a string and put them in other variables.</short> Refer to
 the sscanf function in the Pike reference manual for a complete
 description.</p>
</desc>

<attr name='variables' value='list' required='required'><p>
 A comma separated list with the name of the variables that should be set.</p>
<ex>
<sscanf variables='form.year,var.month,var.day'
format='%4d%2d%2d'>19771003</sscanf>
&form.year;-&var.month;-&var.day;
</ex>
</attr>

<attr name='scope' value='name' required='required'><p>
 The name of the fallback scope to be used when no scope is given.</p>
<ex>
<sscanf variables='year,month,day' scope='var'
 format='%4d%2d%2d'>19801228</sscanf>
&var.year;-&var.month;-&var.day;<br />
<sscanf variables='form.year,var.month,var.day'
 format='%4d%2d%2d'>19801228</sscanf>
&form.year;-&var.month;-&var.day;
</ex>
</attr>

<attr name='return' value='name'><p>
 If used, the number of successfull variable 'extractions' will be
 available in the given variable.</p>
</attr>",

//----------------------------------------------------------------------

  "sprintf":#"<desc type='cont'><p><short>
 Prints out variables with the formating functions availble in the
 Pike function sprintf.</short> Refer to the Pike reference manual for
 a complete description.</p></desc>

<attr name='format' value='string'><p>
  The formatting string.</p>
</attr>

<attr name='split' value='charater'><p>
  If used, the tag content will be splitted with the given string.</p>
<ex>
<sprintf format='#%02x%02x%02x' split=','>250,0,33</sprintf>
</ex>
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

<attr name='language' value='string'>
  <p>Optionally add this language at the top of the list of
     preferred languages.</p>
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

<attr name='add' value='string'>
 <p>The prestate or prestates that should be added, in a comma separated
 list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The prestate or prestates that should be dropped, in a comma separated
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
 just for the convinience of refering to the scope as \"_\".</p>
</attr>

<attr name='scope' value='name' default='form'>
 <p>The name of the new scope, besides \"_\".</p>
</attr>",

//----------------------------------------------------------------------

"set":#"<desc type='both'><p><short>
 Sets a variable in any scope that isn't read-only.</short>
</p>
<ex-box><set variable='var.language'>Pike</set></ex-box>
</desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable.</p>
<ex-box><set variable='var.foo' value='bar'/></ex-box>
</attr>

<attr name='value' value='string'>
 <p>The value the variable should have.</p>
</attr>

<attr name='expr' value='string'>
 <p>An expression whose evaluated value the variable should have.</p>

 <p>Available arithmetic operators are +, -, *, / and % (modulo).
 Available relational operators are &lt;, &gt;, ==, !=, &lt;= and
 &gt;=. Available bitwise operators are &amp;, | and ^, representing
 AND, OR and XOR. Available boolean operators are &amp;&amp; and ||,
 working as the pike AND and OR. Subexpressions can be surrounded by (
 and ).</p>

 <p>The size of a string or array may be retrieved with
 sizeof(var.something).</p>

 <p>Numbers can be represented as decimal integers when numbers
 are written out as normal, e.g. \"42\". Numbers can also be written
 as hexadecimal numbers when precedeed with \"0x\", as octal numbers
 when precedeed with \"0\" and as binary number when precedeed with
 \"0b\". Numbers can also be represented as floating point numbers,
 e.g. \"1.45\" or \"1.6E5\". Numbers can be converted between floats
 and integers by using the cast operators \"(float)\" and \"(int)\".</p>

 <ex-box>(int)3.14</ex-box>

 <p>RXML variables may be referenced with the syntax \"scope.name\".
 Note that they are not written as entity references (i.e. without the
 surrounding &amp; and ;). If they are written that way then their
 values will be substituted into the expression before it is parsed,
 which can lead to strange parsing effects.</p>

 <p>A common problem when dealing with variables from forms is that a
 variable might be empty or a non-numeric string. To ensure that a
 value is produced the special functions INT and FLOAT may be used. In
 the expression \"INT(form.num)+1\" the INT-function will produce some
 integer regardless what the form variable contains, thereby
 preventing errors in the expression.</p>
</attr>

<attr name='from' value='string'>
 <p>The name of another variable that the value should be copied from.</p>
</attr>

<attr name='split' value='string'>
 <p>The value will be splitted by this string into an array.</p>

 <p>If none of the above attributes are specified, the variable is unset.
 If debug is currently on, more specific debug information is provided
 if the operation failed. See also: <xref href='append.tag' /> and <xref href='../programming/debug.tag' />.</p>
</attr> ",

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
",

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

"if#expr":#"<desc type='plugin'><p><short>
  This plugin evaluates an expression and returns true if the result is
  anything but an integer or floating point zero.</short></p>
</desc>

<attr name='expr' value='expression'>
  <p>The expression to test. See the expr attribute to <xref href='set.tag'/>
  for a description of the syntax.</p>
</attr>",

//----------------------------------------------------------------------

"case":#"<desc type='cont'><p><short>
 Alters the case of the contents.</short>
</p></desc>

<attr name='case' value='upper|lower|capitalize' required='required'><p>
 Changes all characters to upper or lower case letters, or
 capitalizes the first letter in the content.</p>

<ex><case case='upper'>upper</case></ex>
<ex><case case='lower'>lower</case></ex>
<ex><case case='capitalize'>capitalize</case></ex>
</attr>",

//----------------------------------------------------------------------

"cond":({ #"<desc type='cont'><p><short>
 This tag makes a boolean test on a specified list of cases.</short>
 This tag is almost eqvivalent to the <xref href='../if/if.tag'
 />/<xref href='../if/else.tag' /> combination. The main difference is
 that the <tag>default</tag> tag may be put whereever you want it
 within the <tag>cond</tag> tag. This will of course affect the order
 the content is parsed. The <tag>case</tag> tag is required.</p>
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
</desc>",

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

"help":#"<desc type='tag'><p><short>
 Gives help texts for tags.</short> If given no arguments, it will
 list all available tags. By inserting <tag>help/</tag> in a page, a
 full index of the tags available in that particular ChiliMoon
 will be presented. If a particular tag is missing from that index, it
 is not available at that moment. Since all tags are available through
 modules, that particular tag's module hasn't been added to the
 ChiliMoon yet. Ask an administrator to add the module.
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
 mandatory to add a plugin as one attribute. The other attributes
 provided are and, or and not, used for combining different plugins
 with logical operations.</p>

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
 categories: Eval, Match, State and Utils.</p>

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
 are \"=\", \"==\", \"is\", \"!=\", \"&lt;\" and \"&gt;\".</p>

 <ex><set variable='var.x' value='6'/>
<if variable='var.x > 5'>More than one hand</if></ex>

 <p>The three operators \"=\", \"==\" and \"is\" all test for
 equality. They can furthermore do pattern matching with the right
 operand. If it doesn't match the left one directly then it's
 interpreted as a glob pattern with \"*\" and \"?\". If it still
 doesn't match then it's splitted on \",\" and each part is tried as a
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

"if#defined":#"<desc type='plugin'><p><short>
 Tests if a certain RXML define is defined by use of the <xref
 href='../variable/define.tag' /> tag, and in that case tests its
 value.</short> This is an <i>Eval</i> plugin. </p>
</desc>

<attr name='defined' value='define' required='required'><p>
 Choose what define to test.</p>
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

"if#exists":#"<desc type='plugin'><p><short>
 Returns true if the named page is viewable.</short> A nonviewable page
 is e.g. a file that matches the internal files patterns in the filesystem module.
 If the path does not begin with /, it is assumed to be a URL relative to the directory
 containing the page with the <tag>if</tag>-statement. 'Magic' files like /$/unit
 will evaluate as true. This is a <i>State</i> plugin.</p>
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
 'Magic' files like /$/unit will evaluate as true.
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
 <xref href='../../tutorial/if_tags/plugins.xml'>If tags
 tutorial</xref>. Match is an <i>Eval</i> plugin.</p></desc>

<attr name='match' value='pattern' required='required'><p>
 Choose what pattern to test. The pattern could be any expression.
 Note!: The pattern content is treated as strings:</p>

<ex>
 <set variable='var.hepp' value='10' />

 <if match='var.hepp is 10'>
  true
 </if>
 <else>
  false
 </else>
</ex>

 <p>This example shows how the plugin treats \"var.hepp\" and \"10\"
 as strings. Hence when evaluating a variable as part of the pattern,
 the entity associated with the variable should be used, i.e.
 <ent>var.hepp</ent> instead of var.hepp. A correct example would be:</p>

<ex>
<set variable='var.hepp' value='10' />

 <if match='&var.hepp; is 10'>
  true
 </if>
 <else>
  false
 </else>
</ex>

 <p>Here, &var.hepp; is treated as an entity and parsed
 correctly, letting the plugin test the contents of the entity.</p>
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

"if#variable":#"<desc type='plugin'><p><short>
 Does the variable exist and, optionally, does its content match the
 pattern?</short> This is an <i>Eval</i> plugin.
</p></desc>

<attr name='variable' value='name[ operator pattern]' required='required'><p>
 Choose variable to test. Valid operators are '=', '==', 'is', '!=',
 '&lt;' and '&gt;'.</p>
</attr>",

//----------------------------------------------------------------------

"if#Variable":#"<desc type='plugin'><p><short>
 Case sensitive version of the <tag>if variable</tag> plugin.</short></p>
</desc>",

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

"elements": #"<desc type='tag'><p><short>
 Returns the number of elements in a variable.</short> If the variable
 isn't of a type which contains several elements (includes strings), 1
 is returned. That makes it consistent with variable indexing, e.g.
 var.foo.1 takes the first element in var.foo if it's an array, and if
 it isn't then it's the same as var.foo.</p></desc>

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

"true":#"<desc type='tag'><p><short>
 An internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag'
 /> tag will not show its contents. It can be useful if you are
 writing your own <xref href='if.tag' /> lookalike tag.</p>
</desc>",

//----------------------------------------------------------------------

"eval":#"<desc type='cont'><p><short>
 Postparses its content.</short> Useful when an entity contains
 RXML-code. <tag>eval</tag> is then placed around the entity to get
 its content parsed.</p>
</desc>",

//----------------------------------------------------------------------

"emit#values":({ #"<desc type='plugin'><p><short>
 Splits the string provided in the values attribute and outputs the
 parts in a loop.</short> The value in the values attribute may also
 be an array or mapping.
</p></desc>

<attr name='values' value='string, mapping or array'><p>
 An array, mapping or a string to be splitted into an array. This
 attribute is required unless the variable attribute is used.</p>
</attr>

<attr name='variable' value='name'><p>Name of a variable from which the
 values are taken.</p>
</attr>

<attr name='split' value='string' default='NULL'><p>
 The string the values string is splitted with. Supplying an empty string
 results in the string being split between every single character.</p>
</attr>

<attr name='advanced' value='lines|words|chars'><p>
 If the input is a string it can be splitted into separate lines, words
 or characters by using this attribute.</p>
</attr>

<attr name='case' value='upper|lower'><p>
 Changes the case of the value.</p>
</attr>

<attr name='trimwhites'><p>
 Trims away all leading and trailing white space charachters from the
 values.</p>
</attr>

<attr name='from-scope' value='name'>
 <p>Create a mapping out of a scope and give it as input to the emit.</p>
</attr>
",

([
"&_.value;":#"<desc type='entity'><p>
 The value of one part of the splitted string</p>
</desc>",

"&_.index;":#"<desc type='entity'><p>
 The index of this mapping entry, if input was a mapping</p>
</desc>"
])
	      }),

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
</attr>",

	  ([

"&_.counter;":#"<desc type='entity'><p>
 Gives the current number of loops inside the <tag>emit</tag> tag.
</p>
</desc>"

	  ])
       }),

//----------------------------------------------------------------------

"if#config":#"<desc type='plugin'><p><short>
 Has the config been set by use of the <xref href='../protocol/aconf.tag'
 /> tag?</short> This is a <i>State</i> plugin.</p>
</desc>

<attr name='config' value='name' required='required'>
</attr>",

//----------------------------------------------------------------------

    ]);
#endif
