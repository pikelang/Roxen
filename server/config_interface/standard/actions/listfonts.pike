/* $Id: listfonts.pike,v 1.2 2000/02/04 05:49:18 per Exp $ */
#if constant(available_font_versions)
inherit "wizard";

constant action = "maintenance";
constant name= "List Available Fonts";
constant doc = "List all available fonts";

string versions(string font)
{
  array res=({ });
  array b = available_font_versions(font,32);
  array a = map(b,describe_font_type);
  mapping m = mkmapping(b,a);
  foreach(sort(indices(m)), string t)
    res += ({ "<input type=hidden name='"+(font+"/"+t)+"'>"+m[t] });
  return String.implode_nicely(res);
}

string list_font(string font)
{
  return ("<input type=hidden value=on name='font:"+font+"'>"+
          map(replace(font,"_"," ")/" ",capitalize)*" "+" <font size=-1>"
          + versions(font)+"</font><br>");
}

string page_0(object id)
{
  string res="<font size=+1>All available fonts</font><p>";
  foreach(roxen->fonts->available_fonts(1), string font) res+=list_font(font);
  res += "<p>Example text: <font size=-1><var type=string name=text default='"
    "The quick brown fox jumps over the lazy dog'>";
  return res;
}

string page_1(object id)
{
  string res="";
  mapping v = id->variables;
  foreach(sort(glob("font:*",indices(v))), string f)
  {
    sscanf(f, "%*s:%s", f);
    string fn = map(replace(f,"_"," ")/" ",capitalize)*" ";
    res += fn+": <gtext align=top font='"+fn+"'>"+v->text+"</gtext><p>";
  }
  return res;
}

mixed parse(object id)
{
  return wizard_for(id,0);
}
#else
#error Only available under roxen 1.2a11 or newer
#endif
