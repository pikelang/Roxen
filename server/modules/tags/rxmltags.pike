// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.
//

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

#define old_rxml_compat 1
#define old_rxml_warning id->conf->api_functions()->old_rxml_warning[0]

constant cvs_version="$Id: rxmltags.pike,v 1.10 1999/10/03 01:10:36 jhs Exp $";
constant thread_safe=1;

#include <module.h>

inherit "module";
inherit "roxenlib";

// ---------------- Module registration stuff ----------------

void create(object c)
{
  defvar("insert_href",1,"Allow &lt;insert href&gt;.",
	 TYPE_FLAG|VAR_MORE,
         "Should the usage of &lt;insert href&gt; be allowed?");
}

array register_module()
{
  return ({ MODULE_PARSER, 
	    "RXML 1.4 tags", 
	    ("This module adds a lot of RXML tags."), 0, 1 });
}

constant permitted = ({ "1", "2", "3", "4", "5", "6", "7", "8", "9",
                        "x", "a", "b", "c,", "d", "e", "f", "n", "t", "\""
                        "X", "A", "B", "C,", "D", "E", "F", "l", "o",
                        "<", ">", "=", "0", "-", "*", "+","/", "%", 
                        "&", "|", "(", ")" });

string sexpr_eval(string what)
{
  array q = what/"";
  what = "mixed foo(){ return "+(q-(q-permitted))*""+";}";
  return (string)compile_string( what )()->foo();
}

// ------------------- Tags ------------------------

string tag_append( string tag, mapping m, object id )
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

#if old_rxml_compat
    // Not part of RXML 1.4
    else if(m->define) {
      // Set variable to the value of a define
      id->variables[ m->variable ] += id->misc->defines[ m->define ]||"";
      old_rxml_warning(id, "define attribute in append tag","only variables");
    }
#endif
  }

  return rxml_error(tag, "Nothing to append from.", id);
}

string tag_auth_required (string tagname, mapping args, object id)
{
  mapping hdrs = http_auth_required (args->realm, args->message);
  if (hdrs->error) _error = hdrs->error;
  if (hdrs->extra_heads) _extra_heads += hdrs->extra_heads;
  if (hdrs->text) _rettext = hdrs->text;
  return "";
}

string|array(string) tag_clientname(string tag, mapping m, object id)
{
  NOCACHE();
  if (sizeof(id->client))
    if(m->full) 
      return ({ id->client * " " });
    else 
      return ({ id->client[0] });

  return ""; 
}

string tag_expire_time(string tag, mapping m, object id)
{
  int t=time();
  if(!m->now)
  {
    t+=id->conf->api_functions()->time_quantifier[0](id, m);
    CACHE(max(t-time(),0));
  } else {
    NOCACHE();
    id->conf->api_functions()->add_header[0](id, "Pragma", "no-cache");
    id->conf->api_functions()->add_header[0](id, "Cache-Control", "no-cache");
  }

  id->conf->api_functions()->add_header[0](id, "Expires", http_date(t));
  return "";
}

array(string) tag_file(string tag, mapping m, object id)
{
  if(m->raw)
    return ({ id->raw_url });
  else
    return ({ id->not_query });
}

string tag_header(string tag, mapping m, object id)
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

  id->conf->api_functions()->add_header[0](id, m->name, m->value);
  return "";
}

array(string) tag_realfile(string tag, mapping m, object id)
{
  return ({ id->realfile || rxml_error(tag, "Real file unknown", id) });
}

string tag_redirect(string tag, mapping m, object id)
{
  if (!(m->to && sizeof (m->to)))
    return rxml_error(tag, "Requires attribute \"to\".", id);

  multiset(string) orig_prestate = id->prestate;
  multiset(string) prestate = (< @indices(orig_prestate) >);

#if old_rxml_compat
  foreach(indices(m), string s)
    if(m[s]==s && sizeof(s))
      switch (s[0]) {
	case '+': prestate[s[1..]] = 1; break;
	case '-': prestate[s[1..]] = 0; break;
      }
#endif

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
  if (m->text)
    _rettext = m->text;

  return "";
}

