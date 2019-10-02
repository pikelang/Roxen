/*
 * $Id$
 */

#if constant (Nettle)

inherit "ssl_common.pike";
inherit "wizard";
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "SSL";

string name = LOCALE(118, "Generate a new RSA key pair...");
string doc = doc_string_start + doc_string_end_a +
	      LOCALE(119, "Note that it is possible to have more than one "
		     "certificate for the same key.");


/* In ssl_common.pike:
 *
 * mixed page_0(object id, object mc)
 * mixed verify_0(object id, object mc)
 */


mixed wizard_done(object id, object mc)
{
  return http_string_answer( sprintf( LOCALE(120,"Wrote %d-bit key in %s")+
				      "<p><cf-ok/></p>",
                                      (int)id->variables->key_size,
                                      combine_path(getcwd(),
                                                   id->variables->key_file)) );
}

mixed parse( RequestID id ) { return wizard_for(id,0); }

#endif /* constant (Nettle) */
