inherit "wizard";
import AutoWeb;

constant name = "Move/Rename Dir";
constant doc = "";

string page_0( object id )
{
  return Misc()->wizardinput(id, "New location:",
			   "Pleace enter full path "
			   "of the new location.",
			   "<var size=40 name=newpath default=" +
			   id->variables->path + ">");
}

int verify_0( object id )
{
  if (id->variables->newpath=="" ||
      id->variables->newpath[0]!='/')
    id->variables->newpath = "/" + id->variables->newpath;
  if (sscanf(id->variables->newpath, id->variables->path + "%*s")) {
    Error(id)->set("Cannot move a directory to itself.");
    return 1;
  }
  if (AutoFile(id, id->variables->newpath)->type()=="File") {
    Error(id)->set("A File " + id->variables->newpath + " exists.");
    return 1;
  }
  Error(id)->reset();
}

string page_1( object id )
{
  return "Are you sure you want to move the directory <b>"
    +id->variables->path + "</b> to <b>" + id->variables->newpath + "</b>?";
}

mixed wizard_done( object id )
{
  AutoFile(id, id->variables->path)->
    move(id->variables->newpath);
}
