// import String;

/* Language support for numbers and dates. Very simple,
 * really. Look at one of the existing language plugins (not really
 * modules, you see..)
 *
 * $Id: language.pike,v 1.19 1999/10/04 15:11:54 per Exp $
 * This file is included by roxen.pike. Not very nice to have a
 * cvs_version variable here.
 *
 * WARNING:
 * If the environment variable 'ROXEN_LANG' is set, it is used as the default 
 * language.
 */

#include <roxen.h>

mapping languages = ([ ]);

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
  report_debug( "Adding languages ... ");
  int start = gethrtime();
  foreach(glob("*.pike",langs), lang)
  {
    if(lang[-1] == 'e')
    {
      array tmp;
      string alias;
      object l;
      mixed err;
      if (err = catch {
        l = (object)("languages/"+lang);
        roxenp()->dump( "languages/"+lang );
	if(tmp=l->aliases()) 
        {
	  foreach(tmp, alias) 
          {
	    languages[alias] = ([ "month":l->month,
				  "ordered":l->ordered,
                                  "date":l->date,
                                  "day":l->day,
                                  "number":l->number,
			       ]);
	  }
	} 
      }) {
	report_error(sprintf("Initialization of language %s failed:%s\n",
			     lang, describe_backtrace(err)));
      }
    }
  }
  
  report_debug( "Done [%4.2fms]\n", (gethrtime()-start)/1000.0 );
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


