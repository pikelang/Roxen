// This is a roxen module. (c) Lysator ACS, 1996.

string cvs_version = "$Id: lysator.pike,v 1.3 1996/12/01 19:18:49 per Exp $";
// Lysator specific parsing, used at www.lysator.liu.se

#include <config.h>
#include <module.h>

inherit "module";

int icon_size, icon_border;

void create()
{
  defvar("isize", 40, "Icon size", TYPE_INT, "The size of an icon");

  defvar("iborder", 0, "Icon has borders", TYPE_FLAG, 
	 "Should icons have borders?");

  defvar("idir", "/icons/", "Icon pre-url", TYPE_STRING, 
	 "Prepend this to a icon-url.");

  defvar("BlinkEnabled", 0, "Blinking Enabled", 
	 TYPE_FLAG, "If set, the server will not filter "+
	 "<blink>&lt;blink&gt</blink> tags.");
}

string tag_icon(string tag, mapping m, mapping got)
{
  string f;
  if(!got["supports"]["images"]) return "";
  if(!(f=m["src"] || m["file"] || m["url"])) return "";

  return ("<img src=\"" + query("idir") + f + ".gif\" alt=\"\" width=" 
	  + icon_size + " border=" + icon_border + " height=" + icon_size 
	  + (m["align"]?" align=" + m["align"]:"") + ">");
}

string tag_picture(string tag, mapping m, mapping got)
{
  string f;
  if(!got["supports"]["images"])  return "";
  if(!(f=m["src"] || m["file"] || m["url"]))    return "";

  return ("<img src=/pictures/"+f+".gif"  
	  + (m["align"]?" align="+m["align"]:"")
	  + (m["width"]?" width="+m["width"]:"")
	  + (m["height"]?" height="+m["height"]:"")
	  + ">");
}

string tag_icons(string tag,mapping m, string s,mapping got,object file)
{
  if(got["supports"]["images"]) return s; return "";
}

string tag_spider(string ta, mapping m, string s) { return s; }

string tag_noblink(string t, mapping m, string s)
{
  if(!QUERY(BlinkEnabled)) return "<b --link-->"+s+"</b --link-->";
  return 0;
}


/* API */

array register_module()
{
  return ({ MODULE_PARSER,
	    "Lysator specific parsing", 
	    "This one adds a few tags, namely icon, icons, picture, blink, "
	      "and lysator.",
	    ({}),
	    1 });
}

int lys_in_table, lys_num_cols, lys_current_col;

string lys_item(string t, mapping m, string s, object id, object file)
{
  string res="";
  int tables;
  
  tables = id->supports->tables&&!id->prestate->notables;

  if(!lys_in_table)
  {
    lys_in_table=1;
    if(tables)
      res += ("<table border=0 cellpadding=3 cellspacing=0 width=100%>\n"
	      "<tr valign=top>");
    else
      res += "<dl>\n";
  }
  if(++lys_current_col >= lys_num_cols)
  {
    if(tables)
      res += "\n</tr>\n<tr valign=top>\n";
    lys_current_col = 0;
  }

  if(tables)  res += "<td>";  else res += "<dt>";
  
  if(!id->prestate->noicons)
  {
    if(m->linkto)
      res += "<a href=\""+m->linkto+"\">";
    if(m->icon)
      if(tables)
	res += "<icon src=\""+m->icon+"\">";
      else
	res += "<icon align=left hspace=8 src=\"" + m->icon + "\">";
      
    if(m->linkto)
      res += "</a>";
  }
  
  if(tables)
    res += "</td>\n<td>";
  else
    res+="<dd>";

  if(m->linkto)
    res += "<a href=\""+m->linkto+"\">";

  if(m->title)
    res += "<b>"+m->title+"</b>";
  
  if(m->linkto)
    res += "</a>";
  res += "<br>";
  res += s;
  // För /local/ sidan
  if(m->uid)
    res += " <a href=/~"+m->uid+"><font size=\"-1\">/"+m->uid+"</font></a>";
  if(tables)
    res+="</td>\n";
  else
    res+="<br clear>";
  return res;
}

string lys_endtable(string t, mapping m, object id)
{
  if(lys_in_table)
  {
    lys_in_table = 0;
    lys_current_col = -1;
    if(id->supports->tables&&!id->prestate->notables)
      return "</table>";
    else
      return "</dl>";
  }
  return "";
}

string lys_header(string t, mapping m, string s, object id)
{
// Sub-header.
  string res="";
  int level = ((int)m->level)||2;

  res += lys_endtable(t,m,id);
  if(m->hr)
    res += "<hr noshade>";
// Simulate H* with a font. Not exactly nice
  if(id->supports->font&&!id->prestate->nofont) 
  {
    res += ("<center><font size=+"+(3-(level-1)/2)+">"+(level%2?"<b>":"")+
	    "<i>"+s+"</i></font></center>");
  } else {
    res += "<h"+level+" align=center>"+s+"</h"+level+">";
  }
  if(m->hr)
    res += "<hr noshade>";
  return res;
}

