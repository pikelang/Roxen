/* $Id: listfonts.pike,v 1.4 2000/02/04 14:38:50 jhs Exp $ */
#if constant(available_font_versions)
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
  return (map(replace(font,"_"," ")/" ",capitalize)*" "+
          " <font size=-1>"+ versions(font)+"</font><br>");
}

string page_0(object id)
{
  string res=("<input type=hidden name=action value=listfonts.pike>"
              "<input type=hidden name=doit value=indeed>"
              "<font size=+1>All available fonts</font><p>");
  foreach(roxen->fonts->available_fonts(1), string font)
  res+=list_font(font);
  res += ("<p>Example text: <font size=-1><input name=text size=46 value='"
          "<cf-locale get=font_test_string>'><p>"
	  "<table width='70%'><tr><td align=left>"
          "<cf-cancel href='?class=maintenance'></td><td align=right>"
	  "<cf-next></td></tr></table>");
  return res;
}

string page_1(object id)
{
  string res="";
  mapping v = id->variables;
  foreach(roxen->fonts->available_fonts(), string fn)
    res += fn+": <gtext align=top font='"+fn+"'>"+v->text+"</gtext><p>";
  return res+"<br><p>\n<cf-ok>";
}

mixed parse(object id)
{
  if( id->variables->doit )
    return page_1( id );
  return page_0( id );
}
#else
#error Only available under roxen 1.2a11 or newer
#endif
