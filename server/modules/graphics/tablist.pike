// This is a roxen module. Copyright © 1997-2000, Roxen IS.
// Makes a tab list like the one in the config interface.

constant cvs_version="$Id: tablist.pike,v 1.45 2000/05/01 06:25:01 nilsson Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

constant module_type = MODULE_PARSER;
constant module_name = "Tab list";
constant module_doc = 
#"Provides the <tt>&lt;tablist&gt;</tt> tag that is used to draw tab lists.
It requires the <i>GButton</i> module.";

/*
 * Functions
 */

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["tablist":({ #"
<desc cont>

Tablist is used in the Roxen products configurationinterfaces.

</desc>", (["tab":#"<desc cont>Tab</desc>"]) }) ]);

#endif

void start(int num, Configuration conf)
{
  module_dependencies(conf, ({ "gbutton" }) );
}

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
    fimage = Roxen.fix_relative( a["frame-image"], id );
  else if(d["frame-image"])
    fimage = Roxen.fix_relative( d["frame-image"], id );
  else if(id->misc->defines["tab-frame-image"])
    fimage = Roxen.fix_relative( id->misc->defines["tab-frame-image"], id );
  else
    //  We need an absolute path or else gbutton will "fix" this according
    //  to the path in the request...
    fimage = "/internal-roxen-tabframe";
  
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

class TagTablist {
  inherit RXML.Tag;
  constant name = "tablist";
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      args->result=({});
      parse_html(content, ([]), (["tab":internal_tag_tab]), args, id);
      if(!sizeof(args->result))
	return 0;

      if( args->result[0][0]->selected )
	add_layers( args->result[0][0], "first selected" );
      else
	add_layers( args->result[0][0], "first unselected" );
      add_layers( args->result[0][0], "first" );
      if( args->result[-1][0]->selected )
	add_layers( args->result[-1][0], "last selected" );
      else
	add_layers( args->result[-1][0], "last unselected" );
      add_layers( args->result[-1][0], "last" );

      return ({ map( args->result, lambda( array q ) {
			       return Roxen.make_container( "gbutton",q[0],q[1]);
			     } )*"" });
    }
  }
}
