// This is a roxen module. Copyright © 2000, Idonex AB.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: preferred_language.pike,v 1.2 2000/01/28 13:51:15 nilsson Exp $";
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
  array(string) config = indices(id->config);
  array(string) pre = indices(id->prestate);
  pre=pre-(pre-languages);
  config=config-(config-languages);

  array(float) qualities=({1.4})*sizeof(pre)+({1.2})*sizeof(config);

  array lang = pre-(pre-languages) +
    config-(config-languages);

  if(id->misc->pref_languages) {
    lang+=id->misc->pref_languages->get_languages();
    qualities+=id->misc->pref_languages->get_qualities();
  }

  if(query("propagate") && sizeof(lang)) {
    if(!id->misc->defines) id->misc->defines=([]);
    id->misc->defines->theme_language=lang[0];
  }

  id->misc->pref_languages->set_sorted(lang, qualities);
  return id;
}
