#define __replace(X) (X)

varargs string input(string name, string val, int t)
{
  if(!t)
    return sprintf("<input type=hidden name=\"%s\" value=\"%O\">", name, val);
  return sprintf("<input size=%d,1 name=\"%s\" value=\"%O\">", t, name, val);
}


string pre(string f)
{
  return "<pre>\n"+f+"</pre>\n";
}


varargs string table(string t, int|void cellspacing, int|void cellpadding,
		     int|void border, int|void width)
{
  string d="";
  int ds, dp;
  if(border)
  {
    d += " border="+border;
    ds=2;
    dp=3;
  }

  if(cellspacing)
    ds=cellspacing;
  d += " cellspacing="+ds;
  if(cellpadding)
    dp=cellpadding;
  d += " cellpadding="+dp;
  if(width)
    d += " width="+width+"%";
  return "<table"+d+">\n"+__replace(t)+"</table>\n\n";
}

varargs string tr(string data, int rows)
{
  if(rows) 
    return "<tr rowspan="+rows+">\n" + __replace(data) + "</tr><p>";
  else
    return "<tr>\n" + __replace(data) + "</tr><p>\n";
}


varargs string td(string t, string align, int rows, int cols)
{
  string q="";
  if(align) q+=" align="+align; 
  if(rows)  q+=" rowspan="+rows;
  if(cols)  q+=" colspan="+cols;
  return "<td"+q+">\n" + __replace(t) +"</td>\n";
}

varargs string bf(string s, int i)
{
  return "<font size=+"+(i+1)+"><b>"+s+"</b></font>";
}

varargs string th(string t, string|void align, int|void rows, 
		  int|void cols)
{
  string q="";
  if(align) q+=" align="+align; 
  if(rows)  q+=" rowspan="+rows;
  if(cols)  q+=" colspan="+cols;
  return "<th"+q+">\n" + __replace(t) +"</th>\n";
}

string h1(string h)
{
  return "<h1>"+h+"</h1>\n\n";
}

string h2(string h)
{
  return "<h2>"+h+"</h2>\n\n";
}

string h3(string h)
{
  return "<h3>"+h+"</h3>\n\n";
}

#if 0
inline string button(string text, string url)
{
  return sprintf("<form method=get action=\"%s\"><input type=submit value"+
		 "=\"%s\"></form>", replace(url, " ", "%20"), text);
}

inline string link(string text, string url)
{ 
  return sprintf("<a href=\"%s\">%s</a>", replace(url, " ", "%20"), text);
}
#endif
 

