
constant task = "status";
constant name = "Cache status";
constant doc  = "Show information about the main memory cache in ChiliMoon";

constant trans = ([
  "supports":"supportdb",
  "fonts":"Fonts",
  "hosts":"DNS",
]);

void clear(string name, String.Buffer buf, function flush) {
  flush();
  gc();
  buf->add( "<b>Flushed ", name, " cache.</b><br /><br />\n" );
}

string parse( RequestID id )
{
  String.Buffer res = String.Buffer(4096);
  res->add( "<input type='hidden' name='action' "
	    "value='cachestatus.pike'/>\n" );

  if(id->variables->clear_loc) {
    clear("locale", res) {
      Locale.flush_cache();
    };
  }
  else if(id->variables->clear_fe) {
    clear("frontend", res) {
      core->configurations->datacache->flush();
    };
  }
  else {
    foreach(indices(id->variables), string var)
      if(sscanf(var, "clear_g_%s", var) && var!="" &&
	 !has_suffix(var, ".x") && !has_suffix(var, ".y")) {
	// This won't work if the cache variable ends in ".x" or ".y".
	clear(var, res) {
	  cache.cache_remove(var);
        };
      }
  }

  // --- Memory Cache

  {
    res->add( "<b>Memory Cache</b><br />"
	      "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
	      "<tr bgcolor=\"&usr.fade3;\">"
	      "<td>Class</td>"
	      "<td align=\"right\">Entries</td>"
	      "<td align=\"right\">Size</td>"
	      "<td align=\"right\">Hits</td>"
	      "<td align=\"right\">Misses</td>"
	      "<td align=\"right\">Hit rate</td><td>Clear</td></tr>" );

    mapping c=cache->status();

    int totale, totalm, totalh, totalt;
    foreach(sort(indices(c)); int i; string n)
    {
      array ent=c[n];
      res->add( "<tr align=\"right\" bgcolor=\"",
		(i/3%2?"&usr.bgcolor;":"&usr.fade1;"),
		"\"><td align=\"left\">", (trans[n]||n), "</td><td>",
		(string)ent[0], "</td><td>" );
      if(ent[3]==-1)
	res->add( "unknown" );
      else
	res->add( String.int2size(ent[3]) );
      res->add( "</td><td>", (string)ent[1], "</td><td>",
		(string)(ent[2]-ent[1]), "</td>" );
      if(ent[2])
	res->add( "<td>", (string)((ent[1]*100)/ent[2]), "%</td>" );
      else
	res->add( "<td>0%</td>" );
      res->add( "</td><td>&nbsp;<submit-gbutton2 name='clear_g_", n,
		"'>Clear cache</submit-gbutton2></td></tr>\n" );
      totale += ent[0];
      totalm += ent[3];
      totalh += ent[1];
      totalt += ent[2];
    }
    res->add( "<tr align=\"right\" bgcolor=\"&usr.fade3;\">"
	      "<td align=\"left\">&nbsp;</td><td>",
	      (string)totale, "</td><td>", String.int2size(totalm), "</td>"
	      "<td>", (string)totalh, "</td><td>", (string)(totalt-totalh),
	      "</td>" );
    if(totalt)
      res->add( "<td>", (string)((totalh*100)/totalt), "%</td>" );
    else
      res->add( "<td>0%</td>" );

    res->add( "<td></td></tr></table>" );
  }


  // --- Disk Cache

  if( roxen->query("cache") )
    res->add( "<br />", roxen->get_garb_info() );


  // --- Non GC Cache

  {
    mapping c = cache->ngc_status();

    if(sizeof(c)) {
      res->add( "<br /><b>Non-garbing Memory Cache</b><br />"
		"<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
		"<tr bgcolor=\"&usr.fade3;\">"
		"<td>Class</td>"
		"<td align=\"right\">Entries</td>"
		"<td align=\"right\">Size</td></tr>" );

      int totale, totalm;
      foreach(sort(indices(c)); int i; string name) {
	array ent = c[name];
	res->add( "<tr align=\"right\" bgcolor=\"",
		  (i/3%2?"&usr.bgcolor;":"&usr.fade1;"),
		  "\"><td align=\"left\">", name, "</td><td>",
		  (string)ent[0], "</td><td>" );
	if(ent[1]==-1)
	  res->add( "unknown" );
	else
	  res->add( String.int2size(ent[1]) );
	res->add( "</td></tr>\n" );
	totale += ent[0];
	totalm += ent[1];
      }

      res->add( "<tr align=\"right\" bgcolor=\"&usr.fade3;\">"
		"<td align=\"left\">&nbsp;</td><td>",
		(string)totale, "</td><td>", String.int2size(totalm),
		"</td></tr></table>" );
    }
  }


  // --- Locale Cache

  {
    mapping l=Locale.cache_status();
    res->add( "<br /><b>Locale Cache</b><br />"
	      "<table>"
	      "<tr><td>Used languages:</td><td>", (string)l->languages,
	      "</td></tr>"
	      "<tr><td>Registered projects:</td><td>", (string)l->reg_proj,
	      "</td></tr>"
	      "<tr><td>Loaded project files:</td><td>", (string)l->load_proj,
	      "</td></tr>"
	      "<tr><td>Current cache size:</td><td>",
	      String.int2size(l->bytes), "</td></tr>"
	      "<tr><td><submit-gbutton2 name='clear_loc'>Clear cache"
	      "</submit-gbutton2></td></tr>"
	      "</table>" );
  }


  // --- Frontend Cache

  {
    int pages, hits, misses, size;
    foreach(core->configurations, Configuration conf) {
      mapping c = conf->datacache->cache_status();
      pages += c->entries;
      size += c->size;
      hits += conf->datacache->hits;
      misses += conf->datacache->misses;
    }

    res->add( "<br /><b>Frontend Cache</b><br />"
	      "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
	      "<tr><td>Pages:</td><td>", (string)pages, "</td></tr>"
	      "<tr><td>Hits:</td><td>", (string)hits, "</td></tr>"
	      "<tr><td>Misses:</td><td>", (string)misses, "</td></tr>"
	      "<tr><td>Current cache size:</td><td>", String.int2size(size),
	      "</td></tr><tr><td>"
	      "<submit-gbutton2 name='clear_fe'>Clear cache"
	      "</submit-gbutton2></td></tr></table>" );
  }

  res->add("<p><submit-gbutton2 name='reload'>Reload</submit-gbutton2>"
	   "<cf-cancel href='?class=&form.class;'/></p>");
  return (string)res;
}
