inherit "wizard";

constant name = "Campaign Delete Wizard";
constant doc = "Delete an ad campaign.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) campaigns;

  campaigns = Advert.Campaign.get_campaigns(db);
  if (sizeof(campaigns) == 0)
    return "Sorry. The are no ad campaigns to edit.";

  ret = "Select the ad campaign you wish to delete:<P><TABLE>";
  foreach(campaigns, mapping m)
    ret +=  "<TR><TD><var type=radio name=id value="+m->id+"></TD>"
            "<TD>"+html_encode_string(m->name)+"</TD></TR>";
  ret += "</TABLE>";

  return ret;
}

int verify_0(object id)
{
  if (!V->id || V->id == "0")
    return 1;
}

string page_1(object id)
{
  return "Are you sure you want to delete this ad campaign?<BR>"
	"<B>This will delete all runs, views and referals associated with this ad campaign.</B><P>"
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
    Advert.Campaign.delete_campaign((int)V->id, db);
    return "The ad campaign has been deleted.";
  }
  else
  {
    return "The ad campaign will <B>not</B> be deleted.";
  }
}

