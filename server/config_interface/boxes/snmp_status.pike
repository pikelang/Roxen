// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)  _DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 1;

LocaleString box_name = _(1066,"SNMP status");
LocaleString box_doc  = _(1067,"Global SNMP server statistics");

// string add_row( string item, string value ) {
//   return "<tr><td>" + item + ":</td><td>" + value + "</td></tr>";
// }

string parse( RequestID id )
{
  array(int) oid_prefix = SNMP.RIS_OID_WEBSERVER;

  array(string) res = ({
    "<th>Name</th>"
    "<th>Value</th>",
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
                "<td>%s%s</td>",
                oid_string,
                Roxen.html_encode_string(name),
                Roxen.html_encode_string(val),
                sizeof(doc)
                  ? "<br><small>" + doc + "</small>" : ""),
    });
  }

  string out;
  if (sizeof(res) <= 1) {
    out =
      "<div><span class='notify info inline'>"
      "No active SNMP ports.</span></div>";
  }
  else {
    out =
      "<div class='negative-wrapper'>"
      "<table class='nice snmp'><thead><tr>" + res[0] + "</tr></thead>"
      "<tbody><tr>" + (res[1..]*"</tr><tr>") + "</tr></tbody></table>"
      "</div>";
  }

  return
    "<cbox type='"+box+"' title='"+box_name+"'>"+ out + "</cbox>";
}
