inherit "wizard";

constant name = "Run Stats";
constant doc = "Display ad run statistics.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) runs;

  runs = Advert.Run.get_runs(db);
  if (sizeof(runs) == 0)
    return "Sorry. The are no configured ad runs.";

  ret = "Select the ad run whose statistics you wish to view:<P><TABLE>";
  foreach(runs, mapping m)
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
  return Advert.Run.get_stats((int)V->id, db);
}

