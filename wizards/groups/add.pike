inherit "wizard";

constant name = "Group Add Wizard";
constant doc = "Add an ad group.";

#define V id->variables

string page_0(object id)
{
  return 
	"<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Name:</TD><TD><var type=string name=name1 size=40></TD></TR>"
	"</TABLE>";
}

int verify_0(object id)
{
  if (!V->name1 || !sizeof(V->name1))
    return 1;
}

string page_1(object id, object db)
{
  V->name = V->name1;
  Advert.Group.add_group(V, db);
  return "Ad group has been added.";
}

