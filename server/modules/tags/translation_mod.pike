// The translation module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_PARSER;
constant module_name = "Translation module";
constant module_doc  = "This module provides an RXML API to the Pike localization system.";
constant thread_safe = 1;
constant cvs_version = "$Id: translation_mod.pike,v 1.6 2000/07/21 05:00:11 lange Exp $";




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
