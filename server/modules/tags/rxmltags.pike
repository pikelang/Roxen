// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.
//

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

constant cvs_version="$Id: rxmltags.pike,v 1.96 2000/03/13 20:50:25 nilsson Exp $";
constant thread_safe=1;
constant language = roxen->language;

#include <module.h>

inherit "module";
inherit "roxenlib";

// ---------------- Module registration stuff ----------------

constant module_type = MODULE_PARSER | MODULE_PROVIDER;
constant module_name = "RXML 2.0 tags";
constant module_doc  = "This module adds a lot of RXML tags.";

void create()
{
  defvar("insert_href",1,"Allow &lt;insert href&gt;.",
	 TYPE_FLAG|VAR_MORE,
         "Should the usage of &lt;insert href&gt; be allowed?");
}

void start()
{
  add_api_function("query_modified", api_query_modified, ({ "string" }));
  query_tag_set()->prepare_context=set_entities;
}

string query_provides() {
  return "modified";
}

constant permitted = "123456789.xabcdefint\"XABCDEFlo<>=0-*+/%%|()"/"";

string sexpr_eval(string what)
{
  array q = what/"";
  what = "mixed foo(){ return "+(q-(q-permitted))*""+";}";
  return (string)compile_string( what )()->foo();
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
  string rxml_const_eval(RXML.Context c) { return c->id->query; }
}

class EntityPageURL {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) { return c->id->raw_url; }
}

class EntityPageLastTrue {
  inherit RXML.Value;
  int rxml_var_eval(RXML.Context c) { return c->id->misc->defines[" _ok"]; }
}

class EntityPageLanguage {
  inherit RXML.Value;
  string rxml_const_eval(RXML.Context c) { return c->id->misc->defines->language || ""; }
}

class EntityPageScope {
  inherit RXML.Value;
  string rxml_var_eval(RXML.Context c) { return c->current_scope(); }
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
    if (!c->id->my_fd->session) return 0;
    return c->id->my_fd->session->cipher_spec->key_bits;
  }
}

mapping(string:object) page_scope=([
  "realfile":EntityPageRealfile(),
  "virtroot":EntityPageVirtroot(),
  "virtfile":EntityPageVirtfile(),
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

mapping client_scope=([
  "ip":EntityClientIP(),
  "name":EntityClientName(),
  "referrer":EntityClientReferrer(),
  "accept-language":EntityClientAcceptLanguage(),
  "accept-languages":EntityClientAcceptLanguages(),
  "language":EntityClientLanguage(),
  "languages":EntityClientLanguages(),
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
  mapping(string:RXML.Type) req_arg_types = ([ "variable" : RXML.t_text ]);

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

mapping tag_auth_required (string tagname, mapping args, RequestID id)
{
  mapping hdrs = http_auth_required (args->realm, args->message);
  if (hdrs->error) _error = hdrs->error;
  if (hdrs->extra_heads)
     _extra_heads += hdrs->extra_heads;
    // We do not need this as long as hdrs only contains strings and numbers
    //   foreach(indices(hdrs->extra_heads), string tmp)
    //      add_http_header(_extra_heads, tmp, hdrs->extra_heads[tmp]);
  if (hdrs->text) _rettext = hdrs->text;
  return hdrs;
}

string tag_expire_time(string tag, mapping m, RequestID id)
{
  int t,t2;
  t=t2==time(1);
  if(!m->now) {
    t+=time_dequantifier(m);
    CACHE(max(t-time(),0));
  }
  if(t==t2) {
    NOCACHE();
    add_http_header(_extra_heads, "Pragma", "no-cache");
    add_http_header(_extra_heads, "Cache-Control", "no-cache");
  }

  add_http_header(_extra_heads, "Expires", http_date(t));
  return "";
}

string tag_header(string tag, mapping m, RequestID id)
{
  if(m->name == "WWW-Authenticate")
  {
    string r;
    if(m->value)
    {
      if(!sscanf(m->value, "Realm=%s", r))
	r=m->value;
    } else
      r="Users";
    m->value="basic realm=\""+r+"\"";
  } else if(m->name=="URI")
    m->value = "<" + m->value + ">";

  if(!(m->value && m->name))
    RXML.parse_error("Requires both a name and a value.\n");

  add_http_header(_extra_heads, m->name, m->value);
  return "";
}

string tag_redirect(string tag, mapping m, RequestID id)
{
  if (!(m->to && sizeof (m->to)))
    RXML.parse_error("Requires attribute \"to\".\n");

  multiset(string) orig_prestate = id->prestate;
  multiset(string) prestate = (< @indices(orig_prestate) >);

  if(m->add) {
    foreach((m->add-" ")/",", string s)
      prestate[s]=1;
    m_delete(m,"add");
  }
  if(m->drop) {
    foreach((m->drop-" ")/",", string s)
      prestate[s]=0;
    m_delete(m,"drop");
  }

  id->prestate = prestate;
  mapping r = http_redirect(m->to, id);
  id->prestate = orig_prestate;

  if (r->error)
    _error = r->error;
  if (r->extra_heads)
    _extra_heads += r->extra_heads;
  // We do not need this as long as r only contains strings and numbers
  //    foreach(indices(r->extra_heads), string tmp)
  //      add_http_header(_extra_heads, tmp, r->extra_heads[tmp]);
  if (m->text)
    _rettext = m->text;

  return "";
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
  mapping(string:RXML.Type) req_arg_types = ([ "variable": RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if (args->value) {
	// Set an entity variable to a value.
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

      parse_error("No value specified.\n");
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
      string res=inc(args, id);
      if(res) parse_error(res);
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
      string res=dec(args, id);
      if(res) parse_error(res);
      return 0;
    }
  }
}

private string inc(mapping m, RequestID id)
{
  RXML.Context context=RXML.get_context();
  array entity=context->parse_user_var(m->variable, m->scope);
  if(!context->exist_scope(entity[0])) RXML.run_error("Scope "+entity[0]+" does not exist.\n");
  int val=(int)m->value||1;
  context->user_set_var(m->variable, (int)context->user_get_var(m->variable, m->scope)+val, m->scope);
  return 0;
}

private string dec(mapping m, RequestID id)
{
  m->value=-(int)m->value||-1;
  return inc(m, id);
}

string|array(string) tag_imgs(string tag, mapping m, RequestID id)
{
  if(m->src)
  {
    string file;
    if(file=id->conf->real_file(fix_relative(m->src, id), id))
    {
      array(int) xysize;
      if(xysize=Dims.dims()->get(file))
      {
	m->width=(string)xysize[0];
	m->height=(string)xysize[1];
      }
      else if(!m->quiet)
	RXML.run_error("Dimensions quering failed.\n");
    }
    else if(!m->quiet)
      RXML.run_error("Virtual path failed.\n");

    if(!m->alt) {
      array src=m->src/"/";
      string src=src[sizeof(src)-1];
      m->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src),".")-2],"_"," "));
    }

    return ({ make_tag("img", m) });
  }
  RXML.parse_error("No src given.\n");
}

