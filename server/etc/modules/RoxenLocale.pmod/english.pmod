/*
 * $Id: english.pmod,v 1.2 2000/07/04 03:43:20 per Exp $
 *
 * Roxen locale support -- English
 *
 * Henrik Grubbström 1998-10-10
 */

inherit RoxenLocale.standard;
constant name        = "english";
constant language    = "language";
constant latin1_name = "english";

string module_doc_string(string var, int long)
{
  return (::module_doc_string(var,long) ||
	  RoxenLocale.standard.module_doc_string( var, long ));
}
// English is the default language -- No need to do anything else.
