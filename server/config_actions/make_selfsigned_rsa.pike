/*
 * $Id: make_selfsigned_rsa.pike,v 1.2 1999/03/02 17:57:53 nisse Exp $
 */

inherit "wizard";

import Standards.PKCS;
import Standards.ASN1.Types;

#if 0
#define WERROR werror
#else
#define WERROR(x)
#endif

constant name = "Security//Generate an RSA key and a Selfsigned Certificate...";

constant doc = 
("In order to use the SSL on your server, "
 "you first have to create a random RSA key pair."
 "One part of the key is kept secret. The "
 "other part is used to create a certificate. "
 "You can create a certificate yourself; this is "
 "not the recommended way to use SSL, and browsers "
 "will complain about not recognizing the entity "
 "that has signed the key (i.e. you). But a "
 "self-signed certificate is a lot better than "
 "nothing.");

#if !constant(_Crypto) || !constant(Crypto.rsa)

constant action_disabled = 1;

#else /* constant(_Crypto) && constant(Crypto.rsa) */

mixed page_0(object id, object mc)
{
  string msg = "";
  
  if (id->variables->_error)
  {
    msg = "<font color=red>" + id->variables->_error
      + "</font><p>";
    id->variables->_error = 0;
  }
  
  return msg
    + ("<font size=+1>How large key do you want to generate?</font><p>"
       "<b>Key size</b><br>"
       "<var name=key_size type=int default=1031><br>\n"
       "<blockquote>"
       "The desired key size. This is a security parameter; larger "
       "keys gives better security, but it also makes connecting to "
       "the server a little slower.<p>"
       "The largest RSA key that is publicly known to have been broken "
       "was 140 decimal digits, or about 465 bits large. This "
       "effort is estimated to 2000 MIPS-years.<p>"
       "A key 1000 bits large should be secure enough for most "
       "applications, but of course you can you use an even larger key "
       "if you so wish."
       "</blockquote>"

       "<b>Key file</b><br>"
       "<var name=key_file type=string default=my_rsa_key.pem><br>\n"
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
  string msg = ""; 
  
  if (id->variables->_error)
  {
    msg = "<font color=red>" + id->variables->_error
      + "</font><p>";
    id->variables->_error = 0;
  }
  
  return msg +
    ("<font size=+1>Your Distinguished Name?</font><p>"
     "<blockquote>"
     "Your X.501 Distinguished Name consists of a chain of attributes "
     "and values, where each link in the chain defines more precisely "
     "who you are. Which attributes are necessary or useful "
     "depends on what you will use the certificate for, and which "
     "Certificate Authority you use. This page lets you specify "
     "the most useful attributes. If you leave a field blank, "
     "that attribute will be omitted from your name.<p>\n"
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
  return ("<font size=+1> For how long should the certificate "
	  "be valid?</font><p>\n"

	  "<b>Certificate lifetime, in days</b><br>\n"
	  "<var name=ttl type=int default=500><br>\n"
	  "<blockquote>"
	  "A certificate includes a validity period. How many days, "
	  "from now, do you want the certificate to be valid?"
	  "</blockquote>"
#if 0
	  "<b>Certificate file</b><br>"
	  "<var name=cert_file type=string default=my_cert.pem><br>\n"
	  "<blockquote>"
	  "A filename in the real filesystem, where the new "
	  "certificate should be stored."
#endif
    );
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

object trim = Regexp("^[ \t]*([^ \t](.*[^ \t]|))[ \t]*$");

mixed page_3(object id, object mc)
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
  foreach( ({ "countryName", "stateOrProvinceName",
	      "localityName", "organizationName",
	      "organizationUnitName", "commonName" }), attr)
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
      /* UTF8String is the recommended type. But it seems that
       * netscape can't handle that. So we use the older TeletexString
       * type instead. */
      name += ({ ([ attr : asn1_teletex_string(attrs[attr]) ]) });
  }

  /* Create a plain X.509 v1 certificate, without any extensions */
  string cert = Tools.X509.make_selfsigned_rsa_certificate
    (rsa, 24 * 3600 * (int) id->variables->ttl, name);
  
  string res=("<font size=+2>This is your Certificate.</font>"
	      "<textarea name=certificate cols=80 rows=12>");

  res += Tools.PEM.simple_build_pem("CERTIFICATE", cert);
  
  res += "</textarea>";
  
  res += "<p>";

  /* FIXME: How to make the checkbox checked by default? */
  res += ("<p><font size=+1>"
	  "<var type=checkbox name=save checked></font>"
          "<b>Save the request in a file:</b><br>"
          "<blockquote><b>Filename</b><br>"
	  "<var type=string name=cert_file default=my_certificate.pem>"
	  "</blockquote>");

  return res;
}

#if 0
mixed page_4(object id, object mc)
{
  string msg = "";
  
  if (id->variables->_error)
  {
    msg = "<font color=red>" + id->variables->_error
      + "</font><p>";
    id->variables->_error = 0;
  }
  
  return msg
    + ("Do you want to store the certificate in a file? ");
}
#endif

mixed verify_3(object id, object mc)
{
  // werror("save = %O\n", id->variables->save);
  if (sizeof(id->variables->save && id->variables->cert_file))
  {
    object file = Stdio.File();
    if (!file->open(id->variables->cert_file, "wct"))
    {
      /* FIXME: Should we use a verify function, to get
       * better error handling? */
      id->variables->_error =
	"Could not open certificate file: "
	+ (strerror(file->errno()) || (string) file->errno())
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

mixed handle(object id) { return wizard_for(id,0); }

#endif /* constant(_Crypto) && constant(Crypto.rsa) */
