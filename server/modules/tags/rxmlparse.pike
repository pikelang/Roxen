// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.
//
// The main RXML parser. If this module is not added to a configuration,
// no RXML parsing will be done at all for .html files. 
//
// It is in severe need of a cleanup in the code.
//
// This file *should* be split into multiple files, one with all
// 'USER' related tags, one with all CLIENT related tags, etc.
// 
// the only thing that should be in this file is the main parser.  

#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

#define old_rxml_compat 1

constant cvs_version="$Id: rxmlparse.pike,v 1.6 1999/07/23 04:12:33 nilsson Exp $";
constant thread_safe=1;

function call_user_tag, call_user_container;

#include <config.h>
#include <module.h>

inherit "module";
inherit "roxenlib";

constant language = roxen->language;

int bytes;  // Holds the number of bytes parsed

// If the string 'w' match any of the patterns in 'a', return 1, else 0.
int _match(string w, array (string) a)
{
  string q;
  foreach(a, q)
    if(stringp(w) && stringp(q) && glob(q, w))
      return 1;
}

// Configuration interface fluff.
string comment()
{
  return query("toparse")*", ";
}

string status()
{
  return (bytes/1024 + " Kb parsed.<br>");
}

void create(object c)
{
  defvar("toparse", ({ "rxml","spml", "html", "htm" }), "Extensions to parse", 
	 TYPE_STRING_LIST, "Parse all files ending with these extensions. "
	 "Note: This module must be reloaded for a change here to take "
	 "effect.");

  defvar("parse_exec", 0, "Require exec bit on files for parsing",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files has to have the execute bit (any of them) set "
	 "in order for them to be parsed by this module. The exec bit "
	 "is the one that is set by 'chmod +x filename'");
	 
  defvar("no_parse_exec", 0, "Don't Parse files with exec bit",
	 TYPE_FLAG|VAR_MORE,
	 "If set, no files with the exec bit set will be parsed. This is the "
	 "reverse of the 'Require exec bit on files for parsing' flag. "
	 "It is not very useful to set both variables.");
	 
  defvar("max_parse", 100, "Maximum file size", TYPE_INT|VAR_MORE,
	 "Maximum file size to parse, in Kilo Bytes.");

#if old_rxml_compat
  defvar("logold", 0, "Log all old RXML calls in the event log.",
         TYPE_FLAG|VAR_MORE,
         "If set, all calls though the backward compatibility code will be"
         "logged in the event log, enabeling you to upgrade those RXML tags.");
#endif
}


void start(int q, object c)
{
  if(!c) return;
  call_user_container = c->parse_module->call_user_container;
  call_user_tag = c->parse_module->call_user_tag;
  define_API_functions();
}

array register_module()
{
  return ({ MODULE_FILE_EXTENSION|MODULE_PARSER, 
	    "RXML 1.4 parser", 
	    ("This module provides basic RXML 1.4 support, e.g. adds a lot of RXML tags and "
             "handles the mapping from .html to the rxml parser."), ({}), 1 });
}

array(string) query_file_extensions() 
{
  if(api_functions()->accessed_extensions)
    return query("toparse") + api_functions()->accessed_extensions[0]();
  return query("toparse");
}

mapping handle_file_extension( object file, string e, object id)
{
  string to_parse;
  mapping defines = id->misc->defines || ([]);
  array stat = defines[" _stat"] || id->misc->stat || file->stat();
  id->misc->defines = defines;
  
  if(id->conf->modules->accessed && search(id->conf->api_functions()->accessed_extensions[0](),e)!=-1)
  {
    id->conf->api_functions()->accessed[0](id, id->not_query, 1);
    defines->counted = "1";
    if(search(QUERY(toparse),e)==-1)  // Parse anyway
      return 0;
  }

  if(QUERY(parse_exec) &&   !(stat[0] & 07111)) return 0;
  if(QUERY(no_parse_exec) && (stat[0] & 07111)) return 0;

  id->misc->defines[" _stat"] = stat;
  bytes += strlen(to_parse = file->read());
  return http_rxml_answer( to_parse, id, file, "text/html" );
}

/* standard roxen tags */

