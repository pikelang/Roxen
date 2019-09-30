// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.
//

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant language = roxen->language;

#include <module.h>
#include <config.h>
#include <request_trace.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG | MODULE_PROVIDER;
constant module_name = "Tags: RXML 2 tags";
constant module_doc  = "This module provides the common RXML tags.";

void start()
{
  add_api_function("query_modified", api_query_modified, ({ "string" }));
  query_tag_set()->prepare_context=set_entities;
}

string query_provides() {
  return "modified";
}

private constant permitted = "123456789.xabcdefint\"XABCDEFlo<>=0-*+/%&|()^"/1;

string sexpr_eval(string what)
{
  array q = what/"";
  // Make sure we hide any dangerous global symbols
  // that only contain permitted characters.
  // FIXME: This should probably be even more paranoid.
  what =
    "constant allocate = 0;"
    "constant atexit = 0;"
    "constant cd = 0;"
    "constant clone = 0;"
    "constant exece = 0;"
    "constant exit = 0;"
    "mixed foo_(){ return "+(q-(q-permitted))*""+";}";
  return (string)compile_string( what )()->foo_();
}

#if ROXEN_COMPAT <= 1.3
private RoxenModule rxml_warning_cache;
private void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=id->conf->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}
#endif


// ----------------- Entities ----------------------

class EntityClientTM {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(c->id->supports->trade) return ENCODE_RXML_XML("&trade;", type);
    if(c->id->supports->supsub) return ENCODE_RXML_XML("<sup>TM</sup>", type);
    return ENCODE_RXML_XML("&lt;TM&gt;", type);
  }
}

class EntityClientReferrer {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    array referrer=c->id->referer;
    return referrer && sizeof(referrer)?ENCODE_RXML_TEXT(referrer[0], type):RXML.nil;
  }
}

class EntityClientName {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    array client=c->id->client;
    return client && sizeof(client)?ENCODE_RXML_TEXT(client[0], type):RXML.nil;
  }
}

class EntityClientIP {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    return ENCODE_RXML_TEXT(c->id->remoteaddr, type);
  }
}

class EntityClientAcceptLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return RXML.nil;
    return ENCODE_RXML_TEXT(c->id->misc["accept-language"][0], type);
  }
}

class EntityClientAcceptLanguages {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return RXML.nil;
    // FIXME: Should this be an array instead?
    return ENCODE_RXML_TEXT(c->id->misc["accept-language"]*", ", type);
  }
}

class EntityClientLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return RXML.nil;
    return ENCODE_RXML_TEXT(c->id->misc->pref_languages->get_language(), type);
  }
}

class EntityClientLanguages {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return RXML.nil;
    // FIXME: Should this be an array instead?
    return ENCODE_RXML_TEXT(c->id->misc->pref_languages->get_languages()*", ", type);
  }
}

class EntityClientHost {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(c->id->host) return ENCODE_RXML_TEXT(c->id->host, type);
    return ENCODE_RXML_TEXT(c->id->host=roxen->quick_ip_to_host(c->id->remoteaddr),
			    type);
  }
}

class EntityClientAuthenticated {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var,
			string scope_name, void|RXML.Type type) {
    // Actually, it is cacheable, but _only_ if there is no authentication.
    c->id->misc->cacheable=0;
    return ENCODE_RXML_INT(!!c->id->conf->authenticate( c->id ), type );
  }
}

class EntityClientUser {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var,
			string scope_name, void|RXML.Type type) {
    User u = c->id->conf->authenticate( c->id );
    c->id->misc->cacheable=0;
    if(!u) return RXML.nil;
    return ENCODE_RXML_TEXT(u->name(), type);
  }
}

class EntityClientPassword {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var,
			string scope_name, void|RXML.Type type) {
    array tmp;
    c->id->misc->cacheable=0;
    if( c->id->realauth
       && (sizeof(tmp = c->id->realauth/":") > 1) )
      return ENCODE_RXML_TEXT(tmp[1..]*":", type);
    return RXML.nil;
  }
}

mapping client_scope=([
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
  c->extend_scope("client", client_scope);
}


// ------------------- Tags ------------------------

class TagRoxenACV {
  inherit RXML.Tag;
  constant name = "roxen-automatic-charset-variable";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    constant magic=
      "<input type=\"hidden\" name=\"magic_roxen_automatic_charset_variable\" value=\"åäö\" />";

    array do_return(RequestID id) {
      result=magic;
    }
  }
}

class TagAppend {
  inherit RXML.Tag;
  constant name = "append";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "variable" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      mixed value=RXML.user_get_var(args->variable, args->scope);
      if (args->value) {
	// Append a value to an entity variable.
	if (value)
	  value+=args->value;
	else
	  value=args->value;
	RXML.user_set_var(args->variable, value, args->scope);
	return 0;
      }
      if (args->from) {
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
      parse_error("No value specified.\n");
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
      mapping hdrs = Roxen.http_auth_required (args->realm, args->message);
      if (hdrs->error) _error = hdrs->error;
      if (hdrs->extra_heads)
	_extra_heads += hdrs->extra_heads;
      // We do not need this as long as hdrs only contains strings and numbers
      //   foreach(indices(hdrs->extra_heads), string tmp)
      //      Roxen.add_http_header(_extra_heads, tmp, hdrs->extra_heads[tmp]);
      if (hdrs->text) _rettext = hdrs->text;
      return 0;
    }
  }
}

class TagExpireTime {
  inherit RXML.Tag;
  constant name = "expire-time";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t,t2;
      t=t2=time(1);
      if(!args->now) {
	t+=Roxen.time_dequantifier(args);
	CACHE(max(t-t2,0));
      }
      if(t==t2) {
	NOCACHE();
	Roxen.add_http_header(_extra_heads, "Pragma", "no-cache");
	Roxen.add_http_header(_extra_heads, "Cache-Control", "no-cache");
      }

      Roxen.add_http_header(_extra_heads, "Expires", Roxen.http_date(t));
      return 0;
    }
  }
}

class TagHeader {
  inherit RXML.Tag;
  constant name = "header";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

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

      if(!(args->value && args->name))
	RXML.parse_error("Requires both a name and a value.\n");

      Roxen.add_http_header(_extra_heads, args->name, args->value);
      return 0;
    }
  }
}

class TagRedirect {
  inherit RXML.Tag;
  constant name = "redirect";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if ( !args->to )
	RXML.parse_error("Requires attribute \"to\".\n");

      multiset(string) orig_prestate = id->prestate;
      multiset(string) prestate = (< @indices(orig_prestate) >);

      if(args->add)
	foreach((m_delete(args,"add") - " ")/",", string s)
	  prestate[s]=1;

      if(args->drop)
	foreach((m_delete(args,"drop") - " ")/",", string s)
	  prestate[s]=0;

      id->prestate = prestate;
      mapping r = Roxen.http_redirect(args->to, id);
      id->prestate = orig_prestate;

      if (r->error)
	_error = r->error;
      if (r->extra_heads)
	_extra_heads += r->extra_heads;
      // We do not need this as long as r only contains strings and numbers
      //    foreach(indices(r->extra_heads), string tmp)
      //      Roxen.add_http_header(_extra_heads, tmp, r->extra_heads[tmp]);
      if (args->text)
	_rettext = args->text;

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
	parse_error("Variable nor scope not specified.\n");
      if(!args->variable && args->scope!="roxen") {
	RXML.get_context()->add_scope(args->scope, ([]) );
	return 0;
      }
      RXML.get_context()->user_delete_var(args->variable, args->scope);
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

  class Frame {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (args->type) content_type = args->type (RXML.PXml);
    }

    array do_return(RequestID id) {
      if (args->value) content = args->value;
      else {
	if (args->expr) {
	  // Set an entity variable to an evaluated expression.
	  mixed val;
	  if(catch(val=sexpr_eval(args->expr)))
	    parse_error("Error in expr attribute.\n");
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
      if(args->split && stringp(content))
	RXML.user_set_var(args->variable, content/args->split, args->scope);
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
      RXML.Context ctx = RXML.get_context();
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
  RXML.Context context=RXML.get_context();
  array entity=context->parse_user_var(m->variable, m->scope);
  if(!context->exist_scope(entity[0])) RXML.parse_error("Scope "+entity[0]+" does not exist.\n");
  context->user_set_var(m->variable, (int)context->user_get_var(m->variable, m->scope)+val, m->scope);
}

class TagImgs {
  inherit RXML.Tag;
  constant name = "imgs";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->src) {
	string|object file=id->conf->real_file(Roxen.fix_relative(args->src, id), id);
	if(!file) {
	  file=id->conf->try_get_file(args->src,id);
	  if(file)
	    file=class {
	      int p=0;
	      string d;
	      void create(string data) { d=data; }
	      int tell() { return p; }
	      int seek(int pos) {
		if(abs(pos)>sizeof(d)) return -1;
		if(pos<0) pos=sizeof(d)+pos;
		p=pos;
		return p;
	      }
	      string read(int bytes) {
		p+=bytes;
		return d[p-bytes..p-1];
	      }
	    }(file);
	}

	if(file) {
	  array(int) xysize;
	  if(xysize=Dims.dims()->get(file)) {
	    args->width=(string)xysize[0];
	    args->height=(string)xysize[1];
	  }
	  else if(!args->quiet)
	    RXML.run_error("Dimensions quering failed.\n");
	}
	else if(!args->quiet)
	  RXML.run_error("Virtual path failed.\n");

	if(!args->alt) {
	  string src=(args->src/"/")[-1];
	  sscanf(src, "internal-roxen-%s", src);
	  args->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src), ".")-2], "_"," "));
	}

	int xml=!m_delete(args, "noxml");

	result = Roxen.make_tag("img", args, xml);
	return 0;
      }
      RXML.parse_error("No src given.\n");
    }
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
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if (args->showid) {
	array path=lower_case(args->showid)/"->";
	if(path[0]!="id" || sizeof(path)==1) RXML.parse_error("Can only show parts of the id object.");
	mixed obj=id;
	foreach(path[1..], string tmp) {
	  if(search(indices(obj),tmp)==-1) RXML.run_error("Could only reach "+tmp+".");
	  obj=obj[tmp];
	}
	result = "<pre>"+Roxen.html_encode_string(sprintf("%O",obj))+"</pre>";
	return 0;
      }
      if (args->werror) {
	report_debug("%^s%#-1s\n",
		     "<debug>: ",
		     id->conf->query_name()+":"+id->not_query+"\n"+
		     replace(args->werror,"\\n","\n") );
      }
      if (args->off)
	id->misc->debug = 0;
      else if (args->toggle)
	id->misc->debug = !id->misc->debug;
      else
	id->misc->debug = 1;
      result = "<!-- Debug is "+(id->misc->debug?"enabled":"disabled")+" -->";
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
	  result = Roxen.sizetostring(s[1]);
	  return 0;
	}
      };
      if(string s=id->conf->try_get_file(Roxen.fix_relative(args->file, id), id) ) {
	result = Roxen.sizetostring(strlen(s));
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
      int t=(int)args["unix-time"] || time(1);
      if(args->timezone=="GMT") t += localtime(t)->timezone;
      t+=Roxen.time_dequantifier(args);

      if(!(args->brief || args->time || args->date))
	args->full=1;

      if(args->part=="second" || args->part=="beat" || args->strftime)
	NOCACHE();
      else
	CACHE(60);

      result = Roxen.tagtime(t, args, id, language);
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

class TagInsertVariable {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variable";

  string get_data(string var, mapping args, RequestID id) {
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
    return (string)RXML.user_get_var(var, args->scope);
  }
}

class TagInsertVariables {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variables";

  string get_data(string var, mapping args) {
    RXML.Context context=RXML.get_context();
    if(var=="full")
      return map(sort(context->list_var(args->scope)),
		 lambda(string s) {
		   return sprintf("%s=%O", s, context->get_var(s, args->scope) );
		 } ) * "\n";
    return String.implode_nicely(sort(context->list_var(args->scope)));
  }
}

class TagInsertScopes {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "scopes";

  string get_data(string var, mapping args) {
    RXML.Context context=RXML.get_context();
    if(var=="full") {
      string result = "";
      foreach(sort(context->list_scopes()), string scope) {
	result += scope+"\n";
	result += Roxen.html_encode_string(map(sort(context->list_var(args->scope)),
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
    
    result=id->conf->try_get_file(var, id);

    if( !result )
      RXML.run_error("No such file ("+Roxen.fix_relative( var, id )+").\n");

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

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if(args->code)
	_error = (int)args->code;
      if(args->text)
	_rettext = replace(args->text, "\n\r"/1, "%0A%0D"/3);
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
  mapping(string:RXML.Type) opt_arg_types = ([ "value" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
//    really... is this error a good idea?  I don't think so, it makes
//    it harder to make pages that use cookies. But I'll let it be for now.
//       /Per

      if(!id->cookies[args->name])
        RXML.run_error("That cookie does not exist.\n");
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
  {
    // FIXME: The auth module should probably not be used in this case.
    if(!id->conf->auth_module)
      RXML.run_error("Modified by requires a user database.\n");
    // FIXME: The next row is defunct. last_modified_by does not exist.
    m->name = id->conf->last_modified_by(file, id);
    CACHE(10);
    return tag_user(tag, m, id);
  }

  if(m->file)
    m->realfile = id->conf->real_file(Roxen.fix_relative( m_delete(m, "file"), id), id);

  if(m->by && m->realfile)
  {
    if(!id->conf->auth_module)
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
    if(m->ssi)
      return Roxen.strftime(id->misc->ssi_timefmt || "%c", s[3]);
    return Roxen.tagtime(s[3], m, id, language);
  }

  if(m->ssi) return id->misc->ssi_errmsg||"";
  RXML.run_error("Couldn't stat file.\n");
}

string|array(string) tag_user(string tag, mapping m, RequestID id )
{
  if(!id->conf->auth_module)
    RXML.run_error("Requires a user database.\n");

  if (!m->name)
    return "";

  string b=m->name;

  array(string) u=id->conf->userinfo(b, id);
  if(!u) return "";

  string dom = id->conf->query("Domain");
  if(sizeof(dom) && (dom[-1]=='.'))
    dom = dom[0..strlen(dom)-2];

  if(m->realname && !m->email)
  {
    if(m->link && !m->nolink)
      return ({ "<a href=\"/~"+b+"/\">"+u[4]+"</a>" });
    return ({ u[4] });
  }

  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return ({ sprintf("<a href=\"mailto:%s@%s\">%s@%s</a>",
			b, dom, b, dom)
	      });
    return ({ b + "@" + dom });
  }

  if(m->nolink && !m->link)
    return ({ sprintf("%s &lt;%s@%s&gt;",
		      u[4], b, dom)
	    });

  return ({ sprintf( (m->nohomepage?"":"<a href=\"/~%s/\">%s</a> ")+
		    "<a href=\"mailto:%s@%s\">&lt;%s@%s&gt;</a>",
		    b, u[4], b, dom, b, dom)
	  });
}

class TagSetMaxCache {
  inherit RXML.Tag;
  constant name = "set-max-cache";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      id->misc->cacheable = Roxen.time_dequantifier(args);
    }
  }
}


// ------------------- Containers ----------------
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
      if( args->in && catch {
	content=Locale.Charset.decoder( args->in )->feed( content )->drain();
      })
	RXML.run_error("Illegal charset, or unable to decode data: %s\n",
		       args->in );
      if( args->out && id->set_output_charset)
	id->set_output_charset( args->out );
      result_type = result_type (RXML.PXml);
      result="";
      return ({content});
    }
  }
}

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
      scope_name=args->extend || "form";
      // FIXME: Should probably work like this, but it's anything but
      // simple to do that now, since variables is a class that simply
      // fakes the old variable structure using real_variables
// #if ROXEN_COMPAT <= 1.3
//       if(scope_name=="form") oldvar=id->variables;
// #endif
      if(args->extend)
	// This is not really good, since we are peeking on the
	// RXML parser internals without any abstraction...
	vars=copy_value(RXML.get_context()->scopes[scope_name]);
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

class TagCache {
  inherit RXML.Tag;
  constant name = "cache";
  RXML.Type content_type = RXML.t_same;

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
#define HASH(x) (x+id->not_query+id->query+id->realauth+id->conf->query("MyWorldLocation"))
      string key="";
      if(!args->nohash) {
	object md5 = Crypto.md5();
	md5->update(HASH(content));
	key=md5->digest();
      }
      if(args->key)
	key += args->key;
      result = cache_lookup("tag_cache", key);
      if(!result) {
	result = Roxen.parse_rxml(content, id);
	cache_set("tag_cache", key, result, Roxen.time_dequantifier(args));
      }
#undef HASH
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
	_ok=crypt(content,args->compare);
	return 0;
      }
      result=crypt(content);
      return 0;
    }
  }
}

