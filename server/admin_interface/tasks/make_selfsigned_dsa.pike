/*
 * $Id: make_selfsigned_dsa.pike,v 1.10 2004/05/28 23:40:37 _cvs_stephen Exp $
 */

#if constant(Crypto) && constant(Crypto.DSA)

inherit "ssl_common.pike";
inherit "wizard";

import Standards.PKCS;

#if 0
#define WERROR werror
#else
#define WERROR(x)
#endif

constant task = "SSL";
constant name = "Generate an DSA key and a Self Signed Certificate...";
constant doc  = doc_string_start + doc_string_end_b;

mixed page_0(object id, object mc)
{
  return
    ssl_errors(id) +
    "<p><font size='+1'>" + key_size_question + "</font></p>\n"
    "<b>Key size</b><br />"
    "<var name='key_size' type='select' default='1024' "
    "choices='512,576,640,704,768,832,896,960,1024'/><br />\n"
    "<blockquote><p>"+generic_key_size_string+"</p></blockquote>"
    + key_file_form("my_dsa_key.pem");
}

mixed verify_0(object id, object mc)
{
  int key_size = (int) id->variables->key_size;
  if ( (key_size < 512) || (key_size > 1024) || (key_size % 64))
  {
    id->variables->_error = "Invalid key size.";
    return 1;
  }
  object file;
  object privs = Privs("Storing private DSA key.");
  if (!(file = lopen(id->variables->key_file, "wct", 0600)))
  {
    id->variables->_error =
      "Could not open file: "
      + (strerror(errno()) || (string) errno())
      + ".";
    privs = 0;
    return 1;
  }

  privs = 0;

  object dsa = Crypto.DSA();
  dsa->generate_key(key_size);

  string key = Tools.PEM.simple_build_pem
    ("DSA PRIVATE KEY",
     Standards.PKCS.DSA.private_key(dsa));
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

  object privs = Privs("Reading private DSA key");
  if (!(file = lopen(id->variables->key_file, "r")))
  {
    privs = 0;

    return "<font color='red'>Could not open key file: "
      + strerror(errno()) + "\n</font>";
  }
  privs = 0;
  string s = file->read(0x10000);
  if (!s)
    return "<font color='red'>Could not read private key: "
      + strerror(file->errno()) + "\n</font>";

  object msg = Tools.PEM.pem_msg()->init(s);
  object part = msg->parts["DSA PRIVATE KEY"];

  if (!part)
    return "<font color='red'>Key file not formatted properly.\n</font>";

  object dsa = DSA.parse_private_key(part->decoded_body());

  if (!dsa)
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
      attrs[attr] = String.trim_whites (id->variables[attr]);
      if (attrs[attr] == "") m_delete (attrs, attr);
    }
  }

  import Standards.ASN1.Types;

  array name = ({ });
  if (attrs->countryName)
    name += ({(["countryName": asn1_printable_string (attrs->countryName)])});
  foreach( ({ "stateOrProvinceName",
	      "localityName", "organizationName",
	      "organizationUnitName", "commonName" }), attr)
  {
    if (attrs[attr])
      /* UTF8String is the recommended type. But it seems that
       * netscape can't handle that. So when PrintableString doesn't
       * suffice, we use latin1 but call it TeletexString (since at
       * least netscape expects things that way). */
      name += ({ ([ attr : (asn1_printable_valid (attrs[attr]) ?
			    asn1_printable_string :
			    asn1_broken_teletex_string) (attrs[attr]) ]) });
  }

  /* Create a plain X.509 v1 certificate, without any extensions */
  string cert = Tools.X509.make_selfsigned_dsa_certificate
    (dsa, 24 * 3600 * (int) id->variables->ttl, name);

  string res=("<font size='+2'>This is your Certificate.</font>"
	      "<textarea name='certificate' cols='80' rows='12'>");

  res += Tools.PEM.simple_build_pem("CERTIFICATE", cert);

  res += "</textarea>";

  res += save_certificate_form("cert_file", "my_dsa_certificate.pem");

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
  return http_string_answer( sprintf("<p>Wrote %d bytes to %s.</p>\n<p><cf-ok/></p>\n",
				     strlen(id->variables->certificate),
				     combine_path(getcwd(),
						  id->variables->cert_file)) );
}


mixed parse( RequestID id ) { return wizard_for(id,0); }


#endif /* constant(Crypto) && constant(Crypto.DSA) */
