inherit "wizard";
import AutoWeb;

constant name = "Move/Rename File";
constant doc = "";

string page_0( object id )
{
  return Error(id)->get() + "<b>Full path of moved file:</b>"
    "<var size=40 name=newpath default=" + id->variables->path + ">";
}

int verify_0( object id )
{
  if (id->variables->newpath=="" ||
      id->variables->newpath[0]!='/')
    id->variables->newpath = "/" + id->variables->newpath;
  string path=combine_path(id->variables->newpath+"/", "../");
  if (AutoFile(id, path)->type()!="Directory") {
    Error(id)->set("Directory "+path+" does not exist.");
    return 1;
  }
  if (AutoFile(id, id->variables->newpath)->type()=="File") {
    Error(id)->set("A File " + id->variables->newpath + " exists");
    return 1;
  }
  Error(id)->reset();
  return 0;
}

string page_1( object id )
{
  return Error(id)->get() + "Move file from <b>" + id->variables->path +
    "</b> to <b>" + id->variables->newpath + "</b> ?";
}

mixed wizard_done( object id )
{
  AutoFile(id, id->variables->path)->move(id->variables->newpath);
  AutoFile(id, id->variables->path+".md")->move(id->variables->newpath+".md");
}
