inherit "wizard";

constant name = "Run Delete Wizard";
constant doc = "Delete an ad run.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) runs;

  runs = Advert.Run.get_runs(db);
  if (sizeof(runs) == 0)
    return "Sorry. The are no ad runs to delete.";

  ret = "Select the ad run you wish to delete:<P><TABLE>";
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

string page_1(object id)
{
  return "Are you sure you want to delete this ad run?<BR>"
	"<B>This will delete all views and referals associated with this ad run.</B><P>"
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
    Advert.Run.delete_run((int)V->id, db);
    return "The ad run has been deleted.";
  }
  else
  {
    return "The ad run will <B>not</B> be deleted.";
  }
}