array(string) tag_roxen(string tagname, mapping m, RequestID id)
{
  string size = m->size || "small";
  string color = m->color || "blue";
  mapping aargs = (["href": "http://www.roxen.com/"]);
  m_delete(m, "color");
  m_delete(m, "size");
  m->src = "/internal-roxen-power-"+size+"-"+color;
  m->width = (["small":"100","medium":"200","large":"300"])[size];
  m->height = (["small":"35","medium":"60","large":"90"])[size];
  if(!m->alt) m->alt="Powered by Roxen";
  if(!m->border) m->border="0";
  if(!m->noxml) m["/"]="/";
  if (m->target) aargs->target = m->target, m_delete (m, "target");
  return ({ make_container ("a", aargs, make_tag("img", m)) });
}

string|array(string) tag_debug( string tag_name, mapping m, RequestID id )
{
  if (m->showid)
  {
    array path=lower_case(m->showid)/"->";
    if(path[0]!="id" || sizeof(path)==1) RXML.parse_error("Can only show parts of the id object.");
    mixed obj=id;
    foreach(path[1..], string tmp) {
      if(search(indices(obj),tmp)==-1) RXML.run_error("Could only reach "+tmp+".");
      obj=obj[tmp];
    }
    return ({ "<pre>"+html_encode_string(sprintf("%O",obj))+"</pre>" });
  }
  if (m->werror) {
    report_debug(replace(m->werror,"\\n","\n"));
  }
  if (m->off)
    id->misc->debug = 0;
  else if (m->toggle)
    id->misc->debug = !id->misc->debug;
  else
    id->misc->debug = 1;
  return "<!-- Debug is "+(id->misc->debug?"enabled":"disabled")+" -->";
}

string tag_fsize(string tag, mapping args, RequestID id)
{
  if(args->file) {
    catch {
      array s = id->conf->stat_file( fix_relative( args->file, id ), id );
      if (s && (s[1]>= 0)) return (string)s[1];
    };
    if(string s=id->conf->try_get_file(fix_relative(args->file, id), id ) )
      return (string)strlen(s);
  }
  RXML.run_error("Failed to find file.\n");
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
      result=Array.map(space, lambda(int|string c) {
				return intp(c)?(string)({c-(sizeof(space))}):c;
			      } )*"";
    }
  }
}

array(string)|string tag_configimage(string t, mapping m, RequestID id)
{
  if (!m->src) RXML.parse_error("No src given.\n", id);

  if (m->src[sizeof(m->src)-4..][0] == '.')
    m->src = m->src[..sizeof(m->src)-5];

  m->alt = m->alt || m->src;
  m->src = "/internal-roxen-" + m->src;
  m->border = m->border || "0";

  return ({ make_tag("img", m) });
}

string tag_date(string q, mapping m, RequestID id)
{
  int t=(int)m["unix-time"] || time(1);
  t+=time_dequantifier(m);

  if(!(m->brief || m->time || m->date))
    m->full=1;

  if(m->part=="second" || m->part=="beat")
    NOCACHE();
  else
    CACHE(60); // One minute is good enough.

  return tagtime(t, m, id, language);
}

