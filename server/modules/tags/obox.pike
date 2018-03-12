// The outlined box module, Copyright © 1996 - 2009, Roxen IS.
//
// Fredrik Noring et al
//
// Several modifications by Francesco Chemolli.


constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
// #include <roxen.h>
inherit "module";

// begin locale stuff
//<locale-token project="mod_obox">LOCALE</locale-token>
//<locale-token project="mod_obox">SLOCALE</locale-token>
#define SLOCALE(X,Y)	_STR_LOCALE("mod_obox",X,Y)
#define LOCALE(X,Y)	_DEF_LOCALE("mod_obox",X,Y)
// end locale stuff

constant module_type = MODULE_TAG | MODULE_DEPRECATED_SOFT;
LocaleString module_name = LOCALE(1,"Tags: Outlined box");

LocaleString module_doc  =
  LOCALE(2,"This module provides the <tt>&lt;obox&gt;</tt> tag that "
	 "draws outlined boxes.");

constant unit_gif = "/internal-roxen-unit";

protected string img_placeholder (mapping args)
{
  int width=((int)args->outlinewidth)||1;

  return sprintf("<img src=\"%s\" alt=\"\" "
		 // border:1 is here to work around a buggy rendering in NS4.
		 "style=\"display:block; border:1;\" "
		 "width=\"%d\" height=\"%d\"%s>",
		 unit_gif, width, width, (args->noxml?"":" /"));
}

protected string handle_title(string name, mapping junk_args,
			      string contents, mapping args)
{
  args->title=contents;
  return "";
}

protected string horiz_line(mapping args)
{
  args->fixedleft="";
  return sprintf("<tr><td colspan=\"5\" bgcolor=\"%s\">\n"
		 "%s</td></tr>\n",
		 args->outlinecolor,
		 img_placeholder(args));
}

protected string title(mapping args)
{
  if (!args->title)
    return horiz_line(args);
  string empty=img_placeholder(args);
  if (!args->left && !args->fixedleft)
    if (args->width && !args->fixedright)
      args->fixedleft = "7";
    else
      args->left = "20";
  if (!args->right && !args->fixedright)
    args->right = args->width || "20";
  switch (args->style) {
   case "groupbox":
    return sprintf("<tr><td colspan=\"2\"><font size=\"-3\">&nbsp;</font></td>\n"
		   "<td rowspan=\"3\"%s nowrap=\"nowrap\">&nbsp;<b>"		/* bgcolor */
		   "%s%s%s"                 /* titlecolor, title, titlecolor */
		   "</b>&nbsp;</td>\n"
		   "<td colspan=\"2\"><font size=\"-3\">&nbsp;</font></td></tr>\n"
		   "<tr%s>"				/* bgcolor */
		   "<td bgcolor=\"%s\" colspan=\"2\">\n"	/* outlinecolor */
		   "%s</td>\n"				/* empty */
		   "<td bgcolor=\"%s\" colspan=\"2\">\n"
		   "%s</td></tr>\n"			/* empty */

		   "<tr%s><td bgcolor=\"%s\">"      /* bgcolor, outlinecolor */
		   "%s</td>\n"				/* empty */
		   "<td%s><font size=\"-3\">%s</font></td>" /* left, fixedleft */
		   "<td%s><font size=\"-3\">%s</font></td>\n" /* right, fixedright */
		   "<td bgcolor=\"%s\">"		/* outlinecolor */
		   "%s</td></tr>\n"			/* empty */
		   ,
		   args->bgcolor ? " bgcolor=\""+args->bgcolor+"\"" : "",
		   args->titlecolor ? "<font color=\""+args->titlecolor+"\">" : "",
		   args->title,
		   args->titlecolor ? "</font>" : "",
		   args->bgcolor ? " bgcolor=\""+args->bgcolor+"\"" : "",
		   args->outlinecolor,
		   empty,
		   args->outlinecolor,
		   empty,
		   args->bgcolor ? " bgcolor=\""+args->bgcolor+"\"" : "",
		   args->outlinecolor,
		   empty,
		   args->left ? " width=\""+args->left+"\"" : "",
		   (args->fixedleft ?
		    ("&nbsp;"*(int)args->fixedleft) : "&nbsp;"),
		   args->right ? " width=\""+args->right+"\"" : "",
		   (args->fixedright ?
		    ("&nbsp;"*(int)args->fixedright) : "&nbsp;"),
		   args->outlinecolor,
		   empty);
   case "caption":
    return sprintf("<tr%s><td colspan=\"2\"><font size=\"-3\">&nbsp;</font></td>\n"
		   "<td rowspan=\"3\" nowrap=\"nowrap\">&nbsp;<b>"		/* bgcolor */
		   "%s%s%s"                 /* titlecolor, title, titlecolor */
		   "</b>&nbsp;</td>\n"
		   "<td colspan=\"2\"><font size=\"-3\">&nbsp;</font></td></tr>\n"
		   "<tr bgcolor=\"%s\">"		/* outlinecolor */
		   "<td colspan=\"2\">\n"
		   "%s</td>\n"				/* empty */
		   "<td colspan=\"2\">\n"
		   "%s</td></tr>\n"			/* empty */

		   "<tr bgcolor=\"%s\"><td>"      /*  outlinecolor */
		   "%s</td>\n"				/* empty */
		   "<td%s><font size=\"-3\">%s</font></td>" /* left, fixedleft */
		   "<td%s><font size=\"-3\">%s</font></td>\n" /* right, fixedright */
		   "<td bgcolor=\"%s\">"		/* outlinecolor */
		   "%s</td></tr>\n"			/* empty */
		   ,
		   args->outlinecolor ? " bgcolor=\""+args->outlinecolor+"\"" : "",
		   args->titlecolor ? "<font color=\""+args->titlecolor+"\">" : "",
		   args->title,
		   args->titlecolor ? "</font>" : "",
		   args->outlinecolor,
		   empty,
		   empty,
		   args->outlinecolor,
		   empty,
		   args->left ? " width=\""+args->left+"\"" : "",
		   (args->fixedleft ?
		    ("&nbsp;"*(int)args->fixedleft) : "&nbsp;"),
		   args->right ? " width=\""+args->right+"\"" : "",
		   (args->fixedright ?
		    ("&nbsp;"*(int)args->fixedright) : "&nbsp;"),
		   args->outlinecolor,
		   empty);
  }
}

