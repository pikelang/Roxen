
constant task = "status";
constant name = "Cache status";
constant doc  = "Show information about the main memory cache in ChiliMoon";

string parse( RequestID id )
{

  string res =
    "<font size='+1'><b>WebServer Memory Cache</b></font>\n"
    "<br />\n"
    "<box-frame iwidth='100%' bodybg='&usr.content-bg;' "
    "           box-frame='yes' padding='0'>\n"
    "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">\n"
    "<tr bgcolor=\"&usr.obox-titlebg;\">"
    "<th align=\"left\">Class</th>"
    "<th align=\"right\">Entries</th>"
    "<th align=\"right\">Size</th>"
    "<th align=\"right\">Hits</th>"
    "<th align=\"right\">Misses</th>"
    "<th align=\"right\">Hit rate</th></tr>\n";

  mapping c=cache->status();

  mapping trans = ([
    "supports":"supportdb",
    "fonts":"Fonts",
    "hosts":"DNS",
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
	    "\"><td align=\"left\">"+ n +"</td><td>"+ ent[0] + "</td><td>" + String.int2size(ent[3])
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
    "<td align=\"left\"><b>Total</b></td><td>" +
    totale + "</td><td>" + String.int2size(totalm) + "</td>" +
    "<td>" + totalh + "</td><td>" + (totalt-totalh) + "</td>";
  if(totalt)
    res += "<td>"+(totalh*100)/totalt+"%</td>";
  else
    res += "<td>0%</td>";

  res += "</tr></table>\n"
    "</box-frame>\n"
    "<br clear='all' />" +
    (core->query("cache")?"<br />"+ core->get_garb_info():"");


  // ---

  c = cache->ngc_status();

  if(sizeof(c)) {
    res += "<br /><font size='+1'><b>"
      "Non-garbing Memory Cache</b></font>\n"
      "<br />\n"
      "<box-frame iwidth='100%' bodybg='&usr.content-bg;' "
      "           box-frame='yes' padding='0'>\n"
      "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
      "<tr bgcolor=\"&usr.obox-titlebg;\">"
      "<th align=\"left\">Class</th>"
      "<th align=\"right\">Entries</th>"
      "<th align=\"right\">Size</th></tr>";

    i = totale = totalm = 0;
    foreach(sort(indices(c)), string name) {
      array ent = c[name];
      res += ("<tr align=\"right\" bgcolor=\"" +
	      (i/3%2?"&usr.fade1;":"&usr.obox-bgcolor;") +
	      "\"><td align=\"left\">"+ name +"</td><td>"+ ent[0] +
	      "</td><td>" +
	      String.int2size(ent[1]) + "</td></tr>");
      totale += ent[0];
      totalm += ent[1];
      i++;
    }

    res += "<tr align=\"right\" bgcolor=\"&usr.fade2;\">"
      "<td align=\"left\"><b>Total</b></td><td>" +
      totale + "</td><td>" + String.int2size(totalm) + "</td></tr>\n"
      "</table>\n"
      "</box-frame>\n"
      "<br clear='all' />\n";
  }

  // ---

  mapping l=Locale.cache_status();
  res += "<br /><font size='+1'><b>Locale Cache</b></font>"
    "<br />\n"
    "<box-frame iwidth='100%' bodybg='&usr.content-bg;' "
    "           box-frame='yes' padding='0'>\n"
    "<table>\n"
    "<tr>\n"
    "<td>Used languages:</td><td>"+l->languages+"</td></tr>\n"
    "<tr><td>Registered projects:</td><td>"+l->reg_proj+"</td></tr>\n"
    "<tr><td>Loaded project files:</td><td>"+l->load_proj+"</td></tr>\n"
    "<tr><td>Current cache size:</td><td>"+String.int2size(l->bytes)+"</td></tr>\n"
    "</table>\n"
    "</box-frame>\n"
    "<br clear='all' />\n";

  return res +
     "<input type=hidden name=task value='cachestatus.pike' />"
    "<p><cf-ok-button href='./'/> <cf-refresh/></p>";
}
