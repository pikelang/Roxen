inherit "wizard";
import AutoWeb;

constant name = "Add To Menu";

string page_0( object id )
{
  mapping md = MetaData(id, id->variables->path)->get();
  string title = "";
  if(md->title)
    title = md->title;
  
  return Error(id)->get()+"<b>Enter menu title:</b>"+
    "<var name=title type=string "
    "size=40 default='"+title+"'>";
}

int verify_0( object id )
{
  if(id->variables->title == "") {
    Error(id)->set("Please enter a nonempty title");
    return 1;
  }
  return 0;
}

mixed wizard_done( object id )
{
  string path;
  if(sscanf(id->variables->path, "%s/index.html", path)>0)
    id->variables->path = path+"/";
  object file = AutoFile(id, "top.menu");
  array menu = MenuFile()->decode(file->read());
  menu += ({ ([ "url":id->variables->path, "title":id->variables->title ]) });
  file->save(MenuFile()->encode(menu));
}
