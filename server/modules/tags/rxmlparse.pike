// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.
//
// The main RXML parser. If this module is not added to a configuration,
// no RXML parsing will be done at all for .html files. 
//

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

#define old_rxml_compat 1

constant cvs_version="$Id: rxmlparse.pike,v 1.20 1999/09/18 01:31:48 nilsson Exp $";
constant thread_safe=1;

constant language = roxen->language;

function call_user_tag, call_user_container;

#include <config.h>
#include <module.h>

inherit "module";
inherit "roxenlib";

int bytes;  // Holds the number of bytes parsed

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
	    "RXML 1.4 stand alone parser", 
	    ("This module handles the mapping from .html to the rxml parser."), 0, 1 });
}

array(string) query_file_extensions() 
{
  return query("toparse");
}

mapping handle_file_extension(object file, string e, object id)
{
  string to_parse;

  array stat;
  if(id->misc->defines)
    stat=_stat;
  else {
    id->misc+=(["defines":([" _ok":1])]);
    stat=_stat=id->misc->stat || file->stat();
  }

  if(QUERY(parse_exec) &&   !(stat[0] & 07111)) return 0;
  if(QUERY(no_parse_exec) && (stat[0] & 07111)) return 0;

  bytes += strlen(to_parse = file->read());
  return http_rxml_answer( to_parse, id, file, "text/html" );
}

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
#if efun(stardate)
      return (string)stardate(t, (int)m->prec||1);
#else
      return "Stardate support disabled";
#endif
    }
  }
  s=language(m->lang, "date")(t,m);

  if(m["case"])
    switch(lower_case(m["case"])) {
    case "upper": return upper_case(s);
    case "lower": return lower_case(s);
    case "capitalize": return capitalize(s);
    }

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
  return s;
#endif
}

string api_read_file(object id, string file)
{
  string s, f = fix_relative(file, id);
  id = id->clone_me();

  if(id->scan_for_query)
    f = id->scan_for_query( f );
  s = id->conf->try_get_file(f, id);

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
      return rxml_error("insert", "No such file ("+f+").", id);
  }

  return s;
}

string tag_modified(string tag, mapping m, object id, object file)
{
  array (int) s;
  object f;
  
  if(m->by && !m->file && !m->realfile)
  {
    if(!id->conf->auth_module)
      return rxml_error(tag, "Modified by requires a user database.", id);
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
  if(s)
    if(m->ssi)
      return strftime(id->misc->defines->timefmt || "%c", s[3]);
    else
      return tagtime(s[3], m, id);

  return rxml_error(tag, "Couldn't stat file.", id);
}

string tag_version() {
  return roxen.version();
}

string tag_user(string tag, mapping m, object id, object file)
{
  string *u;
  string b, dom;

  if(!id->conf->auth_module)
    return rxml_error(tag, "Requires a user database.", id);

  if (!(b=m->name)) {
    return(tag_modified("modified", m | ([ "by":"by" ]), id, file));
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

string api_configurl(string f, mapping m) { return roxen->config_url(); }

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

mapping query_tag_callers()
{
  return ([
	   "version":tag_version]);
}

mapping query_container_callers()
{
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

string api_tagtime_map(object id, int ti, void|mapping m)
{
  NOCACHE();
  return tagtime( ti, m||([]) , id );
}

string api_relative(object id, string path)
{
  return fix_relative( path, id );
}

string api_set(object id, string what, string to)
{
  if (id->variables[ what ])
    id->variables[ what ] += to;
  else
    id->variables[ what ] = to;
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

string api_query_cookie(object id, string f)
{
  return id->cookies[f];
}

string api_query_modified(object id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  return tag_modified("modified", m, id, id);
}

void api_add_header(object id, string h, string v)
{
  add_header(_extra_heads, h, v);
}

int api_set_cookie(object id, string c, string v, void|string p)
{
  if(!c)
    return 0;

  add_header(_extra_heads, "Set-Cookie",
    c+"="+http_encode_cookie(v||"")+
    "; expires="+http_date(time(1)+(3600*24*365*2))+
    "; path=" +(p||"/")
  );

  return 1;
}

int api_remove_cookie(object id, string c, string v)
{
  if(!c)
    return 0;

  add_header(_extra_heads, "Set-Cookie",
    c+"="+http_encode_cookie(v||"")+"; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/"
  );

  return 1;
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

int api_set_return_code(object id, int c, void|string p)
{
  if(c) _error=c;
  if(p) _rettext=p||"";
  return 1;
}

string api_get_referer(object id)
{
  NOCACHE();
  if(id->referer && sizeof(id->referer)) return id->referer*"";
  return "";
}

string api_html_quote(object id, string what)
{
  return replace(what, ({ "<", ">", "& " }),({"&lt;", "&gt;", "&amp; " }));
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
    report_warning("Old RXML in "+(id->query||id->not_query)+", contains "+problem+". Use "+solution+" instead.");
}

void add_api_function( string name, function f, void|array(string) types)
{
  if(this_object()["_api_functions"])
    this_object()["_api_functions"][name] = ({ f, types });
}

string tag_modified_wrapper(object id, string tag, mapping m, object file)
{
  return tag_modified(tag, m, id, file);
}

string tag_user_wrapper(object id, string tag, mapping m, object file)
{
  return tag_user(tag, m, id, file);
}

int time_quantifier(object id, mapping m)
{
  float t = 0.0;
  if (m->seconds) t+=((float)(m->seconds));
  if (m->minutes) t+=((float)(m->minutes))*60;
  if (m->beats)   t+=((float)(m->beats))*86.4;
  if (m->hours)   t+=((float)(m->hours))*3600;
  if (m->days)    t+=((float)(m->days))*86400;
  if (m->weeks)   t+=((float)(m->weeks))*604800;
  if (m->months)  t+=((float)(m->months))*(24*3600*30.46);
  if (m->years)   t+=((float)(m->years))*(3600*(24*365.242190));
  return (int)round(t);
}

//Variables after 0 are optional.
void define_API_functions()
{
  add_api_function("parse_rxml", api_parse_rxml, ({ "string" }));
  add_api_function("tag_time", api_tagtime, ({ "int", 0,"string", "string" }));
  add_api_function("tag_time_wrapper", api_tagtime_map, ({ "int", 0,"mapping"}));
  add_api_function("tag_modified_wrapper", tag_modified_wrapper, ({ "string", "mapping", "object", "object" }));
  add_api_function("tag_user_wrapper", tag_user_wrapper, ({ "string", "mapping", "object", "object" }));
  add_api_function("fix_relative", api_relative, ({ "string" }));
  add_api_function("set_variable", api_set, ({ "string", "string" }));
  add_api_function("define", api_define, ({ "string", "string" }));

  add_api_function("query_define", api_query_define, ({ "string", }));
  add_api_function("query_variable", api_query_variable, ({ "string", }));
  add_api_function("query_cookie", api_query_cookie, ({ "string", }));
  add_api_function("query_modified", api_query_modified, ({ "string", }));

  add_api_function("read_file", api_read_file, ({ "string"}));
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
  add_api_function("query_referer", api_get_referer, ({}));

  add_api_function("roxen_version", tag_version, ({}));
  add_api_function("config_url", api_configurl, ({}));
  add_api_function("old_rxml_warning", api_old_rxml_warning, ({ "string", "string" }));
  add_api_function("time_quantifier", time_quantifier, ({ "mapping" }));
}

int may_disable()  { return 0; }
