inherit "wizard";
// import "../directory/with/module";

constant name = "Campaign Add Wizard";
constant doc = "Add an ad campaign.";

#define V id->variables

string page_0(object id)
{
  return 
	"<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Name:</TD><TD><var type=string name=name1 size=40></TD></TR>"
        "<TR><TD>Password:</TD><TD><var type=password name=password size=40></TD></TR>"
	"</TABLE>";
}

int verify_0(object id)
{
  if (!V->name1 || !sizeof(V->name1))
    return 1;
  if (!V->password || !sizeof(V->password))
    return 1;
}

string page_1(object id, object db)
{
  V->name = V->name1;
  Advert.Campaign.add_campaign(V, db);
  return "Ad campaign has been added.";
}

