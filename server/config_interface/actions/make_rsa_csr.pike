/*
 * $Id$
 */

#if constant (Nettle)

inherit "ssl_common.pike";
inherit "wizard";
#include <roxen.h>
#include <config_interface.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

import Standards.PKCS;
import Standards.ASN1.Types;

constant action = "SSL";

string name= LOCALE(121,
		    "Generate a Certificate Signing Request and an RSA key...");
string doc = doc_string_start + doc_string_end_a;


/* In ssl_common.pike:
 *
 * mixed page_0(object id, object mc)
 * mixed verify_0(object id, object mc)
 */


mixed page_1(mixed id, mixed mc)
{
  return certificate_parameters;
}


/* FIXME: Certificate attributes should be considered obsoleted by
 * X.509 v3. See RFC-2459. */
mixed page_2(object id, object mc)
{
  return ("<p class='large'>"+LOCALE(122,"Certificate Attributes?")+
	  "</p>\n<div class='notify info'>"+
	  LOCALE(123, "An X.509 certificate associates a Common Name "
	  "with a public key. Some certificate authorities support "
	  "\"extended certificates\", defined in PKCS#10. An extended "
	  "certificate may contain other useful information associated "
	  "with the name and the key. This information is signed by the "
	  "CA, together with the X.509 certificate.")+
	  "</div>"

          "<div class='control-group'>"
	    "<label for='emailAddress'>"
              +LOCALE(124, "Email address")+
              "<small>"+
                  LOCALE(125,"An email address to be embedded in the certificate.")+
              "</small>"
            "</label>"
            "<var name='emailAddress' type='email'/>"
          "</div>");
}

mixed page_3(object id, object mc)
{
  return ("<p class='large'>"+LOCALE(126,"CSR Attributes?")+"</p>"
          "<div class='notify info'>"
	    + LOCALE(127,"At last, you can add attributes to the Certificate "
		   "Signing Request, which are meant for the Certificate "
		   "Authority and are not included in the issued Certificate.")+
          "</div>"
          "<div class='control-group'>"
            "<label for='challengePassword'>"
              +LOCALE(128,"Challenge Password")+
              "<small>"+
                  LOCALE(129,"This password could be used if you ever want to revoke "
                         "your certificate. Of course, this depends on the policy of "
                         "your Certificate Authority.")+
              "</small>"
            "</label>"
	    "<var name='challengePassword' type='password'/>"
          "</div>");
}

mixed page_4(object id, object mc)
{
  object file;
  TRACE("page_4: %O\n", mc);
  object privs = Privs("Reading private RSA key");
  if (!(file = lopen(id->variables->key_file, "r")))
  {
    privs = 0;
    return "<p class='notify error inline'>Could not open key file: "
      + strerror(errno()) + "\n</p>";
  }
  privs = 0;
  string s = file->read(0x10000);
  if (!s)
    return "<span class='notify error inline'>Could not read private key: "
      + strerror(file->errno()) + "</span>";

  object msg = Tools.PEM.pem_msg()->init(s);
  object part = msg->parts["RSA PRIVATE KEY"];

  if (!part)
    return "<span class='notify error inline'>Key file not formatted properly.</span>";

  object rsa = RSA.parse_private_key(part->decoded_body());

  if (!rsa)
    return "<span class='notify error inline'>Invalid key.</span>";

  mapping attrs = ([]);
  string attr;

  /* Remove initial and trailing whitespace, and ignore
   * empty attributes. */
  foreach( ({ "countryName", "stateOrProvinceName", "localityName",
	      "organizationName", "organizationUnitName", "commonName",
	      "emailAddress", "challengePassword"}), attr)
  {
    if (id->variables[attr]) {
      attrs[attr] = global.String.trim_whites(id->variables[attr]);
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

  mapping csr_attrs = ([]);
  foreach( ({ "challengePassword" }), attr)
  {
    if (attrs[attr])
      csr_attrs[attr] = ({ PrintableString(attrs[attr]) });
  }

  mapping cert_attrs = ([ ]);
  foreach( ({ "emailAddress" }), attr)
  {
    if (attrs[attr])
      cert_attrs[attr] = ({ IA5String(attrs[attr]) });
  }

  /* Not all CA:s support extendedCertificateAttributes */
  if (sizeof(cert_attrs))
    csr_attrs->extendedCertificateAttributes =
      ({ Certificate.Attributes(Identifiers.attribute_ids,
				cert_attrs) });

  object csr = CSR.build_csr(rsa,
			     Certificate.build_distinguished_name(name),
			     csr_attrs);

  string re;
  string res=("<p class='large'>"+
	      LOCALE(130,"This is your Certificate Signing Request.")+
	      "</p><textarea name='csr' cols='80' rows='17'>");

  res += (re=Tools.PEM.simple_build_pem("CERTIFICATE REQUEST", csr->get_der()));

  res += "</textarea>";

  res += save_certificate_form("save_in_file", "my_rsa_csr.pem");

  return res;
}

mapping wizard_done( object id )
{
  TRACE("**** wizard_done: %O\n", id);

  object privs = Privs("Storing CSR request.");
  mv( id->variables->save_in_file, id->variables->save_in_file+"~" );
  string fname = combine_path(getcwd(), "../local",
			      id->variables->save_in_file);
  Stdio.File file = open(fname, "cwx", 0644);
  privs = 0;
  if (!file || file->write(id->variables->csr) != sizeof(id->variables->csr)) {
    return http_string_answer(sprintf("<p class='notify error inline'>" +
				      LOCALE(155, "Failed to write CSR to %s.")+
				      "</p>\n<p><cf-cancel href='?class=&form.class;&amp;&usr.set-wiz-id;'/></p>\n",
				      fname));
  }
  return http_string_answer( sprintf("<p class='notify ok inline'>"+LOCALE(131,"Wrote %d bytes to %s.")+
				     "</p>\n<p><cf-ok/></p>\n",
				     strlen(id->variables->csr),
				     fname));
}


mixed parse( RequestID id ) { return wizard_for(id,0); }


#endif /* constant (Nettle) */
