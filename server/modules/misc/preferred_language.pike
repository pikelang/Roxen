// This is a roxen module. Copyright © 2000, Roxen IS.
//

//#pragma strict_types

#include <module.h>

inherit "module";

constant cvs_version = "$Id: preferred_language.pike,v 1.18 2001/07/03 01:02:46 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FIRST | MODULE_TAG;
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

constant alias = ({
  "ca",
  "catala",
  "es_CA",
  "cs",
  "cz",
  "cze",
  "czech",
  "de",
  "deutsch",
  "german",
  "en",
  "english",
  "fi",
  "finnish",
  "fr",
  "français",
  "french",
  "hr",
  "cro",
  "croatian",
  "hu",
  "magyar",
  "hungarian",
  "it",
  "italiano",
  "italian",
  "kj",
  "kanji",
  "jp",
  "japanese",
  "nihongo",
  "\62745\63454\105236",
  "mi",
  "maori",
  "maaori",
  "du",
  "nl",
  "ned",
  "dutch",
  "no",
  "norwegian",
  "norsk",
  "pl",
  "po",
  "polish",
  "pt",
  "port",
  "portuguese",
  "ru",
  "russian",
  "\2062\2065\2063\2063\2053\2051\2052",
  "si",
  "svn",
  "slovenian",
  "es",
  "esp",
  "spanish",
  "sr",
  "ser",
  "serbian",
  "sv",
  "se",
  "sve",
  "swedish",
  "svenska"
});

constant language_low=roxen->language_low;
array(string) languages;
array(string) defaults;
void start() {
  languages = roxen->list_languages() + alias;
  defaults=[array(string)]query("defaults")&languages;
}

RequestID first_try(RequestID id) {
  array(string) config = indices([multiset(string)]id->config);
  array(string) pre = indices([multiset(string)]id->prestate);

  array(string) lang = (pre&languages) + (config&languages);

  lang+=([object(PrefLang)]id->misc->pref_languages)->get_languages();

  lang = Array.uniq(lang);

  if(sizeof(defaults))
    lang=lang&defaults;

  if(query("propagate") && sizeof(lang)) {
    if(!id->misc->defines) id->misc->defines=([]);
    ([mapping(string:mixed)]id->misc->defines)->theme_language=lang[0];
  }

  ([object(PrefLang)]id->misc->pref_languages)->set_sorted(lang);
  return 0;
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
					     ->get_language()||"eng" )->language;

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
