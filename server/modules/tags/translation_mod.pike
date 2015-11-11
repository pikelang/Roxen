// The translation module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Tags: Translation module";
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

  array(RXML.Type) result_types = ({ RXML.t_xml(RXML.PXml),
				     RXML.t_html(RXML.PXml),
				     RXML.t_text(RXML.PXml),
				     RXML.t_any(RXML.PXml) });

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
      
      return ({ trans });
    }
  }
}
TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

"trans-reg":#"<desc tag='tag'><p><short>
 Registers a locale project in the locale system.</short> Used
 internally by Roxen. You don't know how to use this tag. </p>
</desc>

<attr name='project' value='string'><p>
 The name of the project.</p></attr>

<attr name='path' value='string'><p>
 The path to the projects language files.</p></attr>
",

"translate":#"<desc tag='tag'><p><short>
 Translates the string to an apropriate string in the current
 locale.</short> Used internally by Roxen. You don't know how to use
 this tag.
</p></desc>

<attr name='id' value='string|number'><p>
 The ID of the string.</p></attr>

<attr name='project' value='string'><p>
 The name of the project in which to look up the string. If only one
 project is registered on the page the translation tag will default to
 that project.</p></attr>

<attr name='variable' value=''><p>
 If set, the string will be put in this variable instead of inserted
 into the current page.</p></attr>

<attr name='scope' value=''><p>
 The scope for the variable.</p></attr>
",

  ]);
#endif
