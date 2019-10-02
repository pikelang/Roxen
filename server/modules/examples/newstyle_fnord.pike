// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

// This is a small sample module intended to show how a newstyle tag
// is written. Note that this is only a very brief overview and that
// the new parser is still under development and incompatible changes
// might be done in the future.

// See fnord.pike for more information of what this tag does.

// This variable is shown in the configinterface as the version of the module.
constant cvs_version = "$Id$";

// Tell Roxen that this module is threadsafe.
constant thread_safe=1;

// Inherit code that is needed in every module.
inherit "module";


// module.h must be included to use the LOCALE macro below.
#include <module.h>
// Some defines for the translation system
// 
//<locale-token project="mod_newstyle_fnord">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_newstyle_fnord",X,Y)
// end of the locale related stuff


// Define the fnord tag class. It must begin with "Tag".
class TagFnord {
  inherit RXML.Tag;

  // This constant tells the parser that the tag should be called "fnord".
  constant name  = "fnord";

  // Declare the type of the attribute, which happens to be optional.
  // Since we declare it to be text, we really don't need this line to
  // get things to work.
  mapping(string:RXML.Type) opt_arg_types = ([ "alt" : RXML.t_text(RXML.PEnt) ]);

  // This class is where all the action are.
  class Frame {
    inherit RXML.Frame;

    // When the parser starts to parse the tag it calls
    // do_enter. We get a normal request object as argument.
    // We also have an args mapping at our disposal, containing
    // the attributes given to the tag.

    // When do_enter has been called the function do_iterate
    // will be called. If do_iterate is a number, as in this case,
    // the contents will be iterated that number of times.

    // Finally we want to set the return value if the attribute
    // alt is set. We do this by modifying the result string.

    array do_enter(RequestID id) {
      if(id->prestate->fnord)
	do_iterate=0;
      else {
	if(args->alt)
	  result=args->alt;
	do_iterate=-1;
      }
      return 0;
    }

    int do_iterate;
  }
}


// Some constants to register the module in the RXML parser.

constant module_type = MODULE_TAG;
LocaleString module_name = LOCALE(3,"Newstyle Fnord!");
LocaleString module_doc  =
  LOCALE(4,"Adds an extra container tag, &lt;fnord&gt; that's supposed "
	 "to make things invisible unless the \"fnord\" prestate is present."
	 "<p>This module is here as an example of how to write a "
	 "very simple newstyle RXML-parsing module.</p>");

// Last, but not least, we want a documentation that can be integrated in the
// online manual. The mapping tagdoc maps from container names to it's description.

// Include this is if you use the TAGDOC system.
#include <module.h>

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["fnord":#"<desc type='cont'>The fnord container tag hides its "
  "contents for the user, unless the fnord prestate is used.</desc>"
  "<attr name=alt value=string>An alternate text that should be written "
  "in place of the hidden text.</attr>"]);
#endif
