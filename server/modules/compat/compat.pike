// Old RXML Compatibility Module Copyright 2000 (c) Idonex
//

inherit "module";
inherit "roxenlib";
#include <module.h>

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]


// ------------------- Module Registration and common stuff ------------------------

constant thread_safe=1;
constant language = roxen->language;

constant module_type   = MODULE_PARSER | MODULE_PROVIDER;
constant module_name   = "Old RXML Compatibility Module";
constant module_doc    = "Adds support for old (deprecated) RXML tags and attributes.";
constant module_unique = 1;

void create()
{
  defvar("logold", 0, "Log all old RXML calls in the event log.",
         TYPE_FLAG,
         "If set, all calls though the backward compatibility code will be"
         "logged in the event log, enabeling you to upgrade those RXML tags.");
}

constant relevant=(<"rxmltags","graphic_text","tablify","countdown","counter">);
multiset enabled;
void start (int when, Configuration conf)
{
  set("_priority",7);
  conf->parse_html_compat = 1;
  enabled=(<>);
  foreach(indices(conf->enabled_modules), string name)
    enabled+=(<name[0..sizeof(name)-3]>);
  enabled-=(enabled-relevant);
}

string query_provides() {
  return "oldRXMLwarning";
}

int warnings=0;
void old_rxml_warning(RequestID id, string problem, string solution)
{
  warnings++;
  if(query("logold"))
    report_warning("Old RXML in "+id->not_query+
    ": contains "+problem+". Use "+solution+" instead.\n");
}

string status() {
  string ret="";
  ret+="<b>RXML Warnings:</b> "+warnings+"<br>\n"
    "<b>Support enabled for:</b> "+
    String.implode_nicely(indices(enabled), ",")+"<br>\n";
  return ret;
}


// ----------------------- Documentation --------------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"clientname":#"<desc tag>
 Returns the name of the client. No required attributes.
</desc>

<attr name=full>
 View the full User Agent string.
</attr>

<attr name=quote value=html,none>
 Quotes the clientname. Default is 'html'.
</attr>",

"file":#"<desc tag>
 Prints the path part of the URL used to get this page.
</desc>

<attr name=quote value=html,none>
 How the filename is quoted. Default is 'html'.
</attr>

<attr name=raw>
 Prints the full path part, including the query part with form
 variables.
</attr>",

"realfile":#"<desc tag>

 Prints the path to the file containing the page in the computers file
 system, rather than Roxen Webserver's virtual file system, or unknown if
 it is impossible to determine.
</desc>",

"referer":#"<desc tag>
 Inserts the URL the visitor came from.
</desc>

<attr name=alt>
 Text to write if no referrer is given.
</attr>

<attr name=quote value=html,none>
 How the referrer should be quoted. Default is 'html'.
</attr>",

"referrer":#"<desc tag>
 Inserts the URL the visitor came from.
</desc>

<attr name=alt>
 Text to write if no referrer is given.
</attr>

<attr name=quote value=html,none>
 How the referrer should be quoted. Default is 'html'.
</attr>",

"refferrer":#"<desc tag>
 Inserts the URL the visitor came from.
</desc>

<attr name=alt>
 Text to write if no referrer is given.
</attr>

<attr name=quote value=html,none>
 How the referrer should be quoted. Default is 'html'.
</attr>",

"vfs":#"<desc tag>
 Prints the mountpoint of the filesystem module that handles the page,
 or unknown if it could not be determined. This is useful for creating
 pages or applications that are to be placed anywhere on a site, but
 for some reason have to use absolute paths.
</desc>",

"accept-language":#"<desc tag>
 Returns the language code of the language the user prefers, as
 specified by the first language in the accept-language header.

 <p>If no accept-language is sent by the users browser None will be
 returned.</p>
</desc>

<attr name=end value=character>

</attr>

<attr name=full>
 Returns all languages the user has specified, as a comma separated list.
</attr>

<attr name=start value=character>

</attr>",
]);
#endif


// --------------------------- Tags and containers ------------------------------

string container_preparse( string tag_name, mapping args, string contents,
		     RequestID id )