string tagtime(int t,mapping m,object id)
{
  string s;
  mixed eris;
  string res;

  if (m->adjust) t+=(int)m->adjust;

  if (m->part)
  {
    string sp;
    if(m->type == "ordered")
    {
      m->type="string";
      sp = "ordered";
    }

    switch (m->part)
    {
     case "year":
      return number2string((int)(localtime(t)->year+1900),m,
			   language(m->lang, sp||"number"));
     case "month":
      return number2string((int)(localtime(t)->mon+1),m,
			   language(m->lang, sp||"month"));
     case "day":
     case "wday":
      return number2string((int)(localtime(t)->wday+1),m,
			   language(m->lang, sp||"day"));
     case "date":
     case "mday":
      return number2string((int)(localtime(t)->mday),m,
			   language(m->lang, sp||"number"));
     case "hour":
      return number2string((int)(localtime(t)->hour),m,
			   language(m->lang, sp||"number"));
     case "min":  // Not part of RXML 1.4
     case "minute":
      return number2string((int)(localtime(t)->min),m,
			   language(m->lang, sp||"number"));
     case "sec": // Not part of RXML 1.4
     case "second":
      return number2string((int)(localtime(t)->sec),m,
			   language(m->lang, sp||"number"));
     case "yday":
      return number2string((int)(localtime(t)->yday),m,
			   language(m->lang, sp||"number"));
     default: return "";
    }
  } else if(m->type) {
    switch(m->type)
    {
     case "iso":
      eris=localtime(t);
      return sprintf("%d-%02d-%02d", (eris->year+1900),
		     eris->mon+1, eris->mday);

     case "discordian":
       //     case "disc":
#if efun(discdate)
      eris=discdate(t);
      res=eris[0];
      if(m->year)
	res += " in the YOLD of "+eris[1];
      if(m->holiday && eris[2])
	res += ". Celebrate "+eris[2];
      return res;
#else
      return "Discordian date support disabled";
#endif
     case "stardate":
       //     case "star":
#if efun(stardate)
      return (string)stardate(t, (int)m->prec||1);
#else
      return "Stardate support disabled";
#endif
     default:
    }
  }
  s=language(m->lang, "date")(t,m);

#if old_rxml_compat
  // Not part of RXML 1.4
  if (m->upper) {
    s=upper_case(s);
    api_old_rxml_warning(id,"upper attribute in a tag","case=\"upper\"");
  }
  if (m->lower) {
    s=lower_case(s);
    api_old_rxml_warning(id,"lower attribute in a tag","case=\"lower\"");
  }
  if (m->cap||m->capitalize) {
    s=capitalize(s);
    api_old_rxml_warning(id,"captialize or cap attribute in a tag.","case=\"capitalize\"");
  }
#endif

  if(m["case"])
    switch(lower_case(m["case"])) {
    case "upper": s=upper_case(s); break;
    case "lower": s=lower_case(s); break;
    case "capitalize": s=capitalize(s);
    }

  return s;
}

string tag_date(string q, mapping m, object id)
{
#if old_rxml_compat
  // unix_time is not part of RXML 1.4
  int t=(int)m["unix-time"] || (int)m->unix_time || time(1);
  if(m->unix_time) api_old_rxml_warning(id, "unix_time attribute in date tag","unix-time");
#else
  int t=(int)m["unix-time"] || time(1);
#endif
  if(m->day)    t += (int)m->day * 86400;
  if(m->hour)   t += (int)m->hour * 3600;
  if(m->minute) t += (int)m->minute * 60;
  //  if(m->min)    t += (int)m->min * 60;
  //  if(m->sec)    t += (int)m->sec;
  if(m->second) t += (int)m->second;

  if(!(m->brief || m->time || m->date))
    m->full=1;

  if(!m->date)
  {
    if(!m->unix_time || m->second)
      NOCACHE();
  } else
    CACHE(60); // One minute is good enough.

  return tagtime(t,m,id);
}


constant permitted = ({ "1", "2", "3", "4", "5", "6", "7", "8", "9",
                        "x","a","b","c,","d","e","f", "n", "t", "\""
                        "X","A","B","C,","D","E","F", "l", "o",
                        "<",">", "=", "0", "-", "*", "+","/", "%", 
                        "&", "|", "(", ")" });

string sexpr_eval(string what)
{
  array q = what/"";
  what = "mixed foo(){ return "+(q-(q-permitted))*""+";}";
  return (string)compile_string( what )()->foo();
}

