
constant task = "status";
constant name = "Cache status";
constant doc  = "Show information about the main memory cache in ChiliMoon";

string parse( RequestID id )
{

  string res = "<b>Memory Cache</b><br />"
    "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
    "<tr bgcolor=\"&usr.fade3;\">"
    "<td>Class</td>"
    "<td align=\"right\">Entries</td>"
    "<td align=\"right\">Size</td>"
    "<td align=\"right\">Hits</td>"
    "<td align=\"right\">Misses</td>"
    "<td align=\"right\">Hit rate</td></tr>";

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
    res += ("<tr align=\"right\" bgcolor=\"" + (i/3%2?"&usr.bgcolor;":"&usr.fade1;") +
	    "\"><td align=\"left\">"+ n +"</td><td>"+ ent[0] + "</td><td>");
    if(ent[3]==-1)
      res += "unknown";
    else
      res += Roxen.sizetostring(ent[3]);
    res += "</td><td>" + ent[1] + "</td><td>" + (ent[2]-ent[1]) + "</td>";
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


  // ---

  c = cache->ngc_status();

  if(sizeof(c)) {
    res += "<br /><b>Non-garbing Memory Cache</b><br />"
      "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
      "<tr bgcolor=\"&usr.fade3;\">"
      "<td>Class</td>"
      "<td align=\"right\">Entries</td>"
      "<td align=\"right\">Size</td></tr>";

    i = totale = totalm = 0;
    foreach(sort(indices(c)), string name) {
      array ent = c[name];
      res += ("<tr align=\"right\" bgcolor=\"" + (i/3%2?"&usr.bgcolor;":"&usr.fade1;") +
	      "\"><td align=\"left\">"+ name +"</td><td>"+ ent[0] + "</td><td>");
      if(ent[1]==-1)
	res += "unknown";
      else
	res += Roxen.sizetostring(ent[1]);
      res += "</td></tr>";
      totale += ent[0];
      totalm += ent[1];
      i++;
    }

    res += "<tr align=\"right\" bgcolor=\"&usr.fade3;\"><td align=\"left\">&nbsp;</td><td>" +
      totale + "</td><td>" + Roxen.sizetostring(totalm) + "</td></tr></table>";
  }

  // ---

  mapping l=Locale.cache_status();
  res += "<br /><b>Locale Cache</b><br />"
    "<table>"
    "<tr><td>Used languages:</td><td>"+l->languages+"</td></tr>"
    "<tr><td>Registered projects:</td><td>"+l->reg_proj+"</td></tr>"
    "<tr><td>Loaded project files:</td><td>"+l->load_proj+"</td></tr>"
    "<tr><td>Current cache size:</td><td>"+Roxen.sizetostring(l->bytes)+"</td></tr>"
    "</table><br />";

  return res +  "<p><cf-ok/></p>";
}