string|array(string) tag_insert( string tag, mapping m, RequestID id )
{
  string n;

  if(n = m->variable)
  {
    if(zero_type(RXML.user_get_var(n, m->scope)))
      RXML.run_error(tag, "No such variable ("+n+").\n", id);
    string var=(string)RXML.user_get_var(n, m->scope);
    return m->quote=="none"?var:({ html_encode_string(var) });
  }

  if(n = m->variables || m->scope) {
    RXML.Context context=RXML.get_context();
    if(n!="variables")
      return ({ html_encode_string(Array.map(sort(context->list_var(m->scope)),
					     lambda(string s) {
					       return sprintf("%s=%O", s, context->get_var(s, m->scope) );
					     } ) * "\n")
				   });
    return ({ String.implode_nicely(sort(context->list_var(m->scope))) });
  }

  if(m->scopes) {
    return ({ String.implode_nicely(sort(RXML.get_context()->list_scopes())) });
  }

  if(m->file)
  {
    if(m->nocache) {
      int nocache=id->pragma["no-cache"];
      id->pragma["no-cache"] = 1;
      n=API_read_file(id,m->file);
      if(!n) RXML.run_error("No such file ("+m->file+").\n");
      id->pragma["no-cache"] = nocache;
      return n;
    }
    n=API_read_file(id,m->file);
    if(!n) RXML.run_error("No such file ("+m->file+").\n");
    return n;
  }

  if(m->href && query("insert_href")) {
    if(m->nocache)
      NOCACHE();
    else
      CACHE(60);
    Protocols.HTTP q=Protocols.HTTP.get_url(m->href);
    if(q && q->status>0 && q->status<400)
      return ({ q->data() });
    RXML.run_error(q ? q->status_desc + "\n": "No server response\n");
  }

  if(m->var) {
    object|array tagfunc=RXML.get_context()->tag_set->get_tag("!--#echo");
    if(!tagfunc) RXML.run_error("No SSI module added.\n");
    return ({ 1, "!--#echo", m});
  }

  RXML.parse_error("No correct insert attribute given.\n");
}

string tag_return(string tag, mapping m, RequestID id)
{
  int c=(int)m->code;
  if(c) _error=c;
  string p=m->text;
  if(p) _rettext=p;
  return "";
}

string tag_set_cookie(string tag, mapping m, RequestID id)
{
  if(!m->name)
    RXML.parse_error("Requires a name attribute.\n");

  string cookies = m->name+"="+http_encode_cookie(m->value||"");
  int t;     //time

  if(m->persistent)
    t=(3600*(24*365*2));
  else
    t=time_dequantifier(m);

  if(t)
    cookies += "; expires="+http_date(t+time(1));

  //FIXME: Check the parameter's usability
  cookies += "; path=" +(m->path||"/");

  add_http_header(_extra_heads, "Set-Cookie", cookies);

  return "";
}

string tag_remove_cookie(string tag, mapping m, RequestID id)
{
  if(!m->name || !id->cookies[m->name]) RXML.run_error("That cookie does not exists.\n");

  add_http_header(_extra_heads, "Set-Cookie",
    m->name+"="+http_encode_cookie(m->value||"")+"; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/"
  );

  return "";
}

string tag_modified(string tag, mapping m, RequestID id, Stdio.File file)
{
  array (int) s;
  Stdio.File f;

  if(m->by && !m->file && !m->realfile)
  {
    // FIXME: The auth module should probably not be used in this case.
    if(!id->conf->auth_module)
      RXML.run_error("Modified by requires a user database.\n");
    // FIXME: The next row is defunct. last_modified_by does not exists.
    m->name = id->conf->last_modified_by(file, id);
    CACHE(10);
    return tag_user(tag, m, id, file);
  }

  if(m->file)
  {
    m->realfile = id->conf->real_file(fix_relative(m->file,id), id);
    m_delete(m, "file");
  }

  if(m->by && m->realfile)
  {
    if(!id->conf->auth_module)
      RXML.run_error("Modified by requires a user database.\n");

    if(f = open(m->realfile, "r"))
    {
      m->name = id->conf->last_modified_by(f, id);
      destruct(f);
      CACHE(10);
      return tag_user(tag, m, id, file);
    }
    return "A. Nonymous.";
  }

  if(m->realfile)
    s = file_stat(m->realfile);

  if(!(_stat || s) && !m->realfile && id->realfile)
  {
    m->realfile = id->realfile;
    return tag_modified(tag, m, id, file);
  }
  CACHE(10);
  if(!s) s = _stat;
  if(!s) s = id->conf->stat_file( id->not_query, id );
  if(s) {
    if(m->ssi)
      return strftime(id->misc->ssi_timefmt || "%c", s[3]);
    return tagtime(s[3], m, id, language);
  }

  if(m->ssi) return id->misc->ssi_errmsg||"";
  RXML.run_error("Couldn't stat file.\n");
}