string|array(string) tag_referrer(string tag, mapping m, object id)
{
  NOCACHE();

#if old_rxml_compat
  if(tag=="refferrer") old_rxml_warning(id, "refferrer tag","referrer tag");
#endif

  if(m->help) 
    return ("Shows from which page the client linked to this one.");

  return ({ sizeof(id->referer) ? id->referer*"" : m->alt || "" });
}

array(string) tag_scope(string tag, mapping m, string contents, object id)
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

string tag_set( string tag, mapping m, object id )
{
  if(m->help) 
    return ("<b>&lt;"+tag+" variable=...&gt;</b>: "+String.capitalize(tag)+" the variable specified "
      "by the 'variable' argument");

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

#if old_rxml_compat
    // Not part of RXML 1.4
    else if(m->define) {
      // Set variable to the value of a define
      id->variables[ m->variable ] = id->misc->defines[ m->define ];
      old_rxml_warning(id, "define attribute in set tag","only variables");
    }
#endif
    else if (m->eval)
      // Set variable to the result of some evaluated RXML
      id->variables[ m->variable ] = parse_rxml(m->eval, id);
    else
      // Unset variable.
      m_delete( id->variables, m->variable );
    return "";
  }

  return rxml_error(tag, "Variable not specified.", id);
}

array(string) tag_vfs(string tag, mapping m, object id)
{
  return ({ id->virtfile || rxml_error(tag, "Virtual file unknown.", id) });
}

string tag_language(string tag, mapping m, object id)
{
  NOCACHE();

  if(!id->misc["accept-language"])
    return "None";

  if(m->full)
    return id->misc["accept-language"]*",";
  else
    return (id->misc["accept-language"][0]/";")[0];
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

string tag_inc(string tag, mapping m, object id)
{
  if(m->variable && id->variables[m->variable]) {
    id->variables[m->variable]=(string)((int)id->variables[m->variable]+1);
    return "";
  }
  return rxml_error(tag, "No variable to increment.", id);
}

string tag_dec(string tag, mapping m, object id)
{
  if(m->variable && id->variables[m->variable]) {
    id->variables[m->variable]=(string)((int)id->variables[m->variable]-1);
    return "";
  }
  return rxml_error(tag, "No variable to decrement.", id);
}

string|array(string) tag_imgs(string tag, mapping m, object id)
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
      }else{
	tmp+=" Dimensions quering failed.";
      }
    }else{
      tmp+=" Virtual path failed";
    }
    if(!m->alt) {
      array src=m->src/"/";
      string src=src[sizeof(src)-1];
      m->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src),".")-2],"_"," "));
    }
    return ({ make_tag("img", m)+(tmp?rxml_error(tag, tmp, id):"") });
  }
  return rxml_error(tag, "No src given.", id);
}

