/*
 * $Id: make_csr.pike,v 1.9 1999/01/31 23:26:59 peter Exp $
 */

inherit "wizard";

import Standards.PKCS;
#if constant(Standards.ASN1.Types) //0.6 feature
import Standards.ASN1.Types;
#else
import Standards.ASN1.Encode;
#endif /* constant(Standards.ASN1.Types) */


#if 0
#define WERROR werror
#else
#define WERROR(x)
#endif

constant name = "Security//Generate a Certificate Signing Request for an RSA key...";

constant doc = ("To use an RSA key with your server, you must have a certificate "
		"for it. You request a certificate by sending a Certificate "
		"Signing Request to a Certificate Authority, for example Thawte "
		"or VeriSign.");

#if !constant(_Crypto) || !constant(Crypto.rsa)

constant action_disabled = 1;

#else /* constant(_Crypto) && constant(Crypto.rsa) */

mixed page_0(object id, object mc)
{
  string msg;
  
  if (id->variables->_error)
  {
    msg = "<font color=red>" + id->variables->_error
      + "</font><p>";
    id->variables->_error = 0;
  }

  return (msg || "" )
    + ("<font size=+1>Which key do you want to certify?</font><p>"
       "<var name=key_file type=string><br>\n"
       "Where the private key is stored.<br> "
       "<help><blockquote>"
       "A filename in the real filesystem, where the private key is stored. "
       "(The private key is needed to sign the CSR. It is <em>not</em> "
       "included in the file sent to the Certificate Authority)."
       "</blockquote></help>");
}

mixed verify_0(object id, object mc)
{
  if (!file_stat(id->variables->key_file))
  {
    id->variables->_error = "File not found.";
    return 1;
  }
  return 0;
}

mixed page_1(mixed id, mixed mc)
{
  return ("<font size=+1>Your Distinguished Name?</font><p>"
	  "<help><blockquote>"
	  "Your X.501 Distinguished Name consists of a chain of attributes "
	  "and values, where each link in the chain defines more precisely "
	  "who you are. Which attributes are necessary or useful "
	  "depends on what you will use the certificate for, and which "
	  "Certificate Authority you use. This page lets you specify "
	  "the most useful attributes. If you leave a field blank, "
	  "that attribute will be omitted from your name.<p>\n"
	  "Unfortunately, all fields should be in US-ASCII."
	  "</blockquote></help>"

	  "<var name=countryName type=string default=SE><br>"
	  "Your country code<br>\n"
	  "<help><blockquote>"
	  "Your two-letter country code, for example GB (United Kingdom). "
	  "This attribute is required."
	  "</blockquote></help>"

	  "<var name=stateOrProvinceName type=string><br>"
	  "State/Province<br>\n"
	  "<help><blockquote>"
	  "The state where you are operating. VeriSign requires this attribute "
	  "to be present for US and Canadian customers. Do not abbreviate."
	  "</blockquote></help>"

	  "<var name=localityName type=string default=Stockholm><br>"
	  "City/Locality<br>\n"
	  "<help><blockquote>"
	  "The city or locality where you are registered. VeriSign "
	  "requires that at least one of the locality and the state "
	  "attributes are present. Do not abbreviate."
	  "</blockquote></help>"
	  
	  "<var name=organizationName type=string default=\"Idonex AB\"><br>"
	  "Organization/Company<br>\n"
	  "<help><blockquote>"
	  "The organization name under which you are registered with some "
	  "national or regional authority."
	  "</blockquote></help>"
	  
	  "<var name=organizationUnitName type=string "
	  "default=\"Roxen Development\"><br>"
	  "Organizational unit<br>\n"
	  "<help><blockquote>"
	  "This attribute is optional, and there are no "
	  "specific requirements on the value of this attribute."
	  "</blockquote></help>"

	  "<var name=commonName type=string default=\"www.idonex.se\"><br>"
	  "Common Name<br>\n"
	  "This is the DNS name of your server (i.e. the host part of "
	  "the URL).\n"
	  "<help><blockquote>"
	  "Browsers will compare the URL they are connecting to with "
	  "the Common Name in the server's certificate, and warn the user "
	  "if they don't match.<p>"
	  "Some Certificate Authorities allow wild cards in the Common "
	  "Name. This means that you can have a certificate for "
	  "<tt>*.idonex.se</tt> which will match all servers at Idonex."
	  "Thawte allows wild card certificates, while VeriSign does not."
	  "</blockquote></help>");
}

