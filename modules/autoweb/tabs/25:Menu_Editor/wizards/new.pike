inherit "wizard";
import AutoWeb;

constant name = "New...";

string page_0( object id )
{
  return Error(id)->get() + "<b>Enter full path of file for new menu item: </b>"
    "<var size=40 name=path>";
}


int verify_0( object id )
{
  if (id->variables->path=="" ||
      id->variables->path[0]!='/')
    id->variables->path = "/" + id->variables->path;
  if(AutoFile(id, id->variables->path)->type()!="File") {
    Error(id)->set("file <b>"+id->variables->path+"</b> does not exist");
  return 1;
  }
  Error(id)->reset();
}

string page_1(object id)
{
  return Error(id)->get()+
    "<b>Enter the title of the new menu item: </b>"
    "<var size=40 name=title default='"+
    MetaData(id, id->variables->path)->get()->title+"'>";
}

int verify_1(object id)
{
  if(id->variables->title=="") {
    Error(id)->set("Please enter a non empty title");
    return 1;
  }
}

mixed wizard_done(object id)
{
  object file = AutoFile(id, "top.menu");
  file->save(MenuFile()->encode(MenuFile()->decode(file->read()) +
				({ ([ "url":id->variables->path,
				      "title":id->variables->title ]) }) ));
}
