// The Diagrams tag module

#include <module.h>
inherit "module.pike";
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
  
  if (args->help) {
    right = 250;
    title = "The Outlined Box container tag";
    contents = "Usage:<p>"
               "&lt;<b>obox</b> <b>title</b>=\"Sample title\"&gt;"
               "<br>Anything, html, text, ...<br>"
               "&lt;<b>/obox</b>&gt;<p>\n"
               "Options:<p>"
      "<b>left</b>: Length of line on the left side of the title<br>\n"
      "<b>right</b>: Length of line on the right side of to the title<br>\n"
      "<b>spacing</b>: Width of the space inside the box<br>\n";
  }

  switch (name) {
  case "obox":
      s = "<table border=0 cellpadding=0 cellspacing=0>\n"
          "<tr><td colspan=2>&nbsp;</td>\n"
          "<td rowspan=3>&nbsp;<b>"+title+"</b> </td>\n"
          "<td colspan=2>&nbsp;</td></tr>\n"
      
          "<tr><td bgcolor=#000000 colspan=2 height=1>\n"
          "<img alt='' src="+unit_gif+" height=1></td>\n"
          "<td bgcolor=#000000 colspan=2 height=1>\n"
	  "<img alt='' src="+unit_gif+"></td></tr>\n"
      
          "<tr><td bgcolor=#000000><img alt='' src="+unit_gif+"></td>\n"
          "<td width="+(string)left+">&nbsp;</td>"
	  "<td width="+(string)right+">&nbsp;</td>\n"
          "<td bgcolor=#000000><img alt='' src="+unit_gif+"></td></tr>\n"

          "<tr><td bgcolor=#000000><img alt='' src="+unit_gif+"></td>\n"
          "<td colspan=3>\n"

          "<table border=0 cellspacing=5 "+
	  (spacing?"width="+(string)spacing+" ":"")+"><tr><td>\n";

      s += contents;
      
      s += "</td></tr></table>\n"
	   "</td><td bgcolor=#000000><img alt='' src="+unit_gif+"></td></tr>\n"
           "<tr><td colspan=5 bgcolor=#000000>\n"
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
