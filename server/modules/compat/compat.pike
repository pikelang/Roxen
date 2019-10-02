// Old RXML Compatibility Module Copyright © 2000 - 2009, Roxen IS.
//

inherit "module";
inherit "roxenlib";
#include <module.h>

#define _stat id->misc->defines[" _stat"]
#define _error id->misc->defines[" _error"]
//#define _extra_heads id->misc->defines[" _extra_heads"]
#define _rettext id->misc->defines[" _rettext"]
#define _ok id->misc->defines[" _ok"]

//<locale-token project="mod_compat">LOCALE</locale-token>
//<locale-token project="mod_compat">SLOCALE</locale-token>
#define SLOCALE(X,Y)	_STR_LOCALE("mod_compat",X,Y)
#define LOCALE(X,Y)	_DEF_LOCALE("mod_compat",X,Y)
// end locale stuff

// -------------- Module Registration and common stuff -------------------

constant thread_safe=1;
constant language = roxen->language;

constant module_type   = MODULE_PARSER | MODULE_PROVIDER;
LocaleString module_name   = LOCALE(3,"Tags: Old RXML Compatibility Module");

#if ROXEN_COMPAT > 1.3
LocaleString module_doc    =
  LOCALE(4,"Adds support for old (deprecated) RXML tags and attributes.") + " " +
  sprintf( LOCALE(1, "In order to function properly the ROXEN_COMPAT define must be "
		  "set to 1.3 or lower. It is currently set to %1.1f."), ROXEN_COMPAT);
#else // ROXEN_COMPAT > 1.3
LocaleString module_doc    =
  LOCALE(4,"Adds support for old (deprecated) RXML tags and attributes.");

// Cached version of the virtual servers compatibility level.
string compat_level;

void create()
{
  defvar("logold", 0,
	 LOCALE(5,"Log all old RXML calls in the event log."),
         TYPE_FLAG,
         LOCALE(6,"If set, all calls through the backward compatibility code "
		"will be logged in the event log, enabeling you to upgrade "
		"those RXML tags."));
  defvar("enableall", 1,
	 LOCALE(7,"Enable all tag compatibility"),
	 TYPE_FLAG,
	 LOCALE(8,"If not set support will only be enabled for tag modules "
		"that you have added to your server. The drawback is that "
		"you have to reload this module when you add a new module "
		"that this has support for"));

  defvar("disableall", 0,
	 LOCALE(9,"Disable all tag compatibility"),
	 TYPE_FLAG,
	 LOCALE(10,"If set, all tag compatiblity will be disabled. The "
		"parser will still run in compatibility mode though, so "
		"you need not write proper XML. The drawback is some "
		"decreased performance and disabled error checking. This "
		"option overrides the 'Enable all tag compatibility' "
		"setting."));

  compat_level = my_configuration() && my_configuration()->query("compat_level");
}

constant relevant=(<"rxmltags","graphic_text","tablify","countdown","counter","ssi","obox">);
multiset enabled;
void start (int when, Configuration conf)
{
  set("_priority",7);
  if (!when) conf->old_rxml_compat++;
  enabled=(<>);
  if(query("disableall")) return;
  if(query("enableall")) {
    enabled=relevant;
    return;
  }
  foreach(indices(conf->enabled_modules), string name)
    enabled+=(<name[0..sizeof(name)-3]>);
  enabled-=(enabled-relevant);
}

void stop()
{
  my_configuration()->old_rxml_compat--;
}

string query_provides() {
  return "oldRXMLwarning";
}

int warnings=0;
void old_rxml_warning(RequestID id, string problem, string solution)
{
  warnings++;
  if(query("logold"))
    report_warning(
      sprintf(LOCALE(11,"Old RXML in %s: contains %s. Use %s instead."),
	      id->not_query,problem,solution)+"\n");
}

