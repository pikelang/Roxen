// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.
//

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

constant cvs_version="$Id: rxmltags.pike,v 1.36 1999/12/14 04:57:45 nilsson Exp $";
constant thread_safe=1;
constant language = roxen->language;

#include <module.h>

inherit "module";
inherit "roxenlib";

// ---------------- Module registration stuff ----------------

void create()
{
  defvar("insert_href",1,"Allow &lt;insert href&gt;.",
	 TYPE_FLAG|VAR_MORE,
         "Should the usage of &lt;insert href&gt; be allowed?");
}

void start()
{
  add_api_function("query_modified", api_query_modified, ({ "string", }));
}

array register_module()
{
  return ({ MODULE_PARSER | MODULE_PROVIDER,
	    "RXML 1.4 tags",
	    ("This module adds a lot of RXML tags."), 0, 1 });
}

string query_provides() {
  return "modified";
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["roxen-automatic-charset-variable":"<desc tag></desc>",
"append":"<desc tag></desc>",
"auth-required":"<desc tag></desc>",
"clientname":"<desc tag></desc>",
"expire-time":"<desc tag></desc>",
"file":"<desc tag></desc>",
"header":"<desc tag></desc>",
"realfile":"<desc tag></desc>",
"redirect":"<desc tag></desc>",
"referer":"<desc tag></desc>",
"referrer":"<desc tag></desc>",
"unset":"<desc tag></desc>",
"set":"<desc tag></desc>",
"vfs":"<desc tag></desc>",
"accept-language":"<desc tag></desc>",
"quote":"<desc tag></desc>",
"inc":"<desc tag></desc>",
"dec":"<desc tag></desc>",
"imgs":"<desc tag></desc>",
"roxen":"<desc tag></desc>",
"debug":"<desc tag></desc>",
"fsize":"<desc tag></desc>",
"configimage":"<desc tag></desc>",
"date":"<desc tag></desc>",
"insert":"<desc tag></desc>",
"configurl":"<desc tag></desc>",
"return":"<desc tag></desc>",
"set-cookie":"<desc tag></desc>",
"remove-cookie":"<desc tag></desc>",
"modified":"<desc tag></desc>",
"user":"<desc tag></desc>",
"set-max-cache":"<desc tag></desc>",

"scope":"<desc cont></desc>",
"catch":"<desc cont></desc>",
"cache":"<desc cont></desc>",
"crypt":"<desc cont></desc>",
"for":"<desc cont></desc>",
"foreach":"<desc cont></desc>",
"apre":"<desc cont></desc>",
"aconf":"<desc cont></desc>",
"maketag":"<desc cont></desc>",
"doc":"<desc cont></desc>",
"autoformat":"<desc cont></desc>",
"smallcaps":"<desc cont></desc>",
"random":"<desc cont></desc>",
"formoutput":"<desc cont></desc>",
"gauge":"<desc cont></desc>",
"trimlines":"<desc cont></desc>",
"throw":"<desc cont></desc>",
"default":"<desc cont></desc>",
"sort":"<desc cont></desc>",
"recursive-output":"<desc cont></desc>",
"repeat":"<desc cont></desc>",
"replace":"<desc cont></desc>",
"cset":"<desc cont></desc>"
    ]);
#endif

constant permitted = "123456789xabcdefnt\"XABCDEFlo<>=0-*+/%%|()"/"";

string sexpr_eval(string what)
{
  array q = what/"";
  what = "mixed foo(){ return "+(q-(q-permitted))*""+";}";
  return (string)compile_string( what )()->foo();
}


// ------------------- Tags ------------------------

string tag_roxen_automatic_charset_variable( string t, mapping m, 
                                             RequestID id )
{
  return make_tag( "input", 
                   ([ 
                     "type":"hidden",
                     "name":"magic_roxen_automatic_charset_variable",
                     "value":"едц",
                   ]) );
}

