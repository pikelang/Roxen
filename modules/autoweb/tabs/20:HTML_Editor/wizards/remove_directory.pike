inherit "wizard";
import AutoWeb;

constant name = "Remove Directory";
constant doc = "";

string page_0( object id )
{
  return Misc()->wizardinput(id, "", "Are you sure you want to "
			     "remove the directory <b>" +
			     id->variables->path+"</b>?", "");
  //    id->variables->path+"</b>?", 
  //  return Error(id)->get()+
  //    "Are you sure you want to remove the directory <b>" +
  //    id->variables->path+"</b>?";
}

int verify_0( object id )
{
  array dir = AutoFile(id, id->variables->path)->get_dir();
  if (!dir||sizeof(dir)) {
    Error(id)->set("Directory is not empty");
    return 1;
  }
  Error(id)->reset();
  return 0;
}

mixed wizard_done(object id)
{
  AutoFile(id, id->variables->path)->rm();
}
