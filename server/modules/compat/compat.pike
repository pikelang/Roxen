inherit "module";
inherit "roxenlib";
#include <module.h>

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

constant thread_safe=1;
constant language = roxen->language;

array register_module()
{
  return ({
    MODULE_PARSER | MODULE_PROVIDER,
    "Old RXML Compatibility Module",
    "Adds support for old (deprecated) RXML tags and attributes.",
    0,1
  });
}

void create(object c)
{
  defvar("logold", 0, "Log all old RXML calls in the event log.",
         TYPE_FLAG,
         "If set, all calls though the backward compatibility code will be"
         "logged in the event log, enabeling you to upgrade those RXML tags.");
}

string query_providers() {
  return "oldRXMLwarning";
}

void old_rxml_warning(object id, string problem, string solution)
{
  if(query("logold"))
    report_warning("Old RXML in "+(id->query||id->not_query)+
    ", contains "+problem+". Use "+solution+" instead.");
}

// Changes the parsing order by first parsing it's contents and then
// morphing itself into another tag that gets parsed.
string container_preparse( string tag_name, mapping args, string contents,
		     RequestID id )
{
  old_rxml_warning(id, "preparse tag","preparse attribute");
  return make_container( args->tag, args - ([ "tag" : 1 ]),
			 parse_rxml( contents, id ) );
}

string|int tag_append(string tag, mapping m, RequestID id)
{
  if(m->variable && m->define) {
    // Set variable to the value of a define
    id->variables[ m->variable ] += id->misc->defines[ m->define ]||"";
    old_rxml_warning(id, "define attribute in append tag","only variables");
    return "";
  }
  return 0;
}

string|int tag_redirect(string tag, mapping m, RequestID id)
{
  if(m->add || m->drop) return 0;

  if (!(m->to && sizeof (m->to)))
    return rxml_error(tag, "Requires attribute \"to\".", id);

  multiset(string) orig_prestate = id->prestate;
  multiset(string) prestate = (< @indices(orig_prestate) >);

  foreach(indices(m), string s)
    if(m[s]==s && sizeof(s))
      switch (s[0]) {
	case '+': prestate[s[1..]] = 1;
      	          old_rxml_warning(id, "+prestate attribute","add=prestate");
                  break;
	case '-': prestate[s[1..]] = 0;
    	          old_rxml_warning(id, "-prestate attribute","drop=prestate");
                  break;
      }

  id->prestate = prestate;
  mapping r = http_redirect(m->to, id);
  id->prestate = orig_prestate;

  if (r->error)
    _error = r->error;
  if (r->extra_heads)
    foreach(indices(r->extra_heads), string tmp)
      add_http_header(_extra_heads, tmp, r->extra_heads[tmp]);
  if (m->text)
    _rettext = m->text;

  return "";
}

string tag_refferrer(string tag, mapping m, RequestID id)
{
  if(tag=="refferrer") old_rxml_warning(id, "refferrer tag","referrer tag");
  return make_tag("referrer",m);
}

string tag_set(string tag, mapping m, RequestID id)
{
  if(m->define && m->variable) {
    // Set variable to the value of a define
    id->variables[ m->variable ] = id->misc->defines[ m->define ];
    old_rxml_warning(id, "define attribute in set tag","only variables");
  }
  return 0;
}

string tag_pr(string tag, mapping m, RequestID id)
{
  if(tag=="pr") old_rxml_warning(id,"pr tag","roxen tag");
  return make_tag("roxen",m);
}

string tag_date(string q, mapping m, RequestID id)
{
  // unix_time is not part of RXML 1.4
  int t=(int)m["unix-time"] || (int)m->unix_time || time(1);
  if(m->unix_time) old_rxml_warning(id, "unix_time attribute in date tag","unix-time");
  if(m->day)    t += (int)m->day * 86400;
  if(m->hour)   t += (int)m->hour * 3600;
  if(m->minute) t += (int)m->minute * 60;
  if(m->second) t += (int)m->second;
  t+=time_dequantifier(m);

  if(!(m->brief || m->time || m->date))
    m->full=1;

  if(m->part=="second" || m->part=="beat")
    NOCACHE();
  else
    CACHE(60); // One minute is good enough.

  return tagtime(t, m, id, language);
}

