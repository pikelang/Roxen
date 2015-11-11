// The translation module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Translation module";
constant module_doc  = "This module provides an RXML API to the Pike localization system.";
constant thread_safe = 1;
constant cvs_version = "$Id$";




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
	Locale.register_project(args->project, args->path);
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
      if (!proj) RXML.parse_error("Missing translation project.\n");
      if (!args->id) RXML.parse_error("Missing translation identifier.\n");
      string trans = Locale.translate(proj, roxen.locale->get(),
				      (int)args->id || args->id,
				      content);

      if(args->variable) {
	RXML.user_set_var(args->variable, trans, args->scope);
	return 0;
      }

      result = trans;
      return 0;
    }
  }
}
