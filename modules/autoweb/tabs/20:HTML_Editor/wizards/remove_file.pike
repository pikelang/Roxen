inherit "wizard";

constant name = "Remove File";


string page_0( object id )
{
  return "Remove file "+id->variables->path+" ?";
}

mixed wizard_done( object id )
{
  rm(id->misc->wa->real_path(id, id->variables->path));
  rm(id->misc->wa->real_path(id, id->variables->path+".md"));

  // FIX ME redirect to ../
}


