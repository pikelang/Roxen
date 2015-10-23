/*
 * $Id$
 */

#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(10, "List fonts");
string doc = LOCALE(11, "List all available fonts");


string versions(string font)
{
  array res=({ });
  array b = available_font_versions(font,32);
  if (!b || !sizeof(b)) 
    return "<b>"+LOCALE("dH","Not available.")+"</b>"; 
  array a = map(b,describe_font_type);
  mapping m = mkmapping(b,a);
  foreach(sort(indices(m)), string t)
    res += ({ //"<input type='hidden' name='"+(font+"/"+t)+"'/>"+
	      Roxen.html_encode_string(m[t]) });
  return String.implode_nicely(res);
}

mapping info;
string list_font(string font)
{
  string fn = replace(lower_case( font ), " ", "_" );
  
  if( mapping m = info[ fn ] )
  {
    string res = "<p><font><b>"+
           (Roxen.html_encode_string(map(replace(font,"_"," ")/" ",
                                         capitalize)*" ")+
                  "</b></font> <font size='-1'>"+versions(font)+"</font><br />"
                  "<table cellspacing=0 cellpadding=0");
    foreach( sort( indices( m ) - ({"name","versions"}) ), string i )
      res += "<tr><td>&nbsp;&nbsp;&nbsp;<font size=-1>"+i+":&nbsp;</font></td><td><font size=-1>"+
          Roxen.html_encode_string(m[i])+"</font></td></tr>\n";
    res += "</table>";
    return res;
  }
  return "<p><font><b>"+
         (Roxen.html_encode_string(map(replace(font,"_"," ")/" ",capitalize)*" ")+
          "</b></font> <font size='-1'>"+versions(font)+"</font><br />");
}

string font_loaders( )
{
  string res ="<dl>";
  foreach( roxen.fonts.font_handlers, FontHandler fl )
  {
    int nf =  sizeof( fl->available_fonts() );
    res += "<b><dt><font>"+fl->name+" ("+nf
        +" font"+(nf==1?"":"s")+")</font></b></dt>"
        "<dd>"+fl->doc+"</dd><p />";
  }
  return res+"</dl>";
}

string page_0(RequestID id)
{
  array q = roxen.fonts.get_font_information();
  info = mkmapping( q->name, q );
  string res=("<input type='hidden' name='action' value='listfonts.pike'/>"
              "<input type='hidden' name='doit' value='indeed'/>\n"
              "<font size='+1'><b>" +
	      LOCALE(58,"Available font loaders") + "</b></font><p>"+
              font_loaders()+"<font size='+1'><b>" +
	      "<br />" + LOCALE("dI","All available fonts") + "</b></font><p>");
  foreach(sort(roxen.fonts.available_fonts(1)), string font)
    res+=list_font(font);
  res += ("</p><p>" + LOCALE(236,"Example text") + " "
	  "<font size=-1><input name=text size=46 value='" +
	  LOCALE(237,"Jackdaws love my big sphinx of quartz.") +
	  "'></p><p><table width='70%'><tr><td align='left'>"
          "<cf-cancel href='?class=status'/></td><td align='right'>"
	  "<cf-next/></td></tr></table></p>");
  return res;
}

string page_1(RequestID id)
{
  string res="";
  mapping v  = id->real_variables;
  string txt = v->text && v->text[0];
  foreach(roxen.fonts.available_fonts(), string fn)
    res += Roxen.html_encode_string( fn )+":<br />\n"
      "<gtext fontsize=16 align='top' font='"+fn+"'>"+Roxen.html_encode_string(txt)+"</gtext><br>"
      "<gtext fontsize=32 align='top' font='"+fn+"'>"+Roxen.html_encode_string(lower_case(txt))+"</gtext><br>"
      "<gtext fontsize=48 align='top' font='"+fn+"'>"+Roxen.html_encode_string(upper_case(txt))+"</gtext><p>";
  return res+"<br /></p><p>\n<cf-ok/></p>";
}

mixed parse( RequestID id )
{
  if( id->variables->doit )
    return page_1( id );
  return page_0( id );
}