inline string do_replace(string s, mapping m, RequestID id)
{
  return replace(s, indices(m), values(m));
  old_rxml_warning(id, "replace (A=B) in in insert tag","the replace tag");
}

string|array(string)|int tag_insert(string tag,mapping m,RequestID id)
{
  string n;

  // Not part of RXML 1.4
  if(n=m->define || m->name) {
    old_rxml_warning(id, "define or name attribute in insert tag","only variables");
    m_delete(m, "define");
    m_delete(m, "name");
    if(id->misc->defines[n])
      return ({ do_replace(id->misc->defines[n], m, id) });
    return rxml_error(tag, "No such define ("+n+").", id);
  }

  if(n = m->variable)
  {
    if(!id->variables[n])
      return rxml_error(tag, "No such variable ("+n+").", id);
    m_delete(m, "variable");
    return m->quote=="none"?do_replace(id->variables[n], m-(["quote":""]), id):
      ({ html_encode_string(do_replace(id->variables[n], m-(["quote":""]), id)) });
  }

  if(n = m->other) {
    if(stringp(id->misc[n]) || intp(id->misc[n])) {
      return m->quote=="none"?(string)id->misc[n]:({ html_encode_string((string)id->misc[n]) });
    }
    return rxml_error(tag, "No such other variable ("+n+").", id);
  }

  if(n=m->cookie)
  {
    NOCACHE();
    m_delete(m, "cookie");
    if(id->cookies[n]) {
      string cookie=do_replace(id->cookies[n], m, id);
      return m->quote=="none"?cookie:({ html_encode_string(cookie) });
    }
    return rxml_error(tag, "No such cookie ("+n+").", id);
  }

  if(m->file)
  {
    if(m->nocache) {
      int nocache=id->pragma["no-cache"];
      id->pragma["no-cache"] = 1;
      n=API_read_file(id,m->file)||rxml_error("insert", "No such file ("+m->file+").", id);
      id->pragma["no-cache"] = nocache;
      m_delete(m, "nocache");
      m_delete(m, "file");
      return do_replace(n, m, id);
    }
    string|int n=API_read_file(id,m->file);
    return n?do_replace(n, m-(["file":""]), id):rxml_error("insert", "No such file ("+m->file+").", id);
  }

  return 0;
}

string|int container_apre(string tag, mapping m, string q, RequestID id)
{
  if(m->add || m->drop) return 0;
  old_rxml_warning(id, "prestates as atomic attributs in apre tag","add and drop");

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

  // Not part of RXML 1.4
  foreach(indices(m), s) {
    if(m[s]==s) {
      m_delete(m,s);

      if(strlen(s) && s[0] == '-')
        prestate[s[1..]]=0;
      else
        prestate[s]=1;
     }
  }

  m->href = add_pre_state(href, prestate);
  return make_container("a", m, q);
}