class TagFor {
  inherit RXML.Tag;
  constant name = "for";

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

  if(!m->href) {
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

string simpletag_maketag(string tag, mapping m, string cont, RequestID id)
{
  mapping args=([]);

  if(m->type=="pi")
    return RXML.t_xml->format_tag(m->name, 0, cont, RXML.FLAG_PROC_INSTR);

  cont=Parser.HTML()->
    add_container("attrib", 
		  lambda(string tag, mapping m, string cont) {
		    args[m->name]=cont;
		    return "";
		  })->
    feed(cont)->read();

  if(m->type=="container")
    return RXML.t_xml->format_tag(m->name, args, cont);
  if(m->type=="tag")
    return Roxen.make_tag(m->name, args, !m->noxml);
  RXML.parse_error("No type given.\n");
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

string simpletag_autoformat(string tag, mapping m, string s, RequestID id)
{
  s-="\r";

  string p=(m["class"]?"<p class=\""+m["class"]+"\">":"<p>");

  if(!m->nonbsp)
  {
    s = replace(s, "\n ", "\n&nbsp;"); // "|\n |"      => "|\n&nbsp;|"
    s = replace(s, "  ", "&nbsp; ");  //  "|   |"      => "|&nbsp;  |"
    s = replace(s, "  ", " &nbsp;"); //   "|&nbsp;  |" => "|&nbsp; &nbsp;|"
  }

  if(!m->nobr) {
    s = replace(s, "\n", "<br />\n");
    if(m->p) {
      if(search(s, "<br />\n<br />\n")!=-1) s=p+s;
      s = replace(s, "<br />\n<br />\n", "\n</p>"+p+"\n");
      if(sizeof(s)>3 && s[0..2]!="<p>" && s[0..2]!="<p ")
        s=p+s;
      if(s[..sizeof(s)-4]==p)
        return s[..sizeof(s)-4];
      else
        return s+"</p>";
    }
    return s;
  }

  if(m->p) {
    if(search(s, "\n\n")!=-1) s=p+s;
      s = replace(s, "\n\n", "\n</p>"+p+"\n");
      if(sizeof(s)>3 && s[0..2]!="<p>" && s[0..2]!="<p ")
        s=p+s;
      if(s[..sizeof(s)-4]==p)
        return s[..sizeof(s)-4];
      else
        return s+"</p>";
    }

  return s;
}

class Smallcapsstr (string bigtag, string smalltag, mapping bigarg, mapping smallarg)
{
  constant UNDEF=0, BIG=1, SMALL=2;
  static string text="",part="";
  static int last=UNDEF;

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
  array q = s/(m->separator || m->sep || "\n");
  int index;
  if(m->seed)
    index = array_sscanf(Crypto.md5()->update(m->seed)->digest(),
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
array split_on_option( string what, Regexp r )
{
  array a = r->split( what );
  if( !a )
     return ({ what });
  return split_on_option( a[0], r ) + a[1..];
}
private int|array internal_tag_select(string t, mapping m, string c, string name, multiset(string) value)
{
  if(name && m->name!=name) return ({ RXML.t_xml->format_tag(t, m, c) });

  // Split indata into an array with the layout
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
    selected=Regexp(".*[Ss][Ee][Ll][Ee][Cc][Tt][Ee][Dd].*")->match(tmp[1]);
    ret+="<"+tmp[0]+tmp[1];
    if(value[nvalue] && !selected) ret+=" selected=\"selected\"";
    ret+=">"+tmp[2];
    if(!Regexp(".*</[Oo][Pp][Tt][Ii][Oo][Nn]")->match(tmp[2])) ret+="</"+tmp[0]+">";
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

string simpletag_sort(string t, mapping m, string c, RequestID id)
{
  if(!m->separator)
    m->separator = "\n";

  string pre="", post="";
  array lines = c/m->separator;

  while(lines[0] == "")
  {
    pre += m->separator;
    lines = lines[1..];
  }

  while(lines[-1] == "")
  {
    post += m->separator;
    lines = lines[..sizeof(lines)-2];
  }

  lines=sort(lines);

  return pre + (m->reverse?reverse(lines):lines)*m->separator + post;
}

string simpletag_replace( string tag, mapping m, string cont, RequestID id)
{
  switch(m->type)
  {
  case "word":
  default:
    if(!m->from) return cont;
   return replace(cont,m->from,(m->to?m->to:""));

  case "words":
    if(!m->from) return cont;
    string s=m->separator?m->separator:",";
    array from=(array)(m->from/s);
    array to=(array)(m->to/s);

    int balance=sizeof(from)-sizeof(to);
    if(balance>0) to+=allocate(balance,"");

    return replace(cont,from,to);
  }
}

class TagCSet {
  inherit RXML.Tag;
  constant name = "cset";
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if( !args->variable ) parse_error("Variable not specified.\n");
      if(!content) content="";
      if( args->quote != "none" )
	content = Roxen.html_decode_string( content );

      RXML.user_set_var(args->variable, content, args->scope);
      return ({ "" });
    }
  }
}

class TagColorScope {
  inherit RXML.Tag;
  constant name = "colorscope";

  class Frame {
    inherit RXML.Frame;
    string link, alink, vlink;

#define LOCAL_PUSH(X) if(args->X) { X=id->misc->defines->X; id->misc->defines->X=args->X; }
    array do_enter(RequestID id) {
      Roxen.push_color("colorscope",args,id);
      LOCAL_PUSH(link);
      LOCAL_PUSH(alink);
      LOCAL_PUSH(vlink);
      return 0;
    }

#define LOCAL_POP(X) if(X) id->misc->defines->X=X
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
    inherit "rxmlhelp";
    inherit RXML.Frame;

    array do_return(RequestID id) {
      array tags=map(indices(RXML.get_context()->tag_set->get_tag_names()),
		     lambda(string tag) {
		       if(tag[..3]=="!--#" || !has_value(tag, "#"))
			 return tag;
		       return "";
		     } ) - ({ "" });
      tags += map(indices(RXML.get_context()->tag_set->get_proc_instr_names()),
		  lambda(string tag) { return "&lt;?"+tag+"?&gt;"; } );
      tags = Array.sort_array(tags,
			      lambda(string a, string b) {
				if(a[..4]=="&lt;?") a=a[5..];
				if(b[..4]=="&lt;?") b=b[5..];
				if(lower_case(a)==lower_case(b)) return a>b;
				return lower_case(a)>lower_case(b); })-({"\x266a"});
      string help_for = args->for || id->variables->_r_t_h;
      string ret="<h2>Roxen Interactive RXML Help</h2>";

      if(!help_for) {
	string char;
	ret += "<b>Here is a list of all defined tags. Click on the name to "
	  "receive more detailed information. All these tags are also availabe "
	  "in the \""+RXML_NAMESPACE+"\" namespace.</b><p>\n";
	array tag_links;

	foreach(tags, string tag) {
	  if(tag[0]!='&' && lower_case(tag[0..0])!=char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char=lower_case(tag[0..0]);
	    tag_links=({});
	  }
	  if (tag[0]=='&' && lower_case(tag[5..5])!=char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char=lower_case(tag[5..5]);
	    tag_links=({});
	  }
	  if(tag[0..sizeof(RXML_NAMESPACE)]!=RXML_NAMESPACE+":") {
	    string enc=tag;
	    if(enc[0..4]=="&lt;?") enc="<?"+enc[5..sizeof(enc)-6];
	    if(undocumented_tags && undocumented_tags[tag])
	      tag_links += ({ tag });
	    else
	      tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>\n",
				      id->not_query, Roxen.http_encode_url(enc), tag) });
	    }
	}

	ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
	/*
	ret+="<p><b>This is a list of all currently defined RXML scopes and their entities</b></p>";

	RXML.Context context=RXML.get_context();
	foreach(sort(context->list_scopes()), string scope) {
	  ret+=sprintf("<h3><a href=\"%s?_r_t_h=%s\">%s</a></h3>\n",
		       id->not_query, Roxen.http_encode_url("&"+scope+";"), scope);
	  ret+="<p>"+String.implode_nicely(Array.map(sort(context->list_var(scope)),
						       lambda(string ent) { return ent; }) )+"</p>";
	}
	*/
	return ({ ret });
      }

      result=ret+find_tag_doc(help_for, id);
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
                            id->misc->defines->theme_language,
			    args->type||"number",id)( (int)args->num );
    }
  }
}


class TagUse {
  inherit RXML.Tag;
  constant name = "use";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

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

    array pack = parse_use_package(data, RXML.get_context());
    cache_set("macrofiles", "|"+f, pack, 300);

    constant types = ({ "if plugin", "tag", "variable" });

    pack = pack + ({});
    pack[0] = indices(pack[0]);
    pack[1] = pack[1]->name;
    pack[2] = indices(pack[2])+indices(pack[3]);

    for(int i; i<3; i++)
      if(sizeof(pack[i])) {
	res += "Defines the following " + types[i] + (sizeof(pack[i])!=1?"s":"") +
	  ": " + String.implode_nicely( sort(pack[i]) ) + ".<br />";
      }

    if(help) res+="<br /><br />All tags accept the <i>help</i> attribute.";
    return res;
  }

  private array parse_use_package(string data, RXML.Context ctx) {
    array res = allocate(4);
    multiset before=ctx->get_runtime_tags();
    if(!ctx->id->misc->_ifs) ctx->id->misc->_ifs = ([]);
    mapping before_ifs = mkmapping(indices(ctx->id->misc->_ifs),
				   indices(ctx->id->misc->_ifs));
    mapping scope_form = mkmapping(ctx->list_var("form"),
				   map(ctx->list_var("form"),
				       lambda(string v) { return ctx->get_var(v, "form"); } ));
    mapping scope_var = mkmapping(ctx->list_var("var"),
				  map(ctx->list_var("var"),
				      lambda(string v) { return ctx->get_var(v, "var"); } ));

    Roxen.parse_rxml( data, ctx->id );

    foreach( ctx->list_var("form"), string var ) {
      mixed val = ctx->get_var(var, "form");
      if(scope_form[var]==val)
	m_delete(scope_form, var);
      else
	scope_form[var]=val;
    }

    foreach( ctx->list_var("var"), string var ) {
      mixed val = ctx->get_var(var, "var");
      if(scope_var[var]==val)
	m_delete(scope_var, var);
      else
	scope_var[var]=val;
    }

    res[0] = ctx->id->misc->_ifs - before_ifs;
    res[1] = indices(RXML.get_context()->get_runtime_tags()-before);
    res[2] = scope_form;
    res[3] = scope_var;
    return res;
  }

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->packageinfo) {
	NOCACHE();
	string res ="<dl>";
	foreach(list_packages(), string f)
	  res += use_file_doc(f, read_package( f ));
	return ({ res+"</dl>" });
      }

      if(!args->file && !args->package)
	parse_error("No file or package selected.\n");

      array res;
      string name, filename;
      if(args->file)
      {
	filename = Roxen.fix_relative(args->file, id);
	name = id->conf->get_config_id() + "|" + filename;
      }
      else
	name = "|" + args->package;
      RXML.Context ctx = RXML.get_context();

      if(args->info || id->pragma["no-cache"] ||
	 !(res=cache_lookup("macrofiles",name)) ) {

	string file;
	if(filename)
	  file = id->conf->try_get_file( filename, id );
	else
	  file = read_package( args->package );

	if(!file)
	  run_error("Failed to fetch "+(args->file||args->package)+".\n");

	if( args->info )
	  return ({"<dl>"+use_file_doc( args->file || args->package, file )+"</dl>"});

	res = parse_use_package(file, ctx);
	cache_set("macrofiles", name, res);
      }

      id->misc->_ifs += res[0];
      foreach(res[1], RXML.Tag tag)
	ctx->add_runtime_tag(tag);
      foreach(indices(res[2]), string var)
	ctx->set_var(var, res[2][var], "form");
      foreach(indices(res[3]), string var)
	ctx->set_var(var, res[3][var], "var");

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

  class Frame
  {
    inherit RXML.Frame;
    constant is_user_tag_contents = 1;
    array do_return()
    {
      int nest = 1;
      RXML.Frame frame = up;
      for (; frame; frame = frame->up)
	if (frame->is_user_tag) {
	  if (!--nest) break;
	}
	else if (frame->is_user_tag_contents) nest++;
      if (!frame)
	parse_error ("No associated defined tag to get contents from.\n");
      return ({frame->user_tag_contents || ""});
    }
  }
}

private RXML.TagSet user_tag_contents_tag_set =
  RXML.TagSet ("user_tag_contents", ({UserTagContents()}));

class UserTag {
  inherit RXML.Tag;
  string name;
  int flags = 0;
  RXML.Type content_type = RXML.t_xml;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  string c;
  mapping defaults;
  string scope;

  void create(string _name, string _c, mapping _defaults,
	      int tag, void|string scope_name) {
    name=_name;
    c=_c;
    defaults=_defaults;
    if(tag) flags=RXML.FLAG_EMPTY_ELEMENT;
    scope=scope_name;
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = user_tag_contents_tag_set;
    mapping vars;
    string scope_name;
    constant is_user_tag = 1;
    string user_tag_contents;

    array do_return(RequestID id) {
      mapping nargs=defaults+args;
      id->misc->last_tag_args = nargs;
      scope_name=scope||name;
      vars = nargs;

      if(!(RXML.FLAG_EMPTY_ELEMENT&flags) && args->trimwhites)
	content=String.trim_all_whites(content);

#if ROXEN_COMPAT <= 1.3
      if(id->conf->old_rxml_compat) {
	array replace_from, replace_to;
	if (flags & RXML.FLAG_EMPTY_ELEMENT) {
	  replace_from = map(indices(nargs),Roxen.make_entity)+({"#args#"});
	  replace_to = values(nargs)+({ Roxen.make_tag_attributes(nargs)[1..] });
	}
	else {
	  replace_from = map(indices(nargs),Roxen.make_entity)+({"#args#", "<contents>"});
	  replace_to = values(nargs)+({ Roxen.make_tag_attributes(nargs)[1..], content });
	}
	string c2;
	c2 = replace(c, replace_from, replace_to);
	if(c2!=c) {
	  vars=([]);
	  return ({c2});
	}
      }
#endif

      vars->args = Roxen.make_tag_attributes(nargs)[1..];
      vars["rest-args"] = Roxen.make_tag_attributes(args - defaults)[1..];
      user_tag_contents = vars->contents = content;
      return ({ c });
    }
  }
}

class TagDefine {
  inherit RXML.Tag;
  constant name = "define";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type = RXML.t_xml (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if(args->preparse)
	m_delete(args, "preparse");
      else
	content_type = RXML.t_xml;
      return 0;
    }

    array do_return(RequestID id) {
      string n;

      if(n=args->variable) {
	if(args->trimwhites) content=String.trim_all_whites(content);
	RXML.user_set_var(n, content, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
#if ROXEN_COMPAT <= 1.3
	n = id->conf->old_rxml_compat?lower_case(n):n;
#endif
	int tag=0;
	if(args->tag) {
	  tag=1;
	  m_delete(args, "tag");
	} else
	  m_delete(args, "container");

	mapping defaults=([]);

#if ROXEN_COMPAT <= 1.3
	if(id->conf->old_rxml_compat)
	  foreach( indices(args), string arg )
	    if( arg[..7] == "default_" )
	      {
		defaults[arg[8..]] = args[arg];
		old_rxml_warning(id, "define attribute "+arg,"attrib container");
		m_delete( args, arg );
	      }
#endif
	content=parse_html(content||"",([]),
			   (["attrib":
			     lambda(string tag, mapping m, string cont) {
			       if(m->name) defaults[m->name]=Roxen.parse_rxml(cont,id);
			       return "";
			     }
			   ]));

	if(args->trimwhites) {
	  content=String.trim_all_whites(content);
	  m_delete (args, "trimwhites");
	}

#if ROXEN_COMPAT <= 1.3
	if(id->conf->old_rxml_compat) content = replace( content, indices(args), values(args) );
#endif

	RXML.get_context()->add_runtime_tag(UserTag(n, content, defaults,
						    tag, args->scope));
	return 0;
      }

      if (n=args->if) {
	if(!id->misc->_ifs) id->misc->_ifs=([]);
	id->misc->_ifs[args->if]=UserIf(args->if, content);
	return 0;
      }

#if ROXEN_COMPAT <= 1.3
      if (n==args->name) {
	id->misc->defines[n]=content;
	old_rxml_warning(id, "attempt to define name ","variable");
	return 0;
      }
#endif

      parse_error("No tag, variable, if or container specified.\n");
    }
  }
}

