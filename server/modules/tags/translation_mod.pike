// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_PARSER;
constant module_name = "Translation module";
constant module_doc  = "This module provides an RXML API to the Pike localization system.";


// ------------------------ The tags -------------------------

class TagTranslationRegistration {
  inherit RXML.Tag;
  constant name = "trans-reg";
  constant flags = RXML.FLAG_EMPTY_ENTITY;

  mapping(string:RXML.Type) req_arg_types = ([ "project":RXML.t_text,
					       "path":RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
#if constant(Locale.register_project)
      Locale.register_project(args->project, args->path);
#else
      RoxenLocale.register_project(args->project, args->path);
#endif
      result = "";
      return 0;
    }
  }
}

class TagTranslate {
  inherit RXML.Tag;
  constant name = "translate";

  mapping(string:RXML.Type) req_arg_types = ([ "project":RXML.t_text,
					       "id":RXML.t_text ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "variable":RXML.t_text,
					       "scope":RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
#if constant(Locale.transtale)
      string trans = Locale.translate(roxen.locale->get()[args->project],
				      args->id,
				      content);
#else
      string trans = RoxenLocale.translate(roxen.locale->get()[args->project],
					   args->id,
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