array(string) tag_roxen(string tagname, mapping m, object id)
{
#if old_rxml_compat
  if(tagname=="pr") old_rxml_warning(id,"pr tag","roxen tag");
#endif
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

string|array(string) tag_debug( string tag_name, mapping args, object id )
{
  if (args->showid){
    array path=lower_case(args->showid)/"->";
    if(path[0]!="id" || sizeof(path)==1) return "Can only show parts of the id object.";
    mixed obj=id;
    foreach(path[1..], string tmp) {
      if(search(indices(obj),tmp)==-1) return "Could only reach "+tmp+".";
      obj=obj[tmp];
    }
    return ({ sprintf("<pre>%O</pre>",obj) });
  }
  if (args->off)
    id->misc->debug = 0;
  else if (args->toggle)
    id->misc->debug = !id->misc->debug;
  else
    id->misc->debug = 1;
  return "<!-- Debug is "+(id->misc->debug?"enabled":"disabled")+" -->";
}

array(string) tag_cache(string tag, mapping args, string contents, object id)
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

string tag_fsize(string tag, mapping args, object id)
{
  catch {
    array s = id->conf->stat_file( fix_relative( args->file, id ), id );
    if (s && (s[1]>= 0)) {
      return (string)s[1];
    }
  };
  if(string s=id->conf->try_get_file(fix_relative(args->file, id), id ) )
    return (string)strlen(s);
  return rxml_error(tag, "Failed to find file", id);
}

array(string) tag_configimage(string f, mapping m, object id)
{
  if (m->src) {

    // This should really be fixed the other way around; renaming the files to err1, err2 & err3
#if old_rxml_compat
    if(m->src=="err_1") old_rxml_warning(id, "err_1 argument in configimage tag","err1");
    if(m->src=="err_2") old_rxml_warning(id, "err_2 argument in configimage tag","err2");
    if(m->src=="err_3") old_rxml_warning(id, "err_3 argument in configimage tag","err3");
#endif
    if(m->src=="err1") m->src="err_1";
    if(m->src=="err2") m->src="err_2";
    if(m->src=="err3") m->src="err_3";

    if (m->src[sizeof(m->src)-4..] == ".gif") {
      m->src = m->src[..sizeof(m->src)-5];
    }
    m->src = "/internal-roxen-" + m->src;
  }

  m->border = m->border || "0";
  m->alt = m->alt || m->src;

  return ({ make_tag("img", m) });
}

string tag_date(string q, mapping m, object id)
{
#if old_rxml_compat
  // unix_time is not part of RXML 1.4
  int t=(int)m["unix-time"] || (int)m->unix_time || time(1);
  if(m->unix_time) old_rxml_warning(id, "unix_time attribute in date tag","unix-time");
#else
  int t=(int)m["unix-time"] || time(1);
#endif
  if(m->day)    t += (int)m->day * 86400;
  if(m->hour)   t += (int)m->hour * 3600;
  if(m->minute) t += (int)m->minute * 60;
  if(m->second) t += (int)m->second;

  if(!(m->brief || m->time || m->date))
    m->full=1;

  if(!m->date)
    if(!m->unix_time || m->second)
      NOCACHE();
  else
    CACHE(60); // One minute is good enough.

  return id->conf->api_functions()->tag_time_wrapper[0](id, t, m);
}

#if old_rxml_compat
inline string do_replace(string s, mapping m, object id)
{
  return replace(s, indices(m), values(m));
  old_rxml_warning(id, "replace (A=B) in in insert tag","the replace tag");
}
#endif

string tag_insert(string tag,mapping m,object id)
{
  if(m->help)
    return "Inserts a file, variable or other object into a webpage";

  string n;

#if old_rxml_compat
  // Not part of RXML 1.4
  if(n=m->define || m->name) {
    old_rxml_warning(id, "define or name attribute in insert tag","only variables");
    m_delete(m, "define");
    m_delete(m, "name");
    return do_replace(id->misc->defines[n]||rxml_error(tag, "No such define ("+n+").",id), m, id);
  }
#endif

  if (n=m->variable)
#if old_rxml_compat
    {
      m_delete(m, "variable");
      return do_replace(id->variables[n]||rxml_error(tag, "No such variable ("+n+").",id), m, id);
    }
#else
    return id->variables[n]||rxml_error(tag, "No such variable ("+n+").",id);
#endif

#if old_rxml_compat
  if(m->variables && m->variables!="variables") {
    old_rxml_warning(id, "insert attribute variables set to an value","&lt;debug showid=\"id->variables\"&gt;");
      return Array.map(indices(id->variables), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, id->variables)*"\n";
  }
#endif

  if (n=m->variables)
    return String.implode_nicely(indices(id->variables));

  if (n=m->other)
    return (stringp(id->misc[n])||intp(id->misc[n])?(string)id->misc[n]:rxml_error(tag, "No such variable ("+n+").",id));

  if (n=m->cookies) 
  {
    NOCACHE();
    if(n!="cookies")
      return Array.map(indices(id->cookies), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, id->cookies)*"\n";
    return String.implode_nicely(indices(id->cookies));
  }

  if (n=m->cookie) {
    NOCACHE();
#if old_rxml_compat
    m_delete(m, "cookie");
    return do_replace(id->cookies[n]||rxml_error(tag, "No such cookie ("+n+").", id), m, id);
#else
    return id->cookies[n]||rxml_error(tag, "No such cookie ("+n+").", id);
#endif
  }

  if (m->file)
  {
    if(m->nocache) {
      int nocache=id->pragma["no-cache"];
      id->pragma["no-cache"] = 1;
      n=id->conf->api_functions()->read_file[0](id, m->file);
      id->pragma["no-cache"] = nocache;
#if old_rxml_compat
      m_delete(m, "nocache");
      m_delete(m, "file");
      return do_replace(n, m, id);
#else
      return n;
#endif
    }
#if old_rxml_compat
    n=m->file;
    m_delete(m, "file");
    return do_replace(id->conf->api_functions()->read_file[0](id, n), m, id);
#else
    return id->conf->api_functions()->read_file[0](id, m->file);
#endif
  }

  if(m->href && query("insert_href")) {
    if(m->nocache)
      NOCACHE();
    else
      CACHE(60);
    object q=Protocols.HTTP.get_url(m->href);
    if(q && q->status>0 && q->status<400)
      return q->data();
    return rxml_error(tag,(q?q->status_desc:0)||"No server respons",id);
  }

  string ret="Could not fullfill your request.<br>\nArguments:";
  foreach(indices(m), string tmp)
    ret+="<br />\n"+tmp+" : "+m[tmp];
 
  return rxml_error(tag, ret, id);
}

string tag_configurl(string tag, mapping m, object id) {
  return id->conf->api_functions()->config_url[0]();
}

string tag_return(string tag, mapping m, object id)
{
  id->conf->api_functions()->set_return_code[0]( id, (int)m->code || 200, m->text );
  return "";
}

string tag_set_cookie(string tag, mapping m, object id)
{
  string cookies;
  int t;     //time

  if(m->name)
    cookies = m->name+"="+http_encode_cookie(m->value||"");
  else
    return rxml_error(tag, "Requires a name attribute.", id);

  if(m->persistent)
    t=(3600*(24*365*2));
  else
    t=id->conf->api_functions()->time_quantifier[0](id, m);

  if(t) cookies += "; expires="+http_date(t+time());

  //obs! no check of the parameter's usability
  cookies += "; path=" +(m->path||"/");

  id->conf->api_functions()->add_header[0](id, "Set-Cookie", cookies);

  return "";
}

string tag_remove_cookie(string tag, mapping m, object id)
{
  if(!m->name || !id->cookies[m->name]) return rxml_error(tag, "That cookie does not exists.", id);
  id->conf->api_functions()->remove_cookie[0](id, m->name, m->value);
  return "";
}

string tag_user(string tag, mapping m, object id, object file)
{
  return id->conf->api_functions()->tag_user_wrapper[0](id, tag, m, file);
}

string tag_modified(string tag, mapping m, object id, object file)
{
  return id->conf->api_functions()->tag_user_wrapper[0](id, tag, m, file);
}


// ------------------- Containers ----------------

string tag_aprestate(string tag, mapping m, string q, object id)
{
  string href, s, *foo;

  if(!(href = m->href))
    href=strip_prestate(strip_config(id->raw_url));
  else 
  {
    if ((sizeof(foo = href / ":") > 1) && (sizeof(foo[0] / "/") == 1))
      return make_container("a",m,q);
    href=strip_prestate(fix_relative(href, id));
    m_delete(m, "href");
  }
  
  if(!strlen(href))
    href="";

  multiset prestate = (< @indices(id->prestate) >);

#if old_rxml_compat
  // Not part of RXML 1.4
  int oldflag=0;
  foreach(indices(m), s) {
    if(m[s]==s) {
      m_delete(m,s);
      oldflag=1;

      if(strlen(s) && s[0] == '-')
        prestate[s[1..]]=0;
      else
        prestate[s]=1;
     }
  }
  if(oldflag) old_rxml_warning(id, "prestates as atomic attributs in apre tag","add and drop");
#endif

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
  return make_container("a",m,q);
}

string tag_aconf(string tag, mapping m, string q, object id)
{
  string href,s;
  mapping cookies = ([]);
  
  if(m->help) return "Adds or removes config options.";

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

#if old_rxml_compat
  // Not part of RXML 1.4
  int oldflag=0;
  foreach(indices(m), string opt) {
    if(m[opt]==opt) {
      if(strlen(opt)) {
        oldflag=1;
        switch(opt[0]) {
        case '+':
          m_delete(m, opt);
          cookies[opt[1..]] = opt;
          break;
        case '-':
          m_delete(m, opt);
          cookies[opt] = opt;
          break;
        }
      }
    }
  }
  if(oldflag) old_rxml_warning(id, "config items as atomic attributes in aconf tag","add and drop");
#endif

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

string tag_maketag(string tag, mapping m, string cont, object id) {
  NOCACHE();
  id->misc+=(["maketag_args":(!m->noxml&&m->type=="tag"?(["/":"/"]):([]))]);
  cont=replace(parse_html(cont,([]),(["attrib":
    lambda(string tag, mapping m, string cont, mapping c, object id) {
      id->misc->maketag_args+=([m->name:parse_rxml(cont,id)]);
      return "";
    }
  ]),([]),id), ({"\"","<",">"}), ({"'","&lt;","&gt;"}));
  if(m->type=="container")
    return make_container(m->name, id->misc->maketag_args, cont);
  return make_tag(m->name,id->misc->maketag_args);
}

string tag_doc(string tag, mapping m, string s)
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

string tag_autoformat(string tag, mapping m, string s, object id)
{
  s-="\r";

#if old_rxml_compat
    // m->pre is not part of RXML 1.4
    if(m->pre) {
      old_rxml_warning(id, "pre attribute in autoformat tag","p attribute");
      m+=(["p":1]);
    }
#endif

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

class smallcapsstr {
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

string tag_smallcaps(string t, mapping m, string s)
{
  object ret;
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
    ret=smallcapsstr("font","font", m+bm, m+sm);
  }
  else {
    ret=smallcapsstr("big","small", m+bm, m+sm);
  }

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

string tag_random(string tag, mapping m, string s)
{
  mixed q;
  if(!(q=m->separator || m->sep))
    return (q=s/"\n")[random(sizeof(q))];
  else
    return (q=s/q)[random(sizeof(q))];
}

array(string) tag_formoutput(string tag_name, mapping args, string contents, object id)
{
  return ({do_output_tag( args, ({ id->variables }), contents, id )});
}

mixed tag_gauge(string t, mapping args, string contents, object id)
{
  NOCACHE();

#if constant(gethrtime)
  int t = gethrtime();
  contents = parse_rxml( contents, id );
  t = gethrtime()-t;
#else
  int t = gauge {
    contents = parse_rxml( contents, id );
  } * 1000;
#endif
  string define = args->define?args->define:"gauge";

  id->misc->defines[define+"_time"] = sprintf("%3.6f", t/1000000.0);
  id->misc->defines[define+"_result"] = contents;

  if(args->silent) return "";
  if(args->timeonly) return sprintf("%3.6f", t/1000000.0);
  if(args->resultonly) return ({contents});
  return ({"<br><font size=\"-1\"><b>Time: "+
	   sprintf("%3.6f", t/1000000.0)+
	   " seconds</b></font><br>"+contents});
} 

// Removes empty lines
mixed tag_trimlines( string tag_name, mapping args, string contents,
		      object id )
{
  contents = replace(parse_rxml( contents, id ),
		     ({ "\r\n","\r" }), ({"\n", "\n"}));
  return ({ (contents / "\n" - ({ "" })) * "\n" });
}

// Internal method for the default tag
private mixed tag_input( string tag_name, mapping args, string name,
			  multiset (string) value )
{
  if (name && args->name != name)
    return 0;
  if (args->type == "checkbox" || args->type == "radio")
    if (args->value)
      if (value[ args->value ])
	if (args->checked)
	  return 0;
        else
          args->checked = "checked";
      else
	if (args->checked)
	  m_delete( args, "checked" );
	else
	  return 0;
    else
      if (value[ "on" ])
	if (args->checked)
	  return 0;
	else
	  args->checked = "checked";
      else
	if (args->checked)
	  m_delete( args, "checked" );
	else
	  return 0;
  else
    return 0;
  return ({ make_tag( tag_name, args ) });
}

// Internal method for the default tag
private mixed tag_option( string tag_name, mapping args, string contents,
				  multiset (string) value )
{
  if (args->value)
    if (value[ args->value ])
      if (args->selected)
	return 0;
      else
	args->selected = "selected";
    else
      return 0;
  else
    if (value[ trim( contents ) ])
      if (args->selected)
	return 0;
      else
	args->selected = "selected";
    else
      return 0;
  return ({make_container( tag_name, args, contents )});
}

// Internal method for the default tag
private mixed tag_select( string tag_name, mapping args, string contents,
			   string name, multiset (string) value )
{
  array (string) tmp;
  int c;
  
  if (name && args->name != name)
    return 0;
  tmp = contents / "<option";
  for (c=1; c < sizeof( tmp ); c++)
    if (sizeof( tmp[c] / "</option>" ) == 1)
      tmp[c] += "</option>";
  contents = tmp * "<option";
  mapping m = ([ "option" : tag_option ]);
  contents = parse_html( contents, ([ ]), m, value );
  return ({ make_container( tag_name, args, contents ) });
}

// The default tag is used to give default values to forms elements,
// without any fuss.
array(string) tag_default( string tag_name, mapping args, string contents, object id)
{
  string separator = args->separator || "\000";
#if old_rxml_compat
  separator = args->multi_separator || "\000";
#endif


  contents = parse_rxml( contents, id );
  if (args->value)
    return ({parse_html( contents, ([ "input" : tag_input ]),
			 ([ "select" : tag_select ]),
			 args->name, mkmultiset( args->value
						 / separator ) )});
  else if (args->variable && id->variables[ args->variable ])
    return ({parse_html( contents, ([ "input" : tag_input ]),
			 ([ "select" : tag_select ]),
			 args->name,
			 mkmultiset( id->variables[ args->variable ]
				     / separator ) )});
  else    
    return ({contents});
}

string tag_sort(string t, mapping m, string c, object id)
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

mixed tag_recursive_output (string tagname, mapping args, string contents, object id)
{
#if old_rxml_compat
  if(args->multisep) args->separator=args->multisep;
#endif
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit) {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->separator || ",") : ({});
    outside = args->outside ? args->outside / (args->separator || ",") : ({});
    if (sizeof (inside) != sizeof (outside))
      return "\n<b>'inside' and 'outside' replacement sequences "
	"aren't of same length</b>\n";
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
      (["recurse": lambda (string t, mapping a, string c) {return ({c});}]), ([]),
      "<" + tagname + ">" + replace (contents, inside, outside) + "</" + tagname + ">"),
    id);

  id->misc->recout_limit = save_limit;
  id->misc->recout_inside = save_inside;
  id->misc->recout_outside = save_outside;

  return ({res});
}

string tag_leave(string tag, mapping m, object id)
{
  if(id->misc->leave_repeat) {
    id->misc->leave_repeat--;
    throw(3141);
  }
  return rxml_error(tag, "Must be contained by &lt;repeat&gt;.", id);
}

string tag_repeat(string tag, mapping m, string c, object id)
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
    if((intp(error) && error!=0 && error!=3141) || !intp(error))
      throw(error);
    if(id->misc->leave_repeat!=exit)
      ret+=iter;
  }
  if(loop==maxloop)
    return ret+rxml_error(tag, "Too many iterations ("+maxloop+").", id);
  return ret;
}