class TagUndefine {
  inherit RXML.Tag;
  int flags = RXML.FLAG_EMPTY_ELEMENT;
  constant name = "undefine";
  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      string n;

      if(n=args->variable) {
	RXML.get_context()->user_delete_var(n, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
	RXML.get_context()->remove_runtime_tag(n);
	return 0;
      }

      if (n=args->if) {
	m_delete(id->misc->_ifs, n);
	return 0;
      }

#if ROXEN_COMPAT <= 1.3
      if (n=args->name) {
	m_delete(id->misc->defines, args->name);
	return 0;
      }
#endif

      parse_error("No tag, variable, if or container specified.\n");
    }
  }
}

class Tracer (Configuration conf)
{
  // Note: \n is used sparingly in output to make it look nice even
  // inside <pre>.
  string resolv="<ol>";
  int level;

  string _sprintf()
  {
    return "Tracer()";
  }

#if constant (gethrtime)
  mapping et = ([]);
#endif
#if constant (gethrvtime)
  mapping et2 = ([]);
#endif

  local void start_clock()
  {
#if constant (gethrvtime)
    et2[level] = gethrvtime();
#endif
#if constant (gethrtime)
    et[level] = gethrtime();
#endif
  }

  local string stop_clock()
  {
    string res;
#if constant (gethrtime)
    res = sprintf("%.5f", (gethrtime() - et[level])/1000000.0);
#else
    res = "";
#endif
#if constant (gethrvtime)
    res += sprintf(" (CPU = %.2f)", (gethrvtime() - et2[level])/1000000.0);
#endif
    return res;
  }

  void trace_enter_ol(string type, function|object thing)
  {
    level++;

    if (thing) {
      string name = Roxen.get_modfullname (Roxen.get_owning_module (thing));
      if (name)
	name = "module " + name;
      else if (this_program conf = Roxen.get_owning_config (thing))
	name = "configuration " + Roxen.html_encode_string (conf->query_name());
      else
	name = Roxen.html_encode_string (sprintf ("object %O", thing));
      type += " in " + name;
    }

    string efont="", font="";
    if(level>2) {efont="</font>";font="<font size=-1>";}

    resolv += font + "<li><b>»</b> " + type + "<ol>" + efont;
    start_clock();
  }

  void trace_leave_ol(string desc)
  {
    level--;

    string efont="", font="";
    if(level>1) {efont="</font>";font="<font size=-1>";}

    resolv += "</ol>" + font;
    if (sizeof (desc))
      resolv += "<b>«</b> " + Roxen.html_encode_string(desc);
    string time = stop_clock();
    if (sizeof (time)) {
      if (sizeof (desc)) resolv += "<br />";
      resolv += "<i>Time: " + time + "</i>";
    }
    resolv += efont + "</li>\n";
  }

  string res()
  {
    while(level>0) trace_leave_ol("");
    return resolv + "</ol>";
  }
}

class TagTrace {
  inherit RXML.Tag;
  constant name = "trace";

  class Frame {
    inherit RXML.Frame;
    function a,b;
    Tracer t;

    array do_enter(RequestID id) {
      NOCACHE();
      t = Tracer(id->conf);
      a = id->misc->trace_enter;
      b = id->misc->trace_leave;
      id->misc->trace_enter = t->trace_enter_ol;
      id->misc->trace_leave = t->trace_leave_ol;
      t->start_clock();
      return 0;
    }

