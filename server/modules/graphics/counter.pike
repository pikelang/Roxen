//
// Roxen Graphic Counter Module	by Jordi Murgo <jordi@lleida.net>
// Modifications  1 OCT 1997 by Bill Welliver <hww3@riverweb.com>
// Optimizations 22 FEB 1998 by David Hedbor <david@hedbor.org>
// Optimizations 11 DEC 1999 by Martin Nilsson <nilsson@roxen.com>
// Rewritten     04 SEP 2000 by Martin Nilsson <nilsson@roxen.com>
//

#include <module.h>
inherit "module";

// --------------------- Module Definition ----------------------

void start( int num, Configuration conf )
{
  module_dependencies (conf, ({ "accessed", "graphic_text" }));
}

constant cvs_version = "$Id: counter.pike,v 1.35 2000/09/04 22:20:33 nilsson Exp $";
constant module_type = MODULE_PARSER;
constant module_name = "Graphical Counter";
constant thread_safe = 1;
constant module_doc  = "Generates graphical counters. This module is really only "
  "a wrapper kept for compatibility. It creates a gtext tag with an accessed tag inside.";

// How to update from the old counter module.
// Take your old ppm-fonts add a file called fontname with the name of the font in it.
// Add the location of that directory to the font path in the global settings.
// Know issues:
//  - User directory fonts won't work.

void create()
{
  defvar("font", "counter_a", "Default Font", TYPE_STRING,
	 "Default font for counters (Ex: 'counter_a')");
}

mapping tagdocumentation() {
  string args=" This tag relays the following attributes to gtext; "+String.implode_nicely(g_args)+
    ", and the following to accessed; "+String.implode_nicely(a_args)+". Refer to these tags documentation "
    "for more information.";
  return ([ "counter":"<desc tag>"+module_doc+args+"</desc>",
	    "counter":"<desc tag>"+replace(module_doc, "gtext", "gtext-url")+args+"</desc>"
  ]);
}

constant g_args=({"alt","border","bgcolor","fgcolor","trans","rotate","font","style","scale","size"});
constant a_args=({"add","addreal","case","cheat","database","factor","file","lang",
                 "minlength","padding","per","prec","reset","since","type"});

class TagCounter {
  inherit RXML.Tag;
  constant name = "counter";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  constant gtext = "gtext";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      mapping gtext_args=([]);
      mapping accessed_args=([]);

      foreach(g_args, string arg)
	if(args[arg]) gtext_args[arg]=args[arg];
      foreach(a_args, string arg)
	if(args[arg]) accessed_args[arg]=args[arg];

#ifdef OLD_RXML_COMPAT
      if(args->nfont) gtext_args->font=args->nfont;
      if(args->style) gtext_args->font=args->style;
      if(args->len) accessed_args->minlength=args->len;
      if(gtext_args->font=="ListAllFonts")
	return ({
	  "<table border='1'><tr><th>Name</th><th>Type</th><th>Sample</th></tr></table>"
	  "<emit source='fonts'><tr><td>&_.name;</td><td>&_.type;</td><td><gtext font='&_.name'>123</gtext></td></tr></emit>"
	  "</table>"
	});
#endif

      if(!gtext_args->font) gtext_args->font=query("font");

      string res=RXML.t_xml->
	format_tag( gtext, gtext_args,
		    RXML.t_xml->format_tag( "accessed", accessed_args ) );

#ifdef OLD_RXML_COMPAT
      if(args->bordercolor)
	res="<font color=\""+args->bordercolor+"\">"+res+"</font>";
#endif

      return ({ res });
    }
  }
}

class TagCounterURL {
  inherit TagCounter;
  constant name="counter-url";
  constant gtext="gtext-url";
}

#ifdef OLD_RXML_COMPAT
class TagCounter_URL {
  inherit TagCounter;
  constant name="counter_url";
  constant gtext="gtext_url";
}
#endif
