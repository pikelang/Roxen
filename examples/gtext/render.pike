array colors = ({
  "black",
  "brown",
  "cyan",
  "darkblue",
  "darkred",
  "green",
  "orange",
  "pink",
  "red",
  "white",
});


array (string) list_fonts()
{
  return roxen->available_fonts(1);
}

string make_select(array (string) from, string selected)
{
  array res = ({});
  string s;
  if(!selected) selected="";
  foreach(from, s)
  {
    if((s-" ")==(selected-" "))
      res += ({ "<option value='"+s+"' selected>"+s });
    else
      res += ({ "<option value='"+s+"'>"+s });
  }
  return res*"";
}

array trim(array in)
{
  return Array.map(in,lambda(string s){
    if(sscanf(s, "%*s%*d")==2) return 0;return s;
  })-({0});
}

string parse(object id)
{
  string args ="";
  if(id->variables->weight=="bold") args += " bold";
  if(id->variables->weight=="light") args += " light";
  if(id->variables->weight=="black") args += " black";
  if(id->variables->italic == "italic") args += " italic";

  if(!id->variables->txt) id->variables->txt="Enter text here";
  
  if(!id->variables->color) id->variables->color="white";
  if(!id->variables->bg) id->variables->bg="black";

  return ("<body bgcolor="+id->variables->bg+" text="+id->variables->color+"> "
	  "<form><table><tr><td>Text to render: (\\n is newline)<br><input size=60,1 name=txt value=\""+
	  id->variables->txt+"\">\n"
	  "<table><tr><td>Text</td><td>Background</td><td"
	  " rowspan=2><input type=submit value=Go></td><tr>"
	  "<td><select name=color>"+
	  make_select(colors,id->variables->color)+"</select></td><td>"
	  "<select name=bg>"+
	  make_select(colors,id->variables->bg)+"</select><br></td></table>"
	  "</tr><tr><td>Font:<br><select name=font>"+
	  make_select(sort(list_fonts()), id->variables->font)+
	  "</select>"+"<select name=weight>"+
	  make_select(({"normal","bold","black","light"}),
		      id->variables->weight)+
	  "</select><select name=italic>"+
	  make_select(({"italic","plain"}), id->variables->italic)+
	  "</select></form></table><br>"
	  "<gtext nocache "+args+" nfont=\""+id->variables->font+"\">"+
	  replace(id->variables->txt,({"\\n","<",">","&"}),({"\n","&lt;","&gt;","&amp;"}))+
	  "</gtext>");
}