    array do_return(RequestID id) {
      id->misc->trace_enter = a;
      id->misc->trace_leave = b;
      result = "<h3>Tracing</h3>" + content +
	"<h3>Trace report</h3>" + t->res();
      string time = t->stop_clock();
      if (sizeof (time))
	result += "<h3>Total time: " + time + "</h3>";
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

class TagStrLen {
  inherit RXML.Tag;
  constant name = "strlen";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame {
    inherit RXML.Frame;
    array do_return() {
      if(!stringp(content)) {
	result="0";
	return 0;
      }
      result = (string)strlen(content);
    }
  }
}

class TagCase {
  inherit RXML.Tag;
  constant name = "case";

  class Frame {
    inherit RXML.Frame;
    int cap=0;
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
	    // FIXME: 2.1 compat: Not an error.
	    parse_error ("Invalid value %O to the case argument.\n", args->case);
	}
	// FIXME: 2.1 compat: Not an error.
	parse_error ("Content of type %s doesn't handle being %s.\n",
		     content_type->name, op);
      }

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
  int do_iterate = -1;

  array do_enter(RequestID id) {
    int and = 1;

    if(args->not) {
      m_delete(args, "not");
      do_enter(id);
      do_iterate=do_iterate==1?-1:1;
      return 0;
    }

    if(args->or)  { and = 0; m_delete( args, "or" ); }
    if(args->and) { and = 1; m_delete( args, "and" ); }
    mapping plugins=get_plugins();
    if(id->misc->_ifs) plugins+=id->misc->_ifs;
    array possible = indices(args) & indices(plugins);

    int ifval=0;
    foreach(possible, string s) {
      ifval = plugins[ s ]->eval( args[s], id, args, and, s );
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
  constant flags = RXML.FLAG_SOCKET_TAG;
  program Frame = FrameIf;
}

class TagElse {
  inherit RXML.Tag;
  constant name = "else";
  constant flags = 0;
  class Frame {
    inherit RXML.Frame;
    int do_iterate=1;
    array do_enter(RequestID id) {
      if(_ok) do_iterate=-1;
      return 0;
    }
  }
}

class TagThen {
  inherit RXML.Tag;
  constant name = "then";
  constant flags = 0;
  class Frame {
    inherit RXML.Frame;
    int do_iterate=1;
    array do_enter(RequestID id) {
      if(!_ok) do_iterate=-1;
      return 0;
    }
  }
}

class TagElseif {
  inherit RXML.Tag;
  constant name = "elseif";

  class Frame {
    inherit FrameIf;
    int last;
    array do_enter(RequestID id) {
      last=_ok;
      if(last) return 0;
      return ::do_enter(id);
    }

    array do_return(RequestID id) {
      if(last) return 0;
      return ::do_return(id);
    }

    mapping(string:RXML.Tag) get_plugins() {
      return RXML.get_context()->tag_set->get_plugins ("if");
    }
  }
}

class TagTrue {
  inherit RXML.Tag;
  constant name = "true";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

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
	if (up->result != RXML.Void) return 0;
	content_type = up->result_type (RXML.PXml);
	return ::do_enter (id);
      }

      array do_return (RequestID id)
      {
	::do_return (id);
	if (up->result != RXML.Void) return 0;
	up->result = result;
	result = RXML.Void;
	return 0;
      }

      // Must override this since it's used by FrameIf.
      mapping(string:RXML.Tag) get_plugins()
	{return RXML.get_context()->tag_set->get_plugins ("if");}
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
      int do_iterate = 1;

      array do_enter()
      {
	if (up->result != RXML.Void) {
	  do_iterate = -1;
	  return 0;
	}
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
    RXML.TagSet ("TagCond.cond_tags", ({TagCase(), TagDefault()}));

  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet local_tags = cond_tags;
    string default_data;

    array do_return (RequestID id)
    {
      if (result == RXML.Void && default_data) {
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
  constant flags = RXML.FLAG_SOCKET_TAG|RXML.FLAG_DONT_REPORT_ERRORS;
  mapping(string:RXML.Type) req_arg_types = (["source":RXML.t_text(RXML.PEnt)]);

  int(0..1) should_filter(mapping vs, mapping filter) {
    RXML.Context ctx = RXML.get_context();
    foreach(indices(filter), string v) {
      string|object val = vs[v];
      if(objectp(val))
	val = val->rxml_const_eval ? val->rxml_const_eval(ctx, v, "", RXML.t_text) :
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
	   (int)id->misc->emit_args->maxrows == RXML.get_var("counter"))
	  return 0;
	if(more_rows(res, id->misc->emit_filter))
	  result = content;
	return 0;
      }
    }
  }

  RXML.TagSet internal = RXML.TagSet("TagEmit.internal", ({ TagDelimiter() }) );

  // A slightly modified Array.dwim_sort_func
  // used as emits sort function.
  static int compare(string|object a0,string|object b0, string v) {
    RXML.Context ctx;
    if(objectp(a0)) {
      if(!ctx) ctx = RXML.get_context();
      a0 = a0->rxml_const_eval ? a0->rxml_const_eval(ctx, v, "", RXML.t_text) :
	a0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }
    if(objectp(b0)) {
      if(!ctx) ctx = RXML.get_context();
      b0 = b0->rxml_const_eval ? b0->rxml_const_eval(ctx, v, "", RXML.t_text) :
	b0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }

    if (!a0) {
      if (b0)
	return -1;
      return 0;
    }

    if (!b0)
      return 1;

    string a2="",b2="";
    int a1,b1;
    sscanf(a0,"%s%d%s",a0,a1,a2);
    sscanf(b0,"%s%d%s",b0,b1,b2);
    if (a0>b0) return 1;
    if (a0<b0) return -1;
    if (a1>b1) return 1;
    if (a1<b1) return -1;
    if (a2==b2) return 0;
    return compare(a2,b2,v);
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
      return ret[..sizeof(ret)-2];
    }

    array do_enter(RequestID id) {
      if(!(plugin=get_plugins()[args->source]))
	parse_error("The emit source %O doesn't exist.\n", args->source);
      scope_name=args->scope||args->source;
      vars = (["counter":0]);

      TRACE_ENTER("Fetch emit dataset for source "+args->source, 0);
      res=plugin->get_dataset(args, id);
      TRACE_LEAVE("");

      if(plugin->skiprows && args->skiprows)
	m_delete(args, "skiprows");
      if(args->maxrows) {
	if(plugin->maxrows)
	  m_delete(args, "maxrows");
	else
	  args->maxrows = (int)args->maxrows;
      }

      // Parse the filter argument
      if(args->filter) {
	array pairs = args->filter / ",";
	filter = ([]);
	foreach( args->filter / ",", string pair) {
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
	   (args->skiprows && args->skiprows[0]=='-') )
	  res = expand(res);
	else if(filter) {
	  do_iterate = object_filter_iterate;
	  id->misc->emit_rows = res;
	  if(args->skiprows) args->skiprows = (int)args->skiprows;
	  return 0;
	}
	else {
	  do_iterate = object_iterate;
	  id->misc->emit_rows = res;

	  if(args->skiprows) {
	    int loop = (int)args->skiprows;
	    while(loop--)
	      res->skip_row();
	  }

	  return 0;
	}

      if(arrayp(res)) {
	if(args->sort && !plugin->sort)
	{
	  array(string) order = (args->sort - " ")/"," - ({ "" });
	  res = Array.sort_array( res,
				  lambda (mapping(string:string) m1,
					  mapping(string:string) m2)
				  {
				    foreach (order, string field)
				    {
				      int(-1..1) tmp;
				      
				      if (field[0] == '-')
					tmp = compare( m2[field[1..]],
						       m1[field[1..]],
						       field );
				      else if (field[0] == '+')
					tmp = compare( m1[field[1..]],
						       m2[field[1..]],
						       field );
				      else
					tmp = compare( m1[field], m2[field],
						       field );

				      if (tmp == 1)
					return 1;
				      else if (tmp == -1)
					return 0;
				    }
				    return 0;
				  } );
	}

	if(filter) {

	  // If rowinfo or negative skiprows are used we have
	  // to do filtering in a loop of its own, instead of
	  // doing it during the emit loop.
	  if(args->rowinfo ||
	     (args->skiprows && args->skiprows[-1]=='-')) {
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
	      int skiprows = (int)args->skiprows;
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
	    if(args->skiprows[0]=='-') args->skiprows=sizeof(res)+(int)args->skiprows;
	    res=res[(int)args->skiprows..];
	  }

	  if(args->remainderinfo)
	    RXML.user_set_var(args->remainderinfo, args->maxrows?
			      max(sizeof(res)-args->maxrows, 0): 0);

	  if(args->maxrows) res=res[..args->maxrows-1];
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

      if(args->skiprows>0)
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
      if(args->rowinfo)
	RXML.user_set_var(args->rowinfo, rounds);
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
      return 0;
    }

  }
}

class TagComment {
  inherit RXML.Tag;
  constant name = "comment";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  class Frame {
    inherit RXML.Frame;
    int do_iterate=-1;
    array do_enter() {
      if(args && args->preparse)
	do_iterate=1;
      return 0;
    }
    array do_return = ({});
  }
}

class TagPIComment {
  inherit TagComment;
  constant flags = RXML.FLAG_PROC_INSTR;
}


// ---------------------- If plugins -------------------

class UserIf
{
  inherit RXML.Tag;
  constant name = "if";
  string plugin_name;
  string rxml_code;

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
    tmp = Roxen.parse_rxml(rxml_code, id);
    res = _ok;
    _ok = otruth;

    TRACE_LEAVE("");

    if(ind==plugin_name && res!=-2)
      return res;

    return (ind==tmp);
  }
}

class IfIs
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  constant case_sensitive = 0;
  function source;

  int eval( string value, RequestID id )
  {
    if(cache != -1) CACHE(cache);
    array arr=value/" ";
    string|int|float var=source(id, arr[0]);
    if( !var && zero_type( var ) ) return 0;
    if(sizeof(arr)<2) return !!var;
    string is;
    if(case_sensitive) {
      var = var+"";
      if(sizeof(arr)==1) return !!var;
      is=arr[2..]*" ";
    }
    else {
      var = lower_case( (var+"") );
      if(sizeof(arr)==1) return !!var;
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

    value=source(id, value);
    return !!value;
  }
}

class IfMatch
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  function source;

  int eval( string is, RequestID id ) {
    array|string value=source(id);
    if(cache != -1) CACHE(cache);
    if(!value) return 0;
    if(arrayp(value)) value=value*" ";
    value = lower_case( value );
    is = lower_case( "*"+is+"*" );
    return glob(is,value) || sizeof(filter( is/",", glob, value ));
  }
}

class TagIfDate {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "date";

  int eval(string date, RequestID id, mapping m) {
    CACHE(60); // One minute accuracy is probably good enough...
    int a, b;
    mapping c;
    c=localtime(time(1));
    b=(int)sprintf("%02d%02d%02d", c->year, c->mon + 1, c->mday);
    a=(int)replace(date,"-","");
    if(a > 999999) a -= 19000000;
    else if(a < 901201) a += 10000000;
    if(m->inclusive || !(m->before || m->after) && a==b)
      return 1;
    if(m->before && a>b)
      return 1;
    else if(m->after && a<b)
      return 1;
  }
}

class TagIfTime {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "time";

  int eval(string ti, RequestID id, mapping m) {
    CACHE(time(1)%60); // minute resolution...

    int tok, a, b, d;
    mapping c;
    c=localtime(time(1));

    b=(int)sprintf("%02d%02d", c->hour, c->min);
    a=(int)replace(ti,":","");

    if(m->until) {
      d = (int)m->until;
      if (d > a && (b > a && b < d) )
	return 1;
      if (d < a && (b > a || b < d) )
	return 1;
      if (m->inclusive && ( b==a || b==d ) )
	return 1;
    }
    else if(m->inclusive || !(m->before || m->after) && a==b)
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
    if(crypt(try, org)) return 1;
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
    CACHE(5);
    return id->conf->is_file(Roxen.fix_relative(u, id), id);
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

class TagIfConfig {
  inherit IfIs;
  constant plugin_name = "config";
  int source(RequestID id, string s) {
    return id->config[s];
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

#if ROXEN_COMPAT <= 1.3
class TagIfName {
  inherit TagIfClient;
  constant plugin_name = "name";
}
#endif

class TagIfDefined {
  inherit IfIs;
  constant plugin_name = "defined";
  string|int|float source(RequestID id, string s) {
    mixed val;
    if(!id->misc->defines || !(val=id->misc->defines[s])) return 0;
    if(stringp(val) || intp(val) || floatp(val)) return val;
    return 1;
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

#if ROXEN_COMPAT <= 1.3
class TagIfHost {
  inherit TagIfIP;
  constant plugin_name = "host";
}
#endif

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
  int source(RequestID id, string s) {
    return id->pragma[s];
  }
}

class TagIfPrestate {
  inherit IfIs;
  constant plugin_name = "prestate";
  constant cache = -1;
  int source(RequestID id, string s) {
    return id->prestate[s];
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
  int source(RequestID id, string s) {
    return id->supports[s];
  }
}

class TagIfVariable {
  inherit IfIs;
  constant plugin_name = "variable";
  constant cache = 1;
  string source(RequestID id, string s) {
    mixed var=RXML.user_get_var(s);
    if(!var) return var;
    return RXML.t_text->encode (var);
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
  int source(RequestID id, string s) {
    mixed var=RXML.user_get_var(s);
    if(!var) {
      if(zero_type(RXML.user_get_var(s))) return 0;
      return 1;
    }
    if(stringp(var) || arrayp(var) ||
       multisetp(var) || mappingp(var)) return sizeof(var);
    if(objectp(var) && var->_sizeof) return sizeof(var);
    return sizeof((string)var);
  }
}

class TagIfClientvar {
  inherit IfIs;
  constant plugin_name = "clientvar";
  string source(RequestID id, string s) {
    return id->client_var[s];
  }
}

class TagIfExpr {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "expr";
  int eval(string u) {
    return (int)sexpr_eval(u);
  }
}


// --------------------- Emit plugins -------------------

class TagEmitSources {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="sources";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    return Array.map( indices(RXML.get_context()->tag_set->get_plugins("emit")),
		      lambda(string source) { return (["source":source]); } );
  }
}

class TagPathplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "path";

  class PathResult(array(string) segments)
  {
    protected int pos;
    protected string val = "";

    protected string really_get_row()
    {
      if (pos >= sizeof(segments)) return UNDEFINED;
      if (has_suffix(val, "/")) {
	// NB: Typically only for the segment after the root.
	val += segments[pos];
      } else {
	val += "/" + segments[pos];
      }
      pos++;
      return val;
    }
  }

  array|EmitObject get_dataset(mapping m, RequestID id)
  {
    string fp = "";
    array res = ({});
    string p = m->path || id->not_query;
    if( m->trim )
      sscanf( p, "%s"+m->trim, p );
    if( p[-1] == '/' )
      p = p[..strlen(p)-2];
    array q = p / "/";
    if( m->skip )
      q = q[(int)m->skip..];
    if( m["skip-end"] )
      q = q[..sizeof(q)-((int)m["skip-end"]+1)];

    if ((sizeof(q) > 16) || (sizeof(p) > 1024)) {
      // Avoid O(n^2) memory consumption,
      // (and O(n^3) time consumption).
      return PathResult(q);
    }

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

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    if(m["from-scope"]) {
      m->values=([]);
      RXML.Context context=RXML.get_context();
      map(context->list_var(m["from-scope"]),
	  lambda(string var){ m->values[var]=context->get_var(var, m["from-scope"]);
	  return ""; });
    }

    if( m->variable )
      m->values = RXML.get_context()->user_get_var( m->variable );

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
	}
      }
      m->values=m->values / (m->split || "\000");
    }

    if(mappingp(m->values))
      return map( indices(m->values),
		  lambda(mixed ind) { return (["index":ind,"value":m->values[ind]]); });

    if(arrayp(m->values))
      return map( m->values,
		  lambda(mixed val) {
		    if(m->trimwhites) val=String.trim_all_whites((string)val);
		    if(m->case=="upper") val=upper_case(val);
		    else if(m->case=="lower") val=lower_case(val);
		    return (["value":val]);
		  } );

    RXML.run_error("Values variable has wrong type %t.\n", m->values);
  }
}

class TagEmitFonts
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "fonts";
  array get_dataset(mapping args, RequestID id)
  {
    return roxen->fonts->get_font_information(args->ttf_only);
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
  mapping doc=compile_string("#define manual\n"+file->read())->tagdoc;
  file->close();
  if(!file->open("etc/supports","r")) return doc;
  parse_html(file->read(), ([]), (["flags":format_support,
				   "vars":format_support]), doc);
  return doc;
}

static int format_support(string t, mapping m, string c, mapping doc) {
  string key=(["flags":"if#supports","vars":"if#clientvar"])[t];
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
"&roxen;":#"<desc scope='scope'><p><short>
 This scope contains information specific to this Roxen
 WebServer.</short> It is not possible to write any information to
 this scope
</p></desc>",

"&roxen.domain;":#"<desc ent='ent'><p>
 The domain name of this site.
</p></desc>",

"&roxen.hits;":#"<desc ent='ent'><p>
 The number of hits, i.e. requests the webserver has accumulated since
 it was last started.
</p></desc>",
"&roxen.hits-per-minute;":#"<desc ent='ent'><p>
 The number of hits per minute, in average.
</p></desc>",

"&roxen.pike-version;":#"<desc ent='ent'><p>
 The version of Pike the webserver is using.
</p></desc>",

"&roxen.sent;":#"<desc ent='ent'><p>
The total amount of data the webserver has sent.
</p></desc>",

"&roxen.sent-kbit-per-second;":#"<desc ent='ent'><p>
The average amount of data the webserver has sent, in
Kibibits.
</p></desc>",

"&roxen.sent-mb;":#"<desc ent='ent'><p>
 The total amount of data the webserver has sent, in
 Mebibits.
</p></desc>",

"&roxen.sent-per-minute;":#"<desc ent='ent'><p>
 The number of bytes that the webserver sends during a
 minute, on average.
</p></desc>",

"&roxen.server;":#"<desc ent='ent'><p>
 The URL of the webserver.
</p></desc>",

"&roxen.ssl-strength;":#"<desc ent='ent'><p>
 How many bits encryption strength are the SSL capable of
</p></desc>",

"&roxen.time;":#"<desc ent='ent'><p>
 The current posix time.
</p></desc>",

"&roxen.unique-id;":#"<desc ent='ent'><p>
 Returns a unique id that can be used for e.g. session
 identification.
</p></desc>",

"&roxen.uptime;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in seconds.
</p></desc>",

"&roxen.uptime-days;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in days.
</p></desc>",

"&roxen.uptime-hours;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in hours.
</p></desc>",

"&roxen.uptime-minutes;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in minutes.
</p></desc>",

//----------------------------------------------------------------------

"&client;":#"<desc scope='scope'><p><short>
 This scope contains information specific to the client/browser that
 is accessing the page.</short>
</p></desc>",

"&client.ip;":#"<desc ent='ent'><p>
 The client is located on this IP-address.
</p></desc>",

"&client.host;":#"<desc ent='ent'><p>
 The host name of the client, if possible to resolve.
</p></desc>",

"&client.name;":#"<desc ent='ent'><p>
 The name of the client, i.e. \"Mozilla/4.7\".
</p></desc>",

"&client.Fullname;":#"<desc ent='ent'><p>
 The full user agent string, i.e. name of the client and additional
 info like; operating system, type of computer, etc. E.g.
 \"Mozilla/4.7 [en] (X11; I; SunOS 5.7 i86pc)\".
</p></desc>",

"&client.fullname;":#"<desc ent='ent'><p>
 The full user agent string, i.e. name of the client and additional
 info like; operating system, type of computer, etc. E.g.
 \"mozilla/4.7 [en] (x11; i; sunos 5.7 i86pc)\".
</p></desc>",

"&client.referrer;":#"<desc ent='ent'><p>
 Prints the URL of the page on which the user followed a link that
 brought her to this page. The information comes from the referrer
 header sent by the browser.
</p></desc>",

"&client.accept-language;":#"<desc ent='ent'><p>
 The client prefers to have the page contents presented in this
 language.
</p></desc>",

"&client.accept-languages;":#"<desc ent='ent'><p>
 The client prefers to have the page contents presented in this
 language but these additional languages are accepted as well.
</p></desc>",

"&client.language;":#"<desc ent='ent'><p>
 The clients most preferred language.
</p></desc>",

"&client.languages;":#"<desc ent='ent'><p>
 An ordered list of the clients most preferred languages.
</p></desc>",

"&client.authenticated;":#"<desc ent='ent'><p>
 Returns the name of the user logged on to the site, i.e. the login
 name, if any exists.
</p></desc>",

"&client.user;":#"<desc ent='ent'><p>
 Returns the name the user used when he/she tried to log on the site,
 i.e. the login name, if any exists.
</p></desc>",

"&client.password;":#"<desc ent='ent'><p>

</p></desc>",

"&client.height;":#"<desc ent='ent'><p>
 The presentation area height in pixels. For WAP-phones.
</p></desc>",

"&client.width;":#"<desc ent='ent'><p>
 The presentation area width in pixels. For WAP-phones.
</p></desc>",

"&client.robot;":#"<desc ent='ent'><p>

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

"&client.javascript;":#"<desc ent='ent'><p>
 Returns the highest version of javascript supported.
</p></desc>",

"&client.tm;":#"<desc ent='ent'><p><short>
 Generates a trademark sign in a way that the client can
 render.</short> Possible outcomes are \"&amp;trade;\",
 \"&lt;sup&gt;TM&lt;/sup&gt;\", and \"&amp;gt;TM&amp;lt;\".</p>
</desc>",

//----------------------------------------------------------------------

"&page;":#"<desc scope='scope'><p><short>
 This scope contains information specific to this page.</short></p>
</desc>",

"&page.realfile;":#"<desc ent='ent'><p>
 Path to this file in the file system.
</p></desc>",

"&page.virtroot;":#"<desc ent='ent'><p>
 The root of the present virtual filesystem.
</p></desc>",

//  &page.virtfile; is same as &page.path; but deprecated since we want to
//  harmonize with SiteBuilder entities.
"&page.path;":#"<desc ent='ent'><p>
 Absolute path to this file in the virtual filesystem.
</p></desc>",

"&page.pathinfo;":#"<desc ent='ent'><p>
 The \"path info\" part of the URL, if any. Can only get set if the
 \"Path info support\" module is installed. For details see the
 documentation for that module.
</p></desc>",

"&page.query;":#"<desc ent='ent'><p>
 The query part of the page URI.
</p></desc>",

"&page.url;":#"<desc ent='ent'><p>
 The absolute path for this file from the web server's root or point
 of view including query variables.
</p></desc>",

"&page.last-true;":#"<desc ent='ent'><p>
 Is \"1\" if the last <tag>if</tag>-statement succeeded, otherwise 0.
 (<xref href='../if/true.tag' /> and <xref href='../if/false.tag' />
 is considered as <tag>if</tag>-statements here) See also: <xref
 href='../if/' />.</p>
</desc>",

"&page.language;":#"<desc ent='ent'><p>
 What language the contents of this file is written in. The language
 must be given as metadata to be found.
</p></desc>",

"&page.scope;":#"<desc ent='ent'><p>
 The name of the current scope, i.e. the scope accessible through the
 name \"_\".
</p></desc>",

"&page.filesize;":#"<desc ent='ent'><p>
 This file's size, in bytes.
</p></desc>",

"&page.ssl-strength;":#"<desc ent='ent'><p>
 The strength in bits of the current SSL connection.
</p></desc>",

"&page.self;":#"<desc ent='ent'><p>
 The name of this file.
</p></desc>",

"&page.dir;":#"<desc ent='ent'><p>
 The name of the directory in the virtual filesystem where the file resides.
</p></desc>",

//----------------------------------------------------------------------

"&form;":#"<desc scope='scope'><p><short hide='hide'>
 This scope contains form variables.</short>This scope contains the
 form variables, i.e. the answers to HTML forms sent by the client.
 There are no predefined entities for this scope.
</p></desc>",

//----------------------------------------------------------------------

"&cookie;":#"<desc scope='scope'><p><short>
 This scope contains the cookies sent by the client.</short> Adding,
 deleting or changing in this scope updates the clients cookies. There
 are no predefined entities for this scope. When adding cookies to
 this scope they are automatically set to expire after two years.
</p></desc>",

//----------------------------------------------------------------------

"&var;":#"<desc scope='scope'><p><short>
 This scope is empty when the page parsing begins.</short> There are
 no predefined entities for this
</p></desc>",

//----------------------------------------------------------------------

"roxen_automatic_charset_variable":#"<desc tag='tag'><p>
 If put inside a form, the right character encoding of the submitted
 form can be guessed by Roxen WebServer.
</p></desc>",

//----------------------------------------------------------------------

"colorscope":#"<desc cont='cont'><p><short>
 Makes it possible to change the autodetected colors within the tag.
 Useful when out-of-order parsing occurs, e.g.</p>

<ex type=box>
<define tag=\"hello\">
  <colorscope bgcolor=\"red\">
    <gtext>Hello</gtext>
  </colorscope>
</define>

<table><tr>
  <td bgcolor=\"red\">
    <hello/>
  </td>
</tr></table>
</ex>
</desc>

<attr name='text' value='color'><p>
 Set the text color within the scope.</p>
</attr>

<attr name='bgcolor' value='color'<p>
 Set the background color within the scope.</p>
</attr>

<attr name='link' value='color'<p>
 Set the link color within the scope.</p>
</attr>

<attr name='alink' value='color'<p>
 Set the active link color within the scope.</p>
</attr>

<attr name='vlink' value='color'<p>
 Set the visited link color within the scope.</p>
</attr>",

//----------------------------------------------------------------------

"aconf":#"<desc cont='cont'><p><short>
 Creates a link that can modify the persistent states in the cookie
 RoxenConfig.</short> In practice it will add &lt;keyword&gt;/ right
 after the server, i.e. if you want to remove bacon and add egg the
 first \"directory\" in the path will be &lt;-bacon,egg&gt;. If the
 user follows this link the WebServer will understand how the
 RoxenConfig cookie should be modified and will send a new cookie
 along with a redirect to the given url, but with the first
 \"directory\" removed. The presence of a certain keyword in can be
 controlled with <xref href='../if/if_config.tag' />.</p>
</desc>

<attr name=href value=uri>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name=add value=string>
 <p>The \"cookie\" or \"cookies\" that should be added, in a comma
 separated list.</p>
</attr>

<attr name=drop value=string>
 <p>The \"cookie\" or \"cookies\" that should be dropped, in a comma
 separated list.</p>
</attr>

<attr name=class value=string>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>

 <p>All other attributes will be inherited by the generated a tag.</p>
</attr>",

//----------------------------------------------------------------------

"append":#"<desc tag='tag'><p><short>
 Appends a value to a variable. The variable attribute and one more is
 required.</short>
</p></desc>

<attr name=variable value=string required='required'>
 <p>The name of the variable.</p>
</attr>

<attr name=value value=string>
 <p>The value the variable should have appended.</p>

 <ex>
 <set variable='var.ris' value='Roxen'/>
 <append variable='var.ris' value=' Internet Software'/>
 <ent>var.ris</ent>
 </ex>
</attr>

<attr name=from value=string>
 <p>The name of another variable that the value should be copied
 from.</p>
</attr>",

//----------------------------------------------------------------------

"apre":#"<desc cont='cont'><p><short>

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

<attr name=href value=uri>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name=add value=string>
 <p>The prestate or prestates that should be added, in a comma
 separated list.</p>
</attr>

<attr name=drop value=string>
 <p>The prestate or prestates that should be dropped, in a comma separated
 list.</p>
</attr>

<attr name=class value=string>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>
</attr>",

//----------------------------------------------------------------------

"auth-required":#"<desc tag='tag'><p><short>
 Adds an HTTP auth required header and return code (401), that will
 force the user to supply a login name and password.</short> This tag
 is needed when using access control in RXML in order for the user to
 be prompted to login.
</p></desc>

<attr name=realm value=string>
 <p>The realm you are logging on to, i.e \"Demolabs Intranet\".</p>
</attr>

<attr name=message value=string>
 <p>Returns a message if a login failed or cancelled.</p>
</attr>",

//----------------------------------------------------------------------

"autoformat":#"<desc cont='cont'><p><short hide='hide'>
 Replaces newlines with <tag>br/</tag>:s'.</short>Replaces newlines with
 <tag>br /</tag>:s'.</p>

<ex><autoformat>
It is almost like
using the pre tag.
</autoformat></ex>
</desc>

<attr name=p>
 <p>Replace empty lines with <tag>p</tag>:s.</p>
<ex><autoformat p=''>
It is almost like

using the pre tag.
</autoformat></ex>
</attr>

<attr name=nobr>
 <p>Do not replace newlines with <tag>br /</tag>:s.</p>
</attr>

<attr name=nonbsp><p>
 Do not turn consecutive spaces into interleaved
 breakable/nonbreakable spaces. When this attribute is not given, the
 tag will behave more or less like HTML:s <tag>pre</tag> tag, making
 whitespace indention work, without the usually unwanted effect of
 really long lines extending the browser window width.</p>
</attr>

<attr name=class value=string>
 <p>This cascading style sheet (CSS) definition will be applied on the
 p elements.</p>
</attr>",

//----------------------------------------------------------------------

"cache":#"<desc cont='cont'><p><short>
 This simple tag RXML parse its contents and cache them using the
 normal Roxen memory cache.</short> They key used to store the cached
 contents is the MD5 hash sum of the contents, the accessed file name,
 the query string, the server URL and the authentication information,
 if available. This should create an unique key. The time during which the
 entry should be considered valid can set with one or several time attributes.
 If not provided the entry will be removed from the cache when it has
 been untouched for too long.
</p></desc>

<attr name=key value=string>
 <p>Append this value to the hash used to identify the contents for less
 risk of incorrect caching. This shouldn't really be needed.</p>
</attr>

<attr name=nohash>
 <p>The cached entry will use only the provided key as cache key.</p>
</attr>

<attr name=years value=number>
 <p>Add this number of years to the time this entry is valid.</p>
</attr>
<attr name=months value=number>
 <p>Add this number of months to the time this entry is valid.</p>
</attr>
<attr name=weeks value=number>
 <p>Add this number of weeks to the time this entry is valid.</p>
</attr>
<attr name=days value=number>
 <p>Add this number of days to the time this entry is valid.</p>
</attr>
<attr name=hours value=number>
 <p>Add this number of hours to the time this entry is valid.</p>
</attr>
<attr name=beats value=number>
 <p>Add this number of beats to the time this entry is valid.</p>
</attr>
<attr name=minutes value=number>
 <p>Add this number of minutes to the time this entry is valid.</p>
</attr>
<attr name=seconds value=number>
 <p>Add this number of seconds to the time this entry is valid.</p>
</attr>",

//----------------------------------------------------------------------

"catch":#"<desc cont='cont'><p><short>
 Evaluates the RXML code, and, if nothing goes wrong, returns the
 parsed contents.</short> If something does go wrong, the error
 message is returned instead. See also <xref
 href='throw.tag' />.
</p>
</desc>",

//----------------------------------------------------------------------

"charset":#"<desc cont='cont'><p><short>
 </short>

 </p>
</desc>",

//----------------------------------------------------------------------

"configimage":#"<desc tag='tag'><p><short>
 Returns one of the internal Roxen configuration images.</short> The
 src attribute is required.
</p></desc>

<attr name=src value=string>
 <p>The name of the picture to show.</p>
</attr>

<attr name=border value=number default=0>
 <p>The image border when used as a link.</p>
</attr>

<attr name=alt value=string default='The src string'>
 <p>The picture description.</p>
</attr>

<attr name=class value=string>
 <p>This cascading style sheet (CSS) class definition will be applied to
 the image.</p>

 <p>All other attributes will be inherited by the generated img tag.</p>
</attr>",

//----------------------------------------------------------------------

"configurl":#"<desc tag='tag'><p><short>
 Returns a URL to the administration interface.</short>
</p></desc>",

//----------------------------------------------------------------------

"cset":#"<desc cont='cont'><p>
 Sets a variable with its content.</p>
</desc>

<attr name=variable value=name>
 <p>The variable to be set.</p>
</attr>

<attr name=quote value=html|none>
 <p>How the content should be quoted before assigned to the variable.
 Default is html.</p>
</attr>",

//----------------------------------------------------------------------

"crypt":#"<desc cont='cont'><p><short>
 Encrypts the contents as a Unix style password.</short> Useful when
 combined with services that use such passwords.</p>

 <p>Unix style passwords are one-way encrypted, to prevent the actual
 clear-text password from being stored anywhere. When a login attempt
 is made, the password supplied is also encrypted and then compared to
 the stored encrypted password.</p>
</desc>

<attr name=compare value=string>
 <p>Compares the encrypted string with the contents of the tag. The tag
 will behave very much like an <xref href='../if/if.tag' /> tag.</p>
<ex><crypt compare=\"LAF2kkMr6BjXw\">Roxen</crypt>
<then>Yepp!</then>
<else>Nope!</else>
</ex>
</attr>",

//----------------------------------------------------------------------

"date":#"<desc tag='tag'><p><short>
 Inserts the time and date.</short> Does not require attributes.
</p></desc>

<attr name=unix-time value=number of seconds>
 <p>Display this time instead of the current. This attribute uses the
 specified Unix 'time_t' time as the starting time (which is
 <i>01:00, January the 1st, 1970</i>), instead of the current time.
 This is mostly useful when the <tag>date</tag> tag is used from a
 Pike-script or Roxen module.</p>

<ex ><date unix-time='120'/></ex>
</attr>

<attr name=timezone value=local|GMT default=local>
 <p>Display the time from another timezone.</p>
</attr>

<attr name=years value=number>
 <p>Add this number of years to the result.</p>
 <ex ><date date='' years='2'/></ex>
</attr>

<attr name=months value=number>
 <p>Add this number of months to the result.</p>
 <ex ><date date='' months='2'/></ex>
</attr>

<attr name=weeks value=number>
 <p>Add this number of weeks to the result.</p>
 <ex ><date date='' weeks='2'/></ex>
</attr>

<attr name=days value=number>
 <p>Add this number of days to the result.</p>
</attr>

<attr name=hours value=number>
 <p>Add this number of hours to the result.</p>
 <ex ><date time='' hours='2' type='iso'/></ex>
</attr>

<attr name=beats value=number>
 <p>Add this number of beats to the result.</p>
 <ex ><date time='' beats='10' type='iso'/></ex>
</attr>

<attr name=minutes value=number>
 <p>Add this number of minutes to the result.</p>
</attr>

<attr name=seconds value=number>
 <p>Add this number of seconds to the result.</p>
</attr>

<attr name=adjust value=number>
 <p>Add this number of seconds to the result.</p>
</attr>

<attr name=brief>
 <p>Show in brief format.</p>
<ex ><date brief=''/></ex>
</attr>

<attr name=time>
 <p>Show only time.</p>
<ex ><date time=''/></ex>
</attr>

<attr name=date>
 <p>Show only date.</p>
<ex ><date date=''/></ex>
</attr>

<attr name=type value=string|ordered|iso|discordian|stardate|number|unix>
 <p>Defines in which format the date should be displayed in. Discordian
 and stardate only make a difference when not using part. Note that
 type=stardate has a separate companion attribute, prec, which sets
 the precision.</p>

<xtable>
<row><c><p><i>type=discordian</i></p></c><c><p><ex ><date date='' type='discordian'/> </ex></p></c></row>
<row><c><p><i>type=iso</i></p></c><c><p><ex ><date date='' type='iso'/></ex></p></c></row>
<row><c><p><i>type=number</i></p></c><c><p><ex ><date date='' type='number'/></ex></p></c></row>
<row><c><p><i>type=ordered</i></p></c><c><p><ex ><date date='' type='ordered'/></ex></p></c></row>
<row><c><p><i>type=stardate</i></p></c><c><p><ex ><date date='' type='stardate'/></ex></p></c></row>
<row><c><p><i>type=string</i></p></c><c><p><ex ><date date='' type='string'/></ex></p></c></row>
<row><c><p><i>type=unix</i></p></c><c><p><ex ><date date='' type='unix'/></ex></p></c></row>
</xtable>
</attr>

<attr name=part value=year|month|day|wday|date|mday|hour|minute|second|yday|beat|week|seconds>
 <p>Defines which part of the date should be displayed. Day and wday is
 the same. Date and mday is the same. Yday is the day number of the
 year. Seconds is unix time type. Only the types string, number and
 ordered applies when the part attribute is used.</p>

<xtable>
<row><c><p><i>part=year</i></p></c><c><p>Display the year.<ex ><date part='year' type='number'/></ex></p></c></row>
<row><c><p><i>part=month</i></p></c><c><p>Display the month. <ex ><date part='month' type='ordered'/></ex></p></c></row>
<row><c><p><i>part=day</i></p></c><c><p>Display the weekday, starting with Sunday. <ex ><date part='day' type='ordered'/></ex></p></c></row>
<row><c><p><i>part=wday</i></p></c><c><p>Display the weekday. Same as 'day'. <ex ><date part='wday' type='string'/></ex></p></c></row>
<row><c><p><i>part=date</i></p></c><c><p>Display the day of this month. <ex ><date part='date' type='ordered'/></ex></p></c></row>
<row><c><p><i>part=mday</i></p></c><c><p>Display the number of days since the last full month. <ex ><date part='mday' type='number'/></ex></p></c></row>
<row><c><p><i>part=hour</i></p></c><c><p>Display the numbers of hours since midnight. <ex ><date part='hour' type='ordered'/></ex></p></c></row>
<row><c><p><i>part=minute</i></p></c><c><p>Display the numbers of minutes since the last full hour. <ex ><date part='minute' type='number'/></ex></p></c></row>
<row><c><p><i>part=second</i></p></c><c><p>Display the numbers of seconds since the last full minute. <ex ><date part='second' type='string'/></ex></p></c></row>
<row><c><p><i>part=yday</i></p></c><c><p>Display the number of days since the first of January. <ex ><date part='yday' type='ordered'/></ex></p></c></row>
<row><c><p><i>part=beat</i></p></c><c><p>Display the number of beats since midnight Central European Time(CET). There is a total of 1000 beats per day. The beats system was designed by <a href='http://www.swatch.com'>Swatch</a> as a means for a universal time, without time zones and day/night changes. <ex ><date part='beat' type='number'/></ex></p></c></row>
<row><c><p><i>part=week</i></p></c><c><p>Display the number of the current week.<ex ><date part='week' type='number'/></ex></p></c></row>
<row><c><p><i>part=seconds</i></p></c><c><p>Display the total number of seconds this year. <ex ><date part='seconds' type='number'/></ex></p></c></row>
</xtable>
</attr>

<attr name=strftime value=string>
 <p>If this attribute is given to date, it will format the result
 according to the argument string.</p>

 <xtable>
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

<ex><date strftime=\"%Y%m%d\"/></ex>
</attr>

<attr name=lang value=langcode>
 <p>Defines in what language a string will be presented in. Used together
 with <att>type=string</att> and the <att>part</att> attribute to get
 written dates in the specified language.</p>

<ex><date part='day' type='string' lang='de'></ex>
</attr>

<attr name=case value=upper|lower|capitalize>
 <p>Changes the case of the output to upper, lower or capitalize.</p>
<ex><date date='' lang='&client.language;' case='upper'/></ex>
</attr>

<attr name=prec value=number>
 <p>The number of decimals in the stardate.</p>
</attr>",

//----------------------------------------------------------------------

"debug":#"<desc tag='tag'><p><short>
 Helps debugging RXML-pages as well as modules.</short> When debugging mode is
 turned on, all error messages will be displayed in the HTML code.
</p></desc>

<attr name=on>
 <p>Turns debug mode on.</p>
</attr>

<attr name=off>
 <p>Turns debug mode off.</p>
</attr>

<attr name=toggle>
 <p>Toggles debug mode.</p>
</attr>

<attr name=showid value=string>
 <p>Shows a part of the id object. E.g. showid=\"id->request_headers\".</p>
</attr>

<attr name=werror value=string>
  <p>When you have access to the server debug log and want your RXML
     page to write some kind of diagnostics message or similar, the
     werror attribute is helpful.</p>

  <p>This can be used on the error page, for instance, if you'd want
     such errors to end up in the debug log:</p>

  <ex type=box>
<debug werror='File &page.url; not found!
(linked from &client.referrer;)'/></ex>
</attr>",

//----------------------------------------------------------------------

"dec":#"<desc tag='tag'><p><short>
 Subtracts 1 from a variable.</short>
</p></desc>

<attr name=variable value=string required='required'>
 <p>The variable to be decremented.</p>
</attr>

<attr name=value value=number default=1>
 <p>The value to be subtracted.</p>
</attr>",

//----------------------------------------------------------------------

"default":#"<desc cont='cont'><p><short hide='hide'>
 Used to set default values for form elements.</short> This tag makes it easier
 to give default values to \"<tag>select</tag>\" and \"<tag>input</tag>\" form elements.
 Simply put the <tag>default</tag> tag around the form elements to which it should give
 default values.</p>

 <p>This tag is particularly useful in combination with generated forms or forms with
 generated default values, e.g. by database tags.</p>
</desc>

<attr name=value value=string>
 <p>The value or values to set. If several values are given, they are separated with the
 separator string.</p>
</attr>

<attr name=separator value=string default=','>
 <p>If several values are to be selected, this is the string that
 separates them.</p>
</attr>

<attr name=name value=string>
 <p>If used, the default tag will only affect form element with this name.</p>
</attr>

<ex type='box'>
 <default name='my-select' value='&form.preset;'>
    <select name='my-select'>
      <option value='1'>First</option>
      <option value='2'>Second</option>
      <option value='3'>Third</option>
    </select>
 </default>
</ex>

<ex type='box'>
<form>
<default value=\"&form.opt1;,&form.opt2;,&form.opt3;\">
  <input name=\"opt1\" value=\"yes1\" type=\"checkbox\" /> Option #1
  <input name=\"opt2\" value=\"yes2\" type=\"checkbox\" /> Option #2
  <input name=\"opt3\" value=\"yes3\" type=\"checkbox\" /> Option #3
  <input type=\"submit\" />
</default>
</form>
",

"doc":#"<desc cont='cont'><p><short hide='hide'>
 Eases code documentation by reformatting it.</short>Eases
 documentation by replacing \"{\", \"}\" and \"&amp;\" with
 \"&amp;lt;\", \"&amp;gt;\" and \"&amp;amp;\". No attributes required.
</p></desc>

<attr name='quote'>
 <p>Instead of replacing with \"{\" and \"}\", \"&lt;\" and \"&gt;\"
 is replaced with \"&amp;lt;\" and \"&amp;gt;\".</p>

<ex type='vert'>
<doc quote=''>
<table>
 <tr>
    <td> First cell </td>
    <td> Second cell </td>
 </tr>
</table>
</doc>
</ex>
</attr>

<attr name='pre'><p>
 The result is encapsulated within a <tag>pre</tag> container.</p>

<ex type='vert'><doc pre=''>
{table}
 {tr}
    {td} First cell {/td}
    {td} Second cell {/td}
 {/tr}
{/table}
</doc>
</ex>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the pre element.</p>
</attr>",

//----------------------------------------------------------------------

"expire-time":#"<desc tag='tag'><p><short hide='hide'>
 Sets client cache expire time for the document.</short>Sets client cache expire time for the document by sending the HTTP header \"Expires\".
</p></desc>

<attr name=now>
  <p>Notify the client that the document expires now. The headers \"Pragma: no-cache\" and \"Cache-Control: no-cache\"
  will be sent, besides the \"Expires\" header.</p>

</attr>

<attr name=years value=number>
 <p>Add this number of years to the result.</p>
</attr>

<attr name=months value=number>
  <p>Add this number of months to the result.</p>
</attr>

<attr name=weeks value=number>
  <p>Add this number of weeks to the result.</p>
</attr>

<attr name=days value=number>
  <p>Add this number of days to the result.</p>
</attr>

<attr name=hours value=number>
  <p>Add this number of hours to the result.</p>
</attr>

<attr name=beats value=number>
  <p>Add this number of beats to the result.</p>
</attr>

<attr name=minutes value=number>
  <p>Add this number of minutes to the result.</p>
</attr>

<attr name=seconds value=number>
   <p>Add this number of seconds to the result.</p>

 <p>It is not possible at the time to set the date beyond year 2038,
 since Unix variable <i>time_t</i> data type is used. The <i>time_t</i> data type stores the number of seconds elapsed since 00:00:00 January 1, 1970 UTC. </p>
</attr>",

//----------------------------------------------------------------------

"for":#"<desc cont='cont'><p><short>
 Makes it possible to create loops in RXML.</short>
</p></desc>

<attr name=from value=number>
 <p>Initial value of the loop variable.</p>
</attr>

<attr name=step value=number>
 <p>How much to increment the variable per loop iteration. By default one.</p>
</attr>

<attr name=to value=number>
 <p>How much the loop variable should be incremented to.</p>
</attr>

<attr name=variable value=name>
 <p>Name of the loop variable.</p>
</attr>",

//----------------------------------------------------------------------

"fsize":#"<desc tag='tag'><p><short>
 Prints the size of the specified file.</short>
</p></desc>

<attr name=file value=string>
 <p>Show size for this file.</p>
</attr>",

//----------------------------------------------------------------------

"gauge":#"<desc cont='cont'><p><short>
 Measures how much CPU time it takes to run its contents through the
 RXML parser.</short> Returns the number of seconds it took to parse
 the contents.
</p></desc>

<attr name=define value=string>
 <p>The result will be put into a variable. E.g. define=\"var.gauge\" will
 put the result in a variable that can be reached with <ent>var.gauge</ent>.</p>
</attr>

<attr name=silent>
 <p>Don't print anything.</p>
</attr>

<attr name=timeonly>
 <p>Only print the time.</p>
</attr>

<attr name=resultonly>
 <p>Only print the result of the parsing. Useful if you want to put the time in
 a database or such.</p>
</attr>",

//----------------------------------------------------------------------

"header":#"<desc tag='tag'><p><short>
 Adds a HTTP header to the page sent back to the client.</short> For
 more information about HTTP headers please steer your browser to
 chapter 14, 'Header field definitions' in <a href='http://community.roxen.com/developers/idocs/rfc/rfc2616.html'>RFC 2616</a>, available at Roxen Community.
</p></desc>

<attr name=name value=string>
 <p>The name of the header.</p>
</attr>

<attr name=value value=string>
 <p>The value of the header.</p>
</attr>",

//----------------------------------------------------------------------

"imgs":#"<desc tag='tag'><p><short>
 Generates a image tag with the correct dimensions in the width and height
 attributes. These dimensions are read from the image itself, so the image
 must exist when the tag is generated. The image must also be in GIF, JPEG/JFIF
 or PNG format.</short>
</p></desc>

<attr name=src value=string required='required'>
 <p>The path to the file that should be shown.</p>
</attr>

<attr name=alt value=string>
 <p>Description of the image. If no description is provided, the filename
 (capitalized, without extension and with some characters replaced) will
 be used.</p>
 </attr>

 <p>All other attributes will be inherited by the generated img tag.</p>",

//----------------------------------------------------------------------

"inc":#"<desc tag='tag'><p><short>
 Adds 1 to a variable.</short>
</p></desc>

<attr name=variable value=string required='required'>
 <p>The variable to be incremented.</p>
</attr>

<attr name=value value=number default=1>
 <p>The value to be added.</p>
</attr>",

//----------------------------------------------------------------------

"insert":#"<desc tag='tag'><p><short>
 Inserts a file, variable or other object into a webpage.</short>
</p></desc>

<attr name=quote value=html|none>
 <p>How the inserted data should be quoted. Default is \"html\", except for
 href and file where it's \"none\".</p>
</attr>",

//----------------------------------------------------------------------

"insert#variable":#"<desc plugin='plugin'><p><short>
 Inserts the value of a variable.</short>
</p></desc>

<attr name=variable value=string>
 <p>The name of the variable.</p>
</attr>

<attr name=scope value=string>
 <p>The name of the scope, unless given in the variable attribute.</p>
</attr>

<attr name=index value=number>
 <p>If the value of the variable is an array, the element with this
 index number will be inserted. 1 is the first element. -1 is the last
 element.</p>
</attr>

<attr name=split value=string>
 <p>A string with which the variable value should be splitted into an
 array, so that the index attribute may be used.</p>
</attr>",

//----------------------------------------------------------------------

"insert#variables":#"<desc plugin='plugin'><p><short>
 Inserts a listing of all variables in a scope.</short> Note that it is
 possible to create a scope with an infinite number of variables set.
 In this case the programme of that scope decides which variables that
 should be listable, i.e. this will not cause any problem except that
 all variables will not be listed. It is also possible to hide
 variables so that they are not listed with this tag.
</p></desc>

<attr name=variables value=full|plain>
 <p>Sets how the output should be formatted.</p>

 <ex type='vert'>
<pre>
<insert variables='full' scope='roxen'/>
</pre>
 </ex>
</attr>

<attr name=scope>
 <p>The name of the scope that should be listed, if not the present scope.</p>
</attr>",

//----------------------------------------------------------------------

"insert#scopes":#"<desc plugin='plugin'><p><short>
 Inserts a listing of all present variable scopes.</short>
</p></desc>

<attr name=scopes value=full|plain>
 <p>Sets how the output should be formatted.</p>

 <ex type='vert'>
   <insert scopes='plain'/>
 </ex>
</attr>",

//----------------------------------------------------------------------

"insert#file":#"<desc plugin='plugin'><p><short>
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

<attr name=file value=string>
 <p>The virtual path to the file to be inserted.</p>

 <ex type='box'>
  <eval><insert file='html_header.inc'/></eval>
 </ex>
</attr>",

//----------------------------------------------------------------------

"insert#realfile":#"<desc plugin='plugin'><p><short>
 Inserts a raw, unparsed file.</short> The disadvantage with the
 realfile plugin compared to the file plugin is that the realfile
 plugin needs the inserted file to exist, and can't fetch files from e.g.
 an arbitrary location module. Note that the realfile insert plugin
 can not fetch files from outside the virtual file system.
</p></desc>

<attr name=realfile value=string>
 <p>The virtual path to the file to be inserted.</p>
</attr>",

//----------------------------------------------------------------------

"maketag":({ #"<desc cont='cont'><p><short hide='hide'>
 Makes it possible to create tags.</short>This tag creates tags. The contents of the container will be put into the contents of the produced container.
</p></desc>

<attr name=name value=string required='required'>
 <p>The name of the tag.</p>
</attr>

<attr name=noxml>
 <p>Tags should not be terminated with a trailing slash.</p>
</attr>

<attr name=type value=tag|container|pi default=tag>
 <p>What kind of tag should be produced. The argument 'Pi' will produce a processinstruction tag. </p>
</attr>",

 ([
   "attrib":#"<desc cont='cont'><p>
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
   <attr name=name value=string required=required><p>
   The name of the attribute.</p>
   </attr>"
 ])
   }),

//----------------------------------------------------------------------

"modified":#"<desc tag='tag'><p><short hide='hide'>
 Prints when or by whom a page was last modified.</short> Prints when
 or by whom a page was last modified, by default the current page.
</p></desc>

<attr name=by>
 <p>Print by whom the page was modified. Takes the same attributes as
 <xref href='user.tag' />. This attribute requires a userdatabase.
 </p>

 <ex type='box'>This page was last modified by <modified by=''
 realname=''/>.</ex>
</attr>

<attr name=date>
    <p>Print the modification date. Takes all the date attributes in <xref href='date.tag' />.</p>

 <ex type='box'>This page was last modified <modified date=''
 case='lower' type='string'/>.</ex>
</attr>

<attr name=file value=path>
 <p>Get information from this file rather than the current page.</p>
</attr>

<attr name=realfile value=path>
 <p>Get information from this file in the computers filesystem rather
 than Roxen Webserver's virtual filesystem.</p>
</attr>",

//----------------------------------------------------------------------

"random":#"<desc cont='cont'><p><short>
 Randomly chooses a message from its contents.</short>
</p></desc>

<attr name='separator' value='string'>
 <p>The separator used to separate the messages, by default newline.</p>

<ex><random separator='#'>
Roxen#Pike#Foo#Bar#roxen.com
</random>
</ex>

<attr name='seed' value='string'>
Enables you to use a seed that determines which message to choose.
</attr>
",

//----------------------------------------------------------------------

"redirect":#"<desc tag='tag'><p><short hide='hide'>
 Redirects the user to another page.</short> Redirects the user to
 another page by sending a HTTP redirect header to the client.
</p></desc>

<attr name=to value=URL required='required'>
 <p>The location to where the client should be sent.</p>
</attr>

<attr name=add value=string>
 <p>The prestate or prestates that should be added, in a comma separated
 list.</p>
</attr>

<attr name=drop value=string>
 <p>The prestate or prestates that should be dropped, in a comma separated
 list.</p>
</attr>

<attr name=text value=string>
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

"remove-cookie":#"<desc tag='tag'><p><short>
 Sets the expire-time of a cookie to a date that has already occured.
 This forces the browser to remove it.</short>
 This tag won't remove the cookie, only set it to the empty string, or
 what is specified in the value attribute and change
 it's expire-time to a date that already has occured. This is
 unfortunutaly the only way as there is no command in HTTP for
 removing cookies. We have to give a hint to the browser and let it
 remove the cookie.
</p></desc>

<attr name=name>
 <p>Name of the cookie the browser should remove.</p>
</attr>

<attr name=value value=text>
 <p>Even though the cookie has been marked as expired some browsers
 will not remove the cookie until it is shut down. The text provided
 with this attribute will be the cookies intermediate value.</p>

 <p>Note that removing a cookie won't take effect until the next page
load.</p>

</attr>",

//----------------------------------------------------------------------

"replace":#"<desc cont='cont'><p><short>
 Replaces strings in the contents with other strings.</short>
</p></desc>

<attr name=from value=string required='required'>
 <p>String or list of strings that should be replaced.</p>
</attr>

<attr name=to value=string>
 <p>String or list of strings with the replacement strings. Default is the
 empty string.</p>
</attr>

<attr name=separator value=string default=','>
 <p>Defines what string should separate the strings in the from and to
 attributes.</p>
</attr>

<attr name=type value=word|words default=word>
 <p>Word means that a single string should be replaced. Words that from
 and to are lists.</p>
</attr>",

//----------------------------------------------------------------------

"return":#"<desc tag='tag'><p><short>
 Changes the HTTP return code for this page. </short>
 <!-- See the Appendix for a list of HTTP return codes. (We have no appendix) -->
</p></desc>

<attr name=code value=integer>
 <p>The HTTP status code to return.</p>
</attr>

<attr name=text>
 <p>The HTTP status message to set. If you don't provide one, a default
 message is provided for known HTTP status codes, e g \"No such file
 or directory.\" for code 404.</p>
</attr>",

//----------------------------------------------------------------------

"roxen":#"<desc tag='tag'><p><short>
 Returns a nice Roxen logo.</short>
</p></desc>

<attr name=size value=small|medium|large default=medium>
 <p>Defines the size of the image.</p>
<ex type='vert'><roxen size='small'/> <roxen/> <roxen size='large'/></ex>
</attr>

<attr name=color value=black|white default=white>
 <p>Defines the color of the image.</p>
<ex type='vert'><roxen color='black'/></ex>
</attr>

<attr name=alt value=string default='\"Powered by Roxen\"'>
 <p>The image description.</p>
</attr>

<attr name=border value=number default=0>
 <p>The image border.</p>
</attr>

<attr name=class value=string>
 <p>This cascading style sheet (CSS) definition will be applied on the img element.</p>
</attr>

<attr name=target value=string>
 <p>Names a target frame for the link around the image.</p>

 <p>All other attributes will be inherited by the generated img tag.</p>
</attr> ",

//----------------------------------------------------------------------

"scope":#"<desc cont='cont'><p><short>
 Creates a new variable scope.</short> Variable changes inside the scope
 container will not affect variables in the rest of the page.
</p></desc>

<attr name=extend value=name default=form>
 <p>If set, all variables in the selected scope will be copied into
 the new scope. NOTE: if the source scope is \"magic\", as e.g. the
 roxen scope, the scope will not be copied, but rather linked and will
 behave as the original scope. It can be useful to create an alias or
 just for the convinience of refering to the scope as \"_\".</p>
</attr>

<attr name=scope value=name default=form>
 <p>The name of the new scope, besides \"_\".</p>
</attr>",

//----------------------------------------------------------------------

"set":#"<desc tag='tag'><p><short>
 Sets a variable.</short>
</p></desc>

<attr name=variable value=string required='required'>
 <p>The name of the variable.</p>
<ex type='box'>
<set variable='var.foo' value='bar'/>
</ex>
</attr>

<attr name=value value=string>
 <p>The value the variable should have.</p>
</attr>

<attr name=expr value=string>
 <p>An expression whose evaluated value the variable should have.</p>
</attr>

<attr name=from value=string>
 <p>The name of another variable that the value should be copied from.</p>
</attr>

<attr name=split value=string>
 <p>The value will be splitted by this string into an array.</p>

 <p>If none of the above attributes are specified, the variable is unset.
 If debug is currently on, more specific debug information is provided
 if the operation failed. See also: <xref href='append.tag' /> and <xref href='../programming/debug.tag' />.</p>
</attr> ",

//----------------------------------------------------------------------

"copy-scope":#"<desc tag='tag'><p><short>
 Copies the content of one scope into another scope</short></p>

<attr name='from' value='scope name' required='1'>
 <p>The name of the scope the variables are copied from.</p>
</attr>

<attr name='to' value='scope name' required='1'>
 <p>The name of the scope the variables are copied to.</p>
</attr>",

//----------------------------------------------------------------------

"set-cookie":#"<desc tag='tag'><p><short>
 Sets a cookie that will be stored by the user's browser.</short> This
 is a simple and effective way of storing data that is local to the
 user. If no arguments specifying the time the cookie should survive
 is given to the tag, it will live until the end of the current browser
 session. Otherwise, the cookie will be persistent, and the next time
 the user visits  the site, she will bring the cookie with her.
</p></desc>

<attr name=name value=string>
 <p>The name of the cookie.</p>
</attr>

<attr name=seconds value=number>
 <p>Add this number of seconds to the time the cookie is kept.</p>
</attr>

<attr name=minutes value=number>
 <p>Add this number of minutes to the time the cookie is kept.</p>
</attr>

<attr name=hours value=number>
 <p>Add this number of hours to the time the cookie is kept.</p>
</attr>

<attr name=days value=number>
 <p>Add this number of days to the time the cookie is kept.</p>
</attr>

<attr name=weeks value=number>
 <p>Add this number of weeks to the time the cookie is kept.</p>
</attr>

<attr name=months value=number>
 <p>Add this number of months to the time the cookie is kept.</p>
</attr>

<attr name=years value=number>
 <p>Add this number of years to the time the cookie is kept.</p>
</attr>

<attr name=persistent>
 <p>Keep the cookie for five years.</p>
</attr>

<attr name=domain>
 <p>The domain for which the cookie is valid.</p>
</attr>

<attr name=value value=string>
 <p>The value the cookie will be set to.</p>
</attr>

<attr name=path value=string default=\"/\"><p>
 The path in which the cookie should be available. Use path=\"\" to remove
 the path argument from the sent cookie, thus making the cookie valid only
 for the present directory and below.</p>
</attr>

 <p>Note that the change of a cookie will not take effect until the
 next page load.</p>
</attr>",

//----------------------------------------------------------------------

"set-max-cache":#"<desc tag='tag'><p><short>
 Sets the maximum time this document can be cached in any ram
 caches.</short></p>

 <p>Default is to get this time from the other tags in the document
 (as an example, <xref href='../if/if_supports.tag' /> sets the time to
 0 seconds since the result of the test depends on the client used.</p>

 <p>You must do this at the end of the document, since many of the
 normal tags will override this value.</p>
</desc>

<attr name=years value=number>
 <p>Add this number of years to the time this page was last loaded.</p>
</attr>
<attr name=months value=number>
 <p>Add this number of months to the time this page was last loaded.</p>
</attr>
<attr name=weeks value=number>
 <p>Add this number of weeks to the time this page was last loaded.</p>
</attr>
<attr name=days value=number>
 <p>Add this number of days to the time this page was last loaded.</p>
</attr>
<attr name=hours value=number>
 <p>Add this number of hours to the time this page was last loaded.</p>
</attr>
<attr name=beats value=number>
 <p>Add this number of beats to the time this page was last loaded.</p>
</attr>
<attr name=minutes value=number>
 <p>Add this number of minutes to the time this page was last loaded.</p>
</attr>
<attr name=seconds value=number>
 <p>Add this number of seconds to the time this page was last loaded.</p>
</attr>",

//----------------------------------------------------------------------

"smallcaps":#"<desc cont='cont'><p><short>
 Prints the contents in smallcaps.</short> If the size attribute is
 given, font tags will be used, otherwise big and small tags will be
 used.
</p>

<ex>
  <smallcaps>Roxen WebServer</smallcaps>
</ex>


  </desc>

<attr name=space>
 <p>Put a space between every character.</p>
<ex type='vert'>
<smallcaps space=''>Roxen WebServer</smallcaps>
</ex>
</attr>

<attr name=class value=string>
 <p>Apply this cascading style sheet (CSS) style on all elements.</p>
</attr>

<attr name=smallclass value=string>
 <p>Apply this cascading style sheet (CSS) style on all small elements.</p>
</attr>

<attr name=bigclass value=string>
 <p>Apply this cascading style sheet (CSS) style on all big elements.</p>
</attr>

<attr name=size value=number>
 <p>Use font tags, and this number as big size.</p>
</attr>

<attr name=small value=number default=size-1>
 <p>Size of the small tags. Only applies when size is specified.</p>

 <ex>
  <smallcaps size='6' small='2'>Roxen WebServer</smallcaps>
 </ex>
</attr>",

//----------------------------------------------------------------------

"sort":#"<desc cont='cont'><p><short>
 Sorts the contents.</short></p>

 <ex>
  <sort>
   1
   Hello
   3
   World
   Are
   2
   We
   4
   Communicating?
  </sort>
 </ex>
</desc>

<attr name=separator value=string>
 <p>Defines what the strings to be sorted are separated with. The sorted
 string will be separated by the string.</p>

 <ex type='vert'>
  <sort separator='#'>
   1#Hello#3#World#Are#2#We#4#Communicating?
  </sort>
 </ex>
</attr>

<attr name=reverse>
 <p>Reversed order sort.</p>

 <ex>
  <sort reverse=''>
   1
   Hello
   3
   World
   Are
   2
   We
   4
   Communicating?
  </sort>
 </ex>
</attr>",

//----------------------------------------------------------------------

"throw":#"<desc cont='cont'><p><short>
 Throws a text to be caught by <xref href='catch.tag' />.</short>
 Throws an exception, with the enclosed text as the error message.
 This tag has a close relation to <xref href='catch.tag' />. The
 RXML parsing will stop at the <tag>throw</tag> tag.
 </p></desc>",

//----------------------------------------------------------------------

"trimlines":#"<desc cont='cont'><p><short>
 Removes all empty lines from the contents.</short></p>

  <ex>
  <trimlines>


   Are


   We

   Communicating?


  </trimlines>
 </ex>
</desc>",

//----------------------------------------------------------------------

"unset":#"<desc tag='tag'><p><short>
 Unsets a variable, i.e. removes it.</short>
</p></desc>

<attr name=variable value=string required='required'>
 <p>The name of the variable.</p>

 <ex>
  <set variable='var.jump' value='do it'/>
  <ent>var.jump</ent>
  <unset variable='var.jump'/>
  <ent>var.jump</ent>
 </ex>
</attr>",

//----------------------------------------------------------------------

"user":#"<desc tag='tag'><p><short>
 Prints information about the specified user.</short> By default, the
 full name of the user and her e-mail address will be printed, with a
 mailto link and link to the home page of that user.</p>

 <p>The <tag>user</tag> tag requires an authentication module to work.</p>
</desc>

<attr name=email>
 <p>Only print the e-mail address of the user, with no link.</p>
 <ex type='box'>Email: <user name='foo' email=''/></ex>
</attr>

<attr name=link>
 <p>Include links. Only meaningful together with the realname or email attribute.</p>
</attr>

<attr name=name>
 <p>The login name of the user. If no other attributes are specified, the
 user's realname and email including links will be inserted.</p>
<ex type='box'><user name='foo'/></ex>
</attr>

<attr name=nolink>
 <p>Don't include the links.</p>
</attr>

<attr name=nohomepage>
 <p>Don't include homepage links.</p>
</attr>

<attr name=realname>
 <p>Only print the full name of the user, with no link.</p>
<ex type='box'><user name='foo' realname=''/></ex>
</attr>",

//----------------------------------------------------------------------

"if#expr":#"<desc plugin='plugin'><p><short>
 This plugin evaluates expressions.</short> The arithmetic operators
 are \"+, - and /\". The last main operator is \"%\"(per cent). The
 allowed relationship operators are \"&lt;. &gt;, ==, &lt;= and
 &gt;=\".</p>

 <p>All integers(characters 0 to 9) may be used together with
 \".\" to create floating point expressions.</p>

 <ex type='box'>
   Hexadecimal expression: (0xff / 5) + 3
 </ex>
 <p>To be able to evaluate hexadecimal expressions the characters \"a
 to f and A to F\" may be used.</p>

 <ex type='box'>
   Integer conversion: ((int) 3.14)
   Floating point conversion: ((float) 100 / 7)
 </ex>

 <p>Conversion between int and float may be done through the operators
 \"(int)\" and \"(float)\". The operators \"&amp;\"(bitwise and),
 \"|\"((pipe)bitwise or), \"&amp;&amp;\"(logical and) and \"||\"((double
 pipe)logical or) may also be used in expressions. To set
 prioritizations within expressions the characters \"( and )\" are
 included. General prioritization rules are:</p>

 <list type='ol'>
 <item><p>(int), (float)</p></item>
 <item><p>*, /, %</p></item>
 <item><p>+, -</p></item>
 <item><p>&lt;, &gt;, &lt;=, &gt;=\</p></item>
 <item><p>==</p></item>
 <item><p>&amp;, |</p></item>
 <item><p>&amp;&amp;, ||</p></item>
 </list>

 <ex type='box'>
   Octal expression: 045
 </ex>
 <ex type='box'>
   Calculator expression: 3.14e10 / 3
 </ex>
 <p>Expressions containing octal numbers may be used. It is also
 possible to evaluate calculator expressions.</p>

 <p>Expr is an <i>Eval</i> plugin.</p>
</desc>

<attr name='expr' value='expression'>
 <p>Choose what expression to test.</p>
</attr>",

//----------------------------------------------------------------------

"emit#fonts":({ #"<desc plugin='plugin'><p><short>
 Prints available fonts.</short> This plugin makes it easy to list all
 available fonts in Roxen WebServer.
</p></desc>

<attr name='type' value='ttf|all'>
 <p>Which font types to list. ttf means all true type fonts, whereas all
 means all available fonts.</p>
</attr>",
		([
"&_.name;":#"<desc ent='ent'><p>
 Returns a font identification name.</p>

<p>This example will print all available ttf fonts in gtext-style.</p>
<ex type='box'>
 <emit source='fonts' type='ttf'>
   <gtext font='&_.name;'><ent>_.expose</ent></gtext><br />
 </emit>
</ex>
</desc>",
"&_.copyright;":#"<desc ent='ent'><p>
 Font copyright notice. Only available for true type fonts.
</p></desc>",
"&_.expose;":#"<desc ent='ent'><p>
 The preferred list name. Only available for true type fonts.
</p></desc>",
"&_.family;":#"<desc ent='ent'><p>
 The font family name. Only available for true type fonts.
</p></desc>",
"&_.full;":#"<desc ent='ent'><p>
 The full name of the font. Only available for true type fonts.
</p></desc>",
"&_.path;":#"<desc ent='ent'><p>
 The location of the font file.
</p></desc>",
"&_.postscript;":#"<desc ent='ent'><p>
 The fonts postscript identification. Only available for true type fonts.
</p></desc>",
"&_.style;":#"<desc ent='ent'><p>
 Font style type. Only available for true type fonts.
</p></desc>",
"&_.format;":#"<desc ent='ent'><p>
 The format of the font file, e.g. ttf.
</p></desc>",
"&_.version;":#"<desc ent='ent'><p>
 The version of the font. Only available for true type fonts.
</p></desc>",
"&_.trademark;":#"<desc ent='ent'><p>
 Font trademark notice. Only available for true type fonts.
</p></desc>",
		])
	     }),

//----------------------------------------------------------------------

"case":#"<desc cont='cont'><p><short>
 Alters the case of the contents.</short>
</p></desc>

<attr name='case' value='upper|lower|capitalize' required='required'><p>
 Changes all characters to upper or lower case letters, or
 capitalizes the first letter in the content.</p>

<ex><case upper=''>upper</case></ex>
<ex><case lower=''>lower</case></ex>
<ex><case capitalize=''>capitalize</case></ex>
</attr>",

//----------------------------------------------------------------------

"cond":({ #"<desc cont='cont'><p><short>
 This tag makes a boolean test on a specified list of cases.</short>
 This tag is almost eqvivalent to the <xref href='../if/if.tag'
 />/<xref href='../if/else.tag' /> combination. The main difference is
 that the <tag>default</tag> tag may be put whereever you want it
 within the <tag>cond</tag> tag. This will of course affect the order
 the content is parsed. The <tag>case</tag> tag is required.</p>
</desc>",

	  (["case":#"<desc cont='cont'><p>
 This tag takes the argument that is to be tested and if it's true,
 it's content is executed before exiting the <tag>cond</tag>. If the
 argument is false the content is skipped and the next <tag>case</tag>
 tag is parsed.</p></desc>

<ex type='box'>
<cond>
 <case variable='form.action = edit'>
   some database edit code
 </case>
 <case variable='form.action = delete'>
   some database delete code
 </case>
 <default>
   view something from the database
 </default>
</cond>
</ex>",

	    "default":#"<desc cont='cont'><p>
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

"comment":#"<desc cont='cont'><p><short>
 The enclosed text will be removed from the document.</short> The
 difference from a normal SGML (HTML/XML) comment is that the text is
 removed from the document, and can not be seen even with <i>view
 source</i> in the browser.</p>

 <p>Note that since this is a normal tag, it requires that the content
 is properly formatted. Therefore it's ofter better to use the
 &lt;?comment&nbsp;...&nbsp;?&gt; processing instruction tag to
 comment out arbitrary text (which doesn't contain '?&gt;').</p>

 <p>Just like any normal tag, the <tag>comment</tag> tag nests inside
 other <tag>comment</tag> tags. E.g:</p>

 <ex type='box'>
   <comment> a <comment> b </comment> c </comment>
 </ex>

 <p>Here 'c' is not output since the comment starter before 'a'
 matches the ender after 'c' and not the one before it.</p>
</desc>

<attr name='preparse'>
 Parse and execute any RXML inside the comment tag. This can be used
 to do stuff without producing any output in the response. This is a
 compatibility argument; the recommended way is to use <ref
 type='tag'><tag>nooutput</tag> instead.
</attr>",

//----------------------------------------------------------------------

"?comment":#"<desc pi='pi'><p><short>
 Processing instruction tag for comments.</short> This tag is similar
 to the RXML <ref type='tag'><tag>comment</tag> tag but should be used
 when commenting arbitrary text that doesn't contain '?&gt;'.</p>

<ex type='box'>
<?comment
  This comment will not be shown.
?>
</ex>
</desc>",

//----------------------------------------------------------------------

// <cset> is deprecated. This information is to be put in a special
// 'deprecated' chapter in the manual, due to many persons asking
// about its whereabouts.
"cset":#"<desc tag='tag'><p><short>
 Deprecated in favor of <tag>define variable</tag></short> Deprecated
 in Roxen 2.0.
</p></desc>",

//----------------------------------------------------------------------

"define":({ #"<desc cont='cont'><p><short>

 Defines variables, tags, containers and if-callers.</short>
</p></desc>

<attr name='variable' value='name'><p>
 Sets the value of the variable to the contents of the container.</p>
</attr>

<attr name='tag' value='name'><p>
 Defines a tag that outputs the contents of the container.</p>

<ex><define tag=\"hi\">Hello <ent>_.name</ent>!</define>
<hi name=\"Martin\"/></ex>
</attr>

<attr name='container' value='name'><p>
 Defines a container that outputs the contents of the container.</p>
</attr>

<attr name='if' value='name'><p>
 Defines an if-caller that compares something with the contents of the
 container.</p>
</attr>

<attr name='trimwhites'><p>
 Trim all white space characters from the beginning and the end of the
 contents.</p>
</attr>

<attr name='preparse' value='preparse'><p>
 Sends the definition through the RXML parser when defining. (Without
 this attribute, the definition is only RXML parsed when it is invoked.)
</attr>

 <p>The values of the attributes given to the defined tag are
 available in the scope created within the define tag.</p>
",

	    ([
"attrib":#"<desc cont='cont'><p>
 When defining a tag or a container the container <tag>attrib</tag>
 can be used to define default values of the attributes that the
 tag/container can have.</p>
</desc>

 <attr name='name' value='name'><p>
  The name of the attribute which default value is to be set.</p>
 </attr>",

"&_.args;":#"<desc ent='ent'><p>
 The full list of the attributes, and their arguments, given to the
 tag.
</p></desc>",

"&_.rest-args;":#"<desc ent='ent'><p>
 A list of the attributes, and their arguments, given to the tag,
 excluding attributes with default values defined.
</p></desc>",

"&_.contents;":#"<desc ent='ent'><p>
 The containers contents.
</p></desc>",

"contents":#"<desc tag='tag'><p>
 As the contents entity, but unquoted.
</p></desc>"
	    ])

}),

//----------------------------------------------------------------------

"else":#"<desc cont='cont'><p><short>

 Show the contents if the previous <xref href='if.tag' /> tag didn't,
 or if there was a <xref href='false.tag' /> tag above.</short> This
 tag also detects if the page's truthvalue has been set to false.
 <xref href='../output/emit.tag' /> is an example of a tag that may
 change a page's truthvalue.</p>

 <p>The result is undefined if there has been no <xref href='if.tag'
 />, <xref href='true.tag' /> or <xref href='false.tag' /> tag
 above.</p>

</desc>",

//----------------------------------------------------------------------

"elseif":#"<desc cont='cont'><p><short>
 Same as the <xref href='if.tag' />, but it will only evaluate if the
 previous <tag>if</tag> returned false.</short></p>
</desc>",

//----------------------------------------------------------------------

"false":#"<desc tag='tag'><p><short>
 Internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag' /> tag
 will show its contents. It can be useful if you are writing your own
 <xref href='if.tag' /> lookalike tag. </p>
</desc>",

//----------------------------------------------------------------------

"help":#"<desc tag='tag'><p><short>
 Gives help texts for tags.</short> If given no arguments, it will
 list all available tags. By inserting <tag>help/</tag> in a page, a
 full index of the tags available in that particular Roxen WebServer
 will be presented. If a particular tag is missing from that index, it
 is not available at that moment. All tags are available through
 modules, hence that particular tags' module hasn't been added to the
 Roxen WebServer. Ask an administrator to add the module.
</p>
</desc>

<attr name='for' value='tag'><p>
 Gives the help text for that tag.</p>
<ex type='vert'><help for='roxen'/></ex>
</attr>",

//----------------------------------------------------------------------

"if":#"<desc cont='cont'><p><short>
 <tag>if</tag> is used to conditionally show its contents.</short>The
 <tag>if</tag> tag is used to conditionally show its contents. <xref
 href='else.tag'/> or <xref href='elseif.tag' /> can be used to
 suggest alternative content.</p>

 <p>It is possible to use glob patterns in almost all attributes,
 where * means match zero or more characters while ? matches one
 character. * Thus t*f?? will match trainfoo as well as * tfoo but not
 trainfork or tfo. It is not possible to use regexp's together
 with any of the if-plugins.</p>

 <p>The tag itself is useless without its
 plugins. Its main functionality is to provide a framework for the
 plugins.</p>

 <p>It is mandatory to add a plugin as one attribute. The other
 attributes provided are and, or and not, used for combining plugins
 or logical negation.</p>

 <ex type='box'>
  <if variable='var.foo > 0' and='' match='var.bar is No'>
    ...
  </if>
 </ex>

 <ex type='box'>
  <if variable='var.foo > 0' not=''>
    <ent>var.foo</ent> is lesser than 0
  </if>
  <else>
    <ent>var.foo</ent> is greater than 0
  </else>
 </ex>

 <p>Operators valid in attribute expressions are: '=', '==', 'is', '!=',
 '&lt;' and '&gt;'.</p>

 <p>The If plugins are sorted according to their function into five
 categories: Eval, Match, State, Utils and SiteBuilder.</p>

 <p>The Eval category is the one corresponding to the regular tests made
 in programming languages, and perhaps the most used. They evaluate
 expressions containing variables, entities, strings etc and are a sort
 of multi-use plugins. All If-tag operators and global patterns are
 allowed.</p>

 <ex>
  <set variable='var.x' value='6'/>
  <if variable='var.x > 5'>More than one hand</if>
 </ex>

 <p>The Match category contains plugins that match contents of
 something, e.g. an IP package header, with arguments given to the
 plugin as a string or a list of strings.</p>

 <ex>
  Your domain <if ip='130.236.*'> is </if>
  <else> isn't </else> liu.se.
 </ex>

 <p>State plugins check which of the possible states something is in,
 e.g. if a flag is set or not, if something is supported or not, if
 something is defined or not etc.</p>

 <ex>
   Your browser
  <if supports='javascript'>
   supports Javascript version <ent>client.javascript</ent>
  </if>
  <else>doesn't support Javascript</else>.
 </ex>

 <p>Utils are additonal plugins specialized for certain tests, e.g.
 date and time tests.</p>

 <ex>
  <if time='1700' after=''>
    Are you still at work?
  </if>
  <elseif time='0900' before=''>
     Wow, you work early!
  </elseif>
  <else>
   Somewhere between 9 to 5.
  </else>
 </ex>

 <p>SiteBuilder plugins requires a Roxen Platform SiteBuilder
 installed to work. They are adding test capabilities to web pages
 contained in a SiteBuilder administrated site.</p>
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

"if#true":#"<desc plugin='plugin'><p><short>
 This will always be true if the truth value is set to be
 true.</short> Equivalent with <xref href='then.tag' />.
 True is a <i>State</i> plugin.
</p></desc>

<attr name='true' required='required'><p>
 Show contents if truth value is false.</p>
</attr>",

//----------------------------------------------------------------------

"if#false":#"<desc plugin='plugin'><p><short>
 This will always be true if the truth value is set to be
 false.</short> Equivalent with <xref href='else.tag' />.
 False is a <i>State</i> plugin.</p>
</desc>

<attr name='false' required='required'><p>
 Show contents if truth value is true.</p>
</attr>",

//----------------------------------------------------------------------

"if#module":#"<desc plugin='plugin'><p><short>
 Enables true if the selected module is enabled in the current
 server.</short></p>
</desc>

<attr name='module' value='name'><p>
 The \"real\" name of the module to look for, i.e. its filename
 without extension.</p>
</attr>",

//----------------------------------------------------------------------

"if#accept":#"<desc plugin='plugin'><p><short>
 Returns true if the browser accepts certain content types as specified
 by it's Accept-header, for example image/jpeg or text/html.</short> If
 browser states that it accepts */* that is not taken in to account as
 this is always untrue. Accept is a <i>Match</i> plugin.
</p></desc>

<attr name='accept' value='type1[,type2,...]' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#config":#"<desc plugin='plugin'><p><short>
 Has the config been set by use of the <xref href='../http/aconf.tag'
 /> tag?</short> Config is a <i>State</i> plugin.</p>
</desc>

<attr name='config' value='name' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#cookie":#"<desc plugin='plugin'><p><short>
 Does the cookie exist and if a value is given, does it contain that
 value?</short> Cookie is an <i>Eval</i> plugin.
</p></desc>
<attr name='cookie' value='name[ is value]' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#client":#"<desc plugin='plugin'><p><short>
 Compares the user agent string with a pattern.</short> Client is an
 <i>Match</i> plugin.
</p></desc>
<attr name='client' value='' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#date":#"<desc plugin='plugin'><p><short>
 Is the date yyyymmdd?</short> The attributes before, after and
 inclusive modifies the behavior. Date is a <i>Utils</i> plugin.
</p></desc>
<attr name='date' value='yyyymmdd' required='required'><p>
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

"if#defined":#"<desc plugin='plugin'><p><short>
 Tests if a certain RXML define is defined by use of the <xref
 href='../variable/define.tag' /> tag.</short> Defined is a
 <i>State</i> plugin. </p>
</desc>

<attr name='defined' value='define' required='required'><p>
 Choose what define to test.</p>
</attr>",

//----------------------------------------------------------------------

"if#domain":#"<desc plugin='plugin'><p><short>
 Does the user's computer's DNS name match any of the
 patterns?</short> Note that domain names are resolved asynchronously,
 and that the first time someone accesses a page, the domain name will
 probably not have been resolved. Domain is a <i>Match</i> plugin.
</p></desc>

<attr name='domain' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

// If eval is deprecated. This information is to be put in a special
// 'deprecated' chapter in the manual, due to many persons asking
// about its whereabouts.

"if#eval":#"<desc plugin='plugin'><p><short>
 Deprecated due to non-XML compliancy.</short> The XML standard says
 that attribute-values are not allowed to contain any markup. The
 <tag>if eval</tag> tag was deprecated in Roxen 2.0.</p>

 <ex typ='box'>

 <!-- If eval statement -->
 <if eval=\"<foo>\">x</if>

 <!-- Compatible statement -->
 <define variable=\"var.foo\" preparse=\"preparse\"><foo/></define>
 <if sizeof=\"var.foo\">x</if>
 </ex>
 <p>A similar but more XML compliant construct is a combination of
 <tag>define variable</tag> and an apropriate <tag>if</tag> plugin.
</p></desc>",

"if#exists":#"<desc plugin><short>
 Returns true if the file path exists.</short> If path does not begin
 with /, it is assumed to be a URL relative to the directory
 containing the page with the <tag><ref
 type='tag'>if</ref></tag>-statement. Exists is a <i>Utils</i>
 plugin.
</desc>
<attr name='exists' value='path' required>
 Choose what path to test.
</attr>",

//----------------------------------------------------------------------

"if#group":#"<desc plugin='plugin'><p><short>
 Checks if the current user is a member of the group according
 the groupfile.</short> Group is a <i>Utils</i> plugin.
</p></desc>
<attr name='group' value='name' required='required'><p>
 Choose what group to test.</p>
</attr>

<attr name='groupfile' value='path' required='required'><p>
 Specify where the groupfile is located.</p>
</attr>",

//----------------------------------------------------------------------

"if#ip":#"<desc plugin='plugin'><p><short>

 Does the users computers IP address match any of the
 patterns?</short> This plugin replaces the Host plugin of earlier
 RXML versions. Ip is a <i>Match</i> plugin.
</p></desc>
<attr name='ip' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what IP-adress pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#language":#"<desc plugin='plugin'><p><short>
 Does the client prefer one of the languages listed, as specified by the
 Accept-Language header?</short> Language is a <i>Match</i> plugin.
</p></desc>

<attr name='language' value='language1[,language2,...]' required='required'><p>
 Choose what language to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#match":#"<desc plugin='plugin'><p><short>
 Evaluates patterns.</short> More information can be found in the
 <xref href='../../tutorial/if_tags/plugins.xml'>If tags
 tutorial</xref>. Match is an <i>Eval</i> plugin. </p></desc>

<attr name='match' value='pattern' required='required'><p>
 Choose what pattern to test. The pattern could be any expression.
 Note!: The pattern content is treated as strings:</p>

<ex type='vert'>
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

<ex type='vert'>
<set variable='var.hepp' value='10' />

 <if match='&var.hepp; is 10'>
  true
 </if>
 <else>
  false
 </else>
</ex>

 <p>Here, <ent>var.hepp</ent> is treated as an entity and parsed
 correctly, letting the plugin test the contents of the entity.</p>
</attr>
",

//----------------------------------------------------------------------

"if#Match":#"<desc plugin='plugin'><p><short>
 Case sensitive version of the match plugin</short></p>
</desc>",

//----------------------------------------------------------------------

"if#pragma":#"<desc plugin='plugin'><p><short>
 Compares the HTTP header pragma with a string.</short> Pragma is a
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

"if#prestate":#"<desc plugin='plugin'><p><short>
 Are all of the specified prestate options present in the URL?</short>
 Prestate is a <i>State</i> plugin.
</p></desc>
<attr name='prestate' value='option1[,option2,...]' required='required'><p>
 Choose what prestate to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#referrer":#"<desc plugin='plugin'><p><short>
 Does the referrer header match any of the patterns?</short> Referrer
 is a <i>Match</i> plugin.
</p></desc>
<attr name='referrer' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#supports":#"<desc plugin='plugin'><p><short>
 Does the browser support this feature?</short> Supports is a
 <i>State</i> plugin.
</p></desc>

<attr name=supports'' value='feature' required required='required'>
 <p>Choose what supports feature to test.</p>
</attr>

<p>The following features are supported:</p> <supports-flags-list/>",

//----------------------------------------------------------------------

"if#time":#"<desc plugin='plugin'><p><short>
 Is the time hhmm?</short> The attributes before, after and inclusive modifies
 the behavior. Time is a <i>Utils</i> plugin.
</p></desc>
<attr name='time' value='hhmm' required='required'><p>
 Choose what time to test.</p>
</attr>

<attr name='after'><p>
 The time after present time.</p>
</attr>

<attr name='before'><p>
 The time before present time.</p>
</attr>

<attr name='inclusive'><p>
 Adds present time to after and before.</p>

 <ex>
  <if time='1200' before='' inclusive=''>
    ante meridiem
  </if>
  <else>
    post meridiem
  </else>
 </ex>
</attr>",

//----------------------------------------------------------------------

"if#user":#"<desc plugin='plugin'><p><short>
 Has the user been authenticated as one of these users?</short> If any
 is given as argument, any authenticated user will do. User is a
 <i>Utils</i> plugin.
</p></desc>

<attr name='user' value='name1[,name2,...]|any' required='required'><p>
 Specify which users to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#variable":#"<desc plugin='plugn'><p><short>
 Does the variable exist and, optionally, does it's content match the
 pattern?</short> Variable is an <i>Eval</i> plugin.
</p></desc>

<attr name='variable' value='name[ is pattern]' required='required'><p>
 Choose variable to test. Valid operators are '=', '==', 'is', '!=',
 '&lt;' and '&gt;'.</p>
</attr>",

//----------------------------------------------------------------------

"if#Variable":#"<desc plugin='plugin'><p><short>
 Case sensitive version of the variable plugin</short></p>
</desc>",

//----------------------------------------------------------------------

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#clientvar":#"<desc plugin='plugin'><p><short>
 Evaluates expressions with client specific values.</short> Clientvar
 is an <i>Eval</i> plugin.
</p></desc>

<attr name='clientvar' value='variable [is value]' required='required'><p>
 Choose which variable to evaluate against. Valid operators are '=',
 '==', 'is', '!=', '&lt;' and '&gt;'.</p>
</attr>

<p>Available variables are:</p>",

//----------------------------------------------------------------------

"if#sizeof":#"<desc plugin='plugin'><p><short>
 Compares the size of a variable with a number.</short></p>

<ex>
<set variable=\"var.x\" value=\"hello\"/>
<set variable=\"var.y\" value=\"\"/>
<if sizeof=\"var.x == 5\">Five</if>
<if sizeof=\"var.y > 0\">Nonempty</if>
</ex>
</desc>",

//----------------------------------------------------------------------

"nooutput":#"<desc cont='cont'><p><short>
 The contents will not be sent through to the page.</short> Side
 effects, for example sending queries to databases, will take effect.
</p></desc>",

//----------------------------------------------------------------------

"noparse":#"<desc cont='cont'><p><short>
 The contents of this container tag won't be RXML parsed.</short>
</p></desc>",

//----------------------------------------------------------------------

"<?noparse": #"<desc pi='pi'><p><short>
 The content is inserted as-is, without any parsing or
 quoting.</short> The first whitespace character (i.e. the one
 directly after the \"noparse\" name) is discarded.</p>
</desc>",

//----------------------------------------------------------------------

"<?cdata": #"<desc pi='pi'><p><short>
 The content is inserted as a literal.</short> I.e. any XML markup
 characters are encoded with character references. The first
 whitespace character (i.e. the one directly after the \"cdata\" name)
 is discarded.</p>

 <p>This processing instruction is just like the &lt;![CDATA[ ]]&gt;
 directive but parsed by the RXML parser, which can be useful to
 satisfy browsers that does not handle &lt;![CDATA[ ]]&gt; correctly.</p>
</desc>",

//----------------------------------------------------------------------

"number":#"<desc tag='tag'><p><short>
 Prints a number as a word.</short>
</p></desc>

<attr name='num' value='number' required='required'><p>
 Print this number.</p>
<ex type='vert'><number num='4711'/></ex>
</attr>

<attr name='language' value='langcodes'><p>
 The language to use.</p>
 <lang/>
 <ex type='vert'>Mitt favoritnummer är <number num='11' language='sv'/>.</ex>
 <ex type='vert'>Il mio numero preferito <ent>egrave</ent> <number num='15' language='it'/>.</ex>
</attr>

<attr name='type' value='number|ordered|roman|memory' default='number'><p>
 Sets output format.</p>

 <ex type='vert'>It was his <number num='15' type='ordered'/> birthday yesterday.</ex>
 <ex type='vert'>Only <number num='274589226' type='memory'/> left on the Internet.</ex>
 <ex type='vert'>Spock Garfield <number num='17' type='roman'/> rests here.</ex>
</attr>",

//----------------------------------------------------------------------

"strlen":#"<desc cont='cont'><p><short>
 Returns the length of the contents.</short></p>

 <ex type='vert'>There are <strlen>foo bar gazonk</strlen> characters
 inside the tag.</ex>
</desc>",

//----------------------------------------------------------------------

"then":#"<desc cont='cont'><p><short>
 Shows its content if the truth value is true.</short></p>
</desc>",

//----------------------------------------------------------------------

"trace":#"<desc cont='cont'><p><short>
 Executes the contained RXML code and makes a trace report about how
 the contents are parsed by the RXML parser.</short>
</p></desc>",

//----------------------------------------------------------------------

"true":#"<desc tag='tag'><p><short>
 An internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag'
 /> tag will not show its contents. It can be useful if you are
 writing your own <xref href='if.tag' /> lookalike tag.</p>
</desc>",

//----------------------------------------------------------------------

"undefine":#"<desc tag='tag'><p><short>
 Removes a definition made by the define container.</short> One
 attribute is required.
</p></desc>

<attr name='variable' value='name'><p>
 Undefines this variable.</p>

 <ex>
  <define variable='var.hepp'>hopp</define>
  <ent>var.hepp</ent>
  <undefine variable='var.hepp'/>
  <ent>var.hepp</ent>
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

"use":#"<desc cont='cont'><p><short>
 Reads tag definitions, user defined if plugins and variables from a
 file or package and includes into the current page.</short> Note that the
 file itself is not inserted into the page. This only affects the
 environment in which the page is parsed. The benefit is that the
 package file needs only be parsed once, and the compiled versions of
 the user defined tags can then be used, thus saving time. It is also
 a fairly good way of creating templates for your website. Just define
 your own tags for constructions that appears frequently and save both
 space and time. Since the tag definitions are cached in memory, make
 sure that the file is not dependent on anything dynamic, such as form
 variables or client settings, at the compile time. Also note that the
 use tag only lets you define variables in the form and var scope in
 advance. Variables with the same name will be overwritten when the
 use tag is parsed.</p>
</desc>

<attr name='packageinfo'><p>
 Show a list of all available packages.</p>
</attr>

<attr name='package' value='name'><p>
 Reads all tags, container tags and defines from the given package.
 Packages are files located by default in <i>../rxml_packages/</i>.</p>
</attr>

<attr name='file' value='path'><p>
 Reads all tags and container tags and defines from the file.

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

"eval":#"<desc cont='cont'><p><short>
 Postparses its content.</short> Useful when an entity contains
 RXML-code. <tag>eval</tag> is then placed around the entity to get
 its content parsed.</p>
</desc>",

//----------------------------------------------------------------------

"emit#path":({ #"<desc plugin='plugin'><p><short>
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
"&_.name;":#"<desc ent='ent'><p>
 Returns the name of the most recently traversed directory.</p>
</desc>",

"&_.path;":#"<desc ent='ent'><p>
 Returns the path to the most recently traversed directory.</p>
</desc>"
	       ])
}),

//----------------------------------------------------------------------

"emit#sources":({ #"<desc plugin='plugin'><p><short>
 Provides a list of all available emit sources.</short>
</p></desc>",
  ([ "&_.source;":#"<desc ent='ent'><p>
  The name of the source.</p></desc>" ]) }),

//----------------------------------------------------------------------

"emit#values":({ #"<desc plugin='plugin'><p><short>
 Splits the string provided in the values attribute and outputs the
 parts in a loop.</short> The value in the values attribute may also
 be an array or mapping.
</p></desc>

<attr name='values' value='string, mapping or array' required='required'><p>
 An array, mapping or a string to be splitted into an array.</p>
</attr>

<attr name='split' value='string' default='NULL'><p>
 The string the values string is splitted with.</p>
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
 Create a mapping out of a scope and give it as indata to the emit.
</attr>
",

([
"&_.value;":#"<desc ent='ent'><p>
 The value of one part of the splitted string</p>
</desc>",

"&_.index;":#"<desc ent='ent'><p>
 The index of this mapping entry, if input was a mapping</p>
</desc>"
])
	      }),

//----------------------------------------------------------------------

"emit":({ #"<desc cont='cont'><p><short hide='hide'>

 Provides data, fetched from different sources, as entities. </short>

 <tag>emit</tag> is a generic tag used to fetch data from a
 provided source, loop over it and assign it to RXML variables
 accessible through entities.</p>

 <p>Occasionally an <tag>emit</tag> operation fails to produce output.
 This might happen when <tag>emit</tag> can't find any matches or if
 the developer has made an error. When this happens the truthvalue of
 that page is set to <i>false</i>. By using <xref
 href='../if/else.tag' /> afterwards it's possible to detect when an
 <tag>emit</tag> operation fails.</p>
</desc>

<attr name='source' value='plugin' required='required'><p>
 The source from which the data should be fetched.</p>
</attr>

<attr name='scope' value='name' default='The emit source'><p>
 The name of the scope within the emit tag.</p>
</attr>

<attr name='maxrows' value='number'><p>
 Limits the number of rows to this maximum.</p>
</attr>

<attr name='skiprows' value='number'><p>
 Makes it possible to skip the first rows of the result. Negative
 numbers means to skip everything execept the last n rows.</p>
</attr>

<attr name='rowinfo' value='variable'><p>
 The number of rows in the result, after it has been limited by
 maxrows and skiprows, will be put in this variable, if given.</p>
</attr>

<attr name='do-once'><p>
 Indicate that at least one loop should be made. All variables in the
 emit scope will be empty.</p>
</attr>",

	  ([

"&_.counter;":#"<desc ent='ent'><p>
 Gives the current number of loops inside the <tag>emit</tag> tag.
</p>
</desc>"

	  ])
       }),

//----------------------------------------------------------------------

    ]);
#endif
