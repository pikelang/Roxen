// This is a roxen module. Copyright © 1997-2000, Roxen IS.
// Makes a tab list like the one in the config interface.

constant cvs_version="$Id: tablist.pike,v 1.50 2001/03/05 20:08:44 nilsson Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

constant module_type = MODULE_TAG;
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
  foreach( ({"","background-","mask-","frame-","left-","right-",
             "above-","below-" }), string s )
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

class TagTablist {
  inherit RXML.Tag;
  constant name = "tablist";

  class TagTab {
    inherit RXML.Tag;
    constant name = "tab";

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	string fimage;
	mapping d = id->misc->tablist_args;

	if(args["frame-image"])
	  fimage = Roxen.fix_relative( args["frame-image"], id );
	else if(d["frame-image"])
	  fimage = Roxen.fix_relative( d["frame-image"], id );
	else if(id->misc->defines["tab-frame-image"])
	  fimage = Roxen.fix_relative( id->misc->defines["tab-frame-image"], id );
	else
	  //  We need an absolute path or else gbutton will "fix" this according
	  //  to the path in the request...
	  fimage = "/internal-roxen-tabframe";
  
	mapping gbutton_args = d|args;

	gbutton_args["frame-image"] = fimage;

	if( args->selected  ) {
	  add_layers( gbutton_args, "selected" );
	  gbutton_args->bgcolor = args->selcolor || d->selcolor || "white";
	  gbutton_args->textcolor = (args->seltextcolor || d->seltextcolor ||
				     args->textcolor || d->textcolor ||
				     id->misc->defines->fgcolor ||
				     id->misc->defines->theme_fgcolor ||
				     "black");
	} else {
	  add_layers( gbutton_args, "unselected" );
	  gbutton_args->bgcolor =  args->dimcolor || d->dimcolor || "#003366";
	  gbutton_args->textcolor = (args->textcolor || d->textcolor || "white");
	}
	m_delete(gbutton_args, "selected");
	m_delete(gbutton_args, "dimcolor");
	m_delete(gbutton_args, "seltextcolor");
	m_delete(gbutton_args, "selcolor");
	m_delete(gbutton_args, "result");

	if (args->alt) {
	  gbutton_args->alt = args->alt;
	  m_delete(args, "alt");
	} else
	  gbutton_args->alt = "/" + content + "\\";

	id->misc->tablist_result += ({ ({gbutton_args,content}) });
	return 0;
      }
    }
  }

  RXML.TagSet internal = RXML.TagSet("TagTablist.internal", ({ TagTab() }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id) {
      id->misc->tablist_args = args;
      id->misc->tablist_result = ({});
    }

    array do_return(RequestID id) {
      array(array) result = id->misc->tablist_result;
      if(!sizeof(result))
	return 0;

      if( result[0][0]->selected )
	add_layers( result[0][0], "first selected" );
      else
	add_layers( result[0][0], "first unselected" );
      add_layers( result[0][0], "first" );
      if( result[-1][0]->selected )
	add_layers( result[-1][0], "last selected" );
      else
	add_layers( result[-1][0], "last unselected" );
      add_layers( result[-1][0], "last" );

      return map( result, lambda( array q ) {
			    return RXML.make_tag ("gbutton",q[0],q[1]);
			  } );
    }
  }
}
