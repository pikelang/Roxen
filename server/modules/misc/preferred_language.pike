// This is a roxen module. Copyright © 2000, Idonex AB.
//
inherit "module";

constant cvs_version = "$Id: preferred_language.pike,v 1.6 2000/02/16 07:15:51 per Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FIRST | MODULE_PARSER;
constant module_name = "Preferred Language Analyzer";
constant module_doc  = "Determine the clients preferred language based on \"accept-language\", prestates and cookies.";

void create() {
  defvar( "propagate", 0, "Propagate language", TYPE_FLAG,
	  "Should the most preferred language be propagated into the page.theme_language variable, "
	  "which in turn will control the default language of all multilingual RXML tags." );
  defvar( "defaults", ({}), "Present Languages", TYPE_STRING_LIST,
	  "A list of all languages present on the server." );
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
    else
      langs=defaults;

    string drop=(indices(id->config)&languages)*",";
    function localized=language_low(id->misc->pref_languages->get_language())->language;

    array res=({});
    foreach(langs, string lang) {
      array id=roxen->language_low(lang)->id();
      res+=({ (["code":id[0],
		"en":id[1],
		"local":id[2],
		"drop":drop,
		"localized":localized(lang) ]) });
    }
    return res;
  }
}
