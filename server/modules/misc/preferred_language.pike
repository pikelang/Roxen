// This is a roxen module. Copyright © 2000, Idonex AB.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: preferred_language.pike,v 1.1 2000/01/23 07:59:07 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FIRST;
constant module_name = "Preferred Language Analyzer";
constant module_doc  = "Determine the clients preferred language based on \"accept-language\", prestates and cookies.";

void create() {
  defvar( "propagate", 0, "Propagate language", TYPE_FLAG,
	  "Should the most preferred language be propagated into the page.theme_language variable, "
	  "which in turn will control the default language of all multilingual RXML tags." );
}

array languages;
void start() {
  languages=indices(roxen->languages);
}

RequestID first_try(RequestID id) {
  array config = indices(id->config);
  array pre = indices(id->prestate);
  array lang = pre-(pre-languages) +
    config-(config-languages) +
    (id->misc->pref_languages|| ({}) );

  if(query("propagate") && sizeof(lang)) {
    if(!id->misc->defines) id->misc->defines=([]);
    id->misc->defines->theme_language=lang[0];
  }

  id->misc->pref_languages=lang;
  return id;
}
