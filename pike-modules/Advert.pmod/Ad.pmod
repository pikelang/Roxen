inherit "roxenlib";

// add_ad
//	add an ad to the database
void add_ad(mapping m, object db)
{
  object result;
  string query;
  array row;

  if (m->type == "graphic")
  {
    query = "INSERT INTO graphic_ads "
        "(src, width, height, url, alt, target, js) VALUES "
        "('" + db->quote(m->src) + "'," + m->width + "," + m->height + ",'" +
        db->quote(m->url) + "','" + db->quote(m->alt) + "','" +
        db->quote(m->target) + "','" + db->quote(m->js) + "')";
    db->query(query);
    result = db->big_query("SELECT LAST_INSERT_ID()");
    row = result->fetch_row();
    query = "INSERT INTO ads (type, ad) VALUES ('graphic', "+row[0]+")";
    db->query(query);
  }
}

// get_ads
//	get a listing of ads
array(mapping) get_ads(object db)
{
  object result;
  string query, ret;
  array row, ads;

  query = "SELECT id, type, ad FROM ads ORDER BY id DESC";
  result = db->big_query(query);

  ads = ({});
  while(row = result->fetch_row())
    ads += ({ (["id":row[0],"type":row[1],"ad":row[2]]) });

  return ads;
}

// get_info
//	get an ad's data
mapping get_info(int aid, object db)
{
  object result;
  string query, ret;
  array row;
  mapping ad;

  query = "SELECT id, type, ad FROM ads WHERE id="+aid;
  result = db->big_query(query);
  row = result->fetch_row();

  ad = ([ "id" : row[0], "type" : row[1], "ad" : row[2] ]);

  if (ad->type == "graphic")
    return get_graphic_info(ad, db);
}

// get_graphic_info
//	get a graphic ad's data
mapping get_graphic_info(mapping m, object db)
{
  object result;
  string query, ret;
  array row;

  query = "SELECT id, src, width, height, url, alt, target, js "
	  "FROM graphic_ads WHERE id="+m->ad;
  result = db->big_query(query);
  row = result->fetch_row();

  return m + ([ "src" : row[1], "width" : row[2], "height" : row[3], 
		"url" : row[4], "alt" : row[5], "target" : row[6], 
		"js" : row[7] ]);
}

// set_graphic_info
//	set a graphic ad's data
void set_graphic_info(object db, mapping m)
{
  string query;

  query = "UPDATE graphic_ads SET "
	"src='"		+ db->quote(m->src)	+ "', "
	"width="	+ db->quote(m->width)	+ ", "
	"height="	+ db->quote(m->height)	+ ", "
	"url='"		+ db->quote(m->url)	+ "', "
	"alt='"		+ db->quote(m->alt)	+ "', "
	"target='"	+ db->quote(m->target)	+ "', "
	"js='"		+ db->quote(m->js)      + "' "
	"WHERE id="+db->quote(m->ad);
  db->query(query);
}

// display_ad
//	display an ad
string display_ad(mapping m, object db)
{
  if (m->type == "graphic")
    return display_graphic_ad(get_graphic_info(m, db));
  else
    return "<!-- unknown ad type -->";
}

// display_graphic_ad
//	display a graphic ad
string display_graphic_ad(mapping m)
{
  string ret, url;

  if (m->location)
    url = m->location + "/click?impression=" + m->impression + 
	"&ad=" + m->id + "&run=" + m->run +
	"&group=" + m->gid + "&url=" + http_encode_string(m->url);
  else
    url = m->url;

  ret = "<A HREF=\""+html_encode_string(url)+"\"";
  if (m->target && sizeof(m->target))
    ret += " TARGET=\""+html_encode_string(m->target)+"\"";
  if (m->js == "Y")
    ret += " onMouseover=\"setTimeout('top.window.status=\\'" + 
	html_encode_string(m->alt) + "\\'', 100);\" onMouseout=\""
	"top.window.status='';\" ";
  ret += ">";

  ret += "<IMG SRC=\""+html_encode_string(m->src)+"\" "
	"WIDTH="+html_encode_string(m->width)+" "
	"HEIGHT="+html_encode_string(m->height)+" "
	"ALT=\""+html_encode_string(m->alt)+"\"></A>";
  return ret;
}