// Changes the parsing order by first parsing it's contents and then
// morphing itself into another tag that gets parsed.
{
  old_rxml_warning(id, "preparse tag","preparse attribute");
  return make_container( args->tag, args - ([ "tag" : 1 ]),
			 parse_rxml( contents, id ) );
}

array|string tag_append(string tag, mapping m, RequestID id)
{
  if(m->variable) {
    if(m->define) {
      // Set variable to the value of a define
      id->variables[ m->variable ] += id->misc->defines[ m->define ]||"";
      old_rxml_warning(id, "define attribute in append tag","only variables");
      return ({""});
    }
    if (m->other) {
      old_rxml_warning(id, "other attribute in append tag","only regular variables");
      RXML.Context context=RXML.get_context();
      mixed value=context->user_get_var(m->variable, m->scope);
      // Append the value of a misc variable to an enityt variable.
      if (!id->misc->variables || !id->misc->variables[ m->other ])
	return rxml_error(tag, "Other variable doesn't exist.", id);
      if (value)
	value+=id->misc->variables[ m->other ];
      else
	value=id->misc->variables[ m->other ];
      context->user_set_var(m->variable, value, m->scope);
      return ({""});
    }
  }

  return ({1});
}

string|array tag_redirect(string tag, mapping m, RequestID id)
{
  if(m->add || m->drop) return ({1});

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

  return ({""});
}

array(string) tag_referrer(string tag, mapping m, RequestID id)
{
  NOCACHE();
  old_rxml_warning(id, tag+" tag", "&client.referrer; entity");
  return({ sizeof(id->referer) ?
    (m->quote=="none"?id->referer:(html_encode_string(id->referer*""))) :
    (m->alt || "") });
}

string|array tag_set(string tag, mapping m, RequestID id)
{
  if(m->variable) {
    RXML.Context context=RXML.get_context();
    if(m->define) {
      // Set variable to the value of a define
      context->user_set_var(m->variable, id->misc->defines[ m->define ], m->scope);
      old_rxml_warning(id, "define attribute in set tag","only variables");
      return ({""});
    }
    if (m->other) {
      old_rxml_warning(id, "other attribute in set tag","only regular variables");
      if (id->misc->variables && id->misc->variables[ m->other ]) {
	// Set an entity variable to the value of a misc variable
	context->user_set_var(m->variable, (string)id->misc->variables[m->other], m->scope);
	return ({""});
      }
      return rxml_error(tag, "Other variable doesn't exist.", id);
    }
    if (m->eval) {
      // Set an entity variable to the result of some evaluated RXML
      context->user_set_var(m->variable, parse_rxml(m->eval, id), m->scope);
      old_rxml_warning(id, "eval attribute in set tag","define variable");
      return ({""});
    }
  }
  return ({1});
}

array tag_pr(string tag, mapping m, RequestID id)
{
  old_rxml_warning(id,"pr tag","roxen tag");
  return ({1, "roxen", m});
}

array(string) tag_date(string q, mapping m, RequestID id)
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

  return ({tagtime(t, m, id, language)});
}

inline string do_replace(string s, mapping m, RequestID id)
{
  return replace(s, indices(m), values(m));
  old_rxml_warning(id, "replace (A=B) in in insert tag","the replace tag");
}

string|array tag_insert(string tag,mapping m,RequestID id)
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
    return m->quote=="none"?do_replace((string)id->variables[n], m-(["quote":""]), id):
      ({ html_encode_string(do_replace((string)id->variables[n], m-(["quote":""]), id)) });
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

  return ({1});
}

