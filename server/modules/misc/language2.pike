// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>

inherit "module";
inherit "roxenlib";

constant cvs_version = "$Id: language2.pike,v 1.6 2000/03/16 18:57:13 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_URL | MODULE_PARSER;
constant module_name = "Language module II";
constant module_doc  = "Handles documents in different languages. "
            "What language a file is in is specified with an "
	    "extra extension. index.html.sv would be a file in swedish "
            "while index.html.en would be one in english. ";

void create() {
  defvar( "default_language", "en", "Default language", TYPE_STRING,
	  "The default language for this server. Is used when trying to "
	  "decide which language to send when the user hasn't selected any. "
	  "Also the language for the files with no language-extension." );

  defvar( "languages", ({"en","de","sv"}), "Languages", TYPE_STRING_LIST,
	  "The languages supported by this site." );

  defvar( "rxml", ({"html","rxml"}), "RXML extensions", TYPE_STRING_LIST,
	  "RXML parse files with the following extensions, "
	  "e.g. html make it so index.html.en gets parsed." );
}

string default_language;
array languages;
array rxml;
string cache_id;

void start(int n, Configuration c) {
  default_language=query("default_language");
  languages=query("languages");
  rxml=query("rxml");
  cache_id="lang_mod"+c->get_config_id();
}


// ------------- Find the best language file -------------

array(string) find_language(RequestID id) {
  array langs=id->misc->pref_languages->get_languages()+({default_language});
  return langs-(langs-languages);
}

object remap_url(RequestID id, string url) {
  if(!id->misc->language_remap) id->misc->language_remap=([]);
  if(id->misc->language_remap[url]==1) return 0;
  id->misc->language_remap[url]++;

  if(id->conf->stat_file(url, id)) return 0;

  // find files

  multiset(string) found;
  mapping(string:string) files;
  array split=cache_lookup(cache_id,url);
  if(!found) {
    found=(<>);
    files=([]);

    split=url/"/";
    string path=split[..sizeof(split)-2]*"/"+"/", file=split[-1];
    if(path=="/") return 0;

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


  // Remap

  foreach(find_language(id), string lang) {
    if(found[lang]) {
      url=fix_relative(url, id);
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

function translator(array(string) client, RequestID id) {
  client=({ id->misc->defines->language })+client+({ default_language });
  array(string) _lang=roxen->list_languages();
  foreach(client, string lang)
    if(has_value(_lang,lang)) {
      return roxen->language_low(lang)->language;
    }
}

class TagLanguage {
  inherit RXML.Tag;
  constant name = "language";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string lang=id->misc->defines->language;
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
      if(lang==id->misc->defines->language) return 0;
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
  "language":"<desc tag>Show the pages language.</desc>",
  "unavailable-language":"<desc cont>Show what language the user wanted, if this isn't it.</desc>"
]);
#endif
