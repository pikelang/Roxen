inherit "wizard";

constant name = "Group Delete Wizard";
constant doc = "Delete an ad group.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) groups;

  groups = Advert.Group.get_groups(db);
  if (sizeof(groups) == 0)
    return "Sorry. The are no ad groups to edit.";

  ret = "Select the ad group you wish to delete:<P><TABLE>";
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

string page_1(object id)
{
  return "Are you sure you want to delete this ad group?<BR>"
	"<B>This will delete all views and referals associated with this ad group.</B><P>"
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
    Advert.Group.delete_group((int)V->id, db);
    return "The ad group has been deleted.";
  }
  else
  {
    return "The ad group will <B>not</B> be deleted.";
  }
}

