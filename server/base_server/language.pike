/* Language support for numbers and dates. Very simple,
string cvs_version = "$Id: language.pike,v 1.5 1996/12/01 19:18:30 per Exp $";
 * really. Look at one of the existing language plugins (not really
 * modules, you see..)
 *
 * WARNING:
 * If the environment variable 'LANG' is set, it is used as the default 
 * language.
 */

private mapping languages = ([ ]);

void initiate_languages()
{
  string lang, *langs, p;
  langs = get_dir("languages");
  if(!langs)
  {
    this_object()->nwrite("No languages available!\n"+
			  "This is a serious error.\n"
			  "Most SPML tags will not work as expected!\n");
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
      p += capitalize(lang[0..search(lang, ".")-1])+" ";
      l = compile_file("languages/"+lang)();
      if(tmp=l->aliases())
      {
	foreach(tmp, alias)
	{
	  languages[alias] = ([ "month":l->month,
			       "ordered":l->ordered,
			       "date":l->date,
			       "day":l->day,
			       "number":l->number,
			      "\000":l, /* Bug in µLPC force this, as of
					 * 96-04-15 */
			     ]);
	}
      } 
    }
  }
  perror(p+"\n");
}

private string nil()
{
#ifdef LANGUAGE_DEBUG
  perror(sprintf("Cannot find that one in %O.\n", languages));
#endif
  return "No such function in that language, or no such language.";
}


string default_language = getenv("LANG")||"en";

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


