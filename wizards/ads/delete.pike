inherit "wizard";

constant name = "Ad Delete Wizard";
constant doc = "Delete an ad.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) ads;

  ads = Advert.Ad.get_ads(db);
  if (sizeof(ads) == 0)
    return "Sorry. The are no ads to delete.";

  ret = "Select the ad you wish to delete:<P><TABLE>";
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

string page_1(object id)
{
  return "Are you sure you want to delete this ad?<BR>"
	"This will delete all views and referals associated with this ad.<P>"
	"<CENTER>"
	"<var type=radio name=sure value=y> Yes "
	"<var type=radio name=sure value=n> No"
	"</CENTER>";
}

int verify_1(object id)
{
  if (!V->sure || (V->sure != "y" && V->sure != "n"))
    return 1;
}

string page_2(object id, object db)
{
  if (V->sure == "y")
  {
    Advert.Ad.delete_ad((int)V->ad, db);
    return "The ad has been deleted.";
  }
  else
  {
    return "The ad will <B>not</B> be deleted.";
  }
}

