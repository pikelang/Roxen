/* $Id: listfonts.pike,v 1.1 1997/09/05 22:31:08 per Exp $ */

inherit "wizard";

constant name= "Status//List Available Fonts...";
constant doc = "List all available fonts";
string versions(string font)
{
  array res=({ });
  array b = available_font_versions(font,32);
  array a = Array.map(b,describe_font_type);
  mapping m = mkmapping(b,a);
  foreach(sort(indices(m)), string t)
    res += ({ "<input type=hidden name='"+(font+"/"+t)+"'>"+m[t] });
  return String.implode_nicely(res);
}

string list_font(string font)
{
  return ("<font size=-1><input type=hidden value=on name='font:"+font+"'></font> "+
          Array.map(replace(font,"_"," ")/" ",capitalize)*" "+" <font size=-1>"
          + versions(font)+"</font><br>");
}

mapping render_font(object font, string text)
{
  return http_string_answer(font->write(text)->invert()->
			    scale(0.5)->togif(255,255,255),
			    "image/gif");
}


string page_0(object id)
{
  string res="<font size=+1>All available fonts</font><p>";
  foreach(roxen->available_fonts(1), string font) res+=list_font(font);
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
    string fn = Array.map(replace(f,"_"," ")/" ",capitalize)*" ";
    f = sprintf("action=%s&font=%s&italic=0&bold=0&text=%s&render=1",
		http_encode_string(v->action),
		http_encode_string(f),
		http_encode_string(replace(v->text,"&","%26")));
    res += fn+": <br><img src=?"+f+"><p>";
  }
  return res;
}

mixed handle(object id)
{
  if(!id->variables->render) return wizard_for(id,0);
  return render_font(get_font(id->variables->font, 32, 
			      (int)id->variables->bold,
			      (int)id->variables->italic,
			      "left", 0.0,0.0),
		     id->variables->text);
}