array(string) tag_scope(string tag, mapping m, string contents, object id)
{
  mapping old_variables = id->variables;
  id->variables = ([]);
  if (m->extend)
    id->variables += old_variables;
  contents = parse_rxml(contents, id);
  id->variables = old_variables;
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
      else if (!m->debug || id->misc->debug)
	return "Set: from variable doesn't exist";
      else
	return "";
    else if (m->other)
      // Set variable to the value of a misc variable
      if (id->misc->variables && id->misc->variables[ m->other ])
	id->variables[ m->variable ] = id->misc->variables[ m->other ];
      else if (m->debug || id->misc->debug)
	return "Set: other variable doesn't exist";
      else 
	return "";
#if old_rxml_compat
    // Not part of RXML 1.4
    else if(m->define) {
      // Set variable to the value of a define
      id->variables[ m->variable ] = id->misc->defines[ m->define ];
      api_old_rxml_warning(id, "define attribute in set tag","only variables");
    }
#endif
    else if (m->eval)
      // Set variable to the result of some evaluated RXML
      id->variables[ m->variable ] = parse_rxml(m->eval, id);
    else
      // Unset variable.
      m_delete( id->variables, m->variable );
    return("");
  } else {
    if(id->misc->debug)
      return("set on (line "+id->misc->line+"): variable not specified");
    return("<!-- set (line "+id->misc->line+"): variable not specified -->");
  }
}

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
      else if (m->debug || id->misc->debug)
	return "<b>Append: from variable doesn't exist</b>";
      else
	return "";
    else if (m->other)
      // Set variable to the value of a misc variable
      if (id->misc->variables[ m->other ])
	if (id->variables[ m->variable ])
	  id->variables[ m->variable ] += id->misc->variables[ m->other ];
	else
	  id->variables[ m->variable ] = id->misc->variables[ m->other ];
      else if (m->debug || id->misc->debug)
	return "<b>Append: other variable doesn't exist</b>";
      else
	return "";
#if old_rxml_compat
    // Not part of RXML 1.4
    else if(m->define) {
      // Set variable to the value of a define
      id->variables[ m->variable ] += id->misc->defines[ m->define ]||"";
      api_old_rxml_warning(id, "define attribute in append tag","only variables");
    }
#endif
    else if (m->debug || id->misc->debug)
      return "<b>Append: nothing to append from</b>";
    else
      return "";
    return("");
  }
  else if (m->debug || id->misc->debug)
    return("<b>Append: variable not specified</b>");
  else
    return "";
}

inline string do_replace(string s, mapping (string:string) m) {
  return replace(s, indices(m), values(m));
}

string tag_insert(string tag,mapping m,object id,object file,mapping defines)
{
  if(m->help)
    return "Inserts a file, variable or other object into a webpage";

  string n;
  mapping fake_id=([]);

#if old_rxml_compat
  // Not part of RXML 1.4
  if(n=m->define || m->name) {
    api_old_rxml_warning(id, "define or name attribute in insert tag","only variables");
    return defines[n]||(id->misc->debug?"No such define: "+n:"");
  }
#endif

  if (n=m->variable)
    return id->variables[n]||(id->misc->debug?"No such variable: "+n:"");

  if (n=m->variables) 
  {
    if(n!="variables")
      return Array.map(indices(id->variables), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, id->variables)*"\n";
    return String.implode_nicely(indices(id->variables));
  }

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
    return id->cookies[n]||(id->misc->debug?"No such cookie: "+n:"");
  }

  if (m->file) 
  {
    string s;
    string f;
    f = fix_relative(m->file, id);
    id = id->clone_me();

    if(m->nocache) id->pragma["no-cache"] = 1;
    if(id->scan_for_query)
      f = id->scan_for_query( f );
    s = id->conf->try_get_file(f, id);


    if(!s) {
      if ((sizeof(f)>2) && (f[sizeof(f)-2..] == "--")) {
	// Might be a compat insert. <!--#include file=foo.html-->
	s = id->conf->try_get_file(f[..sizeof(f)-3], id);
      }
      if (!s) {

	// Might be a PATH_INFO type URL.
	array a = id->conf->open_file( f, "r", id );
	if(a && a[0])
	{
	  s = a[0]->read();
	  if(a[1]->raw)
	  {
	    s -= "\r";
	    if(!sscanf(s, "%*s\n\n%s", s))
	      sscanf(s, "%*s\n%s", s);
	  }
	}
	if(!s)
	  return id->misc->debug?"No such file: "+f+"!":"";
      }
    }

    return s;
  }

  if(m->href) {
    mixed error=catch {
      n=(string)Protocols.HTTP.get_url_data(m->href);
    };
    if(arrayp(error)) return "\n<!-- "+error[0]+ "-->\n";
    return n;
  }

  if(id->misc->debug) {
    string ret="Could not fullfill your request.<br>\nArguments:<br>\n";
    foreach(indices(m), string tmp)
      ret+=tmp+" : "+m[tmp]+"<br />\n";
    return ret;
  }

  return "";
}