string status() {
  string ret="";
  ret+="<b>"+LOCALE(12,"RXML Warnings:")+"</b> "+warnings+"<br />\n"
    "<b>"+LOCALE(13,"Support enabled for:")+"</b> "+
    String.implode_nicely(indices(enabled))+"<br />\n";
  if(compat_level >= "2.2")
    ret += "<font color='red'>" + LOCALE(2, "Warning!") + "</font> " +
      sprintf(LOCALE(39, "This sites compatibility level is set to %s, but it "
		     "must be set to a value below 2.2. Change the value in the "
		     "site global settings and restart the server."), compat_level);

return ret;
}


// --------------------------- Tags and containers ------------------------------

string container_preparse( string tag_name, mapping args, string contents,
		     RequestID id )
// Changes the parsing order by first parsing it's contents and then
// morphing itself into another tag that gets parsed.
{
  old_rxml_warning(id,LOCALE(14,"preparse tag"),LOCALE(15,"preparse attribute"));
  return make_container( args->tag, args - ([ "tag" : 1 ]),
			 parse_rxml( contents, id ) );
}

array|string tag_append(string tag, mapping m, RequestID id)
{
  if(m->variable) {
    if(m->define) {
      // Set variable to the value of a define
      id->variables[ m->variable ] += id->misc->defines[ m->define ]||"";
      old_rxml_warning(id, LOCALE(16,"define attribute in append tag"),
		       LOCALE(17,"only variables"));
      return ({""});
    }
    if (m->other) {
      old_rxml_warning(id, LOCALE(18,"other attribute in append tag"),
		       LOCALE(19,"only regular variables"));
      RXML.Context context=RXML.get_context();
      mixed value=context->user_get_var(m->variable, m->scope);
      // Append the value of a misc variable to an enityt variable.
      if (!id->misc->variables || !id->misc->variables[ m->other ])
	RXML.run_error("Other variable doesn't exist.\n");
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
    RXML.parse_error("Requires attribute \"to\".\n");

  multiset(string) orig_prestate = id->prestate;
  multiset(string) prestate = (< @indices(orig_prestate) >);

  foreach(indices(m), string s)
    if(m[s]==s && sizeof(s))
      switch (s[0]) {
	case '+': prestate[s[1..]] = 1;
      	          old_rxml_warning(id, LOCALE(51,"+prestate attribute"),
				   LOCALE(52,"add=prestate"));
                  break;
	case '-': prestate[s[1..]] = 0;
    	          old_rxml_warning(id, LOCALE(53,"-prestate attribute"),
				   LOCALE(54,"drop=prestate"));
                  break;
      }

  id->prestate = prestate;
  mapping r = http_redirect(m->to, id);
  id->prestate = orig_prestate;

  if (r->error)
    RXML_CONTEXT->set_misc (" _error", r->error);
  if (r->extra_heads) {
    foreach(indices(r->extra_heads), string tmp)
      id->add_response_header(tmp, r->extra_heads[tmp]);
  }
  if (m->text)
    RXML_CONTEXT->set_misc (" _rettext", m->text);

  return ({""});
}

array(string) tag_referrer(string tag, mapping m, RequestID id)
{
  NOCACHE();
  old_rxml_warning(id, tag+" "+LOCALE(20,"tag"),
		   LOCALE(21,"&client.referrer; entity"));
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
      old_rxml_warning(id, LOCALE(22,"define attribute in set tag"),
		       LOCALE(17,"only variables"));
      return ({""});
    }
    if (m->other) {
      old_rxml_warning(id, LOCALE(23,"other attribute in set tag"),
		       LOCALE(19,"only regular variables"));
      if (id->misc->variables && id->misc->variables[ m->other ]) {
	// Set an entity variable to the value of a misc variable
	context->user_set_var(m->variable, (string)id->misc->variables[m->other], m->scope);
	return ({""});
      }
      RXML.run_error("Other variable doesn't exist.\n");
    }
    if (m->eval) {
      // Set an entity variable to the result of some evaluated RXML
      context->user_set_var(m->variable, parse_rxml(m->eval, id), m->scope);
      old_rxml_warning(id, LOCALE(24,"eval attribute in set tag"),
		       LOCALE(25,"define variable"));
      return ({""});
    }
  }
  return ({1});
}

