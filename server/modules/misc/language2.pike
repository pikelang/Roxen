// This is a roxen module. Copyright © 2000, Idonex AB.
//

#include <module.h>
inherit "module";
inherit "roxenlib";

constant cvs_version = "$Id: language2.pike,v 1.2 2000/01/17 21:15:34 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_URL | MODULE_PARSER;
constant module_name = "Language module II";
constant module_doc  = "Handles documents in different languages. "
            "What language a file is in is specified with an "
	    "extra extension. index.html.sv would be a file in swedish "
            "while index.html.en would be one in english. ";

void create()
{
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


#define MAX_FOUND_SIZE 4096
mapping found_cache=([]);
multiset(string) find_files(string url, RequestID id) {
  if(found_cache[url]) return found_cache[url];

  array split=url/"/";
  string path=split[..sizeof(split)-2]*"/", file=split[-1];
  multiset found=(<>);
  if(path=="") return found;
  array realdir=id->conf->find_dir(path, id);
  if(!realdir) return found;
  multiset dir=aggregate_multiset(@realdir);

  foreach(query("languages"), string lang)
    if(dir[file+"."+lang]) found+=(<lang>);

  if(sizeof(found_cache)>MAX_FOUND_SIZE) found_cache=([]);
  found_cache[url]=found;
  return found;
}

array(string) find_language(RequestID id) {
  array langs=indices(id->prestate)+
    (id->cookies->RoxemConfig?id->cookies->RoxenConfig/",":({}))+
    (((id->request_headers["accept-language"]||"")-" ")/"," || ({}) )+
    ({query("default_language")});
  return langs-(langs-query("languages"));
}

mixed remap_url( RequestID id, string url )
{
  if(id->misc->language_remap) return 0;
  id->misc->language_remap=1;
  if(id->conf->stat_file(url, id)) return 0;

  multiset found=find_files(url, id);
  foreach(find_language(id), string lang) {
    if(found[lang]) {
      url=fix_relative(url, id);
      string type=id->conf->type_from_filename(url);
      if(search(query("rxml"),extension(url))!=-1) {
	if(!id->misc->defines) id->misc->defines=([]);
	id->misc->defines->language=lang;
	return http_string_answer(parse_rxml(id->conf->try_get_file(url+"."+lang, id), id));
      }

      array path=id->conf->real_file(url+"."+lang, id)/"/";
      return http_file_answer(Stdio.File(path[..sizeof(path)-2]*"/"+"/"+
					 reverse(url/"/")[0]+"."+lang, "r"),
			      type);
      }
  }
  return 0;
}

string tag_language(string t, mapping m, RequestID id) {
  string lang=id->misc->defines->language;
  if(m->type=="short") return lang;
  object tmp=roxen->languages[lang];
  function trans=tmp?tmp->language:roxen->languages[query("default_language")]->language;
  return trans(lang);
}

string tag_unavailable_language(string t, mapping m, RequestID id) {
  string lang=find_language(id)[0];
  if(lang==id->misc->defines->language) return "";
  if(m->type=="short") return lang;
  object tmp=roxen->languages[lang];
  function trans=tmp?tmp->language:roxen->languages[query("default_language")]->language;
  return trans(lang);
}

string container_languages(string t, mapping m, string c, RequestID id) {
  object tmp=roxen->languages[find_language(id)[0]];
  function trans=tmp?tmp->language:roxen->languages[query("default_language")]->language;

  string ret="", url=strip_prestate(strip_config(id->raw_url));

  array conf_langs=id->cookies->RoxenConfig?id->cookies->RoxenConfig/",":({});
  conf_langs=Array.map(conf_langs-(conf_langs-query("languages")),
		       lambda(string lang) { return "-"+lang; } );

  foreach(query("languages"), string lang) {
    ret+=replace(c, ({"&short;", "&long;", "&preurl;", "&confurl;" }),
		 ({lang,
		   trans(lang)||"",
		   add_pre_state(url, id->prestate-aggregate_multiset(@query("languages"))+(<lang>)),
		   add_config(url, conf_langs+({lang}), id->prestate)
		 }) );
  }
  return ret;
}
