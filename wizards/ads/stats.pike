inherit "wizard";

constant name = "Ad Stats";
constant doc = "Display ad statistics.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) ads;

  ads = Advert.Ad.get_ads(db);
  if (sizeof(ads) == 0)
    return "Sorry. The are no configured ads.";

  ret = "Select the ad whose statistics you wish to view:<P><TABLE>";
  foreach(ads, mapping m)
    ret +=  "<TR><TD><var type=radio name=ad value="+m->id+"></TD>"
	    "<TD>"+Advert.Ad.display_ad(m, db)+"</TD></TR>";
  ret += "</TABLE>";

  return ret;
}

int verify_0(object id)
{
  if (!V->ad || V->ad == "0")
    return 1;
}

string page_1(object id, object db)
{
  return Advert.Ad.get_stats((int)V->ad, db);
}

