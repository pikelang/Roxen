inherit "wizard";

constant name = "Group Stats";
constant doc = "Display ad group statistics.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) groups;

  groups = Advert.Group.get_groups(db);
  if (sizeof(groups) == 0)
    return "Sorry. The are no configured ad groups.";

  ret = "Select the ad group whose statistics wish to display:<P><TABLE>";
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
  return Advert.Group.get_stats((int)V->id, db);
}