string|array(string) tag_user(string tag, mapping m, RequestID id, Stdio.File file)
{
  array(string) u;
  string b, dom;

  if(!id->conf->auth_module)
    RXML.run_error("Requires a user database.\n");

  if (!(b=m->name))
    return(tag_modified("modified", m | ([ "by":"by" ]), id, file));

  b=m->name;

  dom=id->conf->query("Domain");
  if(dom[-1]=='.')
    dom=dom[0..strlen(dom)-2];
  if(!b) return "";
  u=id->conf->userinfo(b, id);
  if(!u) return "";

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
      id->misc->cacheable = time_dequantifier(args);
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
  mapping(string:RXML.Type) opt_arg_types = ([ "extend" : RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;

    constant scope_name = "form";
    mapping vars;
    mapping oldvar;

    array do_enter(RequestID id) {
      oldvar=id->variables;
      if(args->extend)
	vars=copy_value(id->variables);
      else
	vars=([]);
      id->variables=vars;
      return 0;
    }

    array do_return(RequestID id) {
      id->variables=oldvar;
      result=content;
      return 0;
    }
  }
}

array(string) container_catch( string tag, mapping m, string c, RequestID id )
{
  string r;
  if(!id->misc->catcher_is_ready)
    id->misc+=(["catcher_is_ready":1]);
  else
    id->misc->catcher_is_ready++;
  array e = catch(r=parse_rxml(c, id));
  id->misc->catcher_is_ready--;
  if(e) return e[0];
  return ({r});
}

array(string) container_cache(string tag, mapping args,
                              string contents, RequestID id)
{
#define HASH(x) (x+id->not_query+id->query+id->realauth+id->conf->query("MyWorldLocation"))
  string key="";
  contents=parse_html(contents, ([]), (["cache":container_cache]) );
  if(!args->nohash) {
#if constant(Crypto.md5)
    object md5 = Crypto.md5();
    md5->update(HASH(contents));
    key=md5->digest();
#else
    key = (string)hash(HASH(contents));
#endif
  }
  if(args->key)
    key += args->key;
  string parsed = cache_lookup("tag_cache", key);
  if(!parsed) {
    parsed = parse_rxml(contents, id);
    cache_set("tag_cache", key, parsed, time_dequantifier(args));
  }
  return ({parsed});
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

string simpletag_foreach(string t, mapping args, string c, RequestID id)
{
  string v = args->variable;
  array what;
  if(!args->in)
    RXML.parse_error("No in attribute given.\n");
  if(args->variables)
    what = Array.map(args->in/"," - ({""}),
		     lambda(string name, mapping v) {
				     return v[name] || "";
				   }, id->variables);
  else
    what = Array.map(args->in / "," - ({""}),
		     lambda(string var) {
		       sscanf(var, "%*[ \t\n\r]%s", var);
		       var = reverse(var);
		       sscanf(var, "%*[ \t\n\r]%s", var);
		       return reverse(var);
		     });

  string res="";
  foreach(what, string w)
    res += "<set variable="+v+" value="+w+">"+c;
  return res;
}

string simpletag_apre(string tag, mapping m, string q, RequestID id)
{
  string href, s;
  array(string) foo;

  if(!(href = m->href))
    href=strip_prestate(strip_config(id->raw_url));
  else
  {
    if ((sizeof(foo = href / ":") > 1) && (sizeof(foo[0] / "/") == 1))
      return make_container("a", m, q);
    href=strip_prestate(fix_relative(href, id));
    m_delete(m, "href");
  }

  if(!strlen(href))
    href="";

  multiset prestate = (< @indices(id->prestate) >);

  if(m->add) {
    foreach((m->add-" ")/",", s)
      prestate[s]=1;
    m_delete(m,"add");
  }
  if(m->drop) {
    foreach((m->drop-" ")/",", s)
      prestate[s]=0;
    m_delete(m,"drop");
  }
  m->href = add_pre_state(href, prestate);
  return make_container("a", m, q);
}

string simpletag_aconf(string tag, mapping m,
		       string q, RequestID id)
{
  string href,s;

  if(!m->href)
    href=strip_prestate(strip_config(id->raw_url));
  else
  {
    href=m->href;
    if (search(href, ":") == search(href, "//")-1)
      RXML.parse_error("It is not possible to add configs to absolute URLs.\n");
    href=fix_relative(href, id);
    m_delete(m, "href");
  }

  array cookies = ({});
  if(m->add) {
    foreach((m->add-" ")/",", s)
      cookies+=({s});
    m_delete(m,"add");
  }
  if(m->drop) {
    foreach((m->drop-" ")/",", s)
      cookies+=({"-"+s});
    m_delete(m,"drop");
  }

  m->href = add_config(href, cookies, id->prestate);
  return make_container("a", m, q);
}

string simpletag_maketag(string tag, mapping m, string cont, RequestID id)
{
  mapping args=(!m->noxml&&m->type=="tag"?(["/":"/"]):([]));
  cont=parse_html(parse_rxml(cont,id), ([]), (["attrib":
    lambda(string tag, mapping m, string cont, mapping args) {
      args[m->name]=cont;
      return "";
    }
  ]), args);
  if(m->type=="container")
    return make_container(m->name, args, cont);
  return make_tag(m->name, args);
}

string simpletag_doc(string tag, mapping m, string s)
{
  if(!m["quote"])
    if(m["pre"]) {
      m_delete(m,"pre");
      return "\n"+make_container("pre",m,
	replace(s, ({"{","}","& "}),({"&lt;","&gt;","&amp; "})))+"\n";
    }
    else
      return replace(s, ({ "{", "}", "& " }), ({ "&lt;", "&gt;", "&amp; " }));
  else
    if(m["pre"]) {
      m_delete(m,"pre");
      m_delete(m,"quote");
      return "\n"+make_container("pre",m,
	replace(s, ({"<",">","& "}),({"&lt;","&gt;","&amp; "})))+"\n";
    }
    else
      return replace(s, ({ "<", ">", "& " }), ({ "&lt;", "&gt;", "&amp; " }));
}

string simpletag_autoformat(string tag, mapping m, string s, RequestID id)
{
  s-="\r";

  string p=(m["class"]?"<p class=\""+m["class"]+"\">":"<p>");

  if(!m->nobr) {
    s = replace(s, "\n", "<br>\n");
    if(m->p) {
      if(search(s, "<br>\n<br>\n")!=-1) s=p+s;
      s = replace(s, "<br>\n<br>\n", "\n</p>"+p+"\n");
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

class Smallcapsstr {
  constant UNDEF=0, BIG=1, SMALL=2;
  static string text="",part="",bigtag,smalltag;
  static mapping bigarg,smallarg;
  static int last=UNDEF;

  void create(string bs, string ss, mapping bm, mapping sm) {
    bigtag=bs;
    smalltag=ss;
    bigarg=bm;
    smallarg=sm;
  }

  string _sprintf() {
    return "Smallcapsstr()";
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
      text+=make_container(bigtag,bigarg,part);
      break;
    case SMALL:
      text+=make_container(smalltag,smallarg,part);
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

string simpletag_random(string tag, mapping m, string s)
{
  string|array q;
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
  if(!id->misc->catcher_is_ready && c[-1]!='\n')
    c+="\n";
  throw( ({ c, backtrace() }) );
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

  return ({ make_tag(t, m) });
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
  if(m->name!=name) return ({ make_container(t,m,c) });
  Regexp r = Regexp( "(.*)<([Oo][Pp][Tt][Ii][Oo][Nn])([^>]*)>(.*)" );
  array(string) tmp=split_on_option(c,r);
  string ret=tmp[0],nvalue;
  int selected,stop;
  tmp=tmp[1..];
  while(sizeof(tmp)>2) {
    stop=search(tmp[2],"<");
    if(sscanf(lower_case(tmp[1]),"%*svalue=%s%*[ >]",nvalue)!=3) nvalue=tmp[2][..stop==-1?sizeof(tmp[2]):stop];
    selected=Regexp(".*[Ss][Ee][Ll][Ee][Cc][Tt][Ee][Dd].*")->match(tmp[1]);
    ret+="<"+tmp[0]+tmp[1];
    if(value[nvalue] && !selected) ret+=" selected=\"selected\"";
    ret+=">"+tmp[2];
    if(!Regexp(".*</[Oo][Pp][Tt][Ii][Oo][Nn]")->match(tmp[2])) ret+="</"+tmp[0]+">";
    tmp=tmp[3..];
  }
  return ({ make_container(t,m,ret) });
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

array(string)|string container_recursive_output (string tagname, mapping args,
                                  string contents, RequestID id)
{
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit)
  {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else
  {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->separator || ",") : ({});
    outside = args->outside ? args->outside / (args->separator || ",") : ({});
    if (sizeof (inside) != sizeof (outside))
      RXML.parse_error("'inside' and 'outside' replacement sequences "
		       "aren't of same length.\n");
  }

  if (limit <= 0) return contents;

  int save_limit = id->misc->recout_limit;
  string save_inside = id->misc->recout_inside, save_outside = id->misc->recout_outside;

  id->misc->recout_limit = limit;
  id->misc->recout_inside = inside;
  id->misc->recout_outside = outside;

  string res = parse_rxml (
    parse_html (
      contents,
      (["recurse": lambda (string t, mapping a, string c) {return ({c});}]),
      ([]),
      "<" + tagname + ">" + replace (contents, inside, outside) +
      "</" + tagname + ">"),
    id);

  id->misc->recout_limit = save_limit;
  id->misc->recout_inside = save_inside;
  id->misc->recout_outside = save_outside;

  return ({res});
}

//I'll donate a Star Wars insiders guide to the
//first one to figure out what this number means,
//and how it was calculated. nilsson@roxen.com
#define MAGIC_EXIT 4921325

string tag_leave(string tag, mapping m, RequestID id)
{
  if(id->misc->leave_repeat)
  {
    id->misc->leave_repeat--;
    throw(MAGIC_EXIT);
  }
  RXML.parse_error("Must be contained by <repeat>.\n");
}

string container_repeat(string tag, mapping m, string c, RequestID id)
{
  if(!id->misc->leave_repeat)
    id->misc->leave_repeat=0;
  int exit=id->misc->leave_repeat++,loop,maxloop=(int)m->maxloops||10000;
  string ret="",iter;
  while(loop<maxloop && id->misc->leave_repeat!=exit) {
    loop++;
    mixed error=catch {
      iter=parse_rxml(c,id);
    };
    if((intp(error) && error!=0 && error!=MAGIC_EXIT) || !intp(error))
      throw(error);
    if(id->misc->leave_repeat!=exit)
      ret+=iter;
  }

  if(loop==maxloop)
    RXML.run_error("Too many iterations ("+maxloop+").");

  return ret;
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
      if(!content) content="";
      if( args->quote != "none" )
	content = html_decode_string( content );
      if( !args->variable ) parse_error("Variable not specified.\n");

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
"&client.ip;":"<desc ent>The client is located on this IP-address.</desc>",
"&client.name;":"<desc ent>The name of the client, i.e. \"Mozilla/4.7\". </desc>",
"&client.full-name;":#"<desc ent>The full user agent string, i.e. name of the client
 and additional info like; operating system, type of computer, etc.
 E.g. \"Mozilla/4.7 [en] (X11; I; SunOS 5.7 i86pc)\". </desc>",
"&client.referrer;":#"<desc ent>Prints the URL of the page on which the user followed
 a link that brought her to this page. The information comes from the referrer header
 sent by the browser.</desc>",
"&client.accept-language;":#"<desc ent>The client prefers to have the page contents
 presented in this language.</desc>",
"&client.accept-languages;":#"<desc ent>The client prefers to have the page contents
 presented in this language but these additional languages are accepted as well.</desc>",
"&client.language;":"<desc ent>The clients most preferred language.</desc>",
"&client.languages;":"<desc ent>An ordered list of the clients most preferred</desc>",

"&page.realfile;":"<desc ent>Path to this file in the file system.</desc>",
"&page.virtroot;":"<desc ent>The root of the present virtual filesystem.</desc>",
"&page.virtfile;":"<desc ent>Path to this file in the virtual file systme.</desc>",
"&page.query;":"<desc ent></desc>",
"&page.url;":"<desc ent>The URL to this file, from the web server's root or point of view.</desc>",
"&page.last-true;":"<desc ent></desc>",
"&page.language;":#"<desc ent>What language the contens of this file is written in.
 The language must be given as metadata to be found.</desc>",
"&page.scope;":"<desc ent></desc>",
"&page.filesize;":"<desc ent>This file's size, in bytes.</desc>",
"&page.ssl-strength;":"<desc ent>The strength in bits of the current SSL connection.</desc>",
"&page.self;":"<desc ent>The name of this file.</desc>",

"roxen_automatic_charset_variable":#"<desc tag>
 Internal Roxen tag. Not yet documented.
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
 This CSS class definition will apply to the a-element.
</attr>
 <p>All other attributes will be inherited by the generated a tag.</p>",

"append":#"<desc tag><short>
 Appends a value to a variable. The variable attribute and one more is
 required.</short>
</desc>

<attr name=variable value=string>
 The name of the variable.
</attr>

<attr name=value value=string>
 The value the variable should have appended.
</attr>

</attr name=from value=string>
 The name of another variable that the value should be copied from.
</attr>",

"apre":#"<desc cont><short>
 Creates a link that can modify prestates.</short>
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
 This CSS class definition will apply to the a-element.
</attr>

 Adds or removes a prestate option. Prestate options are simple
 toggles, and are added to the URL of the page. Use <tag>if</tag>
 prestate=...<tag>/if</tag> to test for the presence of a prestate.
 <tag>apre</tag> works just like the <tag>a href=...</tag> container,
 but if no \"href\" attribute is specified, the current page is used.",

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

"autoformat":#"<desc cont><short>
 Replaces newlines with <tag>br</tag>:s.</short>
</desc>

<attr name=nobr>
 Do not replace newlines with <tag>br</tag>:s.
</attr>

<attr name=p>
 Replace double newlines with <tag>p</tag>:s.
</attr>

<attr name=class value=string>
 This CSS definition will be applied on the p elements.
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

"catch":#"<desc cont><short>
 Evaluates the RXML code, and, if nothing goes wrong, returns the
 parsed contents.</short> If something does go wrong, the error
 message is returned instead. See also <tag><ref
 type=tag>throw</ref></tag>.
</desc>",

"configimage":#"<desc tag><short>
 Returns one of the internal Roxen configuration images.</short> The
 src attribute is required.
</desc>

<attr name=src value=string>
 The name of the picture to show.
</attr>

<attr name=border value=number>
 The image border when used as a link. Default is 0.
</attr>

<attr name=alt value=string>
 The picture description. Default is the src string.
</attr>

<attr name=class value=string>
 This CSS class definition will be applied to the image.
</attr>
 All other attributes will be inherited by the generated img tag.",

"configurl":#"<desc tag><short>
 Returns a URL to the configuration interface.</short>
</desc>",

"cset":#"<desc cont></desc>",

"crypt":#"<desc cont><short>
 Encrypts the contents as a Unix style password.</short> Useful when
 combined with services that use such passwords. <p>Unix style
 passwords are one-way encrypted, to prevent the actual clear-text
 password from being stored anywhere. When a login attempt is made,
 the password supplied is also encrypted and then compared to the
 stored encrypted password.</p>
</desc>",

"date":#"<desc tag><short>
 Inserts the time and date.</short> Does not require attributes.
</desc>

<attr name=unix-time value=number>
 Display this time instead of the current.
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

<attr name=adjust value=number>
 Add this number of seconds to the result.
</attr>

<attr name=brief>
 Show in brief format.
</attr>

<attr name=time>
 Show only time.
</attr>

<attr name=date>
 Show only date.
</attr>

<attr name=type value=string,ordered,iso,discordian,stardate,number>
 Defines in which format the date should be displayed in.
</attr>

<attr name=part value=year,month,day,wday,date,mday,hour,minute,second,yday,beat,week,seconds>
 Defines which part of the date should be displayed. Day and wday is
 the same. Date and mday is the same. Yday is the day number of the
 year. Seconds is unix time type. Only the types string, number and
 ordered applies when the part attribute is used.
</attr>

<attr name=lang value=language_code>
 Defines in what language the a string will be presented in.
</attr>

<attr name=case value=upper,lower,capitalized>
 Changes the case of the output to upper, lower or capitalized.
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
 Subtracts 1 from a variable.</short> Attribute variable is required.
</desc>

<attr name=variable value=string>
 The variable to be decremented.
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

<attr name=separator value=string>

</attr>

<attr name=name value=string>
 Only affect form element with this name.
</attr>

<attr name=variable value=string>

</attr>",

"doc":#"<desc cont><short hide>
 Eases code documentation by reformatting it.</short>
 Eases documentation by replacing \"{\", \"}\" and \"&\" with \"<\", \">\" and
 \"&\". No attributes required.
</desc>

<attr name=quote>
 Instead of replacing \"{\" and \"}\", \"<\" and \">\" is replaced with \"&amp;lt;\"
 and \"&amp;gt;\".
</attr>

<attr name=pre>
 The result is encapsulated within a <tag>pre</tag> container.
</attr>

<attr name=class value=string>
 This CSS definition will be applied on the pre element.
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

"foreach":#"<desc cont>

</desc>

<attr name=variable>

</attr>

<attr name=variables>

</attr>

<attr name=in>

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
 put the result in a variable that can be reached with &var.gauge;.
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
 See the Appendix for a list of HTTP headers.",

"imgs":#"<desc tag><short>
 Generates a image tag with proper dimensions.</short> Attribute src
 is required.
</desc>

<attr name=src value=string>
 The name of the file that should be shown.
</attr>

<attr name=alt value=string>
 Description of the image. Default is the image file name.
</attr>
 All other attributes will be inherited by the generated img tag.",

"inc":#"<desc tag><short>
 Adds 1 to a variable.</short> Attribute variable is required.
</desc>

<attr name=variable value=string>
 The variable to be incremented.
</attr>",

"insert":#"<desc tag><short>
 Inserts a file, variable or other object into a webpage.</short>
 One attribute is required.
</desc>

<attr name=variable value=string>
 Inserts the value of that variable.
</attr>

<attr name=variables>
 Inserts a variable listing.
</attr>

<attr name=scopes>
 Inserts a listing of all present scopes.
</attr>

<attr name=file value=string>
 Inserts the contents of that file.
</attr>

<attr name=href value=string>
 Inserts the contents at that URL.
</attr>

<attr name=quote value=html,none>
 How the inserted data should be quoted. Default is \"html\", except for
 href and file where it's \"none\".
</attr>",

"maketag":#"<desc cont><short hide>Makes it able to create tags.</short>
 This tag creates tags. The contents of the container will be put into
 the contents of the produced container. Requires the name attribute.
</desc>

<attr name=name value=string>
 The name of the tag.
</attr>

<attr name=noxml>
 Tags should not be terminated with a trailing slash.
</attr>

<attr name=type value=tag,container>
 What kind of tag should be produced. Default is tag.
</attr>
 Inside the maketag container the container attrib is defined. It is
 used to add attributes to the produced tag. It has the required
 attribute attrib, which is the name of the attribute. The contents of
 the attribute container will be the attribute value. E.g.

 <p>&lt;maketag name=replace type=container&gt;
 &lt;attrib name=from&gt;A&lt;/attrib&gt;
 &lt;attrib name=to&gt;U&lt;/attrib&gt;
 MAD
 &lt;/maketag&gt;

 will result in

 &lt;replace from=A to=U&gt;MAD&lt;/replace&gt;
 &lt;/pre&gt;</p>",

"modified":#"<desc tag><short hide>
 Prints when or by whom a page was last modified.</short> Prints when
 or by whom a page was last modified, by default the current page.
</desc>

<attr name=by>
 Print by whom the page was modified. Takes the same attributes as the
 <tag><ref type=tag>user</ref></tag> tag. This attribute requires a
 userdatabase.
</attr>

<attr name=date>
 Print the modification date. Takes all the date attributes in the
 <tag><ref type=tag>date</ref></tag> tag.
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
 <ref type=tag>apre</ref></tag>). Note that this only works when the
 to=... URL is absolute, i.e. begins with a \"/\", otherwise these
 state toggles have no effect.",

"remove-cookie":#"<desc tag><short>
 Sets the expire-time of a cookie to a date that has already occured.
 This forces the browser to remove it.</short>
 This tag won't remove the cookie, only set it to the empty string, or
 what is specified in the </attr>value</attr> attribute and change
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

"repeat":#"<desc cont><short>
 Repeats the contents until a <tag>leave</tag> tag has been
 found.</short> Requires no attributes.
</desc>

<attr name=maxloops>
 The maximum number of loops. Default is 10000.
</attr>",

"replace":#"<desc cont><short>
 Replaces strings in the contents with other strings.</short> Requires
 the from attribute.
</desc>

<attr name=from value=string>
 String or list of strings that should be replaced.
</attr>

<attr name=to value=string>
 String or list of strings with the replacement strings. Default is the
 empty string.
</attr>

<attr name=separator value=string>
 Defines what string should seperate the strings in the from and to
 attributes. Default is \",\".
</attr>

<attr name=type value=word,words>
 Word means that a single string should be replaced. Words that from
 and to are lists. Default is word.
</attr>",

"return":#"<desc tag><short>
 Changes the HTTP return code for this page.</short>

 See the Appendix for a list of HTTP return codes.
</desc>

<attr name=code>
 The return code to set.
</attr>",

"roxen":#"<desc tag><short>
 Returns a nice Roxen logo.</short>
</desc>

<attr name=size value=small,medium,large>
 Defines the size of the image. Default is small.
</attr>

<attr name=color value=blue,green,purple,brown>
 Defines the color of the image. Default is blue.
</attr>

<attr name=alt value=string>
 The image description. Default is \"Powered by Roxen\".
</attr>

<attr name=border value=number>
 The image border. Default is 0.
</attr>

<attr name=class value=string>
 This CSS definition will be applied on the img element.
</attr>

<attr name=target value=string>
 Names a target frame for the link around the image.
</attr>
 All other attributes will be inherited by the generated img tag.",

"scope":#"<desc cont><short>
 Creates a different variable scope.</short> Variable changes inside the scope
 container will not affect variables in the rest of the page.
 Variables set outside the scope is not available inside the scope
 unless the extend attribute is used. No attributes are required.
</desc>

<attr name=extend>
 If set, all variables will be copied into the scope.
</attr>",

"set":#"<desc tag><short>
Sets a variable.</short> The variable attribute is required.
</desc>

<attr name=variable value=string>
 The name of the variable.
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

<attr name=other value=string>
 The name of a id->misc->variables that the value should be copied from.
</attr>

<attr name=eval value=string>
 An RXML expression whose evaluated value the variable should have.
</attr>

 If none of the above attributes are specified, the variable is unset.
 If debug is currently on, more specific debug information is provided
 if the operation failed. See also: <tag><ref type=tag>append</ref></tag>
 and <tag><ref type=tag>debug</ref></tag>",

"set-cookie":#"<desc tag><short>
 Sets a cookie that will be stored by the user's browser.</short> This
 is a simple and effective way of storing data that is local to the
 user. The cookie will be persistent, the next time the user visits
 the site, she will bring the cookie with her.
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

<attr name=value value=string>
 The value the cookie will be set to.
</attr>

<attr name=path value=string>
 The path in which the cookie should be available.
</attr>

 If persistent is specified; the cookie will be persistent until year
 2038, otherwise, the specified delays are used, just as for
 <tag><ref type=tag>expire-time</ref></tag>.

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
</attr>

<attr name=class value=string>
 Apply this CSS style on all elements.
</attr>

<attr name=smallclass value=string>
 Apply this CSS style on all small elements.
</attr>

<attr name=bigclass value=string>
 Apply this CSS style on all big elements.
</attr>

<attr name=size value=number>
 Use font tags, and this number as big size.
</attr>

<attr name=small value=number>
 Size of the small tags. Only applies when size is specified. Default
 is size-1.
</attr>",

"sort":#"<desc cont><short>
 Sorts the contents.</short> No attributes required.
</desc>

<attr name=separator value=string>
 Defines what the strings to be sorted are separated with.
</attr>

<attr name=reverse>
 Reversed order sort.
</attr>",

"throw":#"<desc cont><short hide>
 Throws a text to be catched by <tag>catch</tag>.</short>
 Throws an exception, with the enclosed text as the error message.
 This tag has a close relation to <tag>catch</tag>. The RXML parsing
 will stop at the <tag>throw</tag> tag.
</desc>",

"trimlines":#"<desc cont><short>
 Removes all empty lines from the contents.</short>
</desc>",

"unset":#"
<desc tag><short>
 Unsets a variable, i.e. removes it.</short> The variable attribute is
 required.
</desc>

<attr name=variable value=string>
 The name of the variable.
</attr>",

"user":#"<desc tag><short>
 Prints information about the specified user.</short> By default, the
 full name of the user and her e-mail address will be printed, with a
 mailto link and link to the home page of that user.

 <p>The <tag>user</tag> tag requires an authentication module to work.</p>
</desc>

<attr name=email>
 Only print the e-mail address of the user, with no link.
</attr>

<attr name=link>
 Include links. Only meaningful together with the realname or email attribute.
</attr>

<attr name=name>
 The login name of the user.
</attr>

<attr name=nolink>
 Don't include the links.
</attr>

<attr name=nohomepage>
 Don't include homepage links.
</attr>

<attr name=realname>
 Only print the full name of the user, with no link.
</attr>",

"if#expr":#"<desc plugin>
 Evaluates expressions. The following characters may be used: \"1, 2,
 3, 4, 5, 6, 7, 8, 9, x, a, b, c, d, e, f, i, n, t, \, X. A, B, C, D, E,
 F, l, o, &lt;, &gt;, =, 0, -, +, /, %, &, |, (, ), .\".
</desc>",

    ]);
#endif
