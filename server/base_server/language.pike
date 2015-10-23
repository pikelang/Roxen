// Roxen Locale Support
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

#pragma strict_types

#include <roxen.h>
#define PROJECT "languages"

string default_locale;
//! Contains the default locale for the entire roxen server.

string default_page_locale;
//! Contains the default locale for web pages.

#ifdef THREADS
Thread.Local locale = thread_local();
#else
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

container locale = container();
#endif /* THREADS */

int(0..1) set_locale(void|string lang)
  //! Changes the locale of the current thread. If no
  //! argument is given, the default locale if used.
  //! Valid arguments are ISO-639-2 codes, ISO-639-1
  //! codes and the old symbolic names. No argument or
  //! zero sets the locale to the default locale.
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
protected mapping(string:string) compat_languages = ([
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
     Standards.ISO639_2.get_language(lang)
     )
    return lang;
  else if(sizeof(lang)==2 &&
	  (set = Standards.ISO639_2.map_639_1(lang))
	  )
    return set;
  else
    if(set = compat_languages[lang])
      return set;

  return 0;  // Enables fallback to default_locale
}

void set_default_locale(string def_loc)
{
  def_loc = lower_case(def_loc);

  string tmp;
  if(def_loc != "standard") {
    // Default locale from Globals
    tmp = def_loc;
  }
  else if ((tmp = [string] (getenv("LC_MESSAGES") || getenv("LANG")))) {
    // Try default locale from environment
    sscanf(tmp, "%s_%*s", tmp);   //Handle e.g. en_US
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
  report_debug("Default locale set to %O. ", default_locale);
#endif
}

void initiate_languages(string def_loc)
{
  report_debug( "Adding languages ... \b");
  int start = gethrtime();

  set_default_locale(def_loc);

  Locale.register_project(PROJECT, "languages/_xml_glue/%L.xml");

  // Atleast read the default_locale, to make sure that fallback is ok.
  if(!Locale.get_object(PROJECT, default_locale))
    report_fatal("\n* The default language %O is not available!\n"
		 "* This is a serious error.\n"
		 "* Several RXML tags might not work as expected!\n",
		 default_locale);

  report_debug( "\bDone [%4.2fms]\n", (gethrtime()-start)/1000.0 );
}



// ------------- The language functions ------------

protected string nil()
{
#ifdef LANGUAGE_DEBUG
  report_debug("Cannot find that one in %O.\n", list_languages());
#endif
  return "No such function in that language, or no such language.";
}

/* Return a pointer to an language-specific conversion function. */
function language(string lang, string func, object|void id)
{
#ifdef LANGUAGE_DEBUG
  report_debug("Function: '" + func + "' in "+ verify_locale(lang) +"\n");
#endif
  return Locale.call(PROJECT, verify_locale(lang), 
		     func, default_page_locale) || nil;  
}

array(string) list_languages() {
  return Locale.list_languages(PROJECT);
}

object language_low(string lang) {
  object locale_obj = Locale.get_object(PROJECT, verify_locale(lang));
  return locale_obj && [object] locale_obj->functions;
}