string|array container_apre(string tag, mapping m, string q, RequestID id)
{
  if(m->add || m->drop) return ({1});
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

string|array container_aconf(string tag, mapping m, string q, RequestID id)
{
  if(m->add || m->drop) return ({1});
  old_rxml_warning(id, "config items as atomic attributes in aconf tag","add and drop");

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

array container_autoformat(string tag, mapping m, string c, RequestID id)
{
  if(!m->pre) return ({1});
  old_rxml_warning(id, "pre attribute in autoformat tag","p attribute");
  m->p=1;
  m_delete(m, "pre");
  return ({1, tag, m, c});
}

array container_default(string tag, mapping m, string c, RequestID id)
{
  if(!m->multi_separator) return ({1});
  old_rxml_warning(id, "multiseparator attribute in default tag","separator attribute");
  m+=(["separator":m->multi_separator]);
  m_delete(m, "multi_separator");
  return ({1, tag, m, c});
}

array container_recursive_output(string tag, mapping m, string c, RequestID id)
{
  if(!m->multisep) return ({1});
  old_rxml_warning(id, "multisep attribute in recursive-output tag","separator attribute");
  m+=(["separator":m->multisep]);
  m_delete(m, "multisep");
  return ({1, tag, m, c});
}

string container_source(string tag, mapping m, string s, RequestID id)
{
  old_rxml_warning(id, "source tag","a template");
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return "<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
    +"</pre>"+sep+s;
}

array tag_countdown(string tag, mapping m, string c, RequestID id)
{
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
	      "dogyears","combined","when"}), string tmp)
      if(m[tmp]) {
	m->display=tmp;
	m_delete(m, tmp);
	old_rxml_warning(id, "countdown attribute "+tmp,"display="+tmp);
      }
  }

  return ({1, tag, m, c});
}

array container_tablify(string tag, mapping m, string q, RequestID id)
{
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
  return ({1, tag, m, q});
}

array tag_echo(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "echo tag","insert tag");
  return ({1,"!--#echo",m});
}

array container_gtext(string t, mapping|int m, string c, RequestID id) {
  return ({1, t, gtext_compat(m,id), c});
}

array tag_gtext_id(string t, int|mapping m, RequestID id) {
  return ({1, t, gtext_compat(m,id)});
}

mapping gtext_compat(mapping m, RequestID id) {
  foreach(glob("magic_*", indices(m)), string q) {
    m["magic-"+q[6..]]=m[q];
    m_delete(m, q);
    old_rxml_warning(id, "gtext attribute "+q,"magic-"+q[6..]);
  }
  for(int i=2; i<10; i++)
    if(m[(string)i])
    {
      m->scale = (string)(1.0 / ((float)i*0.6));
      m_delete(m,(string)i);
    }
  if(m->fg) {
    m->fgcolor=m->fg;
    m_delete(m, "fg");
    old_rxml_warning(id, "gtext attribute fg","fgcolor");
  }
  if(m->bg) {
    m->bgcolor=m->bg;
    m_delete(m, "bg");
    old_rxml_warning(id, "gtext attribute bg","bgcolor");
  }
  if(m->fuzz) {
    m["magic-glow"]=m->fuzz=="fuzz"?m->fgcolor+",1":m->fuzz;
    m_delete(m, "fuzz");
    old_rxml_warning(id, "gtext attribute fuzz","magic-glow");
  }
  if(m->magicbg) {
    m["magic-background"]=m->magicbg;
    m_delete(m, "magicbg");
    old_rxml_warning(id, "gtext attribute magicbg","magic-background");
  }
  if(m->turbulence) {
    m->bgturbulence=m->turbulence;
    m_delete(m, "turbulence");
    old_rxml_warning(id ,"gtext attribute turbulence","bgturbulence");
  }

  return m;
}

array tag_counter(string t, mapping m, RequestID id) {
  if(!m->fg && !m->bg) return ({1});
  if(m->fg) {
    m->fgcolor=m->fg;
    m_delete(m,"fg");
    old_rxml_warning(id ,"counter attribute fg","fgcolor");
  }
  if(m->bg) {
    m->bgcolor=m->bg;
    m_delete(m,"bg");
    old_rxml_warning(id ,"counter attribute bg","bgcolor");
  }
  return ({1, t, m});
}

array tag_list_tags(string t, mapping m, RequestID id) {
  old_rxml_warning(id ,"list-tags tag","help tag");
  return ({1, "help", m});
}