string tag_modified(string tag, mapping m, object id, object file,
		    mapping defines)
{
  array (int) s;
  object f;
  

  if(m->by && !m->file && !m->realfile)
  {
    if(!id->conf->auth_module)
      return id->misc->debug?"Modified by requires an user database!\n":"";
    m->name = id->conf->last_modified_by(file, id);
    CACHE(10);
    return tag_user(tag, m, id, file, defines);
  }

  if(m->file)
  {
    m->realfile = id->conf->real_file(fix_relative(m->file,id), id);
    m_delete(m, "file");
  }

  if(m->by && m->realfile)
  {
    if(!id->conf->auth_module)
      return id->misc->debug?"Modified by requires an user database!\n":"";

    if(f = open(m->realfile, "r"))
    {
      m->name = id->conf->last_modified_by(f, id);
      destruct(f);
      CACHE(10);
      return tag_user(tag, m, id, file,defines);
    }
    return "A. Nonymous.";
  }
  
  if(m->realfile)
    s = file_stat(m->realfile);

  if(!(_stat || s) && !m->realfile && id->realfile)
  {
    m->realfile = id->realfile;
    return tag_modified(tag, m, id, file, defines);
  }
  CACHE(10);
  if(!s) s = _stat;
  if(!s) s = id->conf->stat_file( id->not_query, id );
  if(s)
    if(m->ssi)
      return strftime(defines->timefmt || "%c", s[3]);
    else
      return tagtime(s[3], m, id);
  else
    return "Error: Cannot stat file";
}

function tag_version = roxen.version;

string tag_clientname(string tag, mapping m, object id)
{
  NOCACHE();
  if (sizeof(id->client))
    if(m->full) 
      return id->client * " ";
    else 
      return id->client[0];

  return ""; 
}

string tag_user(string tag, mapping m, object id, object file,mapping defines)
{
  string *u;
  string b, dom;

  if(!id->conf->auth_module)
    return id->misc->debug?"User requires an user database!\n":"";

  if (!(b=m->name)) {
    return(tag_modified("modified", m | ([ "by":"by" ]), id, file,defines));
  }

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
      return "<a href=\"/~"+b+"/\">"+u[4]+"</a>";
    return u[4];
  }
  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return "<a href=\"mailto:" + b + "@" + dom + "\">"
	+ b + "@" + dom + "</a>";
    return b + "@" + dom;
  }
  if(m->nolink && !m->link)
    return u[4] + " &lt;" + b + "@" + dom + "&gt;";
  return ("<a href=\"/~"+b+"/\">"+u[4]+"</a>"+
	  " <a href=\"mailto:" + b + "@" + dom + "\"> &lt;"+
	  b + "@" + dom + "&gt;</a>");
}

string tag_configurl(string f, mapping m) { return roxen->config_url(); }

string tag_configimage(string f, mapping m)
{
  if (m->src) {
    if (m->src[sizeof(m->src)-4..] == ".gif") {
      m->src = m->src[..sizeof(m->src)-5];
    }
    m->src = "/internal-roxen-" + m->src;
  }

  m->border = m->border || "0";
  m->alt = m->alt || m->src;

  return make_tag("img", m);
}