string tag_append( string tag, mapping m, RequestID id )
{
  if (m->variable)
  {
    if (m->value)
      // Set variable to value.
      if (id->variables[ m->variable ])
	id->variables[ m->variable ] += m->value;
      else
	id->variables[ m->variable ] = m->value;
    else if (m->from)
      // Set variable to the value of another variable
      if (id->variables[ m->from ])
	if (id->variables[ m->variable ])
	  id->variables[ m->variable ] += id->variables[ m->from ];
	else
	  id->variables[ m->variable ] = id->variables[ m->from ];
      else
        return rxml_error(tag, "From variable doesn't exist.", id);

    else if (m->other)
      // Set variable to the value of a misc variable
      if (id->misc->variables[ m->other ])
	if (id->variables[ m->variable ])
	  id->variables[ m->variable ] += id->misc->variables[ m->other ];
	else
	  id->variables[ m->variable ] = id->misc->variables[ m->other ];
      else
        return rxml_error(tag, "Other variable doesn't exist.", id);
  }

  return rxml_error(tag, "Nothing to append from.", id);
}

string tag_auth_required (string tagname, mapping args, RequestID id)
{
  mapping hdrs = http_auth_required (args->realm, args->message);
  if (hdrs->error) _error = hdrs->error;
  if (hdrs->extra_heads)
     _extra_heads += hdrs->extra_heads;
    // We do not need this as long as hdrs only contains strings and numbers
    //    foreach(indices(hdrs->extra_heads), string tmp)
    //      add_http_header(_extra_heads, tmp, hdrs->extra_heads[tmp]);
  if (hdrs->text) _rettext = hdrs->text;
  return "";
}

string|array(string) tag_clientname(string tag, mapping m, RequestID id)
{
  NOCACHE();
  string client="";
  if (sizeof(id->client)) {
    if(m->full)
      client=id->client * " ";
    else
      client=id->client[0];
  }

  return m->quote=="none"?client:({ html_encode_string(client) });
}

string tag_expire_time(string tag, mapping m, RequestID id)
{
  int t=time();
  if(!m->now)
  {
    t+=time_dequantifier(m);
    CACHE(max(t-time(),0));
  } else {
    NOCACHE();
    add_http_header(_extra_heads, "Pragma", "no-cache");
    add_http_header(_extra_heads, "Cache-Control", "no-cache");
  }

  add_http_header(_extra_heads, "Expires", http_date(t));
  return "";
}

array(string) tag_file(string tag, mapping m, RequestID id)
{
  string file;
  if(m->raw)
    file=id->raw_url;
  else
    file=id->not_query;
  return m->quote=="none"?file:({ html_encode_string(file) });
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
    return rxml_error(tag, "Requires both a name and a value.", id);

  add_http_header(_extra_heads, m->name, m->value);
  return "";
}

string|array(string) tag_realfile(string tag, mapping m, RequestID id)
{
  if(id->realfile)
    return ({ id->realfile });
  return rxml_error(tag, "Real file unknown", id);
}