string|array(string) tag_clientname(string tag, mapping m, RequestID id)
{
  NOCACHE();
  string client="";
  if (sizeof(id->client)) {
    if(m->full) {
      old_rxml_warning(id ,"clientname tag","&client.Fullname; or &client.fullname;");
      client=id->client * " ";
    }
    else {
      old_rxml_warning(id ,"clientname tag","&client.name;");
      client=id->client[0];
    }
  }

  return m->quote=="none"?client:({ html_encode_string(client) });
}

array(string) tag_file(string tag, mapping m, RequestID id)
{
  string file;
  if(m->raw) {
    old_rxml_warning(id ,"file tag","&page.url;");
    file=id->raw_url;
  }
  else {
    old_rxml_warning(id ,"file tag","&page.virtfile;");
    file=id->not_query;
  }
  return m->quote=="none"?file:({ html_encode_string(file) });
}

string|array(string) tag_realfile(string tag, mapping m, RequestID id)
{
  old_rxml_warning(id ,"realfile tag","&page.realfile;");
  if(id->realfile)
    return ({ id->realfile });
  return rxml_error(tag, "Real file unknown", id);
}

string|array(string) tag_vfs(string tag, mapping m, RequestID id)
{
  old_rxml_warning(id ,"vfs tag","&page.virtroot;");
  if(id->virtfile)
    return ({ id->virtfile });
  return rxml_error(tag, "Virtual file unknown.", id);
}

array(string) tag_accept_language(string tag, mapping m, RequestID id)
{
  NOCACHE();

  if(!id->misc["accept-language"])
    return ({ "None" });

  if(m->full) {
    old_rxml_warning(id ,"accept-language tag","&client.accept_languages;");
    return ({ html_encode_string(id->misc["accept-language"]*",") });
  }
  else {
    old_rxml_warning(id ,"accept-language tag","&client.accept_language;");
    return ({ html_encode_string((id->misc["accept-language"][0]/";")[0]) });
  }
}

array(string) tag_version(string tag, mapping m, RequestID id) {
  old_rxml_warning(id, "version tag", "&roxen.version;");
  return ({ roxen->version() });
}

//array(string) tag_line(string tag, mapping m, RequestID id) {
//  return ({ (string)id->misc->line });
//}

class TagQuote {
  inherit RXML.Tag;
  constant name="quote";
  constant flags=0;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      rxml_fatal("<quote> does not work with the new parser.");
    }
  }
}


// --------------- Register tags, containers and if-callers ---------------

mapping query_tag_callers() {
  mapping active=(["list-tags":tag_list_tags,
		   "version":tag_version,
		   //		   "line":tag_line
  ]);
  if(enabled->countdown) active->countdown=tag_countdown;
  if(enabled->counter) active->counter=tag_counter;
  if(enabled->graphic_text) active["gtext-id"]=tag_gtext_id;
  if(enabled->rxmltags) active+=([
    "echo":tag_echo,
    "insert":tag_insert,
    "date":tag_date,
    "pr":tag_pr,
    "refferrer":tag_referrer,
    "referrer":tag_referrer,
    "referer":tag_referrer,
    "set":tag_set,
    "redirect":tag_redirect,
    "append":tag_append,
    "clientname":tag_clientname,
    "file":tag_file,
    "realfile":tag_realfile,
    "vfs":tag_vfs,
    "accept-language":tag_accept_language
  ]);
  return active;
}

mapping query_container_callers() {
  mapping active=([]);
  if(enabled->tablify) active->tablify=container_tablify;
  if(enabled->graphic_text) active+=([
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
  if(enabled->rxmltags) active+=([
    "source":container_source,
    "recursive-output":container_recursive_output,
    "default":container_default,
    "autoformat":container_autoformat,
    "aconf":container_aconf,
    "apre":container_apre,
    "preparse":container_preparse
  ]);
  return active;
}

class TagIfsuccessful {
  inherit RXML.Tag;
  constant plugin_name = "successful";
  int `() (string u, RequestID id) {
    return id->misc->defines[" _ok"];
  }
}

class TagIffailed {
  inherit RXML.Tag;
  constant plugin_name = "failed";
  int `() (string u, RequestID id) {
    return !id->misc->defines[" _ok"];
  }
}
