/*
 * $Id: make_csr.pike,v 1.9 1999/02/15 23:23:27 per Exp $
 */

inherit "wizard";

import Standards.PKCS;
import Standards.ASN1.Encode;

#if 0
#define WERROR werror
#else
#define WERROR(x)
#endif

constant name = "Security//Generate a Certificate Signing Request and an RSA key...";

constant doc = 
("In order to use the SSL on your server, "
 "you first have to create a random RSA key pair."
 "One part of the key is kept secret. The "
 "other part should be submitted to a certificate "
 "authority, such as Thawte or VeriSign. The "
 "certificate authority will return the signed "
 "certificate that is needed to run a secure server.");

#if !constant(_Crypto) || !constant(Crypto.rsa)

constant action_disabled = 1;

#else /* constant(_Crypto) && constant(Crypto.rsa) */


// Change this page to generate the key...
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
    + ("<font size=+1>How large key do you want to generate?</font><p>"
       "<b>Key size</b><br>"
       "<var name=key_size type=int default=1031><br>\n"
       "<blockquote>"
       "The desired key size. This is a security parameter; larger "
       "keys gives better security, but it also makes connecting to "
       "the server a little slower.<p>"
       "The largest RSA key that is publicly known to have been broken "
       "was 130 decimal digits, or about 430 bits large. This "
       "effort required 500 MIPS-years.<p>"
       "A key 1000 bits large should be secure enough for most "
       "applications, but of course you can you use an even larger key "
       "if you so wish."
       "</blockquote>"
       "<b>Key file</b><br>"
       "<var name=key_file type=string default=ssl3key><br>\n"
       "<blockquote>"
       "A filename in the real filesystem, where the secret key should "
       "be stored."
       "</blockquote>");
}

mixed verify_0(object id, object mc)
{
  int key_size = (int) id->variables->key_size;
  if (key_size < 300)
  {
    id->variables->_error =
      "Keys smaller than 300 bits are ridiculous.";
    return 1;
  }
  if (key_size > 5000)
  {
    id->variables->_error =
      "Keys larger than 5000 bits would take too long to generate.";
    return 1;
  }

  object file = Stdio.File();
  object privs = Privs("Storing private RSA key.");
  if (!file->open(id->variables->key_file, "wct", 0600))
  {
    id->variables->_error =
      "Could not open file: "
      + (strerror(file->errno()) || (string) file->errno())
      + ".";
    privs = 0;
    return 1;
  }

  privs = 0;

  object rsa = Crypto.rsa();
  rsa->generate_key(key_size, Crypto.randomness.reasonably_random()->read);

  string key = Tools.PEM.simple_build_pem
    ("RSA PRIVATE KEY",
     Standards.PKCS.RSA.rsa_private_key(rsa));
  WERROR(key);
  
  if (strlen(key) != file->write(key))
  {
    id->variables->_error =
      "Write failed: "
      + (strerror(file->errno()) || (string) file->errno())
      + ".";
    return 1;
  }
  destruct(file);

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
	  "<blockquote>"
	  "Your X.501 Distinguished Name consists of a chain of attributes "
	  "and values, where each link in the chain defines more precisely "
	  "who you are. Which attributes are necessary or useful "
	  "depends on what you will use the certificate for, and which "
	  "Certificate Authority you use. This page lets you specify "
	  "the most useful attributes. If you leave a field blank, "
	  "that attribute will be omitted from your name.<p>\n"
	  "Unfortunately, all fields should be in US-ASCII."
	  "</blockquote>"

	  "<b>Your country code</b><br>\n"
	  "<var name=countryName type=string default=SE><br>"
	  "<blockquote>"
	  "Your two-letter country code, for example GB (United Kingdom). "
	  "This attribute is required."
	  "</blockquote>"

	  "<b>State/Province</b><br>\n"
	  "<var name=stateOrProvinceName type=string><br>"
	  "<blockquote>"
	  "The state where you are operating. VeriSign requires this attribute "
	  "to be present for US and Canadian customers. Do not abbreviate."
	  "</blockquote>"

	  "<b>City/Locality</b><br>\n"
	  "<var name=localityName type=string default=Stockholm><br>"
	  "<blockquote>"
	  "The city or locality where you are registered. VeriSign "
	  "requires that at least one of the locality and the state "
	  "attributes are present. Do not abbreviate."
	  "</blockquote>"
	  
	  "<b>Organization/Company</b><br>\n"
	  "<var name=organizationName type=string default=\"Idonex AB\"><br>"
	  "<blockquote>"
	  "The organization name under which you are registered with some "
	  "national or regional authority."
	  "</blockquote>"
	  
	  "<b>Organizational unit</b><br>\n"
	  "<var name=organizationUnitName type=string "
	  "default=\"Roxen Development\"><br>"
	  "<blockquote>"
	  "This attribute is optional, and there are no "
	  "specific requirements on the value of this attribute."
	  "</blockquote>"

	  "<b>Common Name</b><br>\n"
	  "<var name=commonName type=string default=\"www.idonex.se\"><br>"
	  "This is the DNS name of your server (i.e. the host part of "
	  "the URL).\n"
	  "<blockquote>"
	  "Browsers will compare the URL they are connecting to with "
	  "the Common Name in the server's certificate, and warn the user "
	  "if they don't match.<p>"
	  "Some Certificate Authorities allow wild cards in the Common "
	  "Name. This means that you can have a certificate for "
	  "<tt>*.idonex.se</tt> which will match all servers at Idonex."
	  "Thawte allows wild card certificates, while VeriSign does not."
	  "</blockquote>");
}

