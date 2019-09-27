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

inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG | MODULE_PROVIDER;
constant module_name = "RXML 2 tags";
constant module_doc  = "This module provides the common RXML tags.";

void start()
{
  add_api_function("query_modified", api_query_modified, ({ "string" }));
  query_tag_set()->prepare_context=set_entities;
}

string query_provides() {
  return "modified";
}

constant permitted = "123456789.xabcdefint\"XABCDEFlo<>=0-*+/%&|()"/"";

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


// ----------------- Entities ----------------------

class EntityPageRealfile {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) { return c->id->realfile||""; }
}

class EntityPageVirtroot {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) { return c->id->virtfile||""; }
}

class EntityPageVirtfile {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) { return c->id->not_query; }
}

class EntityPageQuery {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    return c->id->query||"";
  }
}

class EntityPageURL {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    return c->id->raw_url;
  }
}

class EntityPageLastTrue {
  inherit RXML.Value;
  int rxml_var_eval(RXML.Context c) { return c->id->misc->defines[" _ok"]; }
}

class EntityPageLanguage {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    return c->id->misc->defines->language || "";
  }
}

class EntityPageScope {
  inherit RXML.Value;
  string rxml_var_eval(RXML.Context c) { return c->current_scope()||""; }
}

class EntityPageFileSize {
  inherit RXML.Value;
  int rxml_const_eval(RXML.Context c) { return c->id->misc->defines[" _stat"]?c->id->misc->defines[" _stat"][1]:-4; }
}

class EntityPageSelf {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) { return (c->id->not_query/"/")[-1]; }
}

class EntityPageSSLStrength {
  inherit RXML.Value;
  int rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable = 0;
    if (!c->id->my_fd || !c->id->my_fd->session) return 0;
    return c->id->my_fd->session->cipher_spec->key_bits;
  }
}

mapping(string:object) page_scope=([
  "realfile":EntityPageRealfile(),
  "virtroot":EntityPageVirtroot(),
  "virtfile":EntityPageVirtfile(),  //  deprecated; use &page.path; instead
  "path": EntityPageVirtfile(),
  "query":EntityPageQuery(),
  "url":EntityPageURL(),
  "last-true":EntityPageLastTrue(),
  "language":EntityPageLanguage(),
  "scope":EntityPageScope(),
  "filesize":EntityPageFileSize(),
  "self":EntityPageSelf(),
  "ssl-strength":EntityPageSSLStrength(),
]);

class EntityClientReferrer {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    array referrer=c->id->referer;
    return referrer && sizeof(referrer)?referrer[0]:"";
  }
}

class EntityClientName {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    array client=c->id->client;
    return client && sizeof(client)?client[0]:"";
  }
}

class EntityClientIP {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    return c->id->remoteaddr;
  }
}

class EntityClientAcceptLanguage {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return "";
    return c->id->misc["accept-language"][0];
  }
}

class EntityClientAcceptLanguages {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return "";
    return c->id->misc["accept-language"]*", ";
  }
}

class EntityClientLanguage {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return "";
    return c->id->misc->pref_languages->get_language() || "";
  }
}

class EntityClientLanguages {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return "";
    return c->id->misc->pref_languages->get_languages()*", ";
  }
}

class EntityClientHost {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    if(c->id->host) return c->id->host;
    return c->id->host=roxen->quick_ip_to_host(c->id->remoteaddr);
  }
}

class EntityClientAuthenticated {
  inherit RXML.Value;
  int rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    return c->id->auth&&c->id->auth[0]&&c->id->auth[1];
  }
}

class EntityClientUser {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    c->id->misc->cacheable=0;
    return c->id->rawauth&&(c->id->rawauth/":")[0];
  }
}

class EntityClientPassword {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) {
    array tmp;
    c->id->misc->cacheable=0;
    return (c->id->auth 
	    && !c->id->auth[0] 
	    && c->id->rawauth
	    && (sizeof(tmp = c->id->rawauth/":") > 1) 
	    && tmp[1]);
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
]);

void set_entities(RXML.Context c) {
  c->extend_scope("page", page_scope);
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
      "<input type=\"hidden\" name=\"magic_roxen_automatic_charset_variable\" value=\"едц\" />";

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
	if(!from) parse_error("From variable doesn't exist.\n");
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
      t=t2==time(1);
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
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "variable": RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if (args->value) {
	// Set an entity variable to a value.
	if(args->split) RXML.user_set_var(args->variable, args->value/args->split, args->scope);
	RXML.user_set_var(args->variable, args->value, args->scope);
	return 0;
      }
      if (args->expr) {
	// Set an entity variable to an evaluated expression.
	RXML.user_set_var(args->variable, sexpr_eval(args->expr), args->scope);
	return 0;
      }
      if (args->from) {
	// Copy a value from another entity variable.
	mixed from=RXML.user_get_var(args->from, args->scope);
	if(!from) run_error("From variable doesn't exist.\n");
	RXML.user_set_var(args->variable, from, args->scope);
	return 0;
      }

      RXML.user_set_var(args->variable, content, args->scope);
      return 0;
    }
  }
}

