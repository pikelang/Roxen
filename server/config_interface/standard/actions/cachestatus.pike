
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "status";
constant name = "Cache Status";
constant name_svenska = "Cachestatus";

constant doc = "Show information about the main memory cache in roxen";
constant doc_svenska = "Visa information om minnescachen i roxen";

string parse( RequestID id )
{

  string res = "<b>"+LOCALE(0, "WebServer Memory Cache")+"</b><br />"
    "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
    "<tr bgcolor=\"&usr.fade3;\">"
    "<td>"+LOCALE(0, "Class")+"</td>"
    "<td align=\"right\">"+LOCALE(0, "Entries")+"</td>"
    "<td align=\"right\">"+LOCALE(0, "Size")+"</td>"
    "<td align=\"right\">"+LOCALE(0, "Hits")+"</td>"
    "<td align=\"right\">"+LOCALE(0, "Misses")+"</td>"
    "<td align=\"right\">"+LOCALE(0, "Hit rate")+"</td>";

  mapping c=cache->status();

  mapping trans = ([
    "supports":LOCALE(0,"supportdb"),
    "fonts":LOCALE(0,"fonts"),
    "hosts":LOCALE(0,"DNS"),
  ]);

  foreach(indices(c), string n)
    if(trans[n]) {
      c[trans[n]]=c[n];
      m_delete(c, n);
    }

  int i, totale, totalm, totalh, totalt;
  foreach(sort(indices(c)), string n)
  {
    array ent=c[n];
    res += ("<tr align=\"right\" bgcolor=\"" + (i/3%2?"&usr.bgcolor;":"&usr.fade1;") +
	    "\"><td align=\"left\">"+ n +"</td><td>"+ ent[0] + "</td><td>" + Roxen.sizetostring(ent[3])
	    + "</td><td>" + ent[1] + "</td><td>" + (ent[2]-ent[1]) + "</td>");
    if(ent[2])
      res += "<td>" + (ent[1]*100)/ent[2] + "%</td>";
    else
      res += "<td>0%</td>";
    res += "</tr>";
    totale += ent[0];
    totalm += ent[3];
    totalh += ent[1];
    totalt += ent[2];
    i++;
  }
  res += "<tr align=\"right\" bgcolor=\"&usr.fade3;\"><td align=\"left\">&nbsp;</td><td>" +
    totale + "</td><td>" + Roxen.sizetostring(totalm) + "</td>" +
    "<td>" + totalh + "</td><td>" + (totalt-totalh) + "</td>";
  if(totalt)
    res += "<td>"+(totalh*100)/totalt+"%</td>";
  else
    res += "<td>0%</td>";

  res += "</tr></table>" +
    (roxen->query("cache")?"<br />"+ roxen->get_garb_info():"");

#if constant(Locale.cache_status)
  mapping l=Locale.cache_status();
#else
  mapping l=RoxenLocale.cache_status();
#endif
  res += "<br /><b>"+LOCALE(0, "Locale Cache")+"</b><br />"
    "<table>"
    "<tr><td>"+LOCALE(0, "Loaded languages:")+"</td><td>"+l->languages+"</td></tr>"
    "<tr><td>"+LOCALE(0, "Registered projects:")+"</td><td>"+l->reg_proj+"</td></tr>"
    "<tr><td>"+LOCALE(0, "Loaded projects:")+"</td><td>"+l->load_proj+"</td></tr>"
    "<tr><td>"+LOCALE(0, "Current cache size:")+"</td><td>"+Roxen.sizetostring(l->bytes)+"</td></tr>"
    "</table><br />";

  return res +  "<p><cf-ok/></p>";
}
