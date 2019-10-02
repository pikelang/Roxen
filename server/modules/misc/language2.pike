// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

//#pragma strict_types

#include <module.h>

inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_URL | MODULE_TAG;
constant module_name = "Language module II";
constant module_doc  = "Handles documents in different languages. "
            "What language a file is in is specified with the "
	    "language code before the extension. index.sv.html would be a file in swedish "
            "while index.en.html would be one in english. ";

void create() {
  defvar( "default_language", "en", "Default language", TYPE_STRING,
	  "The default language for this server. Is used when trying to "
	  "decide which language to send when the user hasn't selected any." );

  defvar( "languages", ({"en","de","sv"}), "Languages", TYPE_STRING_LIST,
	  "The languages supported by this site." );
}

string default_language;
array(string) languages;
string cache_id;
array(string) roxen_languages;

void start(int n, Configuration c) {
  if(c->enabled_modules["content_editor#0"]) {
    call_out( c->disable_module, 0.5,  "language2#0" );
    report_error("Language II is not compatible with SiteBuilder content editor.\n");
    return;
  }

  default_language = lower_case([string]query("default_language"));
  languages = map([array(string)]query("languages"), lower_case);
  cache_id = "lang_mod"+c->get_config_id();

  mapping conv = Standards.ISO639_2.list_639_1();
  conv = mkmapping( values(conv), indices(conv) );
  roxen_languages = roxen->list_languages() +
    map(roxen->list_languages(), lambda(string in) { return conv[in]; });
  roxen_languages -= ({ 0 });
}


// ------------- Find the best language file -------------

object remap_url(RequestID id, string url) {
  if (!languages) return 0;   //  module not initialized
  if(!id->misc->language_remap) id->misc->language_remap=([]);
  if(id->misc->language_remap[url]==1) return 0;
  id->misc->language_remap[url]++;

  if(id->conf->stat_file(url, id)) return 0;

  // find files

  multiset(string) found;
  mapping(string:string) files;
  array split=[array]cache_lookup(cache_id,url);
  if(!split) {
    found=(<>);
    files=([]);

    split=url/"/";
    string path=split[..sizeof(split)-2]*"/"+"/", file=split[-1];

    id->misc->language_remap[path]=1;
    array realdir=id->conf->find_dir(path, id);
    if(!realdir) return 0;
    multiset dir=aggregate_multiset(@realdir);

    split=file/".";
    if(!sizeof(split)) split=({""});
    file=split[..sizeof(split)-2]*".";

    string this;
    foreach(languages, string lang) {
      string this=file+"."+lang+"."+split[-1];
      if(dir[this]) {
	found+=(<lang>);
	files+=([lang:path+this]);
      }
    }

    cache_set(cache_id, url, ({ found,files }) );
  }
  else
    [found,files]=split;

  //  Register known languages with the protocol cache
  PrefLanguages pl = id->misc->pref_languages;
  if (pl)
    pl->register_known_language_forks(found, id);
  
  //  Get language search order
  array(string) find_lang =
    (pl ? pl->get_languages() : ({ }) ) + ({ default_language });
  find_lang &= languages;
  
  //  Remap
  foreach(find_lang, string lang) {
    if(found[lang]) {
      url=Roxen.fix_relative(url, id);
      string type=id->conf->type_from_filename(url);

      if(!id->misc->defines) id->misc->defines=([]);
      id->misc->defines->language=lang;
      id->misc->defines->present_languages=found;
      id->not_query=files[lang];
      id->misc->language_remap=([]);
      return id;
    }
  }
  return 0;
}


// ---------------- Tag definitions --------------

function(string:string) translator(array(string) client, RequestID id) {
  client= ({ id->misc->defines->language }) + client + ({ default_language });

  foreach(client, string lang)
    if(has_value(roxen_languages,lang)) {
      return roxen->language_low(lang)->language;
    }
  return roxen->language_low("en")->language;
}

class TagLanguage {
  inherit RXML.Tag;
  constant name = "language";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string lang=([mapping(string:mixed)]id->misc->defines)->language;
      if(args->type=="code") {
	result=lang;
	return 0;
      }
      result=translator( ({}),id )(lang);
      return 0;
    }
  }
}

class TagUnavailableLanguage {
  inherit RXML.Tag;
  constant name = "unavailable-language";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string lang=id->misc->pref_languages->get_languages()[0];
      if(lang==([mapping(string:mixed)]id->misc->defines)->language) return 0;
      if(args->type=="code") {
	result=lang;
	return 0;
      }
      result=translator( ({}),id )(lang);
      return 0;
    }
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "language":"<desc type='tag'><p><short>Show the pages language.</short></p></desc>",
  "unavailable-language":"<desc type='cont'><p><short>Show what language the user "
                         "wanted, if this isn't it.</short></p></desc>"
]);
#endif
