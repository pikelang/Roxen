// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>

inherit "module";
inherit "roxenlib";

constant cvs_version = "$Id: preferred_language.pike,v 1.8 2000/03/16 18:57:14 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FIRST | MODULE_PARSER;
constant module_name = "Preferred Language Analyzer";
constant module_doc  = "Determine the clients preferred language based on \"accept-language\", prestates and cookies.";

void create() {
  defvar( "propagate", 0, "Propagate language", TYPE_FLAG,
	  "Should the most preferred language be propagated into the page.theme_language variable, "
	  "which in turn will control the default language of all multilingual RXML tags." );
  defvar( "defaults", ({}), "Present Languages", TYPE_STRING_LIST,
	  "A list of all languages present on the server. An empty list means no restrictions." );
}

constant language_low=roxen->language_low;
array languages;
array defaults;
void start() {
  languages=roxen->list_languages();
  defaults=query("defaults")&languages;
}

RequestID first_try(RequestID id) {
  array(string) config = indices(id->config);
  array(string) pre = indices(id->prestate);
  pre=pre-(pre-languages);
  config=config-(config-languages);

  array lang = (pre&languages) + (config&languages);

  lang+=id->misc->pref_languages->get_languages();

  if(sizeof(defaults))
    lang=lang&defaults;

  if(query("propagate") && sizeof(lang)) {
    if(!id->misc->defines) id->misc->defines=([]);
    id->misc->defines->theme_language=lang[0];
  }

  id->misc->pref_languages->set_sorted(lang);
  return id;
}

class TagEmitLanguages {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "languages";

  array get_dataset(mapping m, RequestID id) {
    array langs;
    if(m->langs)
      langs=(m->langs/",")&languages;
    else if(id->misc->defines->present_languages)
      langs=indices(id->misc->defines->present_languages);
    else
      langs=defaults;

    function localized=language_low(id->misc->pref_languages->get_language())->language;
    string url=strip_prestate(strip_config(id->raw_url));
    array conf_langs=Array.map(indices(id->config) & languages,
			       lambda(string lang) { return "-"+lang; } );

    array res=({});
    foreach(langs, string lang) {
      array lid=roxen->language_low(lang)->id();
      res+=({ (["code":lid[0],
		"en":lid[1],
		"local":lid[2],
		"preurl":add_pre_state(url, id->prestate-aggregate_multiset(@languages)+(<lang>)),
		"confurl":add_config(url, conf_langs+({lang}), id->prestate),
		"localized":localized(lang) ]) });
    }
    return res;
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "emit#languages":"<desc plugin>Outputs language descriptions</desc>"
]);
#endif
