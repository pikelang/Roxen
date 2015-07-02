/*
 * $Id$
 */

#if constant (Nettle)

inherit "ssl_common.pike";
inherit "wizard";
#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

import Standards.PKCS;
import Standards.ASN1.Types;

constant action = "SSL";

string name= LOCALE(132, "Generate an RSA key and a Self Signed Certificate...");
string doc = doc_string_start + doc_string_end_b;


/* In ssl_common.pike:
 *
 * mixed page_0(object id, object mc)
 * mixed verify_0(object id, object mc)
 */


mixed page_1(mixed id, mixed mc)
{
  return certificate_parameters;
}

mixed page_2(object id, object mc)
{
  return certificate_TTL;
}

mixed verify_2(object id, object mc)
{
  if ( ( (int) id->variables->ttl) <= 0)
  {
    id->variables->_error = "Invalid certificate lifetime; must be positive.";
    return 1;
  }

  return 0;
}

mixed page_3(object id, object mc)
{
  object file;

  object privs = Privs("Reading private RSA key");
  if (!(file = lopen(id->variables->key_file, "r")))
  {
    privs = 0;

    return "<font color='red'>Could not open key file: "
      + strerror(errno()) + "\n</font>";
  }
  privs = 0;
  string s = file->read(0x10000);
  if (!s)
    return "<font color=red>Could not read private key: "
      + strerror(file->errno()) + "\n</font>";

  object msg = Tools.PEM.pem_msg()->init(s);
  object part = msg->parts["RSA PRIVATE KEY"];

  if (!part)
    return "<font color='red'>Key file not formatted properly.\n</font>";

  object rsa = RSA.parse_private_key(part->decoded_body());

  if (!rsa)
    return "<font color='red'>Invalid key.\n</font>";

  mapping attrs = ([]);
  string attr;

  /* Remove initial and trailing whitespace, and ignore
   * empty attributes. */
  foreach( ({ "countryName", "stateOrProvinceName",
	      "localityName", "organizationName",
	      "organizationUnitName", "commonName" }), attr)
  {
    if (id->variables[attr]) {
      attrs[attr] = global.String.trim_whites (id->variables[attr]);
      if (attrs[attr] == "") m_delete (attrs, attr);
    }
  }

  array name = ({ });
  if (attrs->countryName)
    name += ({([ "countryName": PrintableString(attrs->countryName) ])});
  foreach( ({ "stateOrProvinceName",
	      "localityName", "organizationName",
	      "organizationUnitName", "commonName" }), attr)
  {
    if (attrs[attr])
      name += ({ ([ attr : UTF8String(attrs[attr]) ]) });
  }

  /* Create a plain X.509 v1 certificate, with default extensions and hash. */
  string cert = Standards.X509.make_selfsigned_certificate
    (rsa, 24 * 3600 * (int) id->variables->ttl, name);

  string res=("<font size='+2'>"+LOCALE(133,"This is your Certificate.")+
	      "</font>"
	      "<textarea name='certificate' cols='80' rows='12'>");

  res += Tools.PEM.simple_build_pem("CERTIFICATE", cert);

  res += "</textarea>";

  res += save_certificate_form("cert_file", "my_rsa_certificate.pem");

  return res;
}

mixed verify_3(object id, object mc)
{
  if (sizeof(id->variables->cert_file))
  {
    object file;
    if (!(file = lopen(id->variables->cert_file, "wct")))
    {
      /* FIXME: Should we use a verify function, to get
       * better error handling? */
      id->variables->_error =
	"Could not open certificate file: "
	+ (strerror(errno()) || (string) errno())
	+ ".";
      return 1;
    }
    if (file->write(id->variables->certificate)
	!= strlen(id->variables->certificate))
    {
      id->variables->_error =
	"Write failed: "
	+ (strerror(file->errno()) || (string) file->errno())
	+ ".";
      return 1;
    }
  }
  return 0;
}

mixed wizard_done(object id, object mc)
{
  return http_string_answer( sprintf("<p>"+LOCALE(131,"Wrote %d bytes to %s.")+
				     "</p>\n<p><cf-ok/></p>\n",
				     strlen(id->variables->certificate),
				     combine_path(getcwd(), "../local/",
						  id->variables->cert_file)) );
}


mixed parse( RequestID id ) { return wizard_for(id,0); }


#endif /* constant (Nettle) */
