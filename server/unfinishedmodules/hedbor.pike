// Hedbor module. Quite 'hedbor.org' specific parsing.

string cvs_version = "$Id: hedbor.pike,v 1.2 1996/12/01 19:18:52 per Exp $";
inherit "module";
#include <module.h>

#define INLINE static inline nomask private

INLINE string stort(string from, object id)
{ 
  if(id->supports->font && !id->prestate->nofont)
    return "<tt><smallcaps size=4><b>"+from+"</b></smallcaps></tt>";
  return "<h1>"+from+"</h1>";
}

INLINE string head(object id)
{
  if(id->config->dark || id->prestate->dark)
    return ("<body background=bg_dark.jpg text=#ffffff link=#00ff00 bgcolor=#001155 "
	    "      vlink=#ffaaff alink=#0000ff>");
  else
    return ("<body background=bg.jpg text=#000000 link=#006600 "
	    "bgcolor=#ffeeaa vlink=#005500 alink=#ffff00>");
}

string tag_rubrik(string s, mapping m, string contents, object id, mapping defines, object fd)
{
  if(id->supports->tables && !id->prestate->notables)
    return ("<title>"+contents+"</title>\n"+head(id)+"<table width=100%><tr><td width="+QUERY(lc)+">"
	    "<td width="+QUERY(pc)+"></td><td width=100%><center>"
	    +stort(contents,id)+"</center></table><hr noshade size=1>\n");
  else
    return ("<title>"+contents+"</title>\n""<h1>"+contents+"</h1>");
}

string tag_email(string s, mapping m, string contents, object id, mapping defines, object fd)
{
  string res="", line;
  foreach(contents/"\n", line)
  {
    array words;
    string word;
    words = line/" ";
    line="";
    foreach(words, word)
    {
      string pre, post;
      if(sscanf(word, "%s@%s", pre, post)==2)
	word = "<a href=mailto:"+pre+"@"+post+">"+pre+"@"+post+"</a>";
      line += word+" ";
    }
    res += line[..strlen(line)-2]+"\n";
  }
  if(m->pre)
    return "<pre>"+res[..strlen(res)-2]+"</pre>";
  else
    return res;
}

string tag_stycke(string s, mapping m, string contents, object id, mapping defines, object fd)
{
  contents = replace(contents, "\n\n", "\n\n<p>\n\n");
  if(id->supports->tables && !id->prestate->notables)
    return ("<table width=100%><tr valign=top>"
	    "<td width="+QUERY(lc)+">"+QUERY(bs)+
	    "<p align=right><font size=5><b>"+m->namn+"</b></font>"+QUERY(as)+"</td>"
	    "<td width="+QUERY(pc)+">&nbsp;&nbsp;</td>"
	    "<td width=100%>"+contents+"</td></tr></table>"
	    "<hr noshade size=1>\n");
  else
    return ("<h2>"+m->namn+"</h2>"+contents);
}

string tag_lank(string s, mapping m, object id, mapping defines, object fd)
{
  string res;
  if(id->supports->font && !id->prestate->nofont)
    res = "<tt><smallcaps size=3><b>"+m->namn+"</b></smallcaps></tt><br>";
  else
    res = "<li>"+m->namn;
  if(m->till)
    res = "<a href=\""+m->till+"\">"+res+"</a>";
  return res;
}

string tag_punkt(string s, mapping m, string contents, object id, mapping defines, object fd)
{
  string res;
  if(m->namn)
    if(id->supports->font && !id->prestate->nofont)
      if(search(m->namn,"@")==-1)
	res = "<p><tt><smallcaps size=4><b>"+m->namn+"</b></smallcaps></tt><p>";
      else
	res = "<p><b>"+m->namn+"</b><p>";
    else
      res = "<h3>"+m->namn+"</h3>";
  if(m["länk"])
    res = "<a href=\""+m["länk"]+"\">"+res+"</a>";
  return res+contents;
}


mapping query_tag_callers()
{
  return (["länk":tag_lank,]);
}

mapping query_container_callers()
{
  return (["stycke":tag_stycke,
	   "punkt":tag_punkt,
	   "mailto":tag_email,
	   "rubrik":tag_rubrik,
	   ]);
}


array register_module()
{
  return ({ MODULE_PARSER, 
	    "hedbor.org parser", 
	    ("This module provides an abstact mark up langauge for the hedbor.org pages"),
	    ({}), 1 });
}

void create()
{
  defvar("lc", 84, "Left column", TYPE_INT, "leftmost column width.");
  defvar("pc", 20, "Padding column", TYPE_INT, "padding column width.");
  defvar("bs", "<if prestate=dark><font color=black></if><else><font color=white></else>",
	 "Before header of 'stycke'", TYPE_STRING, "");
  defvar("as", "</font>", "After header of 'stycke'", TYPE_STRING, "");
}



