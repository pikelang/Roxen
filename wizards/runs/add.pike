inherit "wizard";

constant name = "Run Add Wizard";
constant doc = "Add an ad run.";

#define V id->variables

string foo(mapping m)
{
  return m->id + ":" + html_encode_string(m->name);
}

string page_0(object id, object db)
{
  array(mapping) groups, campaigns;

  groups = Advert.Group.get_groups(db);
  campaigns = Advert.Campaign.get_campaigns(db);

  return
	"<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Campaign:</TD><TD><var type=select name=campaign options='"
	+ (Array.map(campaigns, foo) * ",") + "'></TD></TR>"
        "<TR><TD>Start date:</TD><TD><var type=select name=start-month "
	"options=01:Jan,02:Feb,03:Mar,04:Apr,05:May,06:Jun,07:Jul,08:Aug,09:Sep,10:Oct,11:Nov,12:Dec>"
	"<var type=select name=start-day options=01,02,03,04,05,06,07,08,09,"
	"10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31>"
	"<var type=select name=start-year options=1999,2000,2001,2002></TD></TR>"
	"<TR><TD>End date:</TD><TD><var type=select name=end-month "
	"options=01:Jan,02:Feb,03:Mar,04:Apr,05:May,06:Jun,07:Jul,08:Aug,09:Sep,10:Oct,11:Nov,12:Dec>"
	"<var type=select name=end-day options=01,02,03,04,05,06,07,08,09,"
	"10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31>"
	"<var type=select name=end-year options=1999,2000,2001,2002></TD></TR>"
	"<TR><TD>Desired impression:</TD>"
	"<TD><var type=int name=impressions></TD></TR>"
	"<TR><TD>Ad groups:</TD><TD>"
	"<var type=select_multiple name=groups size=5 options='"
	+ (Array.map(groups, foo) * ",") + "'></TD></TR>"
	"<TR><TD>Default groups:</TD><TD>"
	"<var type=select_multiple name=default_groups size=5 options='"
        + (Array.map(groups, foo) * ",") + "'></TD></TR>"
	"</TABLE>";
}

int verify_0(object id)
{
  if (!V->groups || !sizeof(V->groups))
    return 1;
}

string page_1(object id, object db)
{
  return
        "<TABLE CELLSPACING=0 CELLPADDING=4 BORDER=0>"
        "<TR><TD>Max user exposure:<BR>(zero = no limit)</TD><TD>"
        "<var type=int name=exposure default='0'></TD></TR>"
        "<TR VALIGN=TOP><TD>Target by domain:</TD><TD>"
        "<var type=list name=domains_ size=30>"
        "</TD></TR>"
	"<TR VALIGN=TOP><TD>Target by browser:</TD><TD>"
	"<var type=select_multiple name=browsers_ size=5 options='" +
	(Advert.Run.browsers * ",") + "'></TD></TR>"
	"<TR VALIGN=TOP><TD>Target by OS:</TD><TD>"
	"<var type=select_multiple name=oses_ size=5 options='" +
	(Advert.Run.oses * "," ) + "'></TD></TR>"
        "</TABLE>";
}

string page_2(object id, object db)
{
  array(mapping) campaigns;

  campaigns = Advert.Campaign.get_campaigns(db);

  return
        "<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Competing Campaigns:</TD><TD>"
        "<var type=select_multiple name=competitors_ size=5 options='"
        + (Array.map(campaigns, foo) * ",") + "'></TD></TR>"
        "</TABLE>";
}

string page_3(object id, object db)
{
  string ret;
  array(mapping) ads;

  ads = Advert.Ad.get_ads(db);
  if (sizeof(ads) == 0)
    return "Sorry. The are no ads.";

  ret = "Select the ad for this run:<P><TABLE>";
  foreach(ads, mapping m)
    ret +=  "<TR><TD><var type=radio name=ad value="+m->id+"></TD>"
            "<TD>"+Advert.Ad.display_ad(m, db)+"</TD></TR>";
  ret += "</TABLE>";

  return ret;
}

int verify_3(object id)
{
  if (!V->ad|| V->ad == "0")
    return 1;
}

string page_4(object id, object db)
{
  V->start = V["start-year"] + V["start-month"] + V["start-day"];
  V->end   = V["end-year"] + V["end-month"] + V["end-day"];
  V->domains     = V->domains_     ? (V->domains_     / "\0") - ({""}) : ({});
  V->browsers    = V->browsers_    ? (V->browsers_    / "\0") - ({""}) : ({});
  V->oses        = V->oses_        ? (V->oses_        / "\0") - ({""}) : ({});
  V->competitors = V->competitors_ ? (V->competitors_ / "\0") - ({""}) : ({});
  Advert.Run.add_run(V, db);
  return "Ad run has been added.";
}