array tag_pr(string tag, mapping m, RequestID id)
{
  old_rxml_warning(id,LOCALE(26,"pr tag"),LOCALE(27,"roxen tag"));
  if(m->color && m->color!="white" && m->color!="black")
    m->color="black";
  return ({1, "roxen", m});
}

array(string) tag_date(string q, mapping m, RequestID id)
{
  // unix_time is not part of RXML 2.0
  int t=(int)m["unix-time"] || (int)m->unix_time || time(1);
  if(m->unix_time)
    old_rxml_warning(id, LOCALE(28,"unix_time attribute in date tag"),
		     LOCALE(29,"unix-time"));
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
  old_rxml_warning(id, LOCALE(30,"replace (A=B) in in insert tag"),
		   LOCALE(31,"the replace tag"));
}

protected string compat_broken_http_encode_string(string f)
{
  return replace(f, ({ "\000", " ", "\t", "\n", "\r", "%", "'", "\"" }),
		 ({"%00", "%20", "%09", "%0A", "%0D", "%25", "%27", "%22"}));
}

string|array tag_insert(string tag,mapping m,RequestID id)
{
  string n;

  if(m->index || m->scope || m->scopes || m->realfile) return ({1});

  if(n=m->define || m->name) {
    old_rxml_warning(id, LOCALE(32,"define or name attribute in insert tag"),
		     LOCALE(17,"only variables"));
    m_delete(m, "define");
    m_delete(m, "name");
    if(id->misc->defines[n])
      return ({ do_replace(id->misc->defines[n], m, id) });
    RXML.run_error("No such define ("+n+").\n");
  }

  if(n = m->variable)
  {
    string var;
    if(zero_type(var=RXML.get_context()->user_get_var(n, m->scope, RXML.t_text)))
      RXML.run_error("No such variable ("+n+").\n");
    m_delete(m, "variable");
    return m->quote=="none"?do_replace(var, m-(["quote":""]), id):
      ({ html_encode_string(do_replace(var, m-(["quote":""]), id)) });
  }

  if(n = m->other) {
    old_rxml_warning(id, LOCALE(33,"other attribute in insert tag"),
		     LOCALE(19,"only regular variables"));
    if(stringp(id->misc[n]) || intp(id->misc[n]))
      return m->quote=="none"?(string)id->misc[n]:({ html_encode_string((string)id->misc[n]) });
    RXML.run_error("No such other variable ("+n+").\n");
  }

  if(n = m->cookies)
  {
    NOCACHE();
    old_rxml_warning(id, LOCALE(34,"cookies attribute in insert tag"),
		     "<insert scope=cookie>");
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
    old_rxml_warning(id, LOCALE(35,"cookie attribute in insert tag"),
		     LOCALE(36,"cookie entities"));
    m_delete(m, "cookie");
    if(id->cookies[n]) {
      string cookie=do_replace(id->cookies[n], m, id);
      return m->quote=="none"?cookie:({ html_encode_string(cookie) });
    }
    RXML.run_error("No such cookie ("+n+").\n");
  }

  if(m->file)
  {
    if(m->nocache) {
      int nocache=id->pragma["no-cache"];
      id->pragma["no-cache"] = 1;
      n=id->conf->try_get_file(fix_relative(m->file,id),id);
      if(!n) RXML.run_error("No such file ("+m->file+").\n");
      id->pragma["no-cache"] = nocache;
      m_delete(m, "nocache");
      m_delete(m, "file");
      n=do_replace(n, m, id);
      // Should probably be html_encode_string below, but, well..
      // compat is compat. :P /mast
      return m->quote!="html"?n:({ compat_broken_http_encode_string(n) });
    }
    n=id->conf->try_get_file(fix_relative(m->file,id),id);
    if(!n) RXML.run_error("No such file ("+m->file+").\n");
    n=do_replace(n, m-(["file":""]), id);
    // Should probably be html_encode_string below, but, well.. compat
    // is compat. :P /mast
    return m->quote!="html"?n:({ compat_broken_http_encode_string(n) });
  }

  if(m->var) {
    object|array tagfunc=RXML.get_context()->tag_set->get_tag("!--#echo");
    if(!tagfunc) RXML.run_error("No SSI module added.\n");
    return ({ 1, "!--#echo", m});
  }

  return ({1});
}