string tag_aprestate(string tag, mapping m, string q, object id)
{
  string href, s, *foo;

  if(!(href = m->href))
    href=strip_prestate(strip_config(id->raw_url));
  else 
  {
    if ((sizeof(foo = href / ":") > 1) && (sizeof(foo[0] / "/") == 1))
      return make_container("a",m,q);
    href=fix_relative(href, id);
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
  if(oldflag) api_old_rxml_warning(id, "prestates as atomic attributs in apre tag","add and drop");
#endif

  if(m->add) {
    foreach(m->add/",", s)
      prestate[s]=1;
    m_delete(m,"add");
  }
  if(m->drop) {
    foreach(m->drop/",", s)
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
      return sprintf((id->misc->debug?"It is not possible to add "
                      "configs to absolute URLs (yet, at least)\n":"")+
		     "<a href=\"%s\">%s</a>", href, q);
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
  if(oldflag) api_old_rxml_warning(id, "config items as atomic attributes in aconf tag","add and drop");
#endif

  if(m->add) {
    foreach(m->add/",", s)
      cookies[s]=s;
    m_delete(m,"add");
  }
  if(m->drop) {
    foreach(m->drop/",", s)
      cookies["-"+s]="-"+s;
    m_delete(m,"drop");
  }

  m->href = add_config(href, indices(cookies), id->prestate);
  return make_container("a", m, q);
}

string add_header(mapping to, string name, string value)
{
  if(to[name])
    if(arrayp(to[name]))
      to[name] += ({ value });
    else
      to[name] = ({ to[name], value });
  else
    to[name] = value;
}

string tag_add_cookie(string tag, mapping m, object id, object file,
		      mapping defines)
{
  string cookies;
  int    t;     //time

  if(m->name)
    cookies = m->name+"="+http_encode_cookie(m->value||"");
  else
    return id->misc->debug?"set-cookie requires a `name'":"";

  if(m->persistent)
    t=(3600*(24*365*2));
  else
  {
    if (m->hours)   t+=((int)(m->hours))*3600;
    if (m->minutes) t+=((int)(m->minutes))*60;
    if (m->seconds) t+=((int)(m->seconds));
    if (m->days)    t+=((int)(m->days))*(24*3600);
    if (m->weeks)   t+=((int)(m->weeks))*(24*3600*7);
    if (m->months)  t+=((int)(m->months))*(24*3600*30+37800); /* 30.46d */
    if (m->years)   t+=((int)(m->years))*(3600*(24*365+6));   /* 365.25d */
  }

  if(t) cookies += "; expires="+http_date(t+time());

  //obs! no check of the parameter's usability
  cookies += "; path=" +(m->path||"/");

  add_header(_extra_heads, "Set-Cookie", cookies);

  return "";
}

string tag_remove_cookie(string tag, mapping m, object id, object file,
			 mapping defines)
{
  string cookies;
  if(m->name)
    cookies = m->name+"="+http_encode_cookie(m->value||"")+
      "; expires="+http_date(0)+"; path=/";
  else
    return id->misc->debug?"remove-cookie requires a `name'":"";

  add_header(_extra_heads, "Set-Cookie", cookies);
  return "";
}

string tag_return(string tag, mapping m, object id, object file,
		  mapping defines)
{
  if(m->code)_error=(int)m->code || 200;
  if(m->text)_rettext=m->text;
  return "";
}

string tag_referrer(string tag, mapping m, object id, object file,
		   mapping defines)
{
  NOCACHE();

#if old_rxml_compat
  if(tag=="refferrer") api_old_rxml_warning(id, "refferrer tag","referrer tag");
#endif

  if(m->help) 
    return ("Shows from which page the client linked to this one.");
  if(id->referer)
    return sizeof(id->referer)?id->referer*"":m->alt?m->alt:"..";
  return m->alt?m->alt:"..";
}

string tag_header(string tag, mapping m, object id, object file,
		  mapping defines)
{
  if(m->name == "WWW-Authenticate")
  {
    string r;
    if(m->value)
    {
      if(!sscanf(m->value, "Realm=%s", r))
	r=m->value;
    } else {
      r="Users";
    }
    m->value="basic realm=\""+r+"\"";
  } else if(m->name=="URI") {
    m->value = "<" + m->value + ">";
  }
  
  if(!(m->value && m->name))
    return id->misc->debug?"Header requires both a name and a value.":"";

  add_header(_extra_heads, m->name, m->value);
  return "";
}

string tag_redirect(string tag, mapping m, object id, object file,
		    mapping defines)
{
  if (!m->to) {
    return(id->misc->debug?"Redirect requires attribute \"to\".":"");
  }

  multiset(string) orig_prestate = id->prestate;
  multiset(string) prestate = (< @indices(orig_prestate) >);
  foreach(indices(m), string s)
    if(m[s]==s && sizeof(s))
      switch (s[0]) {
	case '+': prestate[s[1..]] = 1; break;
	case '-': prestate[s[1..]] = 0; break;
      }
  id->prestate = prestate;
  mapping r = http_redirect(m->to, id);
  id->prestate = orig_prestate;

  if (r->error) {
    _error = r->error;
  }
  if (r->extra_heads) {
    _extra_heads += r->extra_heads;
  }
  if (m->text) {
    _rettext = m->text;
  }
  return("");
}

string tag_auth_required (string tagname, mapping args, object id,
			  object file, mapping defines)
{
  mapping hdrs = http_auth_required (args->realm, args->message);
  if (hdrs->error) _error = hdrs->error;
  if (hdrs->extra_heads) _extra_heads += hdrs->extra_heads;
  if (hdrs->text) _rettext = hdrs->text;
  return "";
}

string tag_expire_time(string tag, mapping m, object id, object file,
		       mapping defines)
{
  int t=time();
  if(!m->now)
  {
    if (m->hours) t+=((int)(m->hours))*3600;
    if (m->minutes) t+=((int)(m->minutes))*60;
    if (m->seconds) t+=((int)(m->seconds));
    if (m->days) t+=((int)(m->days))*(24*3600);
    if (m->weeks) t+=((int)(m->weeks))*(24*3600*7);
    if (m->months) t+=((int)(m->months))*(24*3600*30+37800); /* 30.46d */
    if (m->years) t+=((int)(m->years))*(3600*(24*365+6));   /* 365.25d */
    CACHE(max(t-time(),0));
  } else {
    NOCACHE();
    add_header(_extra_heads, "Pragma", "no-cache");
    add_header(_extra_heads, "Cache-Control", "no-cache");
  }

  add_header(_extra_heads, "Expires", http_date(t));
  return "";
}

string tag_file(string tag, mapping m, object id)
{
  if(m->raw)
    return id->raw_url;
  else
    return id->not_query;
}

string tag_realfile(string tag, mapping m, object id)
{
  return id->realfile || "unknown";
}

string tag_vfs(string tag, mapping m, object id)
{
  return id->virtfile || "unknown";
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

string tag_imgs(string tagname, mapping m, object id)
{
  string img = id->conf->real_file(fix_relative(m->src||"", id), id);
  if(img && search(img, ".gif")!=-1) {
    object fd = open(img, "r");
    if(fd) {
      int x, y;
      sscanf(gif_size(fd), "width=%d height=%d", x, y);
      m->width=x;
      m->height=y;
    }
  }
  if(!m->alt) {
    array src=m->src/"/";
    string src=src[sizeof(src)-1];
    m->alt=String.capitalize(replace(src[..sizeof(m->src)-5],"_"," "));
  }
  return make_tag("img", m);
}

string tag_roxen(string tagname, mapping m, object id)
{
#if old_rxml_compat
  if(tagname=="pr") api_old_rxml_warning(id,"pr tag","roxen tag");
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
  return ("<a href=\"http://www.roxen.com/\">"+make_tag("img", m)+"</a>");
}

string tag_debug( string tag_name, mapping args, object id )
{
  if (args->off)
    id->misc->debug = 0;
  else if (args->toggle)
    id->misc->debug = !id->misc->debug;
  else
    id->misc->debug = 1;
  return "";
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
}

#if old_rxml_compat
// Not part of RXML 1.4

string tag_source(string tag, mapping m, string s, object id,object file)
{
  api_old_rxml_warning(id, "source tag","a template");
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return ("<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
    +"</pre>"+sep+s);
}

#endif

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
	    "expire-time":tag_expire_time,
	    "file":tag_file,
	    "fsize":tag_fsize,           
	    "header":tag_header,
	    "imgs":tag_imgs,
	    "insert":tag_insert,
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
 	    "set-cookie":tag_add_cookie,
	    "set-max-cache":
	    lambda(string t, mapping m, object id) { 
	      id->misc->cacheable = (int)m->time; 
	    },
	    "unset":tag_set,
	    "user":tag_user,
	    "version":tag_version,
	    "vfs":tag_vfs,

#if old_rxml_compat
            // Not part of RXML 1.4
            "echo":
            lambda(string t, mapping m, object id) {   // Well, this isn't exactly 100% compatible...
              api_old_rxml_warning(id, "echo tag","insert tag");
              return make_tag("!--#echo",m);
            },
            "pr":tag_roxen,
            "refferrer":tag_referrer,
            "source":tag_source,
#endif
   ]);
}

