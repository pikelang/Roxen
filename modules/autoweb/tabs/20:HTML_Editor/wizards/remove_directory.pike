inherit "wizard";

constant name = "Remove Directory";
constant doc = "";

string page_0( object id )
{
  return AutoWeb.Error(id)->get()+
    "Remove directory <b>" + id->variables->path+"</b> ?";
}

int verify_0( object id )
{
  array dir = AutoWeb.AutoFile(id, id->variables->path)->get_dir();
  if (!dir||sizeof(dir)) {
    AutoWeb.Error(id)->set("Directory is not empty");
    return 1;
  }
  AutoWeb.Error(id)->reset();
  return 0;
}

mixed wizard_done(object id)
{
  AutoWeb.AutoFile(id, id->variables->path)->rm();
  // FIX ME redirect to ../
}