string tag_redirect(string tag, mapping m, RequestID id)
{
  if (!(m->to && sizeof (m->to)))
    return rxml_error(tag, "Requires attribute \"to\".", id);

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

array(string) tag_referer(string t, mapping m, RequestID id) {
  return tag_referrer(t,m,id);
}

array(string) tag_referrer(string tag, mapping m, RequestID id)
{
  NOCACHE();

  return({ sizeof(id->referer) ?
    (m->quote=="none"?id->referer:(html_encode_string(id->referer*""))) :
    (m->alt || "") });
}

string tag_unset(string tag, mapping m, RequestID id) {
  if(!m->variable)  return rxml_error(tag, "Variable not specified.", id);
  m_delete( id->variables, m->variable );
  return "";
}

string tag_set( string tag, mapping m, RequestID id )
{
  if (m->variable)
  {
    if (m->value)
      // Set variable to value.
      id->variables[ m->variable ] = m->value;
    else if (m->expr)
      id->variables[ m->variable ] = sexpr_eval( m->expr );
    else if (m->from)
      // Set variable to the value of another variable
      if (id->variables[ m->from ])
	id->variables[ m->variable ] = id->variables[ m->from ];
      else
	return rxml_error(tag, "From variable doesn't exist.", id);

    else if (m->other)
      // Set variable to the value of a misc variable
      if (id->misc->variables && id->misc->variables[ m->other ])
	id->variables[ m->variable ] = (string)id->misc->variables[ m->other ];
      else
	return rxml_error(tag, "Other variable doesn't exist.", id);
    else if (m->eval)
      // Set variable to the result of some evaluated RXML
      id->variables[ m->variable ] = parse_rxml(m->eval, id);
    return "";
  }

  return rxml_error(tag, "Variable not specified.", id);
}

string|array(string) tag_vfs(string tag, mapping m, RequestID id)
{
  if(id->virtfile)
    return ({ id->virtfile });
  return rxml_error(tag, "Virtual file unknown.", id);
}

array(string) tag_accept_language(string tag, mapping m, RequestID id)
{
  NOCACHE();

  if(!id->misc["accept-language"])
    return ({ "None" });

  if(m->full)
    return ({ html_encode_string(id->misc["accept-language"]*",") });
  else
    return ({ html_encode_string((id->misc["accept-language"][0]/";")[0]) });
}

string tag_quote(string tagname, mapping m)
{
#if efun(set_start_quote)
  if(m->start && strlen(m->start))
    set_start_quote(m->start[0]);
  if(m->end && strlen(m->end))
    set_end_quote(m->end[0]);
#endif
  return "";
}

string tag_inc(string tag, mapping m, RequestID id)
{
  if(m->variable && id->variables[m->variable]) {
    id->variables[m->variable]=(string)((int)id->variables[m->variable]+1);
    return "";
  }
  return rxml_error(tag, "No variable to increment.", id);
}

string tag_dec(string tag, mapping m, RequestID id)
{
  if(m->variable && id->variables[m->variable]) {
    id->variables[m->variable]=(string)((int)id->variables[m->variable]-1);
    return "";
  }
  return rxml_error(tag, "No variable to decrement.", id);
}

string|array(string) tag_imgs(string tag, mapping m, RequestID id)
{
  string tmp="";
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
      else
	tmp+=" Dimensions quering failed.";
    }
    else
      tmp+=" Virtual path failed";
    if(!m->alt) {
      array src=m->src/"/";
      string src=src[sizeof(src)-1];
      m->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src),".")-2],"_"," "));
    }
    return ({ make_tag("img", m)+(tmp?rxml_error(tag, tmp, id):"") });
  }
  return rxml_error(tag, "No src given.", id);
}

array(string) tag_roxen(string tagname, mapping m, RequestID id)
{
  string size = m->size || "small";
  string color = m->color || "blue";
  m_delete(m, "color");
  m_delete(m, "size");
  m->src = "/internal-roxen-power-"+size+"-"+color;
  m->width = (["small":"100","medium":"200","large":"300"])[size];
  m->height = (["small":"35","medium":"60","large":"90"])[size];
  if(!m->alt) m->alt="Powered by Roxen";
  if(!m->border) m->border="0";
  return ({ "<a href=\"http://www.roxen.com/\">"+make_tag("img", m)+"</a>" });
}

string|array(string) tag_debug( string tag_name, mapping args, RequestID id )
{
  if (args->showid)
  {
    array path=lower_case(args->showid)/"->";
    if(path[0]!="id" || sizeof(path)==1) return "Can only show parts of the id object.";
    mixed obj=id;
    foreach(path[1..], string tmp) {
      if(search(indices(obj),tmp)==-1) return "Could only reach "+tmp+".";
      obj=obj[tmp];
    }
    return ({ "<pre>"+html_encode_string(sprintf("%O",obj))+"</pre>" });
  }
  if (args->off)
    id->misc->debug = 0;
  else if (args->toggle)
    id->misc->debug = !id->misc->debug;
  else
    id->misc->debug = 1;
  return "<!-- Debug is "+(id->misc->debug?"enabled":"disabled")+" -->";
}

