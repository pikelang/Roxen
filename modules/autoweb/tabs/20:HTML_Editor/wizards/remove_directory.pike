inherit "wizard";

constant name = "Remove Directory";
constant doc = "";

string page_0( object id )
{
  if (sizeof(get_dir(id->misc->wa->real_path(id, id->variables->path)))) {
    id->variables->dir = "empty";
    return "Directory is not empty";
  }
  return "Remove directory " + id->variables->path+" ?";
}

string verify_0( object id )
{
  if (id->variables->dir == "empty")
    return 0;
  // FIX ME redirect to ../
}

void wizard_done(object id)
{
  rm(id->misc->wa->real_path(id, id->variables->path));
}
