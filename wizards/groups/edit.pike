inherit "wizard";

constant name = "Group Edit Wizard";
constant doc = "Edit an ad group.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) groups;

  groups = Advert.Group.get_groups(db);
  if (sizeof(groups) == 0)
    return "Sorry. The are no ad groups to edit.";

  ret = "Select the ad group you wish to edit:<P><TABLE>";
  foreach(groups, mapping m)
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

  m = Advert.Group.get_info((int)V->id, db);

  return 
        "<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Name:</TD><TD>"
	"<var type=string name=name1 size=40 default='"+html_encode_string(m->name)+"'></TD></TR>"
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
  Advert.Group.set_info(V, db);
  return "The ad group has been updated.";
}