// delete_ad
//	delete an ad. this will remove any runs or impressions
//	associated with this ad.
void delete_ad(int id, object db)
{
  object result;
  string query, ret;
  mapping m;

  m = get_info(id, db);

  // delete runs associated with the ad
  result = db->big_query("SELECT id FROM runs WHERE ad="+id);
/*
XXX - get into some ugly recursion trying to access the .Run module
      which accesses this (.Ad) module for the do_stat function.
      eventually each module will have its own stats function
      and we can uncomment this code.
  while(row = result->fetch_row())
    .Run.delete_run((int)row[0], db);
*/

  // delete any remaining impressions associated with the ad
  db->query("DELETE FROM impressions WHERE ad="+id);

  // delete the ad
  if (m->type == "graphic")
    db->query("DELETE FROM graphic_ads WHERE id="+m->ad);
  db->query("DELETE FROM ads WHERE id="+id);
}

// view
//	display an ad and log the impression
string view(mapping ad, int group, string host, int user, object db)
{
  int impression;

  if (ad->type == "graphic")
    ad += get_graphic_info(ad, db);

  impression = log_impression(ad, group, host, user, db);
  ad->impression = impression;
  return display_ad(ad, db);
}

// log_impression
int log_impression(mapping ad, int group, string host, int user, object db)
{
  string query;
  object result;
  array row;

  query = "INSERT INTO impressions (run,ad,gid,host,user,day,hour) VALUES ( " +
          ad->run+","+ad->id+","+group+",'"+host+"',"+user+","
	  "TO_DAYS(NOW()), HOUR(NOW()) )";
  db->query(query);
  result = db->big_query("SELECT LAST_INSERT_ID()");
  row = result->fetch_row();

  return (int)row[0];
}

// log_clickthrough
void log_clickthrough(int impression, int ad, int run, int gid, string host,
		int user, object db)
{
  string query;

  // logging the clickthrough on the imressions table means that for one
  // particular impression there will always be at most a single clickthrough
  // recorded regarless of how many clickthroughs actually occur.
  //
  // this can be an issue with web proxy caches as a single impression (the 
  // request by the proxy) can generate multiple clickthroughs (and
  // impressions) from clients behind the proxy. 
  //
  // we could records clickthroughs in some other table but that would skew 
  // the clickthrough ration since we would fail to record the real number
  // of impression from clients behind the proxy.
  //
  // if you are worried about this issue the solution is to enable cache 
  // busting

  query = "UPDATE impressions SET click='Y' WHERE id=" + impression;
  db->query(query);
}

// get_stats
//	returns as html the ad's statistics
string get_stats(int ad, object db)
{
  return do_stats("ad="+ad, db);
}

string do_stats(string where, object db)
{
  object result;
  array row;
  string ret, query;
  int impressions, clickthroughs;

  query = "SELECT FROM_DAYS(day) AS d, COUNT(*), COUNT(DISTINCT host), "
	  "COUNT(DISTINCT user), COUNT(IF(click = 'Y',1,NULL)) "
	  "FROM impressions WHERE "+where+" GROUP BY day ORDER BY d";

  result = db->big_query(query);
  ret = "<table cellpadding=1 cellspacing=0 border=0 bgcolor=#000000><tr><td>"
	"<TABLE border=0 cellspacing=0 cellpadding=4>"
	"<TR BGCOLOR=#113377><TH><FONT COLOR=#ffffff>Date</FONT></TH>"
	"<TH><FONT COLOR=#ffffff>Impressions</FONT></TH>"
	"<TH><FONT COLOR=#ffffff>Clickthroughs</FONT></TH>"
	"<TH><FONT COLOR=#ffffff>Rate (%)</FONT></TH>"
	"<TH><FONT COLOR=#ffffff>Hosts</FONT></TH>"
	"<TH><FONT COLOR=#ffffff>Users</FONT></TH></TR>";
  impressions = 0;
  clickthroughs = 0;

  while(row = result->fetch_row())
  {
    ret += "<TR ALIGN=RIGHT BGCOLOR=#FFFFFF>"
	   "<TD>"+row[0]+"</TD><TD>"+row[1]+"</TD><TD>"+row[4]+"</TD><TD>"+
	   sprintf("%.2f",(((float)row[4]/(float)row[1])*100)) + "</TD><TD>" + row[2] + "</TD>"
	  "<TD>" + row[3] + "</TD></TR>";
    impressions += (int)row[1];
    clickthroughs += (int)row[4];
  }

  if (impressions)
    ret += "<TR BGCOLOR=#FFFFFF><TD COLSPAN=6><HR NOSHADE></TD></TR>"
         "<TR ALIGN=RIGHT BGCOLOR=#FFFFFF>"
	 "<TD>&nbsp;</TD><TD>"+impressions+"</TD><TD>"+clickthroughs+"</TD>" 
	"<TD>"+sprintf("%.2f", ((float)clickthroughs/(float)impressions)*100) + 
	"</TD><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>";

  ret += "</TABLE>"
	 "</td></tr></table>";

  return ret;
}

