/*
 * $Id: generate_rsa.pike,v 1.7 2002/06/13 00:18:09 nilsson Exp $
 */

#if constant(_Crypto) && constant(Crypto.rsa)

inherit "ssl_common.pike";
inherit "wizard";

constant task = "SSL";
constant name = "Generate a new RSA key pair...";
constant  doc = (doc_string_start + doc_string_end_a +
		 "Note that it is possible to have more than one "
		 "certificate for the same key.");


/* In ssl_common.pike:
 *
 * mixed page_0(object id, object mc)
 * mixed verify_0(object id, object mc)
 */


mixed wizard_done(object id, object mc)
{
  return http_string_answer( sprintf( "Wrote %d-bit key in %s<p><cf-ok/></p>",
                                      (int)id->variables->key_size,
                                      combine_path(getcwd(),
                                                   id->variables->key_file)) );
}

mixed parse( RequestID id ) { return wizard_for(id,0); }

#endif /* constant(_Crypto) && constant(Crypto.rsa) */
