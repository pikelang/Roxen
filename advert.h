constant create_ads_table =
	"CREATE TABLE ads ("
	"  id   SMALLINT UNSIGNED      NOT NULL AUTO_INCREMENT,"
	"  type ENUM('graphic','html') NOT NULL,"
        "  ad   SMALLINT UNSIGNED      NOT NULL,"
        "  PRIMARY KEY(id)"
	");";

constant create_graphic_ads_table =
	"CREATE TABLE graphic_ads ("
	"  id     SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,"
	"  src    VARCHAR(255)      NOT NULL,"
	"  width  SMALLINT UNSIGNED NOT NULL,"
	"  height SMALLINT UNSIGNED NOT NULL,"
	"  url    VARCHAR(255)      NOT NULL,"
	"  alt    VARCHAR(255)      NOT NULL,"
	"  target VARCHAR(255)      NOT NULL,"
	"  js	  ENUM('Y','N')     NOT NULL DEFAULT 'Y',"
	"  PRIMARY KEY(id)"
	");";

constant create_runs_table =
	"CREATE TABLE runs ("
	"  id          SMALLINT  UNSIGNED NOT NULL AUTO_INCREMENT,"
	"  ad          SMALLINT  UNSIGNED NOT NULL,"
        "  campaign    SMALLINT  UNSIGNED NOT NULL,"
	"  startd      DATE               NOT NULL,"
	"  endd        DATE               NOT NULL,"
	"  impressions INT       UNSIGNED NOT NULL,"
	"  weight      MEDIUMINT UNSIGNED NOT NULL,"
	"  exposure    SMALLINT  UNSIGNED NOT NULL,"
	"  domains     TEXT               NOT NULL,"
	"  browsers    TEXT               NOT NULL,"
	"  oses        TEXT               NOT NULL,"
	"  competitors TEXT		  NOT NULL,"
        "  PRIMARY KEY(id),"
	"  KEY(ad),"
        "  KEY(startd),"
        "  KEY(endd),"
        "  KEY(impressions)"
	");";

constant create_groups_table =
	"CREATE TABLE groups ("
	"  id   SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,"
	"  name VARCHAR(255)      NOT NULL,"
        "  PRIMARY KEY(id),"
	"  UNIQUE(name)"
	");";

constant create_group_ads_table =
	"CREATE TABLE groupAds ("
	"  gid   SMALLINT UNSIGNED NOT NULL,"
	"  run   SMALLINT UNSIGNED NOT NULL,"
	"  PRIMARY KEY(gid, run),"
	"  KEY(gid),"
	"  KEY(run)"
	");";

constant create_group_default_ads_table =
	"CREATE TABLE groupDefaultAds ("
	"  gid SMALLINT UNSIGNED NOT NULL,"
	"  run SMALLINT UNSIGNED NOT NULL,"
	"  PRIMARY KEY(gid,run),"
	"  KEY(gid),"
	"  KEY(run)"
	");";

constant create_campaigns_table =
	"CREATE TABLE campaigns ("
	"  id       SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,"
	"  name     VARCHAR(255)      NOT NULL,"
	"  password VARCHAR(255)      NOT NULL,"
        "  PRIMARY KEY(id)"
	");";

constant create_impressions_table =
	"CREATE TABLE impressions ("
	"  id    INT       UNSIGNED NOT NULL AUTO_INCREMENT,"
	"  run   SMALLINT  UNSIGNED NOT NULL,"
	"  ad    SMALLINT  UNSIGNED NOT NULL,"
	"  gid   SMALLINT  UNSIGNED NOT NULL,"
	"  timestmp  TIMESTAMP          NOT NULL,"
	"  day   MEDIUMINT UNSIGNED NOT NULL,"
	"  hour  TINYINT   UNSIGNED NOT NULL,"
	"  host  CHAR(15)           NOT NULL,"
	"  user  INT       UNSIGNED NOT NULL,"
	"  click ENUM('Y','N')      NOT NULL DEFAULT 'N',"
	"  PRIMARY KEY (id),"
        "  KEY(run),"
	"  KEY(ad),"
        "  KEY(gid),"
        "  KEY(timestmp),"
	"  KEY(day,hour),"
	"  KEY(user)"
	");";

constant create_tables = ([
	"ads" 			: create_ads_table, 
	"graphic_ads" 		: create_graphic_ads_table,
	"runs" 			: create_runs_table,
        "groups" 		: create_groups_table,
	"groupAds"		: create_group_ads_table,
	"groupDefaultAds"	: create_group_default_ads_table,
	"campaigns" 		: create_campaigns_table,
	"impressions" 		: create_impressions_table ]);