class TagInc {
  inherit RXML.Tag;
  constant name = "inc";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "variable":RXML.t_text ]);

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
	  args->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src),".")-2],"_"," "));
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
	report_debug("%^s%#-1s\n", "<debug>: ", replace(args->werror,"\\n","\n") );
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
		   return sprintf("%s=%O", s, context->user_get_var(s, args->scope) );
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

  string get_data(string var, mapping args, RequestID id) {
    string result;
    if(args->nocache) {
      int nocache=id->pragma["no-cache"];
      id->pragma["no-cache"] = 1;
      result=id->conf->try_get_file(var, id);
      id->pragma["no-cache"] = nocache;
    }
    else result = id->conf->try_get_file(var, id);
    if(!result) RXML.run_error("No such file ("+var+").\n");

#ifdef OLD_RXML_COMPAT
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
        RXML.run_error("That cookie does not exists.\n");
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
    // FIXME: The next row is defunct. last_modified_by does not exists.
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
    s = file_stat(id->realfile);

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

string simpletag_charset( string t, mapping m, string c, RequestID id )
{
  if( m->in )
    if( catch {
      c = Locale.Charset.decoder( m->in )->feed( c )->drain();
    })
      RXML.run_error( "Illegal charset, or unable to decode data: "+
                      m->in+"\n" );
  if( m->out && id->set_output_charset)
    id->set_output_charset( m->out );
  return c;
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
#ifdef OLD_RXML_COMPAT
      if(scope_name=="form") oldvar=id->variables;
#endif
      if(args->extend)
	// This is not really good, since we are peeking on the
	// RXML parser internals without any abstraction...
	vars=copy_value(RXML.get_context()->scopes[scope_name]);
      else
	vars=([]);
#ifdef OLD_RXML_COMPAT
      if(oldvar) id->variables=vars;
#endif
      return 0;
    }

    array do_return(RequestID id) {
#ifdef OLD_RXML_COMPAT
      if(oldvar) id->variables=oldvar;
#endif
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

string container_cache(string tag, mapping args,
		       string contents, RequestID id)
{
#define HASH(x) (x+id->not_query+id->query+id->realauth+id->conf->query("MyWorldLocation"))
  string key="";
  if(!args->nohash) {
    object md5 = Crypto.md5();
    md5->update(HASH(contents));
    key=md5->digest();
  }
  if(args->key)
    key += args->key;
  string parsed = cache_lookup("tag_cache", key);
  if(!parsed) {
    parsed = Roxen.parse_rxml(contents, id);
    cache_set("tag_cache", key, parsed, Roxen.time_dequantifier(args));
  }
  return parsed;
#undef HASH
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
  string|array q;
  NOCACHE();
  if(!(q=m->separator || m->sep)) return (q=s/"\n")[random(sizeof(q))];
  return (q=s/q)[random(sizeof(q))];
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
  if (sizeof(c) && (c[-1] != '\n')) c += "\n";
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
    if(sscanf(tmp[1],"%*svalue=%s%*[ >]",nvalue)!=3 &&
       sscanf(tmp[1],"%*sVALUE=%s%*[ >]",nvalue)!=3) nvalue=tmp[2][..stop==-1?sizeof(tmp[2]):stop];
    if(!sscanf(nvalue, "\"%s\"", nvalue)) sscanf(nvalue, "'%s'", nvalue);
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


// ----------------- If registration stuff --------------

class TagIfExpr {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "expr";
  int eval(string u) {
    return (int)sexpr_eval(u);
  }
}


// ---------------- Emit registration stuff --------------

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

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"&client.ip;":#"<desc ent>The client is located on this IP-address.</desc>",
"&client.host;":#"<desc ent>The host name of the client, if possible to resolve.</desc>",
"&client.name;":#"<desc ent>The name of the client, i.e. \"Mozilla/4.7\". </desc>",
"&client.Fullname;":#"<desc ent>The full user agent string, i.e. name of the client
 and additional info like; operating system, type of computer, etc.
 E.g. \"Mozilla/4.7 [en] (X11; I; SunOS 5.7 i86pc)\". </desc>",
"&client.fullname;":#"<desc ent>The full user agent string, i.e. name of the client
 and additional info like; operating system, type of computer, etc.
 E.g. \"mozilla/4.7 [en] (x11; i; sunos 5.7 i86pc)\". </desc>",
"&client.referrer;":#"<desc ent>Prints the URL of the page on which the user followed
 a link that brought her to this page. The information comes from the referrer header
 sent by the browser.</desc>",
"&client.accept-language;":#"<desc ent>The client prefers to have the page contents
 presented in this language.</desc>",
"&client.accept-languages;":#"<desc ent>The client prefers to have the page contents
 presented in this language but these additional languages are accepted as well.</desc>",
"&client.language;":#"<desc ent>The clients most preferred language.</desc>",
"&client.languages;":#"<desc ent>An ordered list of the clients most preferred</desc>",
"&client.authenticated;":#"<desc ent></desc>",
"&client.user;":#"<desc ent></desc>",
"&client.password;":#"<desc ent></desc>",


"&page.realfile;":#"<desc ent>Path to this file in the file system.</desc>",
"&page.virtroot;":#"<desc ent>The root of the present virtual filesystem.</desc>",
//  &page.virtfile; is same as &page.path; but deprecated since we want to
//  harmonize with SiteBuilder entities.
"&page.path;":#"<desc ent>Absolute path to this file in the virtual filesystem.</desc>",
"&page.pathinfo;":#"\
<desc ent>The \"path info\" part of the URL, if any. Can only get set
if the \"Path info support\" module is installed. For details see the
documentation for that module.</desc>",
"&page.query;":#"<desc ent>The query part of the page URI.</desc>",
"&page.url;":#"<desc ent>The absolute path for this file from the web server's root or point of view including query variables</desc>",
"&page.last-true;":#"<desc ent>Is 1 if the last <tag>if</tag>-statement succeeded, otherwise 0.
 (<tag>true/</tag> and <tag>false/</tag> is considered as <tag>if</tag>-statements here)</desc>",
"&page.language;":#"<desc ent>What language the contens of this file is written in.
 The language must be given as metadata to be found.</desc>",
"&page.scope;":#"<desc ent>The name of the current scope, i.e. the scope accessible through the name \"_\".</desc>",
"&page.filesize;":#"<desc ent>This file's size, in bytes.</desc>",
"&page.ssl-strength;":#"<desc ent>The strength in bits of the current SSL connection.</desc>",
"&page.self;":#"<desc ent>The name of this file.</desc>",

"roxen_automatic_charset_variable":#"<desc tag>
 If put inside a form, the right character encoding of the submitted form can be guessed
 by Roxen Webserver.
</desc>",

"aconf":#"<desc cont><short>
 Creates a link that can modify the persistent states in the cookie
 RoxenConfig.</short>
</desc>

<attr name=href value=uri>
 Indicates which page should be linked to, if any other than the
 present one.
</attr>

<attr name=add value=string>
 The \"cookie\" or \"cookies\" that should be added, in a comma
 seperated list.
</attr>

<attr name=drop value=string>
 The \"cookie\" or \"cookies\" that should be droped, in a comma
 seperated list.
</attr>

<attr name=class value=string>
This cascading style sheet (CSS) class definition will apply to the a-element.
</attr>
 All other attributes will be inherited by the generated a tag.",

"append":#"<desc tag><short>
 Appends a value to a variable. The variable attribute and one more is
 required.</short>
</desc>

<attr name=variable value=string required>
 The name of the variable.
</attr>

<attr name=value value=string>
 The value the variable should have appended.

 <ex>
 <set variable='var.ris' value='Roxen'/>
 <append variable='var.ris' value=' Internet Software'/>
 <ent>var.ris</ent>
 </ex>
</attr>

<attr name=from value=string>
 The name of another variable that the value should be copied from.
</attr>",

"apre":#"<desc cont><short>
 Creates a link that can modify prestates.</short> Prestate options
 are simple toggles, and are added to the URL of the page. Use <tag>if
 prestate='...'</tag> ... <tag>/if</tag>to test for the presence of a
 prestate. <tag>apre</tag> works just like the <tag>a href=...</tag>
 container, but if no \"href\" attribute is specified, the current
 page is used.
</desc>

<attr name=href value=uri>
 Indicates which page should be linked to, if any other than the
 present one.
</attr>

<attr name=add value=string>
 The prestate or prestates that should be added, in a comma seperated list.
</attr>

<attr name=drop value=string>
 The prestate or prestates that should be droped, in a comma seperated
 list.
</attr>

<attr name=class value=string>
 This cascading style sheet (CSS) class definition will apply to the a-element.
</attr>",

"auth-required":#"<desc tag><short>
 Adds an HTTP auth required header and return code (401), that will
 force the user to supply a login name and password.</short> This tag
 is needed when using access control in RXML in order for the user to
 be prompted to login.
</desc>

<attr name=realm value=string>
 The realm you are logging on to, i.e \"Intranet foo\".
</attr>

<attr name=message value=string>
 Returns a message if a login failed or cancelled.
</attr>",

"autoformat":#"<desc cont><short hide>
 Replaces newlines with <br/>:s'.</short>Replaces newlines with <tag>br /</tag>:s'.

<ex><autoformat>
It is almost like
using the pre tag.
</autoformat></ex>

</desc>

<attr name=p>
 Replace empty lines with <tag>p</tag>:s.
<ex><autoformat p=''>
It is almost like

using the pre tag.
</autoformat></ex>
</attr>

<attr name=nobr>
 Do not replace newlines with <tag>br /</tag>:s.
</attr>

<attr name=class value=string>
 This cascading style sheet (CSS) definition will be applied on the p elements.
</attr>",

"cache":#"<desc cont><short>
 This simple tag RXML parse its contents and cache them using the
 normal Roxen memory cache.</short> They key used to store the cached
 contents is the MD5 hash sum of the contents, the accessed file name,
 the query string, the server URL and the authentication information,
 if available. This should create an unique key. The time during which the
 entry should be considered valid can set with one or several time attributes.
 If not provided the entry will be removed from the cache when it has
 been untouched for too long.
</desc>

<attr name=key value=string>
 Append this value to the hash used to identify the contents for less
 risk of incorrect caching. This shouldn't really be needed.
</attr>

<attr name=nohash>
 The cached entry will use only the provided key as cache key.
</attr>

<attr name=years value=number>
 Add this number of years to the time this entry is valid.
</attr>
<attr name=months value=number>
 Add this number of months to the time this entry is valid.
</attr>
<attr name=weeks value=number>
 Add this number of weeks to the time this entry is valid.
</attr>
<attr name=days value=number>
 Add this number of days to the time this entry is valid.
</attr>
<attr name=hours value=number>
 Add this number of hours to the time this entry is valid.
</attr>
<attr name=beats value=number>
 Add this number of beats to the time this entry is valid.
</attr>
<attr name=minutes value=number>
 Add this number of minutes to the time this entry is valid.
</attr>
<attr name=seconds value=number>
 Add this number of seconds to the time this entry is valid.
</attr>",

"catch":#"<desc cont><short>
 Evaluates the RXML code, and, if nothing goes wrong, returns the
 parsed contents.</short> If something does go wrong, the error
 message is returned instead. See also <tag><ref
 type='tag'>throw</ref></tag>.
</desc>",

"configimage":#"<desc tag><short>
 Returns one of the internal Roxen configuration images.</short> The
 src attribute is required.
</desc>

<attr name=src value=string>
 The name of the picture to show.
</attr>

<attr name=border value=number default=0>
 The image border when used as a link.
</attr>

<attr name=alt value=string default='The src string'>
 The picture description.
</attr>

<attr name=class value=string>
 This cascading style sheet (CSS) class definition will be applied to
 the image.
</attr>
 All other attributes will be inherited by the generated img tag.",

"configurl":#"<desc tag><short>
 Returns a URL to the administration interface.</short>
</desc>",

"cset":#"<desc cont>Sets a variable with its content.</desc>

<attr name=variable value=name>
 The variable to be set.
</attr>

<attr name=quote value=html|none>
 How the content should be quoted before assigned to the variable. Default is html.
</attr>
",

"crypt":#"<desc cont><short>
 Encrypts the contents as a Unix style password.</short> Useful when
 combined with services that use such passwords. <p>Unix style
 passwords are one-way encrypted, to prevent the actual clear-text
 password from being stored anywhere. When a login attempt is made,
 the password supplied is also encrypted and then compared to the
 stored encrypted password.</p>
</desc>

<attr name=compare value=string>
 Compares the encrypted string with the contents of the tag. The tag
 will behaive very much  like an <tag>if</tag> tag.
<ex><crypt compare=\"LAF2kkMr6BjXw\">Roxen</crypt>
<then>Yepp!</then>
<else>Nope!</else>
</ex>
</attr>",

"date":#"<desc tag><short>
 Inserts the time and date.</short> Does not require attributes.
</desc>

<attr name=unix-time value=number of seconds>

Display this time instead of the current. This attribute uses the
specified Unix 'time_t' time as the starting time, (which is <i>01:00,
January the 1st, 1970</i>) instead of the current time. This is mostly
useful when the <tag>date</tag> tag is used from a Pike-script or
Roxen module.

<ex ><date unix-time='120'/></ex>
</attr>

<attr name=timezone value=local|GMT default=local>
Display the time from another timezone.
</attr>

<attr name=years value=number>
 Add this number of years to the result.
 <ex ><date date='' years='2'/></ex>
</attr>

<attr name=months value=number>
 Add this number of months to the result.
 <ex ><date date='' months='2'/></ex>
</attr>

<attr name=weeks value=number>
 Add this number of weeks to the result.
 <ex ><date date='' weeks='2'/></ex>
</attr>

<attr name=days value=number>
 Add this number of days to the result.
</attr>

<attr name=hours value=number>
 Add this number of hours to the result.
 <ex ><date time='' hours='2' type='iso'/></ex>
</attr>

<attr name=beats value=number>
 Add this number of beats to the result.
 <ex ><date time='' beats='10' type='iso'/></ex>
</attr>

<attr name=minutes value=number>
 Add this number of minutes to the result.
</attr>

<attr name=seconds value=number>
 Add this number of seconds to the result.
</attr>

<attr name=adjust value=number>
 Add this number of seconds to the result.
</attr>

<attr name=brief>
 Show in brief format.
<ex ><date brief=''/></ex>
</attr>

<attr name=time>
 Show only time.
<ex ><date time=''/></ex>
</attr>

<attr name=date>
 Show only date.
<ex ><date date=''/></ex>
</attr>

<attr name=type value=string|ordered|iso|discordian|stardate|number>
 Defines in which format the date should be displayed in. Discordian
 and stardate only make a difference when not using part. Note that
 type=stardate has a separate companion attribute, prec, which sets
 the precision.
<xtable>
<row><c><i>type=discordian</i></c><c><ex ><date date='' type='discordian'/> </ex></c></row>
<row><c><i>type=iso</i></c><c><ex ><date date='' type='iso'/></ex></c></row>
<row><c><i>type=number</i></c><c><ex ><date date='' type='number'/></ex></c></row>
<row><c><i>type=ordered</i></c><c><ex ><date date='' type='ordered'/></ex></c></row>
<row><c><i>type=stardate</i></c><c><ex ><date date='' type='stardate'/></ex></c></row>
<row><c><i>type=string</i></c><c><ex ><date date='' type='string'/></ex></c></row>
</xtable>
</attr>

<attr name=part value=year|month|day|wday|date|mday|hour|minute|second|yday|beat|week|seconds>
 Defines which part of the date should be displayed. Day and wday is
 the same. Date and mday is the same. Yday is the day number of the
 year. Seconds is unix time type. Only the types string, number and
 ordered applies when the part attribute is used.
<xtable>
<row><c><i>part=year</i></c><c>Display the year.<ex ><date part='year' type='number'/></ex></c></row>
<row><c><i>part=month</i></c><c>Display the month. <ex ><date part='month' type='ordered'/></ex></c></row>
<row><c><i>part=day</i></c><c>Display the weekday, starting with Sunday. <ex ><date part='day' type='ordered'/></ex></c></row>
<row><c><i>part=wday</i></c><c>Display the weekday. Same as 'day'. <ex ><date part='wday' type='string'/></ex></c></row>
<row><c><i>part=date</i></c><c>Display the day of this month. <ex ><date part='date' type='ordered'/></ex></c></row>
<row><c><i>part=mday</i></c><c>Display the number of days since the last full month. <ex ><date part='mday' type='number'/></ex></c></row>
<row><c><i>part=hour</i></c><c>Display the numbers of hours since midnight. <ex ><date part='hour' type='ordered'/></ex></c></row>
<row><c><i>part=minute</i></c><c>Display the numbers of minutes since the last full hour. <ex ><date part='minute' type='number'/></ex></c></row>
<row><c><i>part=second</i></c><c>Display the numbers of seconds since the last full minute. <ex ><date part='second' type='string'/></ex></c></row>
<row><c><i>part=yday</i></c><c>Display the number of days since the first of January. <ex ><date part='yday' type='ordered'/></ex></c></row>
<row><c><i>part=beat</i></c><c>Display the number of beats since midnight Central European Time(CET). There is a total of 1000 beats per day. The beats system was designed by <a href='http://www.swatch.com'>Swatch</a> as a means for a universal time, without time zones and day/night changes. <ex ><date part='beat' type='number'/></ex></c></row>
<row><c><i>part=week</i></c><c>Display the number of the current week.<ex ><date part='week' type='number'/></ex></c></row>
<row><c><i>part=seconds</i></c><c>Display the total number of seconds this year. <ex ><date part='seconds' type='number'/></ex></c></row>
</xtable>
</attr>

<attr name=strftime value=string>
 If this attribute is given to date, it will format the result according to the argument string.
 <xtable>
 <row><c>%%</c><c>Percent character</c></row>
 <row><c>%a</c><c>Abbreviated weekday name, e.g. \"Mon\"</c></row>
 <row><c>%A</c><c>Weekday name</c></row>
 <row><c>%b</c><c>Abbreviated month name, e.g. \"Jan\"</c></row>
 <row><c>%B</c><c>Month name</c></row>
 <row><c>%c</c><c>Date and time, e.g. \"%a %b %d  %H:%M:%S %Y\"</c></row>
 <row><c>%C</c><c>Century number, zero padded to two charachters.</c></row>
 <row><c>%d</c><c>Day of month (1-31), zero padded to two characters.</c></row>
 <row><c>%D</c><c>Date as \"%m/%d/%y\"</c></row>
 <row><c>%e</c><c>Day of month (1-31), space padded to two characters.</c></row>
 <row><c>%H</c><c>Hour (24 hour clock, 0-23), zero padded to two characters.</c></row>
 <row><c>%h</c><c>See %b</c></row>
 <row><c>%I</c><c>Hour (12 hour clock, 1-12), zero padded to two charcters.</c></row>
 <row><c>%j</c><c>Day numer of year (1-366), zero padded to three characters.</c></row>
 <row><c>%k</c><c>Hour (24 hour clock, 0-23), space padded to two characters.</c></row>
 <row><c>%l</c><c>Hour (12 hour clock, 1-12), space padded to two characters.</c></row>
 <row><c>%m</c><c>Month number (1-12), zero padded to two characters.</c></row>
 <row><c>%M</c><c>Minute (0-59), zero padded to two characters.</c></row>
 <row><c>%n</c><c>Newline</c></row>
 <row><c>%p</c><c>\"a.m.\" or \"p.m.\"</c></row>
 <row><c>%r</c><c>Time in 12 hour clock format with %p</c></row>
 <row><c>%R</c><c>Time as \"%H:%M\"</c></row>
 <row><c>%S</c><c>Seconds (0-61), zero padded to two characters.</c></row>
 <row><c>%t</c><c>Tab</c></row>
 <row><c>%T</c><c>Time as \"%H:%M:%S\"</c></row>
 <row><c>%u</c><c>Weekday as a decimal number (1-7), 1 is Sunday.</c></row>
 <row><c>%U</c><c>Week number of year as a decimal number (0-53), with sunday as the first day of week 1,
    zero padded to two characters.</c></row>
 <row><c>%V</c><c>ISO week number of the year as a decimal number (1-53), zero padded to two characters.</c></row>
 <row><c>%w</c><c>Weekday as a decimal number (0-6), 0 is Sunday.</c></row>
 <row><c>%W</c><c>Week number of year as a decimal number (0-53), with sunday as the first day of week 1,
    zero padded to two characters.</c></row>
 <row><c>%x</c><c>Date as \"%a %b %d %Y\"</c></row>
 <row><c>%X</c><c>See %T</c></row>
 <row><c>%y</c><c>Year (0-99), zero padded to two characters.</c></row>
 <row><c>%Y</c><c>Year (0-9999), zero padded to four characters.</c></row>
 </xtable>

<ex><date strftime=\"%Y%m%d\"/></ex>
</attr>

<attr name=lang value=langcode>
 Defines in what language a string will be presented in. Used together
 with <att>type=string</att> and the <att>part</att> attribute to get
 written dates in the specified language.

<ex><date part='day' type='string' lang='de'></ex>
</attr>

<attr name=case value=upper|lower|capitalize>
 Changes the case of the output to upper, lower or capitalize.
<ex><date date='' lang='<ent>client.language</ent>' case='upper'/></ex>
</attr>

<attr name=prec value=number>
 The number of decimals in the stardate.
</attr>",

"debug":#"<desc tag><short>
 Helps debugging RXML-pages as well as modules.</short> When debugging mode is
 turned on, all error messages will be displayed in the HTML code.
</desc>

<attr name=on>
 Turns debug mode on.
</attr>

<attr name=off>
 Turns debug mode off.
</attr>

<attr name=toggle>
 Toggles debug mode.
</attr>

<attr name=showid value=string>
 Shows a part of the id object. E.g. showid=\"id->request_headers\".
</attr>",

"dec":#"<desc tag><short>
 Subtracts 1 from a variable.</short>
</desc>

<attr name=variable value=string required>
 The variable to be decremented.
</attr>

<attr name=value value=number default=1>
 The value to be subtracted.
</attr>",

"default":#"<desc cont><short hide>
 Used to set default values for form elements.</short> Makes it easier
 to give default values to \"<tag>select</tag>\" or
 \"<tag>checkbox</tag>\" form elements.

 <p>The <tag>default</tag> container tag is placed around the form element it
 should give a default value.</p>

 <p>This tag is particularly useful in combination with database tags.</p>
</desc>

<attr name=value value=string>
 The value to set.
</attr>

<attr name=separator value=string default=','>
 If several values are to be selected, this is the string that seperates them.
</attr>

<attr name=name value=string>
 Only affect form element with this name.
</attr>

<ex type='box'>
 <default name='my-select' value='<ent>form.preset</ent>'>
    <select name='my-select'>
      <option value='1'>First</option>
      <option value='2'>Second</option>
      <option value='3'>Third</option>
    </select>
 </default>
</ex>",

"doc":#"<desc cont><short hide>
 Eases code documentation by reformatting it.</short>
 Eases documentation by replacing \"{\", \"}\" and \"&amp;\" with \"&amp;lt;\", \"&amp;gt;\" and
 \"&amp;amp;\". No attributes required.
</desc>

<attr name=quote>
 Instead of replacing with \"{\" and \"}\", \"&lt;\" and \"&gt;\" is replaced with \"&amp;lt;\"
 and \"&amp;gt;\".

<ex><doc quote=''>
<table>
 <tr>
    <td> First cell </td>
    <td> Second cell </td>
 </tr>
</table>
</doc>
</ex>

</attr>

<attr name=pre>
 The result is encapsulated within a <tag>pre</tag> container.
<ex><doc pre=''>
{table}
 {tr}
    {td} First cell {/td}
    {td} Second cell {/td}
 {/tr}
{/table}
</doc>
</ex>
</attr>

<attr name=class value=string>
  This cascading style sheet (CSS) definition will be applied on the pre element.
  </attr>",

"expire-time":#"<desc tag><short>
 Sets cache expire time for the document.</short>
</desc>

<attr name=now>
 The document expires now.
</attr>

<attr name=years value=number>
 Add this number of years to the result.
</attr>

<attr name=months value=number>
 Add this number of months to the result.
</attr>

<attr name=weeks value=number>
 Add this number of weeks to the result.
</attr>

<attr name=days value=number>
 Add this number of days to the result.
</attr>

<attr name=hours value=number>
 Add this number of hours to the result.
</attr>

<attr name=beats value=number>
 Add this number of beats to the result.
</attr>

<attr name=minutes value=number>
 Add this number of minutes to the result.
</attr>

<attr name=seconds value=number>
 Add this number of seconds to the result.
</attr>
 It is not possible at the time to set the date beyond year 2038,
 since a unix time_t is used.",

"for":#"<desc cont><short>
 Makes it possible to create loops in RXML.</short>
</desc>

<attr name=from value=number>
 Initial value of the loop variable.
</attr>

<attr name=step value=number>
 How much to increment the variable per loop iteration. By default one.
</attr>

<attr name=to value=number>
 How much the loop variable should be incremented to.
</attr>

<attr name=variable value=name>
 Name of the loop variable.
</attr>",

"fsize":#"<desc tag><short>
 Prints the size of the specified file.</short>
</desc>

<attr name=file value=string>
 Show size for this file.
</attr>",

"gauge":#"<desc cont><short>
 Measures how much CPU time it takes to run its contents through the
 RXML parser.</short> Returns the number of seconds it took to parse
 the contents.
</desc>

<attr name=define value=string>
 The result will be put into a variable. E.g. define=var.gauge vill
 put the result in a variable that can be reached with <ent>var.gauge</ent>.
</attr>

<attr name=silent>
 Don't print anything.
</attr>

<attr name=timeonly>
 Only print the time.
</attr>

<attr name=resultonly>
 Only the result of the parsing. Useful if you want to put the time in
 a database or such.
</attr>",

"header":#"<desc tag><short>
 Adds a header to the document.</short>
</desc>

<attr name=name value=string>
 The name of the header.
</attr>

<attr name=value value=string>
 The value of the header.
</attr>

 For more information about HTTP headers please steer your browser to chapter 14, 'Header field definitions' in <a href='http://community.roxen.com/developers/idocs/rfc/rfc2616.html'> RFC 2616</a> at Roxen Community.",


"imgs":#"<desc tag><short>
 Generates a image tag with proper dimensions.</short>
</desc>

<attr name=src value=string required>
 The name of the file that should be shown.
</attr>

<attr name=alt value=string>
 Description of the image.
</attr>
 All other attributes will be inherited by the generated img tag.",

"inc":#"<desc tag><short>
 Adds 1 to a variable.</short>
</desc>

<attr name=variable value=string required>
 The variable to be incremented.
</attr>

<attr name=value value=number default=1>
 The value to be added.
</attr>",

"insert":#"<desc tag><short>
 Inserts a file, variable or other object into a webpage.</short>
</desc>

<attr name=quote value=html|none>
 How the inserted data should be quoted. Default is \"html\", except for
 href and file where it's \"none\".
</attr>",

"insert#variable":#"<desc plugin>Inserts the value of a variable.</desc>

<attr name=variable value=string>
 The name of the variable.
</attr>

<attr name=scope value=string>
 The name of the scope, unless given in the variable attribute.
</attr>

<attr name=index value=number>
 If the value of the variable is an array, the element with this index number
 will be inserted. 1 is the first element. -1 is the last element.
</attr>

<attr name=split value=string>
 A string with which the variable value should be splitted into an array, so
 that the index attribute may be used.
</attr>",

"insert#variables":#"<desc plugin><short>Inserts listing of all variables in a scope.</short>
Note that it is possible to create a scope with an infinite number of variables set. In
this case the programme of that scope decides which variables that should be listable, i.e.
this will not cause any problem except that all variables will not be listed. It is also
possible to hide variables so that they are not listed with this tag.
</desc>
<attr name=variables value=full|plain>
  Sets how the output should be formatted. 
 <ex>
<pre>
<insert variables='full' scope='roxen'/>
</pre>
 </ex>
</attr>

<attr name=scope>
 The name of the scope that should be listed, if not the present scope.
</attr>",

"insert#scopes":#"<desc plugin><short>Inserts a listing of all present scopes.</short></desc>

<attr name=scopes value=full|plain>
 Sets how the output should be formatted.
</attr>

 <ex>
   <insert scopes='plain'/>
 </ex>
</attr>",

"insert#file":#"<desc plugin><short>Inserts the contents of a file.</short>
 It reads files in a way similar to if you fetched the file with a browser, so
 the file may be parsed before it is inserted, depending on settings in
 the RXML parser. Most notably which kinds of files (extensions) that should be
 parsed. Since it reads files like a normal request, e.g. generated pages from
 location modules can be inserted.
 Put the tag <tag>eval</tag> around the <tag>insert</tag> if the file
 should be parsed after it is inserted in the page. This enables RXML defines and
 scope variables to be set in the including file (as opposed to the included file).
 You can also configure the file system module so that files with a certain extension
 can not be downloaded, but still inserted into other documents.</desc>

<attr name=file value=string>
 The virtual path to the file to be inserted.

 <ex type='box'>
  <eval><insert file='html_header.inc'/></eval>
 </ex>
</attr>",

"insert#realfile":#"<desc plugin>Inserts a raw, unparsed file. The disadvantage
with the realfile plugin compared to the file plugin is that the realfile plugin
needs the inserted file to exist, and can't fetch files from e.g. an arbitrary
location module.</desc>

<attr name=realfile value=string>
 The virtual path to the file to be inserted.
</attr>",

"maketag":#"<desc cont><short hide>Makes it possible to create tags.</short>
 This tag creates tags. The contents of the container will be put into
 the contents of the produced container.
</desc>

<attr name=name value=string required>
 The name of the tag.
</attr>

<attr name=noxml>
 Tags should not be terminated with a trailing slash.
</attr>

<attr name=type value=tag|container default=tag>
 What kind of tag should be produced.
</attr>
 Inside the maketag container the container attrib is defined. It is
 used to add attributes to the produced tag. It has the required
 attribute attrib, which is the name of the attribute. The contents of
 the attribute container will be the attribute value. E.g.

<ex><eval>
<maketag name=\"replace\" type=\"container\">
 <attrib name=\"from\">A</attrib>
 <attrib name=\"to\">U</attrib>
 MAD
</maketag>
</eval>
</ex>",

"modified":#"<desc tag><short hide>
 Prints when or by whom a page was last modified.</short> Prints when
 or by whom a page was last modified, by default the current page.
</desc>

<attr name=by>
 Print by whom the page was modified. Takes the same attributes as the
 <tag><ref type='tag'>user</ref></tag> tag. This attribute requires a
 userdatabase.

 <ex type='box'>This page was last modified by <modified by=''
 realname=''/>.</ex>
</attr>

<attr name=date>
 Print the modification date. Takes all the date attributes in the
 <tag><ref type='tag'>date</ref></tag> tag.

 <ex type='box'>This page was last modified <modified date=''
 case='lower' type='string'/>.</ex>
</attr>

<attr name=file value=path>
 Get information from this file rather than the current page.
</attr>

<attr name=realfile value=path>
 Get information from this file in the computers filesystem rather
 than Roxen Webserver's virtual filesystem.
</attr>",

"random":#"<desc cont><short>
 Randomly chooses a message from its contents.</short>
</desc>

<attr name=separator value=string>
 The separator used to separate the messages, by default newline.

<ex><random separator=#>
Roxen#Pike#Foo#Bar#roxen.com#community.roxen.com#Roxen Internet Software
</random>
</ex>

</attr>",

"recursive-output":#"<desc cont>

</desc>

<attr name=limit value=number>

</attr>

<attr name=inside value=string>

</attr>

<attr name=outside value=string>

</attr>

<attr name=separator value=string>

</attr>",

"redirect":#"<desc tag><short>
 Redirects the user to another page.</short> Requires the to attribute.
</desc>

<attr name=to value=string>
 Where the user should be sent to.
</attr>

<attr name=add value=string>
 The prestate or prestates that should be added, in a comma seperated
 list.
</attr>

<attr name=drop value=string>
 The prestate or prestates that should be dropped, in a comma seperated
 list.
</attr>

<attr name=text value=string>
 Sends a text string to the browser, that hints from where and why the
 page was redirected. Not all browsers will show this string. Only
 special clients like Telnet uses it.
</attr>
 Arguments prefixed with \"add\" or \"drop\" are treated as prestate
 toggles, which are added or removed, respectively, from the current
 set of prestates in the URL in the redirect header (see also <tag
 <ref type='tag'>apre</ref></tag>). Note that this only works when the
 to=... URL is absolute, i.e. begins with a \"/\", otherwise these
 state toggles have no effect.",

"remove-cookie":#"<desc tag><short>
 Sets the expire-time of a cookie to a date that has already occured.
 This forces the browser to remove it.</short>
 This tag won't remove the cookie, only set it to the empty string, or
 what is specified in the value attribute and change
 it's expire-time to a date that already has occured. This is
 unfortunutaly the only way as there is no command in HTTP for
 removing cookies. We have to give a hint to the browser and let it
 remove the cookie.
</desc>

<attr name=name>
 Name of the cookie the browser should remove.
</attr>

<attr name=value value=text>
 Even though the cookie has been marked as expired some browsers
 will not remove the cookie until it is shut down. The text provided
 with this attribute will be the cookies intermediate value.
</attr>

Note that removing a cookie won't take effect until the next page
load.",

"replace":#"<desc cont><short>
 Replaces strings in the contents with other strings.</short>
</desc>

<attr name=from value=string required>
 String or list of strings that should be replaced.
</attr>

<attr name=to value=string>
 String or list of strings with the replacement strings. Default is the
 empty string.
</attr>

<attr name=separator value=string default=','>
 Defines what string should seperate the strings in the from and to
 attributes.
</attr>

<attr name=type value=word|words default=word>
 Word means that a single string should be replaced. Words that from
 and to are lists.
</attr>",

"return":#"<desc tag><short>
 Changes the HTTP return code for this page.</short>

 See the Appendix for a list of HTTP return codes.
</desc>

<attr name=code>
 The HTTP status code to return (an integer).
</attr>

<attr name=text>
 The HTTP status message to set. If you don't provide one, a default
 message is provided for known HTTP status codes, e g \"No such file
 or directory.\" for code 404.
</attr>",

"roxen":#"<desc tag><short>
 Returns a nice Roxen logo.</short>
</desc>

<attr name=size value=small|medium|large default=medium>
 Defines the size of the image.
<ex type='vert'><roxen size='small'/> <roxen/> <roxen size='large'/></ex>
</attr>

<attr name=color value=black|white default=white>
 Defines the color of the image.
<ex type='vert'><roxen color='black'/></ex>
</attr>

<attr name=alt value=string default='\"Powered by Roxen\"'>
 The image description.
</attr>

<attr name=border value=number default=0>
 The image border.
</attr>

<attr name=class value=string>
 This cascading style sheet (CSS) definition will be applied on the img element.
</attr>

<attr name=target value=string>
 Names a target frame for the link around the image.
</attr>
 All other attributes will be inherited by the generated img tag.",

"scope":#"<desc cont><short>
 Creates a new variable scope.</short> Variable changes inside the scope
 container will not affect variables in the rest of the page.
</desc>

<attr name=extend value=name default=form>
 If set, all variables in the selected scope will be copied into the new scope.
 NOTE: if the source scope is \"magic\", as e.g. the roxen scope, the scope will
 not be copied, but rather linked and will behave as the original scope. It can
 be useful to create an alias or just for the convinience of refering to the
 scope as \"_\".
</attr>

<attr name=scope value=name default=form>
 The name of the new scope, besides \"_\".
</attr>",

"set":#"<desc tag><short>
Sets a variable.</short>
</desc>

<attr name=variable value=string required>
 The name of the variable.
<ex type='box'>
<set variable='var.foo' value='bar'/>
</ex>
</attr>

<attr name=value value=string>
 The value the variable should have.
</attr>

<attr name=expr value=string>
 An expression whose evaluated value the variable should have.
</attr>

<attr name=from value=string>
 The name of another variable that the value should be copied from.
</attr>

<attr name=split value=string>
 The value will be splitted by this string into an array.
</attr>

 If none of the above attributes are specified, the variable is unset.
 If debug is currently on, more specific debug information is provided
 if the operation failed. See also: <ref type='tag'>append</ref>
 and <ref type='tag'>debug</ref>",

"set-cookie":#"<desc tag><short>
 Sets a cookie that will be stored by the user's browser.</short> This
 is a simple and effective way of storing data that is local to the
 user. If no arguments specifying the time the cookie should survive
 is given to the tag, it will live until the end of the current browser
 session. Otherwise, the cookie will be persistent, and the next time
 the user visits  the site, she will bring the cookie with her.
</desc>

<attr name=name value=string>
 The name of the cookie.
</attr>

<attr name=seconds value=number>
 Add this number of seconds to the time the cookie is kept.
</attr>

<attr name=minutes value=number>
 Add this number of minutes to the time the cookie is kept.
</attr>

<attr name=hours value=number>
 Add this number of hours to the time the cookie is kept.
</attr>

<attr name=days value=number>
 Add this number of days to the time the cookie is kept.
</attr>

<attr name=weeks value=number>
 Add this number of weeks to the time the cookie is kept.
</attr>

<attr name=months value=number>
 Add this number of months to the time the cookie is kept.
</attr>

<attr name=years value=number>
 Add this number of years to the time the cookie is kept.
</attr>

<attr name=persistent>
 Keep the cookie for two years.
</attr>

<attr name=domain>
 The domain for which the cookie is valid.
</attr>

<attr name=value value=string>
 The value the cookie will be set to.
</attr>

<attr name=path value=string>
 The path in which the cookie should be available.
</attr>

 If persistent is specified, the cookie will be persistent until year
 2038, otherwise, the specified delays are used, just as for
 <tag><ref type='tag'>expire-time</ref></tag>.

 Note that the change of a cookie will not take effect until the
 next page load.",

"set-max-cache":#"<desc tag><short>
 Sets the maximum time this document can be cached in any ram
 caches.</short>

 <p>Default is to get this time from the other tags in the document
 (as an example, <tag>if supports=...</tag> sets the time to 0 seconds since
 the result of the test depends on the client used.</p>

 <p>You must do this at the end of the document, since many of the
 normal tags will override this value.</p>
</desc>

<attr name=years value=number>
 Add this number of years to the time this page was last loaded.
</attr>
<attr name=months value=number>
 Add this number of months to the time this page was last loaded.
</attr>
<attr name=weeks value=number>
 Add this number of weeks to the time this page was last loaded.
</attr>
<attr name=days value=number>
 Add this number of days to the time this page was last loaded.
</attr>
<attr name=hours value=number>
 Add this number of hours to the time this page was last loaded.
</attr>
<attr name=beats value=number>
 Add this number of beats to the time this page was last loaded.
</attr>
<attr name=minutes value=number>
 Add this number of minutes to the time this page was last loaded.
</attr>
<attr name=seconds value=number>
 Add this number of seconds to the time this page was last loaded.
</attr>",

"smallcaps":#"<desc cont><short>
 Prints the contents in smallcaps.</short> If the size attribute is
 given, font tags will be used, otherwise big and small tags will be
 used.
</desc>

<attr name=space>
 Put a space between every character.
<ex>
<smallcaps space=''>Roxen WebServer</smallcaps>
</ex>
</attr>

<attr name=class value=string>
 Apply this cascading style sheet (CSS) style on all elements.
</attr>

<attr name=smallclass value=string>
 Apply this cascading style sheet (CSS) style on all small elements.
</attr>

<attr name=bigclass value=string>
 Apply this cascading style sheet (CSS) style on all big elements.
</attr>

<attr name=size value=number>
 Use font tags, and this number as big size.
</attr>

<attr name=small value=number default=size-1>
 Size of the small tags. Only applies when size is specified.

 <ex>
  <smallcaps size='6' small='2'>Roxen WebServer</smallcaps>
 </ex>
 <ex>
  <smallcaps>Roxen WebServer</smallcaps>
 </ex>
</attr>",

"sort":#"<desc cont><short>
 Sorts the contents.</short>

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
 Defines what the strings to be sorted are separated with. The sorted
 string will be separated by the string.

 <ex>
  <sort separator='#'>
   1#Hello#3#World#Are#2#We#4#Communicating?
  </sort>
 </ex>
</attr>

<attr name=reverse>
 Reversed order sort.

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

"throw":#"<desc cont><short hide>
 Throws a text to be catched by <catch>.</short> Throws a text to be
 catched by <tag>catch</tag>. Throws an exception, with the enclosed
 text as the error message. This tag has a close relation to
 <tag>catch</tag>. The RXML parsing will stop at the <tag>throw</tag>
 tag. </desc>",

"trimlines":#"<desc cont><short>
 Removes all empty lines from the contents.</short>

  <ex>
  <trimlines>


   Are


   We

   Communicating?


  </trimlines>
 </ex>
</desc>",

"unset":#"
<desc tag><short>
 Unsets a variable, i.e. removes it.</short>
</desc>

<attr name=variable value=string required>
 The name of the variable.

 <ex>
  <set variable='var.jump' value='do it'/>
  <ent>var.jump</ent>
  <unset variable='var.jump'/>
  <ent>var.jump</ent>
 </ex>
</attr>",

"user":#"<desc tag><short>
 Prints information about the specified user.</short> By default, the
 full name of the user and her e-mail address will be printed, with a
 mailto link and link to the home page of that user.

 <p>The <tag>user</tag> tag requires an authentication module to work.</p>
</desc>

<attr name=email>
 Only print the e-mail address of the user, with no link.
 <ex type='box'>Email: <user name='foo' email=''/></ex>
</attr>

<attr name=link>
 Include links. Only meaningful together with the realname or email attribute.
</attr>

<attr name=name>
 The login name of the user. If no other attributes are specified, the
 user's realname and email including links will be inserted.
<ex type='box'><user name='foo'/></ex>
</attr>

<attr name=nolink>
 Don't include the links.
</attr>

<attr name=nohomepage>
 Don't include homepage links.
</attr>

<attr name=realname>
 Only print the full name of the user, with no link.
<ex type='box'><user name='foo' realname=''/></ex>
</attr>",

"if#expr":#"<desc plugin><short>

 This plugin evaluates expressions.</short> The arithmetic operators
 are \"+, - and /\". The last main operator is \"%\"(per cent). The
 allowed relationship operators are \"&lt;. &gt;, ==, &lt;= and
 &gt;=\".

 <p>All integers(characters 0 to 9) may be used together with
 \".\" to create floating point expressions.</p>

 <p>
 <ex type='box'>
   Hexadecimal expression: (0xff / 5) + 3
 </ex>
 To be able to evaluate hexadecimal expressions the characters \"a
 to f and A to F\" may be used.</p>

 <p>
 <ex type='box'>
   Integer conversion: ((int) 3.14)
   Floating point conversion: ((float) 100 / 7)
 </ex>

 Conversion between int and float may be done through the operators
 \"(int)\" and \"(float)\". The operators \"&\"(bitwise and),
 \"|\"((pipe)bitwise or), \"&&\"(logical and) and \"||\"((double
 pipe)logical or) may also be used in expressions. To set
 prioritizations within expressions the characters \"( and )\" are
 included. General prioritization rules are:

 <list type='ol'>
 <item>(int), (float)</item>
 <item>*, /, %</item>
 <item>+, -</item>
 <item>&lt;, &gt;, &lt;=, &gt;=\</item>
 <item>==</item>
 <item>&, |</item>
 <item>&&, ||</item>
 </list></p>

 <p>
 <ex type='box'>
   Octal expression: 045
 </ex>
 <ex type='box'>
   Calculator expression: 3.14e10 / 3
 </ex>
 Expressions containing octal numbers may be used. It is also
 possible to evaluate calculator expressions.</p>

 <p>Expr is an <i>Eval</i> plugin.</p>
</desc>
<attr name='expr' value='expression'>
 Choose what expression to test.
</attr>",

"emit#fonts":({ #"<desc plugin><short>
 Prints available fonts.</short> This plugin makes it easy to list all
 available fonts in Roxen WebServer.

<attr name='type' value='ttf|all'>
Which font types to list. ttf means all true type fonts, whereas all means all
available fonts.
</attr>
</desc>",
		([
"&_.name;":#"<desc ent>
 Returns a font identification name.

<p>This example will print all available ttf fonts in gtext-style.</p>
<ex type='box'>
 <emit source='fonts' type='ttf'>
   <gtext font='&_.name;'><ent>_.expose</ent></gtext><br />
 </emit>
</ex>
</desc>",
"&_.copyright;":"<desc ent>Font copyright notice. Only available for true type fonts.</desc>",
"&_.expose;":"<desc ent>The preferred list name. Only available for true type fonts.</desc>",
"&_.family;":"<desc ent>The font family name. Only available for true type fonts.</desc>",
"&_.full;":"<desc ent>The full name of the font. Only available for true type fonts.</desc>",
"&_.path;":"<desc ent>The location of the font file.</desc>",
"&_.postscript;":"<desc ent>The fonts postscript identification. Only available for true type fonts.</desc>",
"&_.style;":"<desc ent>Font style type. Only available for true type fonts.</desc>",
"&_.format;":"<desc ent>The format of the font file, e.g. ttf.</desc>",
"&_.version;":"<desc ent>The version of the font. Only available for true type fonts.</desc>",
"&_.trademark;":"<desc ent>Font trademark notice. Only available for true type fonts.</desc>",
		])
	     }),
    ]);
#endif