string tag_replace(string tag,mapping m,string cont,object id) {
  switch(m->type) {

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

#if old_rxml_compat
// Not part of RXML 1.4

string tag_source(string tag, mapping m, string s, object id)
{
  old_rxml_warning(id, "source tag","a template");
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return ("<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
    +"</pre>"+sep+s);
}

#endif


// ----------------- Tag registration stuff --------------

mapping query_tag_callers()
{
   return (["accept-language":tag_language,
	    "append":tag_append,
	    "auth-required":tag_auth_required,
	    "clientname":tag_clientname,
	    "configimage":tag_configimage,
	    "configurl":tag_configurl,
	    "date":tag_date,
	    "debug":tag_debug,
            "dec":tag_dec,
	    "expire-time":tag_expire_time,
	    "file":tag_file,
	    "fsize":tag_fsize,           
	    "header":tag_header,
	    "imgs":tag_imgs,
            "insert":tag_insert,
            "inc":tag_inc,
            "leave":tag_leave,
            "modified":tag_modified,
 	    "quote":tag_quote,
	    "realfile":tag_realfile,
	    "redirect":tag_redirect,
	    "referer":tag_referrer,
	    "referrer":tag_referrer,
	    "remove-cookie":tag_remove_cookie,
	    "return":tag_return,
	    "roxen":tag_roxen,
	    "set":tag_set,
	    "set-cookie":tag_set_cookie,
	    "set-max-cache":
	    lambda(string t, mapping m, object id) { 
	      id->misc->cacheable = (int)m->time; 
	    },
	    "unset":tag_set,
	    "user":tag_user,
	    "vfs":tag_vfs,

#if old_rxml_compat
            // Not part of RXML 1.4
            "echo":
            lambda(string t, mapping m, object id) {   // Well, this isn't exactly 100% compatible...
              old_rxml_warning(id, "echo tag","insert tag");
              return make_tag("!--#echo",m);
            },
            "pr":tag_roxen,
            "refferrer":tag_referrer,
            "source":tag_source,
#endif
   ]);
}

mapping query_container_callers()
{
  return ([
	   "aconf":tag_aconf,
	   "apre":tag_aprestate,
	   "autoformat":tag_autoformat,
	   "cache":tag_cache,
	   "catch":lambda(string t, mapping m, string c, object id) {
		     string r;
		     if(!id->misc->catcher_is_ready)
  		       id->misc+=(["catcher_is_ready":1]);
		     else
		       id->misc->catcher_is_ready++;
		     array e = catch(r=parse_rxml(c, id));
                     id->misc->catcher_is_ready--;
		     if(e) return e[0];
		     return ({r});
		   },
	   "crypt":lambda(string t, mapping m, string c){
		     if(m->compare)
		       return crypt(c,m->compare)?"<true>":"<false>";
		     else
		       return crypt(c);
		   },
	   "doc":tag_doc,
	   "default":tag_default,
	   "formoutput":tag_formoutput,
	   "gauge":tag_gauge,
           "maketag":tag_maketag,
	   "random":tag_random,
	   "recursive-output": tag_recursive_output,
           "repeat":tag_repeat,
           "replace":tag_replace,
	   "scope":tag_scope,
	   "smallcaps":tag_smallcaps,
	   "sort":tag_sort,
	   "throw":lambda(string t, mapping m, string c, object id) { 
		     if(!id->misc->catcher_is_ready && c[-1]!="\n") c+="\n";
                     throw( ({ c, backtrace() }) ); 
           },
	   "trimlines":tag_trimlines,
#if old_rxml_compat
           // Not part of RXML 1.4
	   "cset":lambda(string t, mapping m, string c, object id) {
		    old_rxml_warning(id, "cset tag","&lt;define variable&gt;");
                    return tag_set("set",m+([ "value":html_decode_string(c) ]),
		    id); },
#endif
	   ]);
}

mapping query_if_callers()
{
  return ([
    "expr":lambda( string q){ return (int)sexpr_eval(q); },
  ]);
}
