// This is a roxen module. Copyright © 2000, Roxen IS.
//

//#pragma strict_types

#include <module.h>

inherit "module";

constant cvs_version = "$Id: preferred_language.pike,v 1.12 2000/05/12 13:09:07 nilsson Exp $";
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

class PrefLang {
  array(string) get_languages();
  string get_language();
  void set_sorted(array(string));
}

constant language_low=roxen->language_low;
array(string) languages;
array(string) defaults;
void start() {
  languages=roxen->list_languages();
  defaults=[array(string)]query("defaults")&languages;
}

RequestID first_try(RequestID id) {
  array(string) config = indices([multiset(string)]id->config);
  array(string) pre = indices([multiset(string)]id->prestate);

  array(string) lang = (pre&languages) + (config&languages);

  lang+=([object(PrefLang)]id->misc->pref_languages)->get_languages();

  if(sizeof(defaults))
    lang=lang&defaults;

  if(query("propagate") && sizeof(lang)) {
    if(!id->misc->defines) id->misc->defines=([]);
    ([mapping(string:mixed)]id->misc->defines)->theme_language=lang[0];
  }

  ([object(PrefLang)]id->misc->pref_languages)->set_sorted(lang);
  return id;
}

class TagEmitLanguages {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "languages";

  array get_dataset(mapping m, RequestID id) {
    array(string) langs;
    if(m->langs)
      langs=([string]m->langs/",")&languages;
    else if( ([mapping(string:mixed)]id->misc->defines)->present_languages )
      langs=indices( [multiset(string)]([mapping(string:mixed)]id->misc->defines)->present_languages );
    else
      langs=defaults;

    function(string:string) localized=
      [function(string:string)]language_low( ([object(PrefLang)]id
					      ->misc->pref_languages)
					     ->get_language() )->language;

    string url=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));
    array(string) conf_langs=Array.map(indices(id->config) & languages,
			       lambda(string lang) { return "-"+lang; } );

    array res=({});
    foreach(langs, string lang) {
      array(string) lid=[array(string)]([object]roxen->language_low(lang))->id();
      res+=({ (["code":lid[0],
		"en":lid[1],
		"local":lid[2],
		"preurl":Roxen.add_pre_state(url, id->prestate-aggregate_multiset(@languages)+(<lang>)),
		"confurl":Roxen.add_config(url, conf_langs+({lang}), id->prestate),
		"localized":localized(lang) ]) });
    }
    return res;
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "emit#languages":({ #"<desc plugin><short>Outputs language descriptions.</short>
It will output information associated to languages, such as the name of the language in
different languages. A list of languages that should be outputed can be provided with the langs
attribute. If no such attribute is used a generated list of present languages will be used. If
such a list could not be generated the list provided in the Preferred Language Analyzer module
will be used.</desc>
<attr name=langs>Should contain comma seperated list of language codes. The languages
associated with these codes will be emitted in this order.</attr>
",
		      ([
			"&_.code;":"<desc ent>The language code.</desc>",
			"&_.en;":"<desc ent>The language name in english.</desc>",
			"&_.local;":"<desc ent>The language name as written in the language itself.</desc>",
			"&_.preurl;":#"<desc ent>A URL which makes this language the used one by altering
prestates.</desc>",
			"&_.confurl;":#"<desc ent>A URL which makes the language the used one by altering
the roxen cookie.</desc>",
			"&_.localized;":#"<desc ent>The language name as written in the currently
selected language.</desc>"
		      ])
  })

]);
#endif