string|array container_apre(string tag, mapping m, string q, RequestID id)
{
  if(m->add || m->drop) return ({1});
  old_rxml_warning(id, LOCALE(37,"prestates as atomic attributs in apre tag"),
		   LOCALE(38,"add and drop"));

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

  // Not part of RXML 2.0
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
  old_rxml_warning(id,
		   LOCALE(55,"config items as atomic attributes in aconf tag"),
		   LOCALE(38,"add and drop"));

  string href;
  mapping cookies = ([]);

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

  // Not part of RXML 2.0
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
  old_rxml_warning(id, LOCALE(56,"pre attribute in <autoformat> tag"),
		   LOCALE(57,"p attribute"));
  m->p=1;
  m_delete(m, "pre");
  return ({1, tag, m, c});
}

array container_default(string tag, mapping m, string c, RequestID id)
{
  if(!m->multi_separator) return ({1});
  old_rxml_warning(id,
		   LOCALE(58,"multiseparator attribute in <default> tag"),
		   LOCALE(59,"separator attribute"));
  m+=(["separator":m->multi_separator]);
  m_delete(m, "multi_separator");
  return ({1, tag, m, c});
}

array container_recursive_output(string tag, mapping m, string c, RequestID id)
{
  if(!m->multisep) return ({1});
  old_rxml_warning(id,
		   LOCALE(60,"multisep attribute in <recursive-output> tag"),
		   LOCALE(59,"separator attribute"));
  m+=(["separator":m->multisep]);
  m_delete(m, "multisep");
  return ({1, tag, m, c});
}

string container_source(string tag, mapping m, string s, RequestID id)
{
  old_rxml_warning(id, "source "+LOCALE(20,"tag"),LOCALE(61,"a template"));
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return "<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
    +"</pre>"+sep+s;
}

array tag_countdown(string tag, mapping m, RequestID id)
{
  foreach( ({
    ({"min","minute"}),
    ({"sec","second"}),
    ({"age","since"}) }), array tmp)
    { if(m[tmp[0]]) {
      m[tmp[1]]=m[tmp[0]];
      m_delete(m, tmp[0]);
      old_rxml_warning(id, LOCALE(62,"<countdown> attribute")+" "+tmp[0],
		       tmp[1]);
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
      old_rxml_warning(id, LOCALE(62,"<countdown> attribute")+" "+tmp,
		       "event="+tmp);
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
	old_rxml_warning(id, LOCALE(62,"<countdown> attribute")+" "+tmp,
			 "display="+tmp);
      }
  }

  return ({1, tag, m});
}

array container_tablify(string tag, mapping m, string q, RequestID id)
{
  if(m->fgcolor0) {
    m->oddbgcolor=m->fgcolor0;
    m_delete(m, "fgcolor0");
    old_rxml_warning(id, LOCALE(63,"<tablify> attribute")+
		     " fgcolor0","oddbgcolor");
  }
  if(m->fgcolor1) {
    m->evenbgcolor=m->fgcolor1;
    m_delete(m, "fgcolor1");
    old_rxml_warning(id, LOCALE(63,"<tablify> attribute")+
		     " fgcolor1","evenbgcolor");
  }
  if(m->fgcolor) {
    m->textcolor=m->fgcolor;
    m_delete(m, "fgcolor");
    old_rxml_warning(id, LOCALE(63,"<tablify> attribute")+" fgcolor",
		     "textcolor");
  }
  if(m->rowalign) {
    m->cellalign=m->rowalign;
    m_delete(m, "rowalign");
    old_rxml_warning(id, LOCALE(63,"<tablify> attribute")+" rowalign",
		     "cellalign");
  }
  // When people have forgotten what bgcolor meant we can reuse it as evenbgcolor=oddbgcolor=m->bgcolor
  if(m->bgcolor) {
    m->bordercolor=m->bgcolor;
    m_delete(m, "bgcolor");
    old_rxml_warning(id, LOCALE(63,"<tablify> attribute")+" bgcolor",
		     "bordercolor");
  }
  if (m->preprocess || m->parse) {
    q = parse_rxml(q, id);
    old_rxml_warning(id, LOCALE(63,"<tablify> attribute")+
		     (m->parse?" parse":" preprocess"),"preparse");
    m_delete(m, "parse");
    m_delete(m, "preprocess");
  }
  return ({1, tag, m, q});
}