constant index_page =
	"<HTML><HEAD><TITLE>Advert Configuration</TITLE></HEAD>"
	"<BODY BGCOLOR='#ffffff' TEXT='#000000' LINK='#000070' "
	"VLINK='#000070' ALINK='#ff000'>"
	"<config_tablist>"
	"<tab bgcolor=#FFFFFF href='conf/ads'>Ads</tab>"
	"<tab bgcolor=#FFFFFF href='conf/runs'>Runs</tab>"
	"<tab bgcolor=#FFFFFF href='conf/groups'>Groups</tab>"
	"<tab bgcolor=#FFFFFF href='conf/campaigns'>Campaigns</tab>"
	"<tab bgcolor=#FFFFFF href='conf/help'>Help</tab>"
	"</config_tablist>"
	"</BODY></HTML>";

// there must be a way to generate this horrible stuff from
// a template
constant ad_help =
  "<table cellpadding=1 cellspacing=0 border=0>"
  "<tr><td bgcolor=#113377 width=1%><b><font color=#ffffff size=+3>"
  "&nbsp;&lt;ad&gt;&nbsp;</font></b></td>"
  "<td><img src=/internal-roxen-unit width=200 height=1 alt=''></td></tr>"
  "<tr><td bgcolor=black colspan=2>"
  "<table cellpadding=4 border=0 cellspacing=0 width=100%>"
  "<tr><td bgcolor=#ffffff>"
  "<tt>&lt;ad&gt;</tt> is defined in the <i>Advert</i> module."
  "<p>This tag inserts an ad into the page."
  "<br clear=all><img src=/internal-roxen-unit width=1 height=10 alt=''>"
  "</td></tr></table>"
  "<table cellpadding=4 border=0 cellspacing=0><tr>"
  "<td bgcolor=#113377 width=1%><font color=white>Attributes</font></td>"
  "<td bgcolor=#ffffff>"
  "<img src=/internal-roxen-unit width=100% height=1 alt=""></td></tr>"
  "<tr><td bgcolor=#ffffff colspan=2>"
  "<a href=#brief>group</a>, <a href=#nocache>nocache</a>, "
  "<a href=#pagead>pagead</a>&nbsp;</td></tr></table>"
  "</td></tr></table>"
  "<p><b><font color=#113377 size=+2 >Attributes</font></b><dl>"
  "<p><dt><tt><b><a name=group>group</a></b></tt>"
  "<dd>The ad group from which to select the ad."
  "<p><dt><tt><b><a name=nocache>nocache</a></b><i>=proxy|client</i></tt>"
  "<dd>If <tt>proxy</tt> it instructs proxies not to cache the page with "
  "this ad. If <tt>client</tt> it instructs clients not to cache the page with "  "this ad."
  "<p><dt><tt><b><a name=pagead>pagead</a></b></tt>"
  "<dd>Force all other ads in the same ad group in this page to be the same "
  "and only count them as a single impression.</dl>"
  "<b><font color=#113377 size=+2 >Example</font></b>"
  "<table border=0 cellpadding=1 cellspacing=0 bgcolor=#000000><tr><td>"
  "<table border=0 cellspacing=0 cellpadding=4><tr>"
  "<td valign=top bgcolor=#113377>"
  "<font color=#ffffff><b>source code</b></font></td>"
  "<td bgcolor=white>"
  "<pre>&lt;ad group=homepage pagead nocache=proxy&gt;"
  "<br clear=all><img src=/internal-roxen-unit width=1 height=1 alt=''>"
  "</td></tr><tr><td height=1 bgcolor=#113377>"
  "<img src=/internal-roxen-unit width=1 height=1 alt="">"
  "</td><td height=1 bgcolor=#ffffff>"
  "<table border=0 cellpadding=0 cellspacing=0 width=100%>"
  "<tr><td bgcolor=#000000>"
  "<img src=/internal-roxen-unit width=1 height=1 alt=""></td>"
  "</tr></table></td></tr><tr><td valign=top bgcolor=#113377>"
  "<font color=#ffffff><b>result</b></font>"
  "</td><td valign=top bgcolor=#ffffff>"
  "<br clear=all><img src=/internal-roxen-unit width=1 height=1 alt=''>"
  "</td></tr></table></td></tr></table><p>";