mixed page_2(object id, object mc)
{
  return ("<font size=+1>Certificate Attributes?</font><p>"
	  "<help><blockquote>"
	  "An X.509 certificate associates a Common Name\n"
	  "with a public key. Some certificate authorities support\n"
	  "\"extended certificates\", defined in PKCS#10. An extended\n"
	  "certificate may contain other useful information associated\n"
	  "with the name and the key. This information is signed by the\n"
	  "CA, together with the X.509 certificate.\n"
	  "</blockquote></help>\n"

	  "<var name=emailAddress type=string><br>Email address<br>"
	  "<help><blockquote>"
	  "An email address to be embedded in the certificate."
	  "</blockquote></help>\n");
}

mixed page_3(object id, object mc)
{
  return ("<font size=+1>CSR Attributes?</font><p>"
	  "At last, you can add attributes to the Certificate Signing "
	  "Request, which are meant for the Certificate Authority "
	  "and are not included in the issued Certificate."

	  "<var name=challengePassword type=password> <br>Challenge Password<br>"
	  "<help><blockquote>"
	  "This password could be used if you ever want to revoke "
	  "your certificate. Of course, this depends on the policy of "
	  "your Certificate Authority."
	  "</blockquote></help>\n");
}

object trim = Regexp("^[ \t]*([^ \t](.*[^ \t]|))[ \t]*$");

mixed page_4(object id, object mc)
{
  object file = Stdio.File();

  object privs = Privs("Reading private RSA key");
  if (!file->open(id->variables->key_file, "r"))
  {
    privs = 0;

    return "<font color=red>Could not open key file: "
      + strerror(file->errno()) + "\n</font>";
  }
  privs = 0;
  string s = file->read(0x10000);
  if (!s)
    return "<font color=red>Could not read private key: "
      + strerror(file->errno()) + "\n</font>";

#if constant(Tools)
  object msg = Tools.PEM.pem_msg()->init(s);
  object part = msg->parts["RSA PRIVATE KEY"];
  
  if (!part)
    return "<font color=red>Key file not formatted properly.\n</font>";

  object rsa = RSA.parse_private_key(part->decoded_body());
#else /* !constant(Tools)*/
  /* Backward compatibility */
  mapping m = SSL.pem.parse_pem(s);
  if (!m || !m["RSA PRIVATE KEY"])
    return "<font color=red>Key file not formatted properly.\n</font>";

  object rsa = RSA.parse_private_key(m["RSA PRIVATE KEY"]);
#endif /* constant(Tools) */
  if (!rsa)
    return "<font color=red>Invalid key.\n</font>";
  
  mapping attrs = ([]);
  string attr;
  
  /* Remove initial and trailing whitespace, and ignore
   * empty attributes. */
  foreach( ({ "countryName", "stateOrProvinceName", "localityName",
	      "organizationName", "organizationUnitName", "commonName",
	      "emailAddress", "challengePassword"}), attr)
  {
    if (id->variables[attr])
      {
	array a = trim->split(id->variables[attr]);
	if (a)
	  attrs[attr] = a[0];
      }
  }

  array name = ({ });
  foreach( ({ "countryName", "stateOrProvinceName",
	      "localityName", "organizationName",
	      "organizationUnitName", "commonName" }), attr)
  {
    if (attrs[attr])
      name += ({ ([ attr : asn1_printable_string(attrs[attr]) ]) });
  }

  mapping csr_attrs = ([]);
  foreach( ({ "challengePassword" }), attr)
  {
    if (attrs[attr])
      csr_attrs[attr] = ({ asn1_printable_string(attrs[attr]) });
  }

  mapping cert_attrs = ([ ]);
  foreach( ({ "emailAddress" }), attr)
  {
    if (attrs[attr])
      cert_attrs[attr] = ({ asn1_IA5_string(attrs[attr]) });
  }

  /* Not all CA:s support extendedCertificateAttributes */
  if (sizeof(cert_attrs))
    csr_attrs->extendedCertificateAttributes =
      ({ Certificate.Attributes(Identifiers.attribute_ids,
				cert_attrs) });
  
  object csr = CSR.build_csr(rsa,
			     Certificate.build_distinguished_name(@name),
			     csr_attrs);

#if 0
  werror("csr: %s\n", Crypto.string_to_hex(csr->get_der()));
#endif

#if constant(Tools)
  return "<textarea cols=80 rows=12>"
    + Tools.PEM.simple_build_pem("CERTIFICATE REQUEST", csr->get_der())
    +"</textarea>";
#else /* !constant(Tools) */
  /* Backward compatibility */
  return "<textarea cols=80 rows=12>"
    + SSL.pem.build_pem("CERTIFICATE REQUEST", csr->get_der())
    +"</textarea>";
#endif /* constant(Tools) */
}

mixed wizard_done(object id, object mc)
{
  return 0;
}

mixed handle(object id) { return wizard_for(id,0); }

#endif /* constant(_Crypto) && constant(Crypto.rsa) */