array tag_echo(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "<echo> "+LOCALE(20,"tag"),
		   LOCALE(64,"<insert> tag or entities"));
  return ({1,"!--#echo",m});
}

array container_gtext(string t, mapping|int m, string c, RequestID id) {
  if(t[0..1]=="gh") {
    int size;
    sscanf(t, "gh%d", size);
    t="gtext";
    if(size > 1) m->scale = (string)(1.0 / ((float)size*0.6));
    m-=([ "1":1, "2":1, "3":1, "4":1, "5":1, "6":1, "7":1, "8":1, "9":1 ]);
  }
  return ({1, t, gtext_compat(m,id), c});
}

array tag_gtext_id(string t, int|mapping m, RequestID id) {
  return ({1, t, gtext_compat(m,id)});
}

mapping gtext_compat(mapping m, RequestID id) {
  foreach(glob("magic_*", indices(m)), string q) {
    m["magic-"+q[6..]]=m[q];
    m_delete(m, q);
    old_rxml_warning(id, LOCALE(65,"<gtext> attribute")+" "+q,"magic-"+q[6..]);
  }
  for(int i=2; i<10; i++)
    if(m[(string)i])
    {
      m->scale = (string)(1.0 / ((float)i*0.6));
      old_rxml_warning(id, LOCALE(65, "<gtext> attribute")+" "+i,"scale='" + m->scale + "'");
      m_delete(m,(string)i);
    }
  if(m->fg) {
    m->fgcolor=m->fg;
    m_delete(m, "fg");
    old_rxml_warning(id, LOCALE(65,"<gtext> attribute")+" fg","fgcolor");
  }
  if(m->bg) {
    m->bgcolor=m->bg;
    m_delete(m, "bg");
    old_rxml_warning(id, LOCALE(65,"<gtext> attribute")+" bg","bgcolor");
  }
  if(m->fuzz) {
    m["magic-glow"]=m->fuzz=="fuzz"?m->fgcolor+",1":m->fuzz;
    m_delete(m, "fuzz");
    old_rxml_warning(id, LOCALE(65,"<gtext> attribute")+" fuzz","magic-glow");
  }
  if(m->magicbg) {
    m["magic-background"]=m->magicbg;
    m_delete(m, "magicbg");
    old_rxml_warning(id, LOCALE(65,"<gtext> attribute")+" magicbg",
		     "magic-background");
  }
  if(m->turbulence) {
    m->bgturbulence=m->turbulence;
    m_delete(m, "turbulence");
    old_rxml_warning(id, LOCALE(65,"<gtext> attribute")+" turbulence",
		     "bgturbulence");
  }
  if(m->font_size) {
    m["fontsize"]=m->font_size;
    m_delete(m, "font_size");
    old_rxml_warning(id, LOCALE(65,"<gtext> attribute")+"  font_size",
		     "fontsize");
  }
  if(m->magic && !m["magic-fgcolor"])
    m->fgcolor=id->misc->defines->fgcolor;

  return m;
}