// target_exposure
//	filter out any ads from the set the client has seen as
//	many times or more than the ad's maximum exposure
array(mapping) target_exposure(array(mapping) ads, object id, object db)
{
  int user;
  object result;
  array row;
  string query;

  user = (int)id->cookies->RoxenUserID;

  if (!sizeof(ads) || !user)
    return ads;

  // get all the exposure counts in a single query
  query = "SELECT run, COUNT(*) FROM impressions WHERE user="+user+ " AND ( ";
  foreach(ads, mapping ad)
    query += "run=" + ad->run + " OR ";
  query += " 1=0) GROUP BY run ORDER BY run";

  result = db->big_query(query);
  while(row = result->fetch_row())
  {
    foreach(ads, mapping ad)
      if ((ad->run == row[0]) && ((int)ad->exposure != 0) &&
	  ((int)row[1] >= (int)ad->exposure))
      {
        ads -= ({ ad });
        break;
      }
  }

  return ads;
}

// target_domain
//	target an ad by the client's hostname
array(mapping) target_domain(array(mapping) ads, object id, object db)
{
  string hostname;

  if (!sizeof(ads))
    return ads;

  // XXX - we should really be using ip_to_host() and a call back.
  // but I am to lazy right now and it screws up the flow of the code
  // by using quick_ip_to_host if the hostname is not in the cache
  // we will not have the have the hostname to target the ad correctly.
  hostname = roxen->quick_ip_to_host(id->remoteaddr);
  hostname = reverse(hostname);

  foreach(ads, mapping ad)
    // if no domains to target we assume it is visible by anyone
    if (sizeof(ad->domains))
    {
      // each whether the hostname match any of the domains.
      // if it does not remove this ad from the set
      int match = 0;
      foreach(ad->domains, string domain)
        if (reverse(domain) == hostname[0..(sizeof(domain)-1)])
        {
          match = 1;
          break;
        }
      if (!match)
        ads -= ({ ad });
    }

  return ads;
}

// target_last_ad
//	filter out the last ad the user has seen so that we does
//	not see it twice in a row
array(mapping) target_last_ad(array(mapping) ads, object id)
{
  string last_ad;

  if (!sizeof(ads) || !id->cookies->last_ad)
    return ads;

  last_ad = id->cookies->last_ad;

  foreach(ads, mapping ad)
    if (ad->id == last_ad)
    {
      ads -= ({ ad });
      break;
    }

  return ads;
}

// target_page_ads
//	filter out ads so that the user does not see the same ad
//	twice in a page
array(mapping) target_page_ads(array(mapping) ads, object id)
{
  if (!sizeof(ads) || !multisetp(id->misc->page_ads) ||
      !sizeof(id->misc->page_ads))
    return ads;

  foreach(ads, mapping ad)
    if (id->misc->page_ads[ad->id]) 
      ads -= ({ ad });
  return ads;
}

// target_competotprs
//	filter out ads so that the user does not see on the same
//	page ads from competitors
array(mapping) target_competitors(array(mapping) ads, object id)
{
  if (!sizeof(ads) || !multisetp(id->misc->page_campaigns) || 
      !sizeof(id->misc->page_campaigns))
    return ads;

  foreach(ads, mapping ad)
  {
     // is this ad a competitor of earlier ads?
     if (id->misc->page_competitors[ad->campaign])
     {
       ads -= ({ ad });
       continue;
     }
     // are any of the earlier ads a competitor to this ad?
     foreach(ad->competitors, string competitor)
       if (id->misc->page_campaigns[competitor])
       {
         ads -= ({ ad });
         break;
       }
  }
  return ads;
}

constant oses =({ ({ "Win98", "Windows 98" }),
                  ({ "Win95", "Windows 95" }),
                  ({ "WinNT", "Windows NT" }),
                  ({ "Windows NT", "Windows NT" }),
                  ({ "Windows-NT", "Windows NT" }),
                  ({ "Windows_NT", "Windows NT" }),
                  ({ "Windows 98", "Windows 98" }),
                  ({ "Windows 95", "Windows 95" }),
                  ({ "Windows 3.1", "Windows" }),
                  ({ "Mac_PowerPC", "MacOS" }),
                  ({ "Mac_68K", "MacOS" }),
                  ({ "Mac_68000", "MacOS" }),
                  ({ "Mac_PPC", "MacOS" }),
                  ({ "Macintosh", "MacOS" }),
                  ({ "Linux", "Linux" }),
                  ({ "linux", "Linux" }),
                  ({ "Solaris", "Solaris" }),
                  ({ "BSD/OS", "BSD/OS" }),
                  ({ "FreeBSD", "FreeBSD" }),
                  ({ "NetBSD", "NetBSD" }),
                  ({ "netbsd", "NetBSD" }),
                  ({ "OpenBSD", "OpenBSD" }),
                  ({ "AIX", "AIX" }),
                  ({ "OSF1", "OSF1" }),
                  ({ "IRIX", "IRIX" }),
                  ({ "HP-UX", "HP-UX" }),
                  ({ "SunOS", "SunOS" }),
                  ({ "SCO_SV", "SCO" }),
                  ({ "BeOS", "BeOS" }),
                  ({ "OS/2", "OS/2" }),
                  ({ "OpenVMS", "OpenVMS" }),
                  ({ "AmigaOS", "AmigaOS" }),
                  ({ "Win16", "Windows" }),
                  ({ "32bit", "Windows 95" }),
                  ({ "Win32", "Windows 95" }),
                  ({ "16bit", "Windows" }),
                  ({ "16-bit", "Windows" }) });