string tag_fsize(string tag, mapping args, RequestID id)
{
  catch {
    array s = id->conf->stat_file( fix_relative( args->file, id ), id );
    if (s && (s[1]>= 0)) return (string)s[1];
  };
  if(string s=id->conf->try_get_file(fix_relative(args->file, id), id ) )
    return (string)strlen(s);
  return rxml_error(tag, "Failed to find file", id);
}

array(string)|string tag_configimage(string t, mapping m, RequestID id)
{
  if (!m->src) return rxml_error(t, "No src given", id);

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
    if(!id->variables[n])
      return rxml_error(tag, "No such variable ("+n+").", id);
    return m->quote=="none"?id->variables[n]:({ html_encode_string(id->variables[n]) });
  }

  if(n = m->variables) {
    if(m->variables!="variables")
      return ({ html_encode_string(Array.map(indices(id->variables),
			lambda(string s, mapping m)
			{ return sprintf("%s=%O\n", s, m[s]); },
					   id->variables) * "\n")
	    });
    return ({ String.implode_nicely(indices(id->variables)) });
  }

  if(n = m->other) {
    if(stringp(id->misc[n]) || intp(id->misc[n]))
      return m->quote=="none"?(string)id->misc[n]:({ html_encode_string((string)id->misc[n]) });
    return rxml_error(tag, "No such other variable ("+n+").", id);
  }

  if(n = m->cookies)
  {
    NOCACHE();
    if(n!="cookies")
      return ({ html_encode_string(Array.map(indices(id->cookies),
			  lambda(string s, mapping m)
			  { return sprintf("%s=%O\n", s, m[s]); },
					     id->cookies) * "\n")
	      });
    return ({ String.implode_nicely(indices(id->cookies)) });
  }

  if(n=m->cookie)
  {
    NOCACHE();
    if(id->cookies[n])
      return m->quote=="none"?id->cookies[n]:({ html_encode_string(id->cookies[n]) });
    return rxml_error(tag, "No such cookie ("+n+").", id);
  }

  if(m->file)
  {
    if(m->nocache) {
      int nocache=id->pragma["no-cache"];
      id->pragma["no-cache"] = 1;
      n=API_read_file(id,m->file)||rxml_error("insert", "No such file ("+m->file+").", id);
      id->pragma["no-cache"] = nocache;
      return n;
    }
    return API_read_file(id,m->file)||rxml_error("insert", "No such file ("+m->file+").", id);
  }

  if(m->href && query("insert_href")) {
    if(m->nocache)
      NOCACHE();
    else
      CACHE(60);
    Protocols.HTTP q=Protocols.HTTP.get_url(m->href);
    if(q && q->status>0 && q->status<400)
      return ({ q->data() });
    return rxml_error(tag, (q ? q->status_desc: "No server response"), id);
  }

  string ret="Could not fullfill your request.<br>\nArguments:";
  foreach(indices(m), string tmp)
    ret+="<br />\n"+tmp+" : "+m[tmp];

  return rxml_error(tag, ret, id);
}

string|array(string) tag_configurl(string tag, mapping m, RequestID id)
{
  return ({ roxen->config_url() });
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
    return rxml_error(tag, "Requires a name attribute.", id);

  string cookies = m->name+"="+http_encode_cookie(m->value||"");
  int t;     //time

  if(m->persistent)
    t=(3600*(24*365*2));
  else
    t=time_dequantifier(m);

  cookies += "; expires="+http_date(t+time(1));

  //FIXME: Check the parameter's usability
  cookies += "; path=" +(m->path||"/");

  add_http_header(_extra_heads, "Set-Cookie", cookies);

  return "";
}

string tag_remove_cookie(string tag, mapping m, RequestID id)
{
  if(!m->name || !id->cookies[m->name]) return rxml_error(tag, "That cookie does not exists.", id);

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
      return rxml_error(tag, "Modified by requires a user database.", id);
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
      return rxml_error(tag, "Modified by requires a user database.", id);

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
      return strftime(id->misc->defines->timefmt || "%c", s[3]);
    return tagtime(s[3], m, id, language);
  }

  return rxml_error(tag, "Couldn't stat file.", id);
}