array tag_counter(string t, mapping m, RequestID id) {
  if(!m->fg && !m->bg) return ({1});
  if(m->fg) {
    m->fgcolor=m->fg;
    m_delete(m,"fg");
    old_rxml_warning(id ,LOCALE(66,"<counter> attribute fg"),"fgcolor");
  }
  if(m->bg) {
    m->bgcolor=m->bg;
    m_delete(m,"bg");
    old_rxml_warning(id ,LOCALE(67,"<counter> attribute bg"),"bgcolor");
  }
  return ({1, t, m});
}

array tag_list_tags(string t, mapping m, RequestID id) {
  old_rxml_warning(id ,"list-tags "+LOCALE(20,"tag"),"help "+LOCALE(20,"tag"));
  return ({1, "help", m});
}

string|array(string) tag_clientname(string tag, mapping m, RequestID id)
{
  NOCACHE();
  string client="";
  if (sizeof(id->client)) {
    if(m->full) {
      old_rxml_warning(id ,"clientname "+LOCALE(20,"tag"),
		       "&client.Fullname; "+LOCALE(68,"or")+
		       " &client.fullname;");
      client=id->client * " ";
    }
    else {
      old_rxml_warning(id ,"clientname "+LOCALE(20,"tag"),"&client.name;");
      client=id->client[0];
    }
  }

  return m->quote=="none"?client:({ html_encode_string(client) });
}

array(string) tag_file(string tag, mapping m, RequestID id)
{
  string file;
  if(m->raw) {
    old_rxml_warning(id ,"file "+LOCALE(20,"tag"),"&page.url;");
    file=id->raw_url;
  }
  else {
    old_rxml_warning(id ,"file "+LOCALE(20,"tag"),"&page.virtfile;");
    file=id->not_query;
  }
  return m->quote=="none"?file:({ html_encode_string(file) });
}

string|array(string) tag_realfile(string tag, mapping m, RequestID id)
{
  old_rxml_warning(id ,"realfile "+LOCALE(20,"tag"),"&page.realfile;");
  if(id->realfile)
    return ({ id->realfile });
  RXML.run_error("Real file unknown.\n");
}

string|array(string) tag_vfs(string tag, mapping m, RequestID id)
{
  old_rxml_warning(id ,"vfs "+LOCALE(20,"tag"),"&page.virtroot;");
  if(id->virtfile)
    return ({ id->virtfile });
  RXML.run_error("Virtual file unknown.\n");
}

array(string) tag_accept_language(string tag, mapping m, RequestID id)
{
  NOCACHE();

  if(!id->misc["accept-language"])
    return ({ "None" });

  if(m->full) {
    old_rxml_warning(id ,"accept-language "+LOCALE(20,"tag"),
		     "&client.accept_languages;");
    return ({ html_encode_string(id->misc["accept-language"]*",") });
  }
  else {
    old_rxml_warning(id ,"accept-language "+LOCALE(20,"tag"),
		     "&client.accept_language;");
    return ({ html_encode_string((id->misc["accept-language"][0]/";")[0]) });
  }
}

array(string) tag_version(string tag, mapping m, RequestID id) {
  old_rxml_warning(id, "version "+LOCALE(20,"tag"), "&roxen.version;");
  return ({ roxen->version() });
}

array(string) tag_line(string tag, mapping m, RequestID id) {
  if(query("logold"))
    report_warning("Old RXML in "+id->not_query+
    ": contains deprecated tag <line>.\n");
  return ({ "0" });
}

class TagQuote {
  inherit RXML.Tag;
  constant name="quote";
  constant flags=0;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      parse_error("<quote> does not work with the new parser.\n");
    }
  }
}

array(string) container_cset(string tag, mapping m, string c, RequestID id) {
  if(!c) c="";
  if( m->quote != "none" )
    c = html_decode_string( c );
  if( !m->variable ) RXML.parse_error("Variable not specified.\n");

  RXML.get_context()->user_set_var(m->variable, c, m->scope);
  return ({ "" });
}

array container_elif(string t, mapping m, string c, RequestID id) {
  old_rxml_warning(id, "elif "+LOCALE(20,"tag"), "elseif "+LOCALE(20,"tag"));
  return ({ 1, "elseif", m, c });
}