mixed page_2(object id, object mc)
{
  return ("<font size=+1>Certificate Attributes?</font><p>"
	  "<blockquote>"
	  "An X.509 certificate associates a Common Name\n"
	  "with a public key. Some certificate authorities support\n"
	  "\"extended certificates\", defined in PKCS#10. An extended\n"
	  "certificate may contain other useful information associated\n"
	  "with the name and the key. This information is signed by the\n"
	  "CA, together with the X.509 certificate.\n"
	  "</blockquote>\n"

	  "<br><b>Email address</b><br><var name=emailAddress type=string>"
	  "<blockquote>"
	  "An email address to be embedded in the certificate."
	  "</blockquote>\n");
}

mixed page_3(object id, object mc)
{
  return ("<font size=+1>CSR Attributes?</font><p>"
	  "At last, you can add attributes to the Certificate Signing "
	  "Request, which are meant for the Certificate Authority "
	  "and are not included in the issued Certificate."

          "<p><b>Challenge Password</b><br>"
	  "<var name=challengePassword type=password>"
	  "<blockquote>"
	  "This password could be used if you ever want to revoke "
	  "your certificate. Of course, this depends on the policy of "
	  "your Certificate Authority."
	  "</blockquote>\n");
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

  object msg = Tools.PEM.pem_msg()->init(s);
  object part = msg->parts["RSA PRIVATE KEY"];
  
  if (!part)
    return "<font color=red>Key file not formatted properly.\n</font>";

  object rsa = RSA.parse_private_key(part->decoded_body());

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

  string re;
  string res=("<font size=+2>This is your Certificate "
              "Signing Request.</font><textarea name=csr cols=80 rows=12>");

  res += (re=Tools.PEM.simple_build_pem("CERTIFICATE REQUEST", csr->der()));
  
  res += "</textarea>";
  
  res += "<p>";
  
  res += ("<p><font size=+1><var type=checkbox name=save></font>"
          "<b>Save the request in a file:</b><br>"
          "<blockquote><b>Filename</b><br><var type=string name=save_in_file></blockquote>");


  res += ("<p>"
          "<p><font size=+1><var type=checkbox name=send></font>"
          "<b>Send the request to Thawte</b><br>")   ;

  return res;
}


#include "thawte.form";
mapping wizard_done( object id )
{
  if(id->variables->send[0]=='o')
  {
    return http_string_answer(sprintf(thawte_form, id->variables->csr));
  }
}


/*
  https://www.thawte.com/cgi/server/step1.exe
  
 */

mixed handle(object id) { return wizard_for(id,0); }

#endif /* constant(_Crypto) && constant(Crypto.rsa) */
