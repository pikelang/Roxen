// import String;

/* Language support for numbers and dates. Very simple,
 * really. Look at one of the existing language plugins (not really
 * modules, you see..)
 *
 * $Id: language.pike,v 1.12 1998/02/10 18:36:04 per Exp $
 * This file is included by roxen.pike. Not very nice to have a
 * cvs_version variable here.
 *
 * WARNING:
 * If the environment variable 'ROXEN_LANG' is set, it is used as the default 
 * language.
 */

#include <roxen.h>

mapping languages = ([ ]);

import String;

void initiate_languages()
{
  string lang, *langs, p;
  langs = get_dir("languages");
  if(!langs)
  {
    report_fatal("No languages available!\n"+
		 "This is a serious error.\n"
		 "Most RXML tags will not work as expected!\n");
    return 0;
  }
  p = "Adding languages: ";
  foreach(langs, lang)
  {
    if(lang[-1] == 'e')
    {
      array tmp;
      string alias;
      object l;
      mixed err;
      p += String.capitalize(lang[0..search(lang, ".")-1])+" ";
      if (err = catch {
	l = compile_file("languages/"+lang)();
	if(tmp=l->aliases()) {
	  foreach(tmp, alias) {
	    languages[alias] = ([ "month":l->month,
				  "ordered":l->ordered,
				   "date":l->date,
			           "day":l->day,
			           "number":l->number,
			           "\000":l, /* Bug in Pike force this, as of
					      * 96-04-15. Probably fixed. */
			       ]);
	  }
	} 
      }) {
	report_error(sprintf("Initialization of language %s failed:%s\n",
			     lang, describe_backtrace(err)));
      }
    }
  }
  report_notice(p+"\n");
}

private string nil()
{
#ifdef LANGUAGE_DEBUG
  perror(sprintf("Cannot find that one in %O.\n", languages));
#endif
  return "No such function in that language, or no such language.";
}


string default_language = getenv("ROXEN_LANG")||"en";

/* Return a pointer to an language-specific conversion function. */
public function language(string what, string func)
{
#ifdef LANGUAGE_DEBUG
  perror("Function: " + func + " in "+ what+"\n");
#endif
  if(!languages[what])
    if(!languages[default_language])
      if(!languages->en)
	return nil;
      else
	return languages->en[func];
    else
      return languages[default_language][func];
  else
    return languages[what][func] || nil;
}


