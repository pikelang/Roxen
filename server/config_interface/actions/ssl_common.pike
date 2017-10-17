/*
 * $Id$
 */

#if constant (Nettle)

#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

#if 0
#define WERROR werror
#else
#define WERROR(x)
#endif

string doc_string_start = LOCALE(40,
			     "In order to use the SSL on your server, you "
			     "first have to create a random key pair. "
			     "One part of the key is kept secret. ");
string doc_string_end_a = LOCALE(88,
			      "The other part should be submitted to a "
			      "certificate authority, such as Thawte or "
			      "VeriSign. The certificate authority will "
			      "return the signed certificate that need to "
			      "run a secure server.");
string doc_string_end_b = LOCALE(89,
			      "The other part is used to create a certificate. "
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


mixed verify_0(object id, object mc)
{
  int key_size = (int) id->variables->key_size;
  if (key_size < 300)
  {
    id->variables->_error =
      sprintf(LOCALE(90, "Keys smaller than %d bits are ridiculous."), 300);
    return 1;
  }
  if (key_size > 5000)
  {
    id->variables->_error =
      sprintf(LOCALE(91, "Keys larger than %d bits would take too long "
		     "to generate."), 5000);
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

  Crypto.RSA rsa = Crypto.RSA();
  rsa->generate_key(key_size, Crypto.Random.random_string);

  string key = Tools.PEM.simple_build_pem ("RSA PRIVATE KEY",
					   Standards.PKCS.RSA.private_key(rsa));
  WERROR(key);

  if (strlen(key) != file->write(key))
  {
    id->variables->_error =
      "Write failed: "
      + (strerror(file->errno()) || (string) file->errno())
      + ".";
    return 1;
  }

  return 0;
}


string ssl_errors (RequestID id) {
  string msg = "";
  if (id->variables->_error)
  {
    msg = "<p class='notify error inline'>" + id->variables->_error + "</p>";
    id->variables->_error = 0;
  }
  return msg;
}

string key_size_question = LOCALE(92, "How large key do you want to generate?");

string generic_key_size_string =
   LOCALE(93, "The desired key size. This is a security parameter; larger "
	  "keys gives better security, but it also makes connecting to "
	  "the server a little slower.");

string rsa_key_form =
      ("<p class='large'>" + key_size_question + "</p>"
       "<div class='control-group'>"
         "<label for='key_size'>" + LOCALE(94, "Key size") +
         " <small>" + generic_key_size_string + "</small></label>"
         "<var name='key_size' type='int' id='key_size' default='2048'/>"
       "</div>"
       "<blockquote>"
       "<help><div class='wiz-help'>" +
// http://www.rsasecurity.com/rsalabs/challenges/factoring/status.html
       LOCALE(95,"The largest key that is publicly known to have been broken "
	      "was 155 decimal digits, or 512 bits large. This "
	      "effort required approximately 8000 MIPS-years.<p>"
	      "A key 2048 bits large should be secure enough for most "
	      "applications, but of course you can you use an even larger key "
	      "if you so wish.") +
       "</div></help></blockquote>");


string key_file_form (string filename)
{
  return
    "<div class='control-group'>"
      "<label for='key_file'>"+ LOCALE(96, "Key file") + " "
      "<small>" +
        sprintf(LOCALE(97,
               "Where to store the file, may be relative to %s."),
               combine_path(getcwd(), "../local/")) +
      "</small></label>"
      "<var name='key_file' id='key_file' type='string' default='"+filename+"'/>"
    "</div>"
    "<blockquote>"
    "<help><div class='wiz-help'>" +
    LOCALE(98,
	   "A filename in the real filesystem, where the secret key should "
	   "be stored. This is the filename you enter in the "
	   "'Key file'-field when you configure an SSL listen port.") +
    "</div></help></blockquote>";
}

string certificate_parameters =
// page_1() for make_rsa_csr.pike and make_selfsigned_???.pike
  ("<p class='large'>"+LOCALE(99,"Your Distinguished Name?")+
   "</p><div class='notify ino'>"+
   LOCALE(100, "Your X.501 Distinguished Name consists of a chain of attributes "
	  "and values, where each link in the chain defines more precisely "
	  "who you are. Which attributes are necessary or useful "
	  "depends on what you will use the certificate for, and which "
	  "Certificate Authority you use. This page lets you specify "
	  "the most useful attributes. If you leave a field blank, "
	  "that attribute will be omitted from your name.<p>\n"
	  "Although most browsers will accept 8 bit ISO 8859-1 characters in "
	  "these fields, it can't be counted on. To be on the safe side, "
	  "use only US-ASCII.")+ "</div>"

   "<div class='control-group'>"
     "<label for='countryName'>"+
        LOCALE(101,"Your country code") +
        "<small>"+
          LOCALE(102,"Your two-letter country code, for example GB (United Kingdom). "
                     "This attribute is required.")+
        "</small>"
     "</label>"
     "<var name='countryName' id='countryName' type='string' default='SE'/>"
   "</div>"

   "<div class='control-group'>"
     "<label for='stateOrProvinceName'>"
        + LOCALE(103,"State/Province") +
        "<small>"+
           LOCALE(104,"The state where you are operating. VeriSign requires this "
                      "attribute to be present for US and Canadian customers. "
                      "Do not abbreviate.")+
        "</small>"
     "</label>"
     "<var name='stateOrProvinceName' id='stateOrProvinceName' type='string' />"
   "</div>"

   "<div class='control-group'>"
     "<label for='localityName'>"
        +LOCALE(105,"City/Locality")+
        "<small>"+
           LOCALE(106, "The city or locality where you are registered. VeriSign "
                       "requires that at least one of the locality and the state "
                       "attributes are present. Do not abbreviate.")+
        "</small>"
     "</label>"
     "<var name='localityName' id='localityName' type='string' default='Stockholm'/>"
   "</div>"

   "<div class='control-group'>"
     "<label for='organizationName'>"
        +LOCALE(107,"Organization/Company")+
        "<small>"+
           LOCALE(108, "The organization name under which you are registered with some "
                  "national or regional authority.")+
        "</small>"
     "</label>"
     "<var name='organizationName' id='organizationName' type='string' default='Roxen AB'/>"
   "</div>"


   "<div class='control-group'>"
     "<label for='organizationUnitName'>"
        +LOCALE(109,"Organizational unit")+
        "<small>"+
           LOCALE(110, "This attribute is optional, and there are no "
                  "specific requirements on the value of this attribute.")+
        "</small>"
     "</label>"
     "<var name='organizationUnitName' id='organizationUnitName'"
     " type='string' default='Roxen Development'/>"
   "</div>"

   "<div class='control-group'>"
     "<label for='commonName'>"
        +LOCALE(111,"Common Name")+
     "</label>"
     "<var name='commonName' id='commonName' type='string' default='www.roxen.com'/>"
     "<blockquote>"+
        LOCALE(112, "This is the DNS name of your server (i.e. the host part of "
                  "the URL).<p>"
                  "Browsers will compare the URL they are connecting to with "
                  "the Common Name in the server's certificate, and warn the user "
                  "if they don't match.<p>"
                  "Some Certificate Authorities allow wild cards in the Common "
                  "Name. This means that you can have a certificate for "
                  "<tt>*.roxen.com</tt> which will match all servers at Roxen."
                  "Thawte allows wild card certificates, while VeriSign does not.")+
     "</blockquote>"
   "</div>");

string certificate_TTL =
// page_2() for make_selfsigned_???.pike
  ("<p class='large'>"+
   LOCALE(113,"For how long should the certificate be valid?")+
   "</p>"
   "<div class='control-group'>"
     "<label for='ttl'>"+LOCALE(114,"Certificate lifetime, in days")+
       "<small>"+
           LOCALE(115,"A certificate includes a validity period. How many days, "
                  "from now, do you want the certificate to be valid?")+
       "</small>"
     "</label>"
     "<var name='ttl' type='int' default='500'/>"
   "</div>");

string save_certificate_form (string name, string filename)
{
  return
    "<p><b>"+LOCALE(116,"Save the request in a file:")+"</b></p>"
    "<blockquote>"
    "<div class='control-group'>"
      "<label for='cert-file-name'>"
        +LOCALE(117,"Filename")+
        "<small>"+
            sprintf(LOCALE(97, "Where to store the file, may be relative to %s."),
                    combine_path(getcwd(), "../local/")) +
        "</small>"
      "</label>"
      "<var type='string' id='cert-file-name' name='"+name+"' default='"+filename+"'/>"
    "</div>"
    "</blockquote>";
}


#endif /* constant (Nettle) */
