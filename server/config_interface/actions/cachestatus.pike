
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(59, "Cache status");
string doc = LOCALE(60, 
		    "Show information about the main memory cache in Roxen");

string parse( RequestID id )
{

  string res =
    "<font size='+1'><b>"+LOCALE(61, "WebServer Memory Cache")+"</b></font>\n"
    "<br />\n"
    "<box-frame iwidth='100%' bodybg='&usr.content-bg;' "
    "           box-frame='yes' padding='0'>\n"
    "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">\n"
    "<tr bgcolor=\"&usr.obox-titlebg;\">"
    "<th align=\"left\">"+LOCALE(62, "Class")+"</th>"
    "<th align=\"right\">"+LOCALE(295, "Entries")+"</th>"
    "<th align=\"right\">"+LOCALE(64, "Size")+"</th>"
    "<th align=\"right\">"+LOCALE(293, "Hits")+"</th>"
    "<th align=\"right\">"+LOCALE(294, "Misses")+"</th>"
    "<th align=\"right\">"+LOCALE(67, "Hit rate")+"</th></tr>\n";

  mapping c=cache->status();

  mapping trans = ([
    "supports":LOCALE(68,"supportdb"),
    "fonts":LOCALE(69,"Fonts"),
    "hosts":LOCALE(70,"DNS"),
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
    res += ("<tr align=\"right\" bgcolor=\"" + (i/3%2?"&usr.fade1;":"&usr.obox-bodybg;") +
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
  res += "<tr align=\"right\" bgcolor=\"&usr.fade2;\">"
    "<td align=\"left\"><b>"+LOCALE(178, "Total")+"</b></td><td>" +
    totale + "</td><td>" + Roxen.sizetostring(totalm) + "</td>" +
    "<td>" + totalh + "</td><td>" + (totalt-totalh) + "</td>";
  if(totalt)
    res += "<td>"+(totalh*100)/totalt+"%</td>";
  else
    res += "<td>0%</td>";

  res += "</tr></table>\n"
    "</box-frame>\n"
    "<br clear='all' />" +
    (roxen->query("cache")?"<br />"+ roxen->get_garb_info():"");


  // ---

  c = cache->ngc_status();

  if(sizeof(c)) {
    res += "<br /><font size='+1'><b>"+
      LOCALE(87, "Non-garbing Memory Cache")+"</b></font>\n"
      "<br />\n"
      "<box-frame iwidth='100%' bodybg='&usr.content-bg;' "
      "           box-frame='yes' padding='0'>\n"
      "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
      "<tr bgcolor=\"&usr.obox-titlebg;\">"
      "<th align=\"left\">"+LOCALE(62, "Class")+"</th>"
      "<th align=\"right\">"+LOCALE(295, "Entries")+"</th>"
      "<th align=\"right\">"+LOCALE(64, "Size")+"</th></tr>";

    i = totale = totalm = 0;
    foreach(sort(indices(c)), string name) {
      array ent = c[name];
      res += ("<tr align=\"right\" bgcolor=\"" +
	      (i/3%2?"&usr.fade1;":"&usr.obox-bgcolor;") +
	      "\"><td align=\"left\">"+ name +"</td><td>"+ ent[0] +
	      "</td><td>" +
	      Roxen.sizetostring(ent[1]) + "</td></tr>");
      totale += ent[0];
      totalm += ent[1];
      i++;
    }

    res += "<tr align=\"right\" bgcolor=\"&usr.fade2;\">"
      "<td align=\"left\"><b>"+LOCALE(178, "Total")+"</b></td><td>" +
      totale + "</td><td>" + Roxen.sizetostring(totalm) + "</td></tr>\n"
      "</table>\n"
      "</box-frame>\n"
      "<br clear='all' />\n";
  }

  // ---

  mapping l=Locale.cache_status();
  res += "<br /><font size='+1'><b>"+LOCALE(71, "Locale Cache")+"</b></font>"
    "<br />\n"
    "<box-frame iwidth='100%' bodybg='&usr.content-bg;' "
    "           box-frame='yes' padding='0'>\n"
    "<table>\n"
    "<tr>\n"
    "<td>"+LOCALE(72, "Used languages:")+"</td><td>"+l->languages+"</td></tr>\n"
    "<tr><td>"+LOCALE(73, "Registered projects:")+"</td><td>"+l->reg_proj+"</td></tr>\n"
    "<tr><td>"+LOCALE(74, "Loaded project files:")+"</td><td>"+l->load_proj+"</td></tr>\n"
    "<tr><td>"+LOCALE(75, "Current cache size:")+"</td><td>"+Roxen.sizetostring(l->bytes)+"</td></tr>\n"
    "</table>\n"
    "</box-frame>\n"
    "<br clear='all' />\n";

  return res +
     "<input type=hidden name=action value='cachestatus.pike' />"
    "<p><cf-ok-button href='./'/> <cf-refresh/></p>";
}
