/*
 * $Id: english.pmod,v 1.3 2000/07/09 14:09:46 per Exp $
 *
 * Roxen locale support -- English
 *
 * Henrik Grubbström 1998-10-10
 */

inherit RoxenLocale.standard;
constant name        = "english";
constant language    = "language";
constant latin1_name = "english";

string module_doc_string(int var, int long)
{
  return (::module_doc_string(var,long) ||
	  RoxenLocale.standard.module_doc_string( var, long ));
}
// English is the default language -- No need to do anything else.