string|array(string)|int container_aconf(string tag, mapping m, string q, RequestID id)
{
  if(m->add || m->drop) return 0;
  old_rxml_warning(id, "config items as atomic attributes in aconf tag","add and drop");

  string href,s;
  mapping cookies = ([]);
  
  if(m->help) return ({ "Adds or removes config options." });

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

  // Not part of RXML 1.4
  foreach(indices(m), string opt) {
    if(m[opt]==opt) {
      if(strlen(opt)) {
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

  m->href = add_config(href, indices(cookies), id->prestate);
  return make_container("a", m, q);
}

string|int container_autoformat(string tag, mapping m, string c, RequestID id)
{
  if(!m->pre) return 0;
  old_rxml_warning(id, "pre attribute in autoformat tag","p attribute");
  m+=(["p":1]);
  m_delete(m, "pre");
  return make_container("autoformat", m, c);
}

string|int container_default(string tag, mapping m, string c, RequestID id)
{
  if(!m->multi_separator) return 0;
  old_rxml_warning(id, "multiseparator attribute in default tag","separator attribute");
  m+=(["separator":m->multi_separator]);
  m_delete(m, "multi_separator");
  return make_container("default", m, c);
}

string|int container_recursive_output(string tag, mapping m, string c, RequestID id)
{
  if(!m->multisep) return 0;
  old_rxml_warning(id, "multisep attribute in recursive-output tag","separator attribute");
  m+=(["separator":m->multisep]);
  m_delete(m, "multisep");
  return make_container("recursive-output", m, c);
}

string container_source(string tag, mapping m, string s, RequestID id)
{
  old_rxml_warning(id, "source tag","a template");
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return ("<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
    +"</pre>"+sep+s);
}

//FIXME: I have serious doubts about this one...
string|int tag_configimage(string tag, mapping m, RequestID id)
{
  for(int i=1; i<4; i++)
    if(m->src=="err_"+i) {
      m->src="err"+i;
      old_rxml_warning(id, "err_"+i+" argument in configimage tag","err"+i);
      return make_tag("configimage",m);
    }
  return 0;
}

string|int tag_countdown(string tag, mapping m, string c, RequestID id)
{
  if(!m->min && !m->sec && !m->age && m->prec!="min" &&
     !m->christmas_eve && !m->christmas_day && !m->christmas && !m->year2000 &&
     !m->easter && !m->nowp && !m->seconds && !m->minutes && !m->hours &&
     !m->days && !m->weeks && !m->months && !m->years && !m->dogyears &&
     !m->combined && !m->when) return 0;

  foreach( ({ 
    ({"min","minute"}),
    ({"sec","second"}),
    ({"age","since"}) }), array tmp)
    { if(m[tmp[0]]) { 
      m[tmp[1]]=m[tmp[0]];
      m_delete(m, tmp[0]);
      old_rxml_warning(id, "countdown attribute "+tmp[0],tmp[1]);
    }
  }

  if(m->prec=="min") {
    m->prec="minute";
    old_rxml_warning(id, "prec=min in countdown tag","prec=minute");
  }

  foreach(({"christmas_eve","christmas_day","christmas","year2000","easter"}), string tmp)
    if(m[tmp]) {
      m->event=tmp;
      m_delete(m, tmp);
      old_rxml_warning(id, "countdown attribute "+tmp,"event="+tmp);
    }

  if(m->nowp) {
    m->round="up";
    m->display="boolean";
    m_delete(m, "nowp");
    old_rxml_warning(id, "countdown attribute nowp",
      "display=boolean (possibly together with round=up)");
  }

  if(!m->display) {
    foreach(({"seconds","minutes","hours","days","weeks","months","years",
        "dogyears","combined","when"}), string tmp) {
      if(m[tmp]) m->display=tmp;
      m_delete(m, tmp);
      old_rxml_warning(id, "countdown attribute "+tmp,"display="+tmp);
    }
  }
}

string|int container_tablify(string tag, mapping m, string q, RequestID id)
{
  if(!m->fgcolor0 && !m->fgcolor1 && !m->fgcolor && !m->rowalign &&
     !m->bgcolor && !m->preprocess && !m->parse) return 0;

  if(m->fgcolor0) {
    m->oddbgcolor=m->fgcolor0;
    m_delete(m, "fgcolor0");
    old_rxml_warning(id, "tablify attribute fgcolor0","oddbgcolor");
  }
  if(m->fgcolor1) {
    m->evenbgcolor=m->fgcolor1;
    m_delete(m, "fgcolor1");
    old_rxml_warning(id, "tablify attribute fgcolor1","evenbgcolor");
  }
  if(m->fgcolor) {
    m->textcolor=m->fgcolor;
    m_delete(m, "fgcolor");
    old_rxml_warning(id, "tablify attribute fgcolor","textcolor");
  }
  if(m->rowalign) {
    m->cellalign=m->rowalign;
    m_delete(m, "rowalign");
    old_rxml_warning(id, "tablify attribute rowalign","cellalign");
  }
  // When people have forgotten what bgcolor meant we can reuse it as evenbgcolor=oddbgcolor=m->bgcolor
  if(m->bgcolor) {
    m->bordercolor=m->bgcolor;
    m_delete(m, "bgcolor");
    old_rxml_warning(id, "tablify attribute bgcolor","bordercolor");
  }
  if (m->preprocess || m->parse) {
    q = parse_rxml(q, id);
    old_rxml_warning(id, "tablify attribute "+(m->parse?"parse":"preprocess"),"preparse");
    m_delete(m, "parse");
    m_delete(m, "preprocess");
  }
  return make_container("tablify",m,q);
}

string tag_echo(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "echo tag","insert tag");
  return make_tag("!--#echo",m);  
}

string|int container_gtext(string t, mapping|int m, string c, RequestID id) {
  m=gtext_compat(m,id);
  if(!m) return 0;
  return make_container(t,m,c);
}

string|int tag_gtext_id(string t, int|mapping m, RequestID id) {
  m=gtext_compat(m,id);
  if(!m) return 0;
  return make_tag(t,m);
}

mapping|int gtext_compat(mapping m, RequestID id) {
  int ch=0;
  foreach(glob("magic_*", indices(m)), string q) {
    m["magic-"+q[6..]]=m[q];
    m_delete(m, q);
    old_rxml_warning(id, "gtext attribute "+q,"magic-"+q[6..]);
    ch++;
  }
  if(m->fg) {
    m->fgcolor=m->fg;
    m_delete(m, "fg");
    old_rxml_warning(id, "gtext attribute fg","fgcolor");
    ch++;
  }
  if(m->bg) {
    m->bgcolor=m->bg;
    m_delete(m, "bg");
    old_rxml_warning(id, "gtext attribute bg","bgcolor");
    ch++;
  }
  if(m->fuzz) {
    m["magic-glow"]=m->fuzz=="fuzz"?m->fgcolor+",1":m->fuzz;
    m_delete(m, "fuzz");
    old_rxml_warning(id, "gtext attribute fuzz","magic-glow");
    ch++;
  }
  if(m->magicbg) {
    m["magic-background"]=m->magicbg;
    m_delete(m, "magicbg");
    old_rxml_warning(id, "gtext attribute magicbg","magic-background");
    ch++;
  }
  if(!ch) return 0;
  return m;
}

mapping query_tag_callers() {
  return (["echo":tag_echo,
	   "countdown":tag_countdown,
	   "configimage":tag_configimage,
	   "insert":tag_insert,
	   "date":tag_date,
	   "pr":tag_pr,
	   "refferrer":tag_refferrer,
	   "set":tag_set,
	   "redirect":tag_redirect,
	   "append":tag_append,
	   "gtext-id":tag_gtext_id
  ]);
}

mapping query_container_callers() {
  return (["tablify":container_tablify,
	   "source":container_source,
	   "recursive-output":container_recursive_output,
	   "default":container_default,
	   "autoformat":container_autoformat,
	   "aconf":container_aconf,
	   "apre":container_apre,
	   "preparse":container_preparse,
	   "gtext":container_gtext,
	   "gh":container_gtext,
	   "gh1":container_gtext,
	   "gh2":container_gtext,
	   "gh3":container_gtext,
	   "gh4":container_gtext,
	   "gh5":container_gtext,
	   "gh6":container_gtext,
	   "anfang":container_gtext,
	   "gtext-url":container_gtext
  ]);
}

mapping query_if_callers()
{
  return ([
    "successful":lambda(string q, RequestID id){ return id->misc->defines[" _ok"]; },
    "failed":lambda(string q, RequestID id){ return !id->misc->defines[" _ok"]; }
  ]);
}