string simpletag_obox(string name, mapping args, string contents)
{
  string s;

  // Set the defaults...
  args->outlinecolor = args->outlinecolor || "#000000";
  args->style = args->style || "groupbox";
  if (!args->title) {
    contents=parse_html(contents,([]),(["title":handle_title,]),args);
  }

  s = "<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\"" +
    (args->align?" align=\""+args->align+"\"":"") +
    (args->width ? " width=" + args->width : "") +
    (args->hspace ? " hspace=" + args->hspace : "") +
    (args->vspace ? " vspace=" + args->vspace : "") +  ">\n" +
    title(args) +
    "<tr" +
    (args->bgcolor?" bgcolor=\""+args->bgcolor+"\"":"") +
    "><td bgcolor=\"" + args->outlinecolor + "\">" +
    img_placeholder(args) + "</td>\n"
    "<td" + (args->width && !args->fixedleft && !args->fixedright ? " width=\"1\"" : "") +
    (args->aligncontents ? " align=" + args->aligncontents : "") + " colspan=\"3\"" + ">\n"
    "<table border=\"0\" cellspacing=\"0\" cellpadding=\"" + (args->padding || "5") + "\""+
    (!args->spacing && args->width?" width=\""+(string)((int)args->width-((int)args->outlinewidth*2||2))+"\"":"")+
    (args->spacing?" width=\""+(string)args->spacing+"\"":"")+">"
    "<tr><td>\n";

    if (args->textcolor)
      s += "<font color=\""+args->textcolor+"\">" + contents + "</font>";
    else
      s += contents;

    s += "</td></tr></table>\n"
      "</td><td bgcolor=\"" + args->outlinecolor + "\">" +
      img_placeholder(args) + "</td></tr>\n" +
      horiz_line(args) + "</table>\n";

  return s;
}