string tag_doc(string tag, mapping m, string s, object id,object file)
{
  if(!m["quote"])
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"{","}","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "{", "}", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
  else 
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "<", ">", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
}

string tag_autoformat(string tag, mapping m, string s, object id,object file)
{
  s-="\r";
  if(!m->nobr) {
    s = replace(s, "\n", "<br>\n");
#if old_rxml_compat
    // m->pre is not part of RXML 1.4
    if(m->pre) api_old_rxml_warning(id, "pre attribute in autoformat tag","p attribute");
    if(m->p || m->pre) {
#else
    if(m->p) {
#endif
      if(search(s, "<br>\n<br>\n")!=-1) s="<p>"+s;
      s = replace(s, "<br>\n<br>\n", "\n</p><p>\n");
      if(s[..sizeof(s)-4]=="<p>")
        s=s[..sizeof(s)-4];
      else
        s+="</p>";
    }
#if old_rxml_compat
  // m->pre is not part of RXML 1.4
  } else if(m->p || m->pre) {
#else
  } else if(m->p) {
#endif
    if(search(s, "\n\n")!=-1) s="<p>"+s;
      s = replace(s, "\n\n", "\n</p><p>\n");
      if(s[..sizeof(s)-4]=="<p>")
        s=s[..sizeof(s)-4];
      else
        s+="</p>";
    }
  
  return s;
}

string tag_smallcaps(string t, mapping m, string s)
{
  string build="";
  int i,lc=1,j;
  string small=m->small;
  if (m->size)
  {
    build="<font size=\""+m->size+"\">";
    if (!small)
    {
      if (m->size[0]=='+') small="+"+(((int)m->size[1..10])-1);
      else if (m->size[0]=='-') small="-"+(((int)m->size[1..10])+1);
      else small=""+(((int)m->size)-1);
    }
  } else if (!small) small="-1";
  
  for (i=0; i<strlen(s); i++)
    if (s[i]=='<') 
    { 
      if (!lc) 
      { 
	build+="</font>";
	lc=1; 
      }
      for (j = i;j < strlen(s) && s[j] != '>'; j++);
      build += s[i..j];
      i = j;
    }
    else if (s[i]<=32) 
    { 
      if (!lc) build+="</font>"+s[i..i]; 
      else 
	build+=s[i..i]; 
      lc=1; 
    }
    else if (s[i]&64)
      if (s[i]&32) 
      { 
	if (lc) 
	  build+="<font size=\""+small+"\">"+sprintf("%c",s[i]-32)
	    +(m->space?"&nbsp;":""); 
	else 
	  build+=sprintf("%c",s[i]-32)+(m->space?"&nbsp;":""); lc=0; }
      else { 
	if (!lc) 
	  build+="</font>"+s[i..i]+(m->space?"&nbsp;":""); 
	else 
	  build+=s[i..i]+(m->space?"&nbsp;":""); 
	lc=1; 
      }
    else 
      build+=s[i..i]+(m->space?"&nbsp;":"");
  if (!lc) 
    build+="</font>"; 
  if (m->size) 
    build+="</font>";
  return build;
}

string tag_random(string tag, mapping m, string s)
{
  mixed q;
  if(!(q=m->separator || m->sep))
    return (q=s/"\n")[random(sizeof(q))];
  else
    return (q=s/q)[random(sizeof(q))];
}

array(string) tag_formoutput(string tag_name, mapping args, string contents,
			     object id, mapping defines)
{
  return ({do_output_tag( args, ({ id->variables }), contents, id )});
}

mixed tag_gauge(string t, mapping args, string contents,
		object id, object f, mapping defines)
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

  defines[define+"_time"] = sprintf("%3.6f", t/1000000.0);
  defines[define+"_result"] = contents;

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
array(string) tag_default( string tag_name, mapping args, string contents,
			   object id, object f, mapping defines, object fd )
{
  string multi_separator = args->multi_separator || "\000";

  contents = parse_rxml( contents, id );
  if (args->value)
    return ({parse_html( contents, ([ "input" : tag_input ]),
			 ([ "select" : tag_select ]),
			 args->name, mkmultiset( args->value
						 / multi_separator ) )});
  else if (args->variable && id->variables[ args->variable ])
    return ({parse_html( contents, ([ "input" : tag_input ]),
			 ([ "select" : tag_select ]),
			 args->name,
			 mkmultiset( id->variables[ args->variable ]
				     / multi_separator ) )});
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

  return pre + sort(lines)*m->separator + post;
}

mixed tag_recursive_output (string tagname, mapping args, string contents,
			    object id, object file, mapping defines)
{
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit) {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->multisep || ",") : ({});
    outside = args->outside ? args->outside / (args->multisep || ",") : ({});
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

string tag_maketag(string tag, mapping m, string cont, object id) {
  NOCACHE();
  id->misc+=(["maketag_args":(!m->noxml&&m->type=="tag"?(["/":"/"]):([]))]);
  cont=replace(parse_html(cont,([]),(["attrib":
    lambda(string tag, mapping m, string cont, mapping c, object id) {
      id->misc->maketag_args+=([m->attrib:parse_rxml(cont,id)]);
      return "";
    }
  ]),([]),id), ({"\"","<",">"}), ({"'","&lt;","&gt;"}));
  if(m->type=="tag")
    return make_tag(m->name,id->misc->maketag_args);
  return make_container(m->name, id->misc->maketag_args, cont);
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
		     array e = catch(r=parse_rxml(c, id));
		     if(e) return e[0];
		     return ({r});
		   },
	   "crypt":lambda(string t, mapping m, string c){
		     if(m->compare)
		       return (string)crypt(c,m->compare);
		     else
		       return crypt(c);
		   },
	   "doc":tag_doc,
	   "default" : tag_default,
	   "formoutput":tag_formoutput,
	   "gauge":tag_gauge,
           "maketag":tag_maketag,
	   "random":tag_random,
	   "recursive-output": tag_recursive_output,
           "replace":tag_replace,
	   "scope":tag_scope,
	   "smallcaps":tag_smallcaps,
	   "sort":tag_sort,
	   "throw":lambda(string t, mapping m, string c) {
		     if(c[-1] != "\n") c+="\n";
		     throw( ({ c, backtrace() }) );
		   },
	   "trimlines" : tag_trimlines,
#if old_rxml_compat
           // Not part of RXML 1.4
	   "cset":lambda(string t, mapping m, string c, object id) {
		    api_old_rxml_warning(id, "cset tag","&lt;define variable&gt;");
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

string api_parse_rxml(object id, string r)
{
  return parse_rxml( r, id );
}

string api_tagtime(object id, int ti, string t, string l)
{
  mapping m = ([ "type":t, "lang":l ]);
  NOCACHE();
  return tagtime( ti, m, id );
}

string api_relative(object id, string path)
{
  return fix_relative( path, id );
}

string api_set(object id, string what, string to)
{
  tag_set("set",(["variable":what, "value":to]) , id);
  return ([])[0];
}

string api_define(object id, string what, string to)
{
  id->misc->defines[what]=to;
  return ([])[0];
}

string api_query_define(object id, string what)
{
  return id->misc->defines[what];
}

string api_query_variable(object id, string what)
{
  return id->variables[what];
}

string api_read_file(object id, string f)
{
  mapping m = ([ "file":f ]);
  return tag_insert("insert", m, id, id, id->misc->defines);
}

string api_query_cookie(object id, string f)
{
  mapping m = ([ "cookie":f ]);
  return tag_insert("insert", m, id, id, id->misc->defines);
}

string api_query_modified(object id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  return tag_modified("modified", m, id, id, id->misc->defines);
}

void api_add_header(object id, string h, string v)
{
  add_header(id->misc->defines[" _extra_heads"], h, v);
}

void api_set_cookie(object id, string c, string v)
{
  tag_add_cookie( "add_cookie", (["name":c,"persistent":1,"value":v]),
		  id, id, id->misc->defines);
}

void api_remove_cookie(object id, string c, string v)
{
  tag_remove_cookie( "remove_cookie", (["name":c,"value":v]),
		     id, id, id->misc->defines);
}

int api_prestate(object id, string p)
{
  return id->prestate[p];
}

int api_set_prestate(object id, string p)
{
  return id->prestate[p]=1;
}

int api_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p];
}

