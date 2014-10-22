// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

#pragma strict_types

string input(string name, string value, void|int size,
	     void|mapping(string:string) args, void|int xml)
{
  if(!args)
    args=([]);
  else
    args+=([]);

  args->name=name;
  args->value=value;
  if(size)
    args->size=(string)size; 

  string render="<input";

  foreach([array(string)]indices(args), string attr) {
    render+=" "+attr+"=";
    if(!has_value(args[attr], "\"")) render+="\""+args[attr]+"\"";
    else if(!has_value(args[attr], "'")) render+="'"+args[attr]+"'";
    else render+="\""+replace(args[attr], "'", "&#39;")+"\"";
  }

  if(xml) return render+" />";
  return render+">";
}

string pre(string f)
{
  return "<pre>\n"+f+"</pre>\n";
}

string table(string|void t, int|void cellspacing, int|void cellpadding,
	     int|void border, int|void width)
{
  string d="";
  int ds, dp;
  if(border)
  {
    d += " border=\""+border+"\"";
    ds=2;
    dp=3;
  }

  if(cellspacing)
    ds=cellspacing;
  d += " cellspacing=\""+ds+"\"";
  if(cellpadding)
    dp=cellpadding;
  d += " cellpadding="+dp+"\"";
  if(width)
    d += " width=\""+width+"%\"";
  return "<table"+d+">\n"+t+"</table>\n\n";
}

string tr(string data, int|void rows)
{
  if(rows)
    return "<tr rowspan=\""+rows+"\">\n" + data + "</tr><p>";
  else
    return "<tr>\n" + data + "</tr><p>\n";
}

string td(string t, string|void align, int|void rows, int|void cols)
{
  string q="";
  if(align) q+=" align=\""+align+"\"";
  if(rows)  q+=" rowspan=\""+rows+"\"";
  if(cols)  q+=" colspan=\""+cols+"\"";
  return "<td"+q+">\n" + t +"</td>\n";
}

string bf(string|void s, int|void i)
{
  return "<font size=\"+"+(i+1)+"\"><b>"+s+"</b></font>";
}

string th(string t, string|void align, int|void rows,
	  int|void cols)
{
  string q="";
  if(align) q+=" align=\""+align+"\"";
  if(rows)  q+=" rowspan=\""+rows+"\"";
  if(cols)  q+=" colspan=\""+cols+"\"";
  return "<th"+q+">\n" + t +"</th>\n";
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

string select(string name, array(string)|array(array(string)) choices,
		  void|string selected) {
  string ret = "<select name=\"" + name + "\">\n";

  if(sizeof(choices) && arrayp(choices[0])) {
    foreach([array(array(string))]choices, array(string) value)
      ret += "<option value=\"" + value[0] + "\"" +
	(value[0]==selected?" selected=\"selected\"":"") +
	">" + value[1] + "</option>\n";
  } else {
    foreach([array(string)]choices, string value)
      ret += "<option value=\"" + value + "\"" +
	(value==selected?" selected=\"selected\"":"") +
	">" + value + "</option>\n";
  }

  return ret + "</select>";
}
