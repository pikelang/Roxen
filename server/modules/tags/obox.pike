// The Diagrams tag module

constant cvs_version = "$Id: obox.pike,v 1.5 1997/10/27 12:02:37 grubba Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

#define INFO(s)  // perror("### %O"+(s))
#define DEBUG(s) perror("### %O\n",(s))
#define FATAL(s) perror("### %O\n"+(s))

#define ERROR(a) sprintf("<b>&lt;diagram&gt; error:</b> %s<br>\n", (a))

constant unit_gif = "/internal-roxen-unit";

string container_obox(string name, mapping args,
		      string contents, object request_id)
{
  string s = "hmm..";
  string title = (args->title?args->title:" ");

  int left = (args->left?args->left:25);
  int right = (args->right?args->right:350);
  int spacing = (args->spacing?args->spacing:0);

  string titlecolor =args->titlecolor;
  string outlinecolor = args->outlinecolor||"#000000";
  string bgcolor = args->bgcolor;
  string textcolor = args->textcolor;
  string align = args->align;
  string width = args->width;
  
  if (args->help) {
    right = 250;
    title = "The Outlined Box container tag";
    contents = "Usage:<p>"
               "&lt;<b>obox</b> <b>title</b>=\"Sample title\"&gt;"
               "<br>Anything, html, text, ...<br>"
               "&lt;<b>/obox</b>&gt;<p>\n"
               "Options:<p>\n\n"
      "<b>left</b>: Length of line on the left side of the title<br>\n"
      "<b>right</b>: Length of line on the right side of to the title<br>\n"
      "<b>spacing</b>: Width of the space inside the box<br>\n"
      "<b>titlecolor</b>: Color of the title of the box<br>\n"
      "<b>outlinecolor</b>: Color of the outline<br>\n"
      "<b>bgcolor</b>: Color of the background and title label<br>\n"
      "<b>textcolor</b>: Color of the text inside the box<br>\n"
      "<b>align</b>: How to align the box (left|right)<br>\n"
      "<b>width</b>: width of the generated box\n";
  }

  switch (name) {
  case "obox":
      s = "<table border=0 cellpadding=0 cellspacing=0" +
	(align?" align="+align:"") + (width?" width="+width:"") + ">\n"
	"<tr><td colspan=2>&nbsp;</td>\n"
	"<td rowspan=3" +
	(bgcolor?" bgcolor="+bgcolor:"") +
	">&nbsp;<b>" + 
	(titlecolor ? "<font color=\""+titlecolor+"\">":"") +
	title +
	(titlecolor ? "</font>":"") +
	"</b> </td>\n"
	"<td colspan=2>&nbsp;</td></tr>\n"
      
	"<tr" +
	(bgcolor?" bgcolor="+bgcolor:"") +
	"><td bgcolor=\"" + outlinecolor + "\" colspan=2 height=1>\n"
	"<img alt='' src="+unit_gif+" height=1></td>\n"
	"<td bgcolor=\"" + outlinecolor + "\" colspan=2 height=1>\n"
	"<img alt='' src="+unit_gif+"></td></tr>\n"
      
	"<tr" +
	(bgcolor?" bgcolor="+bgcolor:"") +
	"><td bgcolor=\"" + outlinecolor + "\">"
	"<img alt='' src="+unit_gif+"></td>\n"
	"<td width="+(string)left+">&nbsp;</td>"
	"<td width="+(string)right+">&nbsp;</td>\n"
	"<td bgcolor=\"" + outlinecolor + "\">"
	"<img alt='' src="+unit_gif+"></td></tr>\n"

	"<tr" +
	(bgcolor?" bgcolor="+bgcolor:"") +
	"><td bgcolor=\"" + outlinecolor + "\">"
	"<img alt='' src="+unit_gif+"></td>\n"
	"<td colspan=3>\n"

	"<table border=0 cellspacing=5 "+
	(spacing?"width="+(string)spacing+" ":"")+"><tr><td>\n";

      if (textcolor) {
	s += "<font color=\""+textcolor+"\">" + contents + "</font>";
      } else {
	s += contents;
      }
      
      s += "</td></tr></table>\n"
	"</td><td bgcolor=\"" + outlinecolor + "\">"
	"<img alt='' src="+unit_gif+"></td></tr>\n"
	"<tr><td colspan=5 bgcolor=\"" + outlinecolor + "\">\n"
	"<img alt='' src="+unit_gif+"></td></tr>\n"
	"</table>\n";
    break;
  }
  
  return s;
}

array register_module()
{
  return ({
    MODULE_PARSER,
      "Outlined box",
      "This is a container tag making outlined boxes.<br>"
      "&lt;obox help&gt;&lt;/obox&gt; gives help.",
      0, 1 });
}

mapping query_container_callers()
{
  return ([ "obox":container_obox, ]);
}
