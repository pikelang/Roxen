/*
 * $Id: english.pmod,v 1.1 2000/02/14 08:56:36 per Exp $
 *
 * Roxen locale support -- English
 *
 * Henrik Grubbström 1998-10-10
 */

inherit RoxenLocale.standard;
constant name        = "english";
constant language    = "language";
constant latin1_name = "english";

string module_doc_string( mixed module, string var, int long )
{
  return RoxenLocale.standard.module_doc_string( module, var, long );
}

void register_module_doc( mixed ... args )
{
  RoxenLocale.standard.register_module_doc( @args );
}
// English is the default language -- No need to do anything else.
