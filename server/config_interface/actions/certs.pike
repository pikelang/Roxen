/*
 * $Id$
 */

inherit "wizard";

#include <roxen.h>

//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "SSL";

string name = LOCALE(0, "Certificate Handling");
string doc = LOCALE(0, #"
Handling of SSL/TLS certificates, keys and certificate chains.
");

protected string cert_sort_key(mapping(string:string|int) cert_info)
{
  if (!cert_info) return "";
  mapping(string:array(string)) metadata =
    CertDB.get_cert_metadata(cert_info->id);
  return (metadata->issuer_cn || ({})) * ", " + "\0" +
    (metadata->cn || ({})) * ", ";
}

mixed page_0(RequestID id, mixed mc)
{
  string res =
    sprintf("<h3>%s</h3>\n\n"
	    "<table>\n",
	    LOCALE(0, "Certificates and Keys"));
  array(mapping(string:string|int)) keys = CertDB.list_keys();
  array(mapping(string:string|int)) certs = map(keys->cert_id, CertDB.get_cert);
  sort(map(certs, cert_sort_key), certs, keys);

  int|string current_issuer = -1;
  foreach(keys; int i; mapping(string:string|int) key_info) {
    mapping(string:string|int) cert_info = certs[i];
    if (!cert_info) {
      if (current_issuer) {
	current_issuer = 0;
	res += sprintf("<tr><th colspan='3' align='left'>%s</td></tr>\n",
		       LOCALE(0, "Missing certificates"));
      }
    } else {
      mapping(string:array(string|int)) metadata =
	CertDB.get_cert_metadata(cert_info->id);
      string issuer_cn = (metadata->issuer_cn || ({})) * ", ";
      if (current_issuer != issuer_cn) {
	current_issuer = issuer_cn;
	res += sprintf("<tr><th colspan='3' align='left'>%s</td></tr>\n",
		       Roxen.html_encode_string(current_issuer));
	// FIXME: List chained certs if any.
      }
      res += sprintf("<tr><td>&nbsp;</td><th colspan='2' align='left'>%s</td></tr>\n"
		     "<tr><td>&nbsp;</td><td colspan='2'><tt>%s</tt></td></tr>\n",
		     "<tr><td>&nbsp;</td><td colspan='2'><tt>%s</tt></td></tr>\n",
		     map(metadata->dn || ({}), Roxen.html_encode_string) * ", ",
		     map(metadata->cn || ({}), Roxen.html_encode_string) * ", ",
		     Roxen.html_encode_string(cert_info->path));
    }
    res += sprintf("<tr><td>&nbsp;</td><td colspan='2'><tt>%s</tt></td></tr>\n",
		   Roxen.html_encode_string(key_info->path));
  }
  res += "</table>\n";
  res += sprintf("<submit-gbutton>Upload Certificate</submit-gbutton>\n");
  return res;
}

mixed parse( RequestID id ) { return wizard_for(id, 0); }