array tag_set_max_cache(string t, mapping m, RequestID id) {
  if(m->time) {
    old_rxml_warning(id, LOCALE(43,"the <set-max-cache> attribute time"),
		     LOCALE(44,"the time notation in <date>"));
    id->misc->cacheable = (int)m->time;
    return ({""});
  }
  return ({1});
}

array(string) container_formoutput(string tag_name, mapping args,
                                   string contents, RequestID id)
{
  old_rxml_warning(id, "formoutput "+LOCALE(20,"tag"), LOCALE(46,"entities"));
  return ({ do_output_tag( args, ({ id->variables }), contents, id ) });
}

array tag_set_cookie(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "set_cookie "+LOCALE(20,"tag"), "set-cookie "+LOCALE(20,"tag"));
  return ({ 1, "set-cookie", m });
}

array tag_remove_cookie(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "remove_cookie "+LOCALE(20,"tag"),
		   "remove-cookie "+LOCALE(20,"tag"));
  return ({ 1, "remove-cookie", m });
}

array container_obox(string t, mapping m, string c, RequestID id) {
  m->title = parse_rxml(m->title, id);
  return ({ 1, "obox", m, c });
}

array|string container_if(string t, mapping m, string c, RequestID id) {
  if(id->misc->compat_if) return ({ 1 });
  int only_once;
  string rxml = Parser.HTML()
    ->add_tag("otherwise", lambda(){
			     only_once++;
			     return only_once==1?"</if><if false='1'>":0; })
    ->finish(c)->read();
  if(only_once)
    old_rxml_warning(id, "otherwise "+LOCALE(20,"tag"),
		     "else "+LOCALE(20,"tag"));
  else
    return ({ 1 });

  id->misc->compat_if = 1;
  string tag = "<if";
  foreach(indices(m), string attr)
    if(!has_value(m[attr], "\""))
      tag += " " + attr + "=\"" + m[attr] + "\"";
    else if(!has_value(m[attr], "'"))
      tag += " " + attr + "='" + m[attr] + "'";
    else
      tag += " " + attr + "=\"" + replace(m[attr], "\"", "&quot;") + "\"";
  rxml = parse_rxml( tag+">"+rxml+"</if>", id );
  m_delete(id->misc, "compat_if");
  return rxml;
}


// --------------- Register tags, containers and if-callers ---------------

mapping query_tag_callers() {
  if(!enabled) start(1, my_configuration());
  mapping active=(["list-tags":tag_list_tags,
		   "version":tag_version,
		   "line":tag_line,
  ]);
  if(enabled->countdown) active->countdown=tag_countdown;
  if(enabled->counter) active->counter=tag_counter;
  if(enabled->graphic_text) active["gtext-id"]=tag_gtext_id;
  if(enabled->ssi) active->echo=tag_echo;
  if(enabled->rxmltags) active+=([
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
    "set-max-cache":tag_set_max_cache,
    "configurl":"",
    "accept-language":tag_accept_language,
    "set_cookie":tag_set_cookie,
    "remove_cookie":tag_remove_cookie,
  ]);
  return active;
}

mapping query_container_callers() {
  mapping active=([
    "if":container_if,
  ]);
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
    "formoutput":container_formoutput,
    "source":container_source,
    "recursive-output":container_recursive_output,
    "default":container_default,
    "autoformat":container_autoformat,
    "aconf":container_aconf,
    "apre":container_apre,
    "cset":container_cset,
    "elif":container_elif,
    "preparse":container_preparse
  ]);
  if(enabled->obox) active+=([
    "obox":container_obox,
  ]);
  return active;
}

class TagIfsuccessful {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "successful";
  int eval(string u, RequestID id) {
    return id->misc->defines[" _ok"];
  }
}

class TagIffailed {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "failed";
  int eval(string u, RequestID id) {
    return !id->misc->defines[" _ok"];
  }
}

#endif // !ROXEN_COMPAT > 1.3