object regexp = Regexp();
inline array regexp_match(string match, string in)
{
  regexp->create("^"+match+"$");
  return regexp->split(in);
}

#define MAINTAINERS "/usr/www/html/maintainers"

string|array maintainerlist;

inline array maintainer(string file)
{
  string to_match;
  string match, who;
  array res;

  if(!maintainerlist)
    catch(maintainerlist = read_bytes(MAINTAINERS));
  if(!maintainerlist)
  {
    report_error("Lysmodul: Failed to read the maintainerlist\n");
    return 0;
  }
  if(stringp(maintainerlist))
    maintainerlist = (maintainerlist/"\t"-({""}))*"\t";
  /* Handle escaped newlines */
  foreach(replace(maintainerlist, "\\\n", " ")/"\n", to_match)
    if(strlen(to_match) && to_match[0] != '#'
       && (sscanf(to_match, "%s\t%s", match, who) == 2)
       && (res=regexp_match(match, file)))
      /* Generate an array like ({ "$1", "$2", ... }) */
      return sizeof(res)?
      replace(who, map_array(res, lambda(string s, mapping m) { 
	return "$"+(++m->num);
      }, ([])), map_array(res, lambda(mixed s){return(string)s;})) / "\t" :
    who/"\t";
}

inline int userfilep(object id)
{
  return id->misc->is_user;
}

string lys_fot(string t, mapping m, object id)
{
  string res="";
  array tmp;
  string uid;

  lys_endtable(t,m,id);
  
  if(userfilep(id))
    sscanf(id->not_query, "/~%[^/]", uid);
  else
  {
    if(tmp = maintainer(id->not_query))
      uid = tmp[1];
  }
  if(!uid)
    uid = "www";
  if(m->sv)
    res +=
      "<!--<hr noshade>"
      "Den här sidan har betittats <accessed lang=se type=string> gånger,"
      " och den senaste ändringen gjordes <modified lang=se> av <modified by>."
      "\n--><hr noshade>"
      "Feedback och kommentarer till <user name="+uid+">\n";
  else
    res += "<hr noshade>Feedback and Comments to: <user name="+uid+">\n"
      "<!--"
      " This page has been accessed <accessed>"
      " times since <accessed since>, and it was last"
      " modified <modified> by <modified by nolink realname>."
      "-->";
    
  return res;
}

string lystitle(string t, object id)
{
  string res="";
  res += "<b><i>";
  if(id->supports->font && !id->prestate->nofont)
    res += "<font size=6><center>";
  else
    res += "<h1 align=center>";
  res += t;
  
  if(id->supports->font && !id->prestate->nofont)
    res += "</center></font>";
  else
    res += "</h1>";
  
  return res + "</b></i>";
}

string tag_lysator(string t, mapping m, string s, object id, object file)
{
  // Handle title etc.
  string pre=""; 
  lys_num_cols = (int)id->variables->cols || (int)m->cols || 2;
  lys_current_col = -1;
  lys_in_table = 0;

  if(m->pretxt) 
    pre += "<center>"+m->pretxt+"</center>";
  
  if(m->title) 
    pre += lystitle(m->title, id);


  if(m->txt)
    pre += "<center><i>"+m->txt+"</i></center>";

  pre += "<br clear><hr noshade>";

  return pre + parse_html(s, 
			  ([
			    "endtable":lys_endtable,
			    "fot":lys_fot,
			    ]),
			  ([
			    "item":lys_item,
			    "comment":"<!-- Comment :-) -->",
			    "h":lys_header,
			    ]), id, file);
}


mapping query_container_callers()
{
  return 
    ([
      "icons":tag_icons,
      "spider":tag_spider,
      "blink":tag_noblink,
      "lysator":tag_lysator,
      ]);
}

mapping query_tag_callers()
{
  return 
    ([
      "icon":tag_icon,
      "picture":tag_picture,
      "spiderp":lambda(string f, mapping m, mapping g){
	if(g["supports"]["imagealign"]) return "<br>";
	return "<p>";
      },
      "sdd":lambda(string f, mapping m, mapping g){
	if(g["supports"]["imagealign"]) return "<br>";
	return "<dd>";
      },
      "sdt":lambda(string f, mapping m, mapping g){
	if(g["supports"]["imagealign"]) return "";
	return "<dt>";
      },
      "sdl":lambda(string f, mapping m, mapping g){
	if(g["supports"]["imagealign"]) return "";
	return "<dl>";
      },
      ]);
}

void start() 
{ 
  icon_size=query("isize"); 
  icon_border=query("iborder"); 
}

int may_disable()  { return 0; }