string|array(string) tag_user(string tag, mapping m, RequestID id, Stdio.File file)
{
  string *u;
  string b, dom;

  if(!id->conf->auth_module)
    return rxml_error(tag, "Requires a user database.", id);

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
      return ({ sprintf("<a href=\"mailto:%s@%s@\">%s@%s</a>",
			b, dom, b, dom)
	      });
    return ({ b + "@" + dom });
  }
  if(m->nolink && !m->link)
    return ({ sprintf("%s &lt;%s@%s&gt;",
		      u[4], b, dom)
	    });
  return ({ sprintf("<a href=\"/~%s/\">%s</a> "
		    "<a href=\"mailto:%s@%s\">&lt;%s@%s&gt;</a>",
		    b, u[4], b, dom, b, dom)
	  });
}

array(string) tag_set_max_cache( string tag, mapping m, RequestID id )
{
  id->misc->cacheable = (int)m->time;
  return ({ "" });
}

// ------------------- Containers ----------------

array(string) container_scope(string tag, mapping m,
                              string contents, RequestID id)
{
  mapping old_variables = copy_value(id->variables);
  int truth=_ok;
  if (!m->extend)
    id->variables = ([]);
  contents = parse_rxml(contents, id);
  id->variables = old_variables;
  if (m->truth)
    _ok=truth;
  return ({ contents });
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
#define HASH(x) (x+id->not_query+id->query+id->realauth +id->conf->query("MyWorldLocation"))
#if constant(Crypto.md5)
  object md5 = Crypto.md5();
  md5->update(HASH(contents));
  string key=md5->digest();
#else
  string key = (string)hash(HASH(contents));
#endif
  if(args->key)
    key += args->key;
  string parsed = cache_lookup("tag_cache", key);
  if(!parsed) {
    parsed = parse_rxml(contents, id);
    cache_set("tag_cache", key, parsed);
  }
  return ({parsed});
#undef HASH
}

string|array(string) container_crypt( string s, mapping m,
                                      string c, RequestID id )
{
  if(m->compare) return crypt(c,m->compare)?"<true>":"<false>";
  return ({ crypt(c) });
}

string container_for(string t, mapping args, string c, RequestID id)
{
  string v = args->variable;
  int from = (int)args->from;
  int to = (int)args->to;
  int step = (int)args->step!=0?(int)args->step:(to<from?-1:1);

  if((to<from && step>0)||(to>from && step<0)) to=from+step;

  string res="";
  if(to<from)
  {
    if(v)
      for(int i=from; i>=to; i+=step)
        res += "<set variable="+v+" value="+i+">"+c;
    else
      for(int i=from; i>=to; i+=step)
        res+=c;
    return res;
  }
  else if(to>from)
  {
    if(v)
      for(int i=from; i<=to; i+=step)
        res += "<set variable="+v+" value="+i+">"+c;
    else
      for(int i=from; i<=to; i+=step)
        res+=c;
    return res;
  }

  return "<set variable="+v+" value="+to+">"+c;
}

