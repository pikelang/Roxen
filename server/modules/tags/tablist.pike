// This is a roxen module. Copyright © 1997-1999, Idonex AB.
// Makes a tab list like the one in the config interface.

constant cvs_version="$Id: tablist.pike,v 1.39 2000/02/21 17:49:46 per Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

constant module_type = MODULE_PARSER;
constant module_name = "Tab list";
constant module_doc = ("Adds some tags for making tab lists."
                       " Requires the gbutton module");

/*
 * Functions
 */

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["tablist":({ "<desc cont>Tab list</desc>", (["tab":"<desc cont>Tab</desc>"]) }) ]);
/*
	      "<ul><pre>&lt;tablist&gt;\n"
	      "&lt;tab href=\"/tab1/\"&gt;Some text&lt;/tab&gt;\n"
	      "&lt;tab href=\"/tab2/\"&gt;Some more text&lt;/tab&gt;\n"
	      "&lt;tab href=\"a/strange/place/\"&gt;Tab 3&lt;/tab&gt;\n"
	      "&lt;/tablist&gt;\n"
	      "</pre></ul>Attributes for the &lt;tab&gt; tag:<br>\n"
	      "<ul><table border=0>\n"
	      "<tr><td><b>selected</b></td><td>Whether the tab is selected "
	      "or not.</td></tr>\n"
	      "<tr><td><b>bgcolor</b></td><td>What color to use as "
	      "background (behind the tab). Defaults to white.</td></tr>\n"
	      "<tr><td><b>selcolor</b></td><td>What color to use as "
	      "background for selected tab. Defaults to white.</td></tr>\n"
	      "<tr><td><b>dimcolor</b></td><td>What color to use as "
	      "background for unselected tab. Defaults to grayish.</td></tr>\n"
	      "<tr><td><b>textcolor</b></td><td>What color to use as "
	      "text color. Defaults to black for selected tabs and white "
	      "otherwise.</td></tr>\n"
	      "<tr><td><b>alt</b></td><td>Alt-text for the image (default: "
	      "\"_/\" + text + \"\\_\").</td></tr>\n"
	      "<tr><td><b>border</b></td><td>Border for the image (default: "
	      "0).</td></tr>\n"
              "<tr><td><b>noxml</b></td><td>Images will not be terminated "
	      "with a slash if this attribute is provided.</td></tr>\n"
	      "</table></ul>\n"
              "<br>The bgcolor, selcolor, dimcolor, textcolor and noxml "
	      "attribute can also be given in the tablist tag as global "
	      "attributes. Using color arguments in a tab tag will overide "
	      "the global setting."
 */
#endif

void add_layers( mapping m, string lay )
{
  foreach( ({"","background-","mask-","frame-","left-","right-" }), string s )
  {
    string ind="extra-"+s+"layers", l;
    if( strlen( s ) )
      l = lay+" "+(s-"-");
    else
      l = lay;
    if( m[ind] )
      m[ind]+=","+l;
    else
      m[ind] = l;
  }
}

string internal_tag_tab(string t, mapping a, string contents, mapping d,
                        RequestID id)
{
  string fimage;

  if(a["frame-image"])
    fimage = fix_relative( a["frame-image"], id );
  else if(d["frame-image"])
    fimage = fix_relative( d["frame-image"], id );
  else if(id->misc->defines["tab-frame-image"])
    fimage = fix_relative( id->misc->defines["tab-frame-image"], id );
  else
    //  We need an absolute path or else gbutton will "fix" this according
    //  to the path in the request...
    fimage = getcwd() + "/roxen-images/tabframe.xcf";

  mapping gbutton_args = d|a;

  gbutton_args["frame-image"] = fimage;

  if( a->selected  )
  {
    add_layers( gbutton_args, "selected" );
    gbutton_args->bgcolor = a->selcolor || d->selcolor || "white";
    gbutton_args->textcolor = (a->seltextcolor || d->seltextcolor ||
                               a->textcolor || d->textcolor ||
                               id->misc->defines->fgcolor ||
                               id->misc->defines->theme_fgcolor ||
                               "black");
  } else {
    add_layers( gbutton_args, "unselected" );
    gbutton_args->bgcolor =  a->dimcolor || d->dimcolor || "#003366";
    gbutton_args->textcolor = (a->textcolor || d->textcolor || "white");
  }
  m_delete(gbutton_args, "selected");
  m_delete(gbutton_args, "dimcolor");
  m_delete(gbutton_args, "seltextcolor");
  m_delete(gbutton_args, "selcolor");
  m_delete(gbutton_args, "result");

  //  Create <img> tag
  mapping img_attrs = ([ ]);

  if (a->alt) {
    gbutton_args->alt = a->alt;
    m_delete(a, "alt");
  } else
    gbutton_args->alt = "_/" + contents + "\\_";

  d->result += ({ ({gbutton_args,contents}) });
  return 0;
}

string container_tablist(string t, mapping a, string contents, RequestID id)
{
  a->result=({});
  parse_html(contents, ([]), (["tab":internal_tag_tab]), a, id);
  if(!sizeof(a->result))
    return "";

  if( a->result[0][0]->selected )
    add_layers( a->result[0][0], "first selected" );
  else
    add_layers( a->result[0][0], "first unselected" );
  add_layers( a->result[0][0], "first" );
  if( a->result[-1][0]->selected )
    add_layers( a->result[-1][0], "last selected" );
  else
    add_layers( a->result[-1][0], "last unselected" );
  add_layers( a->result[-1][0], "last" );

  return map( a->result, lambda( array q ) {
                           return make_container( "gbutton",q[0],q[1]);
                         } )*"";
}
