inherit "wizard";
import AutoWeb;

constant name = "Move Directory";
constant doc = "";

string page_0( object id )
{
  return Error(id)->get() + "<b>Full path of new location:</b>"
    "<var size=40 name=newpath default=" + id->variables->path + ">";
}

int verify_0( object id )
{
  if (id->variables->newpath=="" ||
      id->variables->newpath[0]!='/')
    id->variables->newpath = "/" + id->variables->newpath;
  if (sscanf(id->variables->newpath, id->variables->path + "%*s")) {
    Error(id)->set("Cannot move a directory to itself");
    return 1;
  }
  if (AutoFile(id, id->variables->newpath)->type()=="File") {
    Error(id)->set("A File " + id->variables->newpath + " exists");
    return 1;
  }
  Error(id)->reset();
}

string page_1( object id )
{
  return Error(id)->get()+
    "Move directory from <b>" + id->variables->path +
    "</b> to <b>" + id->variables->newpath + "</b> ?";
}

mixed wizard_done( object id )
{
  AutoFile(id, id->variables->path)->
    move(id->variables->newpath);
}
