// The translation module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Translation module";
constant module_doc  = "This module provides an RXML API to the Pike localization system.";
constant thread_safe = 1;
constant cvs_version = "$Id: translation_mod.pike,v 1.9 2000/11/02 22:40:58 nilsson Exp $";




// ------------------------ The tags -------------------------

class TagTranslationRegistration {
  inherit RXML.Tag;
  constant name = "trans-reg";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = 
    ([ "project" : RXML.t_text(RXML.PEnt) ]);

  mapping(string:RXML.Type) opt_arg_types = 
    ([ "path" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->path && args->path!="") {
#if constant(Locale.register_project)
	Locale.register_project(args->project, args->path);
#else
	RoxenLocale.register_project(args->project, args->path);
#endif
      }
      id->misc->translation_proj = args->project;
      result = "";
      return 0;
    }
  }
}

class TagTranslate {
  inherit RXML.Tag;
  constant name = "translate";

  mapping(string:RXML.Type) opt_arg_types = ([ 
    "id":RXML.t_text(RXML.PEnt),
    "project":RXML.t_text(RXML.PEnt),
    "variable":RXML.t_text(RXML.PEnt),
    "scope":RXML.t_text(RXML.PEnt) ]);
  
  class Frame {
    inherit RXML.Frame;
    
    array do_return( RequestID id ) {
      string proj = args->project || id->misc->translation_proj;
#if constant(Locale.translate)
      string trans = Locale.translate(proj, roxen.locale->get(),
				      (int)args->id || args->id,
				      content);
#else
      string trans = RoxenLocale.translate(proj, roxen.locale->get(),
					   (int)args->id || args->id,
					   content);
#endif

      if(args->variable) {
	RXML.user_set_var(args->variable, trans, args->scope);
	return 0;
      }

      result = trans;
      return 0;
    }
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

"trans-reg":#"<desc tag><p><short>Registers a locale project in the locale system.</short>
Used internally by Roxen. You don't know how to use this tag.
</p></desc>

<attr name='project' value='string'>The name of the project.</attr>
<attr name='path' value='string'>The path to the projects language files.</attr>
",

"translate":#"<desc tag><p><short>Translates the string to an apropriate string in the current locale. </short>
Used internally by Roxen. You don't know how to use this tag.
</p></desc>

<attr name='id' value='string|number'>The ID of the string.</attr>
<attr name='project' value='string'>
The name of the project in which to look up the string. If only one
project is registered on the page the translation tag will default to
that project.</attr>

<attr name='variable' value=''>
If set, the string will be put in this variable instead of inserted
into the current page.
</attr>

<attr name='scope' value=''>The scope for the variable.</attr>
",

  ]);
#endif