int api_set_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p]=1;
}


int api_set_return_code(object id, int c, string p)
{
  tag_return("return", ([ "code":c, "text":p ]), id,id,id->misc->defines);
  return ([])[0];
}

string api_get_referer(object id)
{
  NOCACHE();
  if(id->referer && sizeof(id->referer)) return id->referer*"";
  return ([])[0];
}

string api_html_quote(object id, string what)
{
  return replace(what, ({ "<", ">", "&" }),({"&lt;", "&gt;", "&amp;" }));
}

constant replace_from=indices( iso88591 )+({"&lt;","&gt;","&amp;","&#022;"});
constant replace_to =values( iso88591 )+ ({"<",">", "&","\""});

string api_html_dequote(object id, string what)
{
  return replace(what, replace_from, replace_to);
}

string api_html_quote_attr(object id, string value)
{
  return sprintf("\"%s\"", replace(value, "\"", "&quot;"));
}

void api_old_rxml_warning(object id, string problem, string solution)
{
  if(query("logold"))
    report_warning("Old RXML in "+(id->query||id->not_query)+" contains "+problem+". Use "+solution+" instead.");
}

void add_api_function( string name, function f, void|array(string) types)
{
  if(this_object()["_api_functions"])
    this_object()["_api_functions"][name] = ({ f, types });
}

