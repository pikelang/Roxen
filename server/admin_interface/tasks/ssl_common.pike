/*
 * $Id: ssl_common.pike,v 1.11 2004/06/04 08:29:16 _cvs_stephen Exp $
 */

#if constant(Crypto) 

#if 0
#define WERROR werror
#else
#define WERROR(x)
#endif

constant doc_string_start =
("In order to use the SSL on your server, you "
 "first have to create a random key pair. "
 "One part of the key is kept secret. ");

constant doc_string_end_a =
("The other part should be submitted to a "
 "certificate authority, such as Thawte or "
 "VeriSign. The certificate authority will "
 "return the signed certificate that need to "
 "run a secure server.");

constant doc_string_end_b =
("The other part is used to create a certificate. "
 "You can create a certificate yourself; this is "
 "not the recommended way to use SSL, and browsers "
 "will complain about not recognizing the entity "
 "that has signed the key (i.e. you). But a "
 "self-signed certificate is a lot better than "
 "nothing.");


mixed page_0(object id, object mc)
{
  return 
    ssl_errors(id) +
    rsa_key_form +
    key_file_form("my_rsa_key.pem");
}


#if constant(Crypto.RSA)
mixed verify_0(object id, object mc)
{
  int key_size = (int) id->variables->key_size;
  if (key_size < 300)
  {
    id->variables->_error =
      sprintf("Keys smaller than %d bits are ridiculous.", 300);
    return 1;
  }
  if (key_size > 5000)
  {
    id->variables->_error =
      sprintf("Keys larger than %d bits would take too long "
	      "to generate.", 5000);
    return 1;
  }

  Stdio.File file;
  object privs = Privs("Storing private key.");
  if (!(file = lopen(id->variables->key_file, "wxc", 0600)))
  {
    id->variables->_error =
      "Could not open file: "
      + (strerror(errno()) || (string) errno())
      + ".";
    privs = 0;
    return 1;
  }

  privs = 0;

  object rsa = Crypto.RSA();
  rsa->generate_key(key_size);

  string key = Tools.PEM.simple_build_pem
    ("RSA PRIVATE KEY",
     Standards.PKCS.RSA.private_key(rsa));

  WERROR(key);
  
  if (sizeof(key) != file->write(key))
  {
    id->variables->_error =
      "Write failed: "
      + (strerror(file->errno()) || (string) file->errno())
      + ".";
    return 1;
  }

  return 0;
}
#endif /* constant(Crypto.RSA) */


string ssl_errors (RequestID id) {
  string msg = "";
  if (id->variables->_error)
  {
    msg = "<p><font color='red'>" + id->variables->_error + "</font></p>";
    id->variables->_error = 0;
  }
  return msg;
}

constant key_size_question = "How large key do you want to generate?";

constant generic_key_size_string =
("The desired key size. This is a security parameter; larger "
 "keys gives better security, but it also makes connecting to "
 "the server a little slower.");

constant  rsa_key_form =
("<p><font size='+1'>" + key_size_question + "</font></p>"
 "<b>Key size</b><br />"
 "<var name='key_size' type='int' default='1024'/><br />\n<blockquote>"
 "<p>"+generic_key_size_string+"</p><help>"
// http://www.rsasecurity.com/rsalabs/challenges/factoring/status.html
 "The largest key that is publicly known to have been broken "
 "was 155 decimal digits, or 512 bits large. This "
 "effort required approximately 8000 MIPS-years.<p>"
 "A key 1024 bits large should be secure enough for most "
 "applications, but of course you can you use an even larger key "
 "if you so wish.</help></blockquote>");


string key_file_form (string filename) 
{
  return
    "<b>Key file</b><br />"
    "<var name='key_file' type='string' default='"+filename+"'/><blockquote>\n"
    "Where to store the file, may be relative to "+getcwd()+".\n<help><p>"
    "A filename in the real filesystem, where the secret key should "
    "be stored. This is the filename you enter in the "
    "'Key file'-field when you configure an SSL listen port."
    "</p></help></blockquote>";
}

constant certificate_parameters =
// page_1() for make_rsa_csr.pike and make_selfsigned_???.pike
("<p><font size='+1'>Your Distinguished Name?</font></p><blockquote>"
 "Your X.501 Distinguished Name consists of a chain of attributes "
 "and values, where each link in the chain defines more precisely "
 "who you are. Which attributes are necessary or useful "
 "depends on what you will use the certificate for, and which "
 "Certificate Authority you use. This page lets you specify "
 "the most useful attributes. If you leave a field blank, "
 "that attribute will be omitted from your name.<p>\n"
 "Although most browsers will accept 8 bit ISO 8859-1 characters in "
 "these fields, it can't be counted on. To be on the safe side, "
 "use only US-ASCII.</blockquote>"

 "<b>Your country code</b><br />\n"
 "<var name='countryName' type='string' default='SE'/><br /><blockquote>"
 "Your two-letter country code, for example GB (United Kingdom). "
 "This attribute is required.</blockquote>"

 "<b>State/Province</b><br />\n"
 "<var name='stateOrProvinceName' type='string' /><br /><blockquote>"
 "The state where you are operating. VeriSign requires this "
 "attribute to be present for US and Canadian customers. "
 "Do not abbreviate.</blockquote>"

 "<b>City/Locality</b><br />\n"
 "<var name='localityName' type='string' default='Stockholm'/><br />"
 "<blockquote>"
 "The city or locality where you are registered. VeriSign "
 "requires that at least one of the locality and the state "
 "attributes are present. Do not abbreviate.</blockquote>"

 "<b>Organization/Company</b><br />\n"
 "<var name='organizationName' type='string' default='Big and Better Inc.'/><br />"
 "<blockquote>"
 "The organization name under which you are registered with some "
 "national or regional authority.</blockquote>"

 "<b>Organizational unit</b><br />\n"
 "<var name='organizationUnitName' type='string' "
 "default='Research and Development'/><br />"
 "<blockquote>"
 "This attribute is optional, and there are no "
 "specific requirements on the value of this attribute.</blockquote>"

 "<b>Common Name</b><br />\n"
 "<var name='commonName' type='string' default='www.bigandbetterinc.com'/><br />"
 "<blockquote>"
 "This is the DNS name of your server (i.e. the host part of "
 "the URL).<p>"
 "Browsers will compare the URL they are connecting to with "
 "the Common Name in the server's certificate, and warn the user "
 "if they don't match.<p>"
 "Some Certificate Authorities allow wild cards in the Common "
 "Name. This means that you can have a certificate for "
 "<tt>*.chilimoon.com</tt> which will match all servers at ChiliMoon."
 "Thawte allows wild card certificates, while VeriSign does not."
 "</blockquote>");

constant certificate_TTL =
// page_2() for make_selfsigned_???.pike
("<p><font size='+1'>For how long should the certificate be valid?</font></p>\n"
 "<b>Certificate lifetime, in days</b><br />\n"
 "<var name='ttl' type='int' default='500'/><br />\n"
 "<blockquote>"
 "A certificate includes a validity period. How many days, "
 "from now, do you want the certificate to be valid?"
 "</blockquote>");

string save_certificate_form (string name, string filename) 
{
  return 
    "<p><b>Save the request in a file:</b></p>"
    "<blockquote><b>Filename</b><br />"
    "<var type='string' name='"+name+"' default='"+filename+"'/>"
    "<br />"
    "Where to store the file, may be relative to "+getcwd()+".</blockquote>";
}


#endif /* constant(Crypto) */
