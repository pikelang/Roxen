// This is a roxen module. Copyright © 2000, Roxen IS.
//

//#pragma strict_types

#include <module.h>

inherit "module";

constant cvs_version = "$Id: preferred_language.pike,v 1.20 2000/12/29 23:24:44 nilsson Exp $";
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

constant language_low=roxen->language_low;
array(string) languages;
array(string) defaults;
void start() {
  // First get the available languages in ISO-639-2
  array(string) proper_codes = roxen->list_languages();  
  languages = proper_codes;
  foreach(proper_codes, string lang) {
    // Add all the old aliases too
    languages += (array(string))language_low(lang)->_aliases;
  }
  defaults=[array(string)]query("defaults")&languages;
}

RequestID first_try(RequestID id) {
  array(string) config = indices([multiset(string)]id->config);
  array(string) pre = indices([multiset(string)]id->prestate);

  array(string) lang = (pre&languages) + (config&languages);

  lang+=([object(PrefLang)]id->misc->pref_languages)->get_languages();

  // Array.uniq that preserves the order, which the one in pike
  // 7.0 doesn't.
  multiset exists = (<>);
  array tmp = ({});
  foreach( lang, string l )
    if(!exists[l]) {
      exists[l]=1;
      tmp += ({ l });
    }
  lang = tmp;

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
  "emit#languages":({ #"<desc plugin='plugin'><p><short>
 Outputs language descriptions.</short>It will output information
 associated to languages, such as the name of the language in
 different languages. A list of languages that should be output can
 be provided with the langs attribute. If no such attribute is used a
 generated list of present languages will be used. If such a list
 could not be generated the list provided in the Preferred Language
 Analyzer module will be used.</p>
</desc>

<attr name='langs'><p>
 Should contain comma separated list of language codes. The languages
 associated with these codes will be emitted in this order.</p>
</attr>",

		      ([
"&_.code;":#"<desc ent='ent'><p>
 The language code.</p>
</desc>",

"&_.en;":#"<desc ent='ent'><p>
 The language name in english.</p>
</desc>",

"&_.local;":#"<desc ent='ent'><p>
 The language name as written in the language itself.</p>
</desc>",

"&_.preurl;":#"<desc ent='ent'><p>
 A URL which makes this language the used one by altering
 prestates.</p>
</desc>",

"&_.confurl;":#"<desc ent='ent'><p>
 A URL which makes the language the used one by altering the roxen
 cookie.</p>
</desc>",

"&_.localized;":#"<desc ent='ent'><p>
 The language name as written in the currently selected language.</p>
</desc>"
		      ])
  })

]);
#endif
