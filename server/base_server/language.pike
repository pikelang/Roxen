/* Language support for numbers and dates. Very simple,
 * really. Look at one of the existing language plugins (not really
 * modules, you see..)
 *
 * Copyright © 1996 - 2000, Roxen IS.
 *
 * $Id: language.pike,v 1.26 2000/03/07 22:17:37 nilsson Exp $
 *
 * WARNING:
 * If the environment variable 'ROXEN_LANG' is set, it is used as the default
 * language.
 */

#pragma strict_types

private mapping(string:object) languages = ([ ]);

void initiate_languages()
{
  array(string) langs = get_dir("languages")-({"abstract.pike"});

  if(!langs)
  {
    report_fatal("No languages available!\n"+
		 "This is a serious error.\n"
		 "Many RXML tags will not work as expected!\n");
    return 0;
  }
  report_debug( "Adding languages ... ");
  int start = gethrtime();
  foreach(glob("*.pike",langs), string lang)
  {
    array(string) tmp;
    mixed err;
    if (err = catch {
      object l = (object)("languages/"+lang);
      roxenp()->dump( "languages/"+lang );
      if(tmp=([function(void:array(string))]l->aliases)())
	foreach(tmp, string alias)
	  languages[alias] = l;
    }) {
      report_error(sprintf("Initialization of language %s failed:%s\n",
			   lang, describe_backtrace(err)));
    }
  }

  report_debug( "Done [%4.2fms]\n", (gethrtime()-start)/1000.0 );
}

private string nil()
{
#ifdef LANGUAGE_DEBUG
  werror("Cannot find that one in %O.\n", languages);
#endif
  return "No such function in that language, or no such language.";
}

string default_language = [string]getenv("ROXEN_LANG")||"en";

/* Return a pointer to an language-specific conversion function. */
public function language(string what, string func, object|void id)
{
#ifdef LANGUAGE_DEBUG
  werror("Function: " + func + " in "+ what+"\n");
#endif
  object l;
  if( id && id->set_output_charset && (l=languages[what]) && l->charset )
    ([function(string,int:void)]id->set_output_charset)( [string]l->charset, 2 );

  if(!l)
    if(!(l=languages[default_language]))
      if(!(l=languages->en))
	return [function]languages->en[func];

  return [function]l[func] || nil;
}

array list_languages() {
  return indices(languages);
}

object language_low(string what) {
  return languages[what];
}