void define_API_functions()
{
  add_api_function("parse_rxml", api_parse_rxml, ({ "string" }));
  add_api_function("tag_time", api_tagtime, ({ "int", 0,"string", "string" }));
  add_api_function("fix_relative", api_relative, ({ "string" }));
  add_api_function("set_variable", api_set, ({ "string", "string" }));
  add_api_function("define", api_define, ({ "string", "string" }));

  add_api_function("query_define", api_query_define, ({ "string", }));
  add_api_function("query_variable", api_query_variable, ({ "string", }));
  add_api_function("query_cookie", api_query_cookie, ({ "string", }));
  add_api_function("query_modified", api_query_modified, ({ "string", }));

  add_api_function("read_file", api_read_file, ({ "string", 0,"int"}));
  add_api_function("add_header", api_add_header, ({"string", "string"}));
  add_api_function("add_cookie", api_set_cookie, ({"string", "string"}));
  add_api_function("remove_cookie", api_remove_cookie, ({"string", "string"}));

  add_api_function("html_quote", api_html_quote, ({"string"}));
  add_api_function("html_dequote", api_html_dequote, ({"string"}));
  add_api_function("html_quote_attr", api_html_quote_attr, ({"string"}));

  add_api_function("prestate", api_prestate, ({"string"}));
  add_api_function("set_prestate", api_set_prestate, ({"string"}));

  add_api_function("supports", api_supports, ({"string"}));
  add_api_function("set_supports", api_set_supports, ({"string"}));

  add_api_function("set_return_code", api_set_return_code, ({ "int", 0, "string" }));
  add_api_function("query_referer", api_get_referer, ({ "int", 0, "string" }));

  add_api_function("roxen_version", tag_version, ({}));
  add_api_function("config_url", tag_configurl, ({}));
  add_api_function("old_rxml_warning", api_old_rxml_warning, ({ "string", "string" }));
}

int may_disable()  { return 0; }
