/* Language support for numbers and dates. Very simple,
 * really. Look at one of the existing language plugins (not really
 * modules, you see)
 *
 * The languagefiles are loaded on demand and cached through the 
 * Locale-api.
 *
 * Copyright © 1996 - 2000, Roxen IS.
 *
 * $Id: language.pike,v 1.30 2000/07/30 02:41:01 lange Exp $
 *
 * WARNING:
 * If the environment variable 'ROXEN_LANG' is set, it is used as the default
 * language.
 */

#pragma strict_types

#include <roxen.h>
#define PROJECT "languages"

string default_language;

static string fix_lang(string l) {
  if(!l)
    return default_language;
  if(sizeof(l)==2) {
#if constant(Standards.ISO639_2)
    return Standards.ISO639_2.map_639_1(l);
#else
    return RoxenLocale.ISO639_2.map_639_1(l);
#endif
  }
  return l;
}

void initiate_languages()
{
  report_debug( "Adding languages ... ");
  int start = gethrtime();

  default_language = fix_lang([string]getenv("ROXEN_LANG")) || "eng";

  __LOCALEMODULE.register_project(PROJECT, "languages/_xml_glue/%L.xml");

  // Atleast read the default_language, to make sure that fallback is ok.
  if(!__LOCALEMODULE.get_object(PROJECT, default_language))
    report_fatal("\n* The default language %O is not available!\n"
		 "* This is a serious error.\n"
		 "* Several RXML tags might not work as expected!\n",
		 default_language);

  report_debug( "Done [%4.2fms]\n", (gethrtime()-start)/1000.0 );
}

static string nil()
{
#ifdef LANGUAGE_DEBUG
  werror("Cannot find that one in %O.\n", languages);
#endif
  return "No such function in that language, or no such language.";
}

/* Return a pointer to an language-specific conversion function. */
public function language(string lang, string func, object|void id)
{
#ifdef LANGUAGE_DEBUG
  werror("Function: " + func + " in "+ fix_lang(lang) +"\n");
#endif
  return __LOCALEMODULE.call(PROJECT, fix_lang(lang), 
			     func, default_language) || nil;  
}

array(string) list_languages() {
  return __LOCALEMODULE.list_languages(PROJECT);
}

object language_low(string lang) {
  return [object]__LOCALEMODULE.get_object( PROJECT, 
					    fix_lang(lang) )->functions;
}
