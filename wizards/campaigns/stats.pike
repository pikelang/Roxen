inherit "wizard";

constant name = "Campaign Stats";
constant doc = "Display ad campaign statistics.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) campaigns;

  campaigns = Advert.Campaign.get_campaigns(db);
  if (sizeof(campaigns) == 0)
    return "Sorry. The are no configured ad campaigns.";

  ret = "Select the ad campaign whose statistics you wish to view:<P><TABLE>";
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

string page_1(object id, object db)
{
  return Advert.Campaign.get_stats((int)V->id, db);
}

