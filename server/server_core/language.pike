// ChiliMoon Locale Support
// Copyright © 1996 - 2001, Roxen IS.
// $Id: language.pike,v 1.42 2003/01/19 18:33:02 mani Exp $

#pragma strict_types

#include <roxen.h>

string default_locale;
//! Contains the default locale for the entire ChiliMoon server.

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
  else if(getenv("LANG")) {
    // Try default locale from environment
    tmp = [string]getenv("LANG");
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
  report_debug("Default locale set to %O.\n", default_locale);
#endif
}

void initiate_languages(string def_loc)
{
  set_default_locale(def_loc);
  language_list = filter(indices(Locale.Language),
			 lambda(string in) {
			   return sizeof(in)==3;
			 } );
}


// ------------- The language functions ------------

static string nil_l() {
  return "No such language.";
}

static string nil_f() {
  return "No such function in that language.";
}

/* Return a pointer to an language-specific conversion function. */
public function language(string lang, string func, object|void id)
{
#ifdef LANGUAGE_DEBUG
  report_debug("Function: %O in %O (%O)\n", func, verify_locale(lang), lang);
#endif
  lang  = verify_locale(lang);
  if(!lang) return nil_l;
  return [function]([object]Locale.Language[lang])[func] || nil_f;
}

static array(string) language_list;
array(string) list_languages() {
  return language_list+({});
}

object language_low(string lang) {
  return [object]Locale.Language[verify_locale(lang)];
}