string container_foreach(string t, mapping args, string c, RequestID id)
{
  string v = args->variable;
  array what;
  if(!args->in)
    return rxml_error(t, "No in attribute given.", id);
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

string container_apre(string tag, mapping m, string q, RequestID id)
{
  string href, s, *foo;

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

string|array(string) container_aconf(string tag, mapping m,
                                     string q, RequestID id)
{
  string href,s;
  mapping cookies = ([]);

  if(!m->href)
    href=strip_prestate(strip_config(id->raw_url));
  else
  {
    href=m->href;
    if (search(href, ":") == search(href, "//")-1)
      return rxml_error(tag, "It is not possible to add configs to absolute URLs.", id);
    href=fix_relative(href, id);
    m_delete(m, "href");
  }

  if(m->add) {
    foreach((m->add-" ")/",", s)
      cookies[s]=s;
    m_delete(m,"add");
  }
  if(m->drop) {
    foreach((m->drop-" ")/",", s)
      cookies["-"+s]="-"+s;
    m_delete(m,"drop");
  }

  m->href = add_config(href, indices(cookies), id->prestate);
  return make_container("a", m, q);
}

string container_maketag(string tag, mapping m, string cont, RequestID id)
{
  NOCACHE();
  mapping args=(!m->noxml&&m->type=="tag"?(["/":"/"]):([]));
  cont=parse_html(parse_rxml(cont,id), ([]), (["attrib":
    lambda(string tag, mapping m, string cont, mapping c, RequestID id, mapping args) {
      args[m->name]=parse_rxml(cont, id);
      return "";
    }
  ]), ([]), id, args);
  if(m->type=="container")
    return make_container(m->name, args, cont);
  return make_tag(m->name, args);
}

string container_doc(string tag, mapping m, string s)
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

string container_autoformat(string tag, mapping m, string s, RequestID id)
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

string container_smallcaps(string t, mapping m, string s)
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

string container_random(string tag, mapping m, string s)
{
  string|array q;
  if(!(q=m->separator || m->sep)) return (q=s/"\n")[random(sizeof(q))];
  return (q=s/q)[random(sizeof(q))];
}

array(string) container_formoutput(string tag_name, mapping args,
                                   string contents, RequestID id)
{
  return ({ do_output_tag( args, ({ id->variables }), contents, id ) });
}

array(string) container_gauge(string t, mapping args, string contents, RequestID id)
{
  NOCACHE();

  int t = gethrtime();
  contents = parse_rxml( contents, id );
  t = gethrtime()-t;
  string define = args->define?args->define:"gauge";

  if(args->silent) return ({ "" });
  if(args->timeonly) return ({ sprintf("%3.6f", t/1000000.0) });
  if(args->resultonly) return ({contents});
  return ({ "<br><font size=\"-1\"><b>Time: "+
	   sprintf("%3.6f", t/1000000.0)+
	   " seconds</b></font><br>"+contents });
}

// Removes empty lines
array(string) container_trimlines( string tag_name, mapping args,
                           string contents, RequestID id )
{
  contents = replace(parse_rxml(contents,id), ({"\r\n","\r" }), ({"\n","\n"}));
  return ({ (contents / "\n" - ({ "" })) * "\n" });
}

void container_throw( string t, mapping m, string c, RequestID id)
{
  if(!id->misc->catcher_is_ready && c[-1]!="\n")
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

array(string) container_default( string t, mapping m, string c, RequestID id)
{
  multiset value=(<>);
  if(m->value) value=mkmultiset((m->value||"")/(m->separator||","));
  if(m->variable) value+=mkmultiset(({id->variables[m->variable]}));
  c = parse_rxml(c, id );
  if(value==(<>)) return ({c});

  return ({ parse_html(c, (["input":internal_tag_input]),
		       (["select":internal_tag_select]),
		       m->name, value) });
}

string container_sort(string t, mapping m, string c, RequestID id)
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
      return rxml_error(tagname, "'inside' and 'outside' replacement sequences "
	"aren't of same length", id);
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
//and how it was calculated. nilsson@idonex.se
#define MAGIC_EXIT 4921325

string tag_leave(string tag, mapping m, RequestID id)
{
  if(id->misc->leave_repeat)
  {
    id->misc->leave_repeat--;
    throw(MAGIC_EXIT);
  }
  return rxml_error(tag, "Must be contained by &lt;repeat&gt;.", id);
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
    return ret+rxml_error(tag, "Too many iterations ("+maxloop+").", id);
  return ret;
}

string container_replace( string tag, mapping m, string cont, RequestID id)
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

array(string) container_cset( string t, mapping m, string c, RequestID id )
{
  if( m->quote != "none" )
    c = html_decode_string( c );
  if( !m->variable )
    return ({rxml_error(t, "Variable not specified.", id)});
  id->variables[ m->variable ] = c;
  return ({ "" });
}

// ----------------- If registration stuff --------------

mapping query_if_callers()
{
  return ([
    "expr":lambda( string q){ return (int)sexpr_eval(q); }
  ]);
}

// ---------------- API registration stuff ---------------

string api_query_modified(RequestID id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  return tag_modified("modified", m, id, id);
}