object v = Regexp("^[0-9\.]+");

string trim(string s)
{
  while((sizeof(s) > 1) && (s[0] == ' '))
    s = s[1..];
  while((sizeof(s) > 1) && (s[-1] == ' '))
    s = s[0..(sizeof(s)-2)];
  return s;
}

// parse_user_agent
//	parse the user agent string into browser name, version and os.
//	grrr. wish people followed a standard for these things
array(string) parse_user_agent(string client)
{
    string name, version, os;
    array c1, c2, c3, c4;

    name = version = os = "Unknown";

    c1 = client / "(";

    if (sizeof(c1) > 1)
    {
      c4 = replace(c1[1],"; ", ";") / ")";
      c3 = c4[0] / ";";

      // handle "... (compatible; name version; ...) ..."
      if (c3[0] == "compatible" && sizeof(c3) > 1)
        c1[0] = c3[1];

      // handle "... (...) Opera version ..."
      if (sizeof(c4) > 1)
      {
        c3 = trim(c4[1]) / " ";
        if ((sizeof(c3) > 1) && (c3[0] == "Opera"))
        {
          name = c3[0];
          version = c3[1];
        }
      }
    }

    // handle "name/version ..."
    if (name == "Unknown")
    {
      c2 = c1[0] / "/";

      name = trim(c2[0]);
      if ((sizeof(c2) > 1) && sizeof(c2[1]) && (c2[1][0] != ' '))
        version = c2[1];
    }

    // handle "name version ..."
    if (version == "Unknown")
    {
      c3 = name /" ";
      if (sizeof(c3) > 1)
      {
        string x = c3[-1];
        if (v->match(x))
        {
          version = x;
          name = c3[0..(sizeof(c3)-2)] * " ";
        }
      }
    }

    // remove the language cruft from netscape and lynx's version
    if (((name == "Mozilla") || (name == "Emacs-W3") ||
         (name == "OmniWeb") || (name == "SpaceBison"))
        && (version != "Unknown"))
      version = (version / " ")[0];

    if ((search(version, "libwww-perl") != -1) ||
        (search(version, "libwww-FM") != -1))
      version = (version/" ")[0];

    // figure out OS
    foreach(oses, array a)
      if (search(client, a[0]) != -1)
      {
        os = a[1];
        break;
      }

    name = trim(name);
    version = trim(version);
    os = trim(os);

    if (name == "")
      name = "Unknown";

    if (name == "Mozilla")
      name = "Netscape";
    if (name == "MSIE")
      name = "Internet Explorer";

    return ({ name, version, os });
}

// target_browser_and_os
//	target ads by the client's browser and operating system
array(mapping) target_browser_and_os(array(mapping) ads, object id)
{
  array parsed;

  if (!sizeof(ads))
    return ads;

  parsed = parse_user_agent(id->client*" ");
  if (sizeof(parsed) != 3)
    parsed = ({ "", "", "" });

  foreach(ads, mapping ad)
  {
    // if no browsers to target we assume it can be viewed by anyone
    if (arrayp(ad->browsers) && sizeof(ad->browsers))
    {
      // test whether the browser matches.
      // if it does not remove this ad from the set
      int match = 0;
      foreach(ad->browsers, string browser)
        if ((browser == parsed[0]) || (browser == "Other"))
        {
          match = 1;
          break;
        }
      if (!match)
      {
        ads -= ({ ad });
        continue;
      }
    }

    // if no oses to target we assume it can be viewed by anyone
    if (arrayp(ad->oses) && sizeof(ad->oses))
    {
      // test whether the os matches.
      // if it does not remove this ad from the set
      int match = 0;
      foreach(ad->oses, string os)
        if ((os == parsed[2]) || (os == "Other"))
        {
          match = 1;
          break;
        }
      if (!match)
        ads -= ({ ad });
    }
  }

  return ads;
}
