// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 1;

LocaleString box_name = _(0,"SNMP status");
LocaleString box_doc  = _(0,"Global SNMP server statistics");

string add_row( string item, string value ) {
  return "<tr><td>" + item + ":</td><td>" + value + "</td></tr>";
}

string parse( RequestID id )
{
  array(int) oid_prefix = SNMP.RIS_OID_WEBSERVER;

  array(string) res = ({
    "<th align='left'>Name</th>"
    "<th align='left'>Value</th>",
  });

  ADT.Trie mib = ADT.Trie();

conf_loop:
  foreach(roxen->configurations, Configuration conf) {
    foreach(conf->registered_urls, string url) {
      mapping(string:string|Configuration|Protocol) port_info = roxen.urls[url];

      foreach((port_info && port_info->ports) || ({}), Protocol prot) {
	if ((prot->prot_name != "snmp") || (!prot->mib)) {
	  continue;
	}
	mib->merge(prot->mib);
	break conf_loop;
      }
    }
  }

  array(int) oid_stop = SNMP.RIS_OID_WEBSERVER + ({ 2 });
  array(int) oid_start = mib->first();
  for (array(int) oid = oid_start; oid; oid = mib->next(oid)) {
    if ((string)oid >= (string)oid_stop) break;
    string oid_string = ((array(string)) oid) * ".";
    string name = "";
    string doc = "";
    mixed val = "";
    mixed err = catch {
	val = mib->lookup(oid);
	if (zero_type(val)) continue;
	if (objectp(val)) {
	  if (val->update_value) {
	    val->update_value();
	  }
	  name = val->name || "";
	  doc = val->doc || "";
	  val = sprintf("%s", val);
	}
	val = (string)val;
      };
    if (err) {
      name = "Error";
      val = "";
      doc = "<tt>" +
	replace(Roxen.html_encode_string(describe_backtrace(err)),
		"\n", "<br />\n") +
	"</tt>";
    }
    if (!sizeof(name)) continue;
    res += ({
	sprintf("<td><b><a href=\"urn:oid:%s\">%s:</a></b></td>"
		"<td>%s</td>",
		oid_string,
		Roxen.html_encode_string(name),
		Roxen.html_encode_string(val)),
    });
    if (sizeof(doc)) {
      res += ({
	sprintf("<td></td><td><font size='-1'>%s</font></td>", doc),
      });
    }
  }

  if (sizeof(res) <= 1) {
    res = ({ "<th align='left'>No active SNMP ports.</th>" });
  }

  return
    "<box type='"+box+"' title='"+box_name+"'><table cellpadding='0'><tr>" +
    res * "</tr>\n<tr>" +
    "</tr></table></box>\n";
}