TAGDOCUMENTATION
#ifdef manual
constant tagdoc=([
"obox": ([
  "standard":#"<desc type='cont'><p><short>
 This tag creates an outlined box.</short>
</p></desc>

<attr name='align' value='left|right'><p>
 Vertical alignment of the box.</p>
</attr>

<attr name='bgcolor' value='color'><p>
 Color of the background and title label.</p>
</attr>

<attr name='fixedleft' value='number'><p>
 Fixed length of line on the left side of the title. The unit is the
 approximate width of a character.</p>
</attr>

<attr name='fixedright' value='number'><p>
 Fixed length of line on the right side of the title. The unit is the
 approximate width of a character.</p>
</attr>

<attr name='left' value='number'><p>
 Length of the line on the left of the title.</p>
</attr>

<attr name='outlinecolor' value='color'><p>
 Color of the outline.</p>
</attr>

<attr name='outlinewidth' value='number'><p>
 Width, in pixels, of the outline.</p>
</attr>

<attr name='right' value='number'><p>
 Length of the line on the right of the title.</p>
</attr>

<attr name='spacing' value='number'><p>
 Width, in pixels, of the space in the box.</p>
</attr>

<attr name='style' value='caption|groupbox'><p>
 Style of the box. Groupbox is default.</p>
</attr>

<attr name='textcolor' value='color'><p>
 Color of the text inside the box.</p>
</attr>

<attr name='title' value='string'><p>
 Sets the title of the obox.</p>
</attr>

<attr name='titlecolor' value='color'><p>
 Color of the title text.</p>
</attr>

<attr name='width' value='number'><p>
 Width, in pixels, of the box.</p>


 <p>Note that the left and right attributes are constrained by the width
 argument. If the title is not specified in the argument list, you can
 put it in a <tag>title</tag> container in the obox contents.</p>

<ex><obox align='left' outlinewidth='5' outlinecolor='green' width='200'>
<title>Sample box</title>

This is just a sample box.

</obox>
</ex>

</attr>",


  "svenska":#"<desc type='cont'><p><short>
 Denna tagg skapar en ramlåda runt dess innehåll.</short>
</p></desc>

<attr name='align' value='left|right'><p>
 Ramlådans vertikala position.</p>
</attr>

<attr name='bgcolor' value='färg'><p>
 Färgen på bakgrunden samt titeln.</p>
</attr>

<attr name='fixedleft' value='nummer'><p>
 Längden på linjen till vänster om titeln. Värdet på 1 'nummer' är den
 ungefärliga bredden av ett tecken.</p>
</attr>

<attr name='fixedright' value='nummer'><p>
 Längden på linjen till vänster om titeln. Värdet på 1 'nummer' är den
 ungefärliga bredden av ett tecken.</p>
</attr>

<attr name='left' value='nummer'><p>
 Längden på linjen till vänster om titeln.</p>
</attr>

<attr name='outlinecolor' value='färg'><p>
 Färgen på ramen.</p>
</attr>

<attr name='outlinewidth' value='nummer'><p>
 Ramens bredd, i antal pixlar.</p>
</attr>

<attr name='right' value='nummer'><p>
 Längden på linjen till höger om titeln.</p>
</attr>

<attr name='spacing' value='nummer'><p>
 Vidden på utrymmet i ramlådan, i antal pixlar.</p>
</attr>

<attr name='style' value='caption|groupbox'><p>
 Ramlådans stil. Groupbox är standardvärde.</p>
</attr>

<attr name='textcolor' value='färg'><p>
 Färgen på texten inuti lådan.</p>
</attr>

<attr name='title' value='textsträng'><p>
 Ramlådans titel.</p>
</attr>

<attr name='titlecolor' value='färg'><p>
 Färgen på titeltexten.</p>
 </attr>

<attr name='width' value='nummer'><p>
 Bredden på lådan, i antal pixlar.</p>

 <p>Tänk på att <att>left</att> och <att>right</att> attributen begränsas
 av värdet på <att>width</att> attributet. Om titeln inte är satt i
 taggen, finns möjligheten att sätta den inuti en <tag>title</tag>
 tagg och placera denna i ramlådans innehåll.</p>

<ex><obox align='left' outlinewidth='5' outlinecolor='green' width='200'>
<title>Ramlåda</title>

Detta är innehållet.

</obox>
</ex>

</attr>"
]) ]);
#endif

