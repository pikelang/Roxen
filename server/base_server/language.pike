// Roxen Locale Support
// Copyright © 1996 - 2000, Roxen IS.
// $Id: language.pike,v 1.32 2000/09/08 22:50:20 nilsson Exp $

// #pragma strict_types

#include <roxen.h>
#define PROJECT "languages"

string default_locale;
//! Contains the default locale for the entire roxen server.

string default_page_locale;
//! Contains the default locale for web pages.

#ifndef THREADS
// Emulates a thread_local() object.
class container
{
  mixed value;
  mixed set(mixed to)
  {
    return value=to;
  }
  mixed get()
  {
    return value;
  }
}
#endif

#if constant( thread_local )
object locale = thread_local();
#else
object locale = container();
#endif /* THREADS */

int set_locale(void|string lang)
  //! Changes the locale of the current thread. If no
  //! argument is given, the default locale if used.
  //! Valid arguments are ISO-639-2 codes, ISO-639-1
  //! codes and the old symbolic names.
{
  string set;
  if( !(set = verify_locale(lang)) ) {
    if( lang!=default_locale )
      // lang not ok, try default_locale
      set_locale( default_locale );
    return 0;
  }
  locale->set( set );
  return 1;
}

// Compatibility mapping
static mapping(string:string) compat_languages = ([
  "english":"eng",
  "standard":"eng",
  "svenska":"swe",
  "nihongo":"jpn",
  "cestina":"ces",
  "deutsch":"deu",
  "magyar":"hun",
  "nederlands":"nld",
]);


string verify_locale(string lang) {
  if(!lang)
    return default_locale;

  string set;
  if(sizeof(lang)==3 &&
#if constant(Standards.ISO639_2)
     Standards.ISO639_2.get_language(lang)
#else
     RoxenLocale.ISO639_2.get_language(lang)
#endif
     )
    return lang;
  else if(sizeof(lang)==2 &&
#if constant(Standards.ISO639_2)
	  (set = Standards.ISO639_2.map_639_1(lang))
#else
	  (set = RoxenLocale.ISO639_2.map_639_1(lang))
#endif
	  )
    return set;
  else
    if(set = compat_languages[lang])
      return set;

  return "eng";
}

void initiate_languages(string def_loc)
{
  report_debug( "Adding languages ... ");
  int start = gethrtime();

  string tmp;
  if(def_loc != "standard") {
    // Default locale from Globals
    tmp = def_loc;
  }
  else if(getenv("LANG")) {
    // Default locale from environment
    tmp = [string]getenv("LANG");
    sscanf(tmp, "%s_%*s", tmp);
  }

  default_locale=verify_locale(tmp);

  if(!default_locale) {
    // Failed to set locale, fallback to English
    default_locale = "eng";
  }

  if(getenv("ROXEN_LANG")) {
    default_page_locale = verify_locale([string]getenv("ROXEN_LANG"));
  }
  else
    default_page_locale = default_locale;

#ifdef LANGUAGE_DEBUG
  werror("Default locale is set to %O.\n",default_locale);
#endif

  __LOCALEMODULE.register_project(PROJECT, "languages/_xml_glue/%L.xml");

  // Atleast read the default_locale, to make sure that fallback is ok.
  if(!__LOCALEMODULE.get_object(PROJECT, default_locale))
    report_fatal("\n* The default language %O is not available!\n"
		 "* This is a serious error.\n"
		 "* Several RXML tags might not work as expected!\n",
		 default_locale);

  report_debug( "Done [%4.2fms]\n", (gethrtime()-start)/1000.0 );
}



// ------------- The language functions ------------

static string nil()
{
#ifdef LANGUAGE_DEBUG
  werror("Cannot find that one in %O.\n", list_languages());
#endif
  return "No such function in that language, or no such language.";
}

/* Return a pointer to an language-specific conversion function. */
public function language(string lang, string func, object|void id)
{
#ifdef LANGUAGE_DEBUG
  werror("Function: " + func + " in "+ verify_locale(lang) +"\n");
#endif
  return __LOCALEMODULE.call(PROJECT, verify_locale(lang), 
			     func, default_page_locale) || nil;  
}

array(string) list_languages() {
  return __LOCALEMODULE.list_languages(PROJECT);
}

object language_low(string lang) {
  return [object]__LOCALEMODULE.get_object( PROJECT, 
					    verify_locale(lang) )->functions;
}
