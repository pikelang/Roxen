inherit "wizard";

constant name = "Campaign Edit Wizard";
constant doc = "Edit an ad campaign.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) campaigns;

  campaigns = Advert.Campaign.get_campaigns(db);
  if (sizeof(campaigns) == 0)
    return "Sorry. The are no ad campaigns to edit.";

  ret = "Select the ad campaign you wish to edit:<P><TABLE>";
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
  mapping m;

  m = Advert.Campaign.get_info((int)V->id, db);

  return 
        "<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Name:</TD><TD>"
	"<var type=string name=name1 size=40 default='"+html_encode_string(m->name)+"'></TD></TR>"
        "<TR><TD>Password:</TD><TD>"
	"<var type=password name=password size=40>"
        "</TD></TR></TABLE>";
}

int verify_1(object id)
{
  if (!V->name1 || !sizeof(V->name1))
    return 1;
}

string page_2(object id, object db)
{
  V->name = V->name1;
  Advert.Campaign.set_info(V, db);
  return "The ad campaign has been updated.";
}

