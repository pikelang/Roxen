inherit "wizard";
import AutoWeb;

constant name = "Create File";

string page_0( object id )
{
  return Misc()->wizardinput(id, "Filename:",
			     "Pleace enter the filename "
			     "for the new file.",
			     "<var name=filename type=string "
			     "size=40 default=\""+
			     replace((id->variables->path||"/")+"/",
				     "//", "/") + "\">");
}

int verify_0(object id)
{
  if (id->variables->filename=="" ||
      id->variables->filename[0]!='/')
  {
    id->variables->filename = "/" + id->variables->filename;
    if (id->variables->filename[-1] == '/')
      id->variables->filename+="index.html";
    return 1;
  }
  
  if (id->variables->filename[-1] == '/')
  {
    id->variables->filename+="index.html";
    return 1;
  }

  string path;
  sscanf(reverse(id->variables->filename), "%*s/%s", path);
  path = reverse(path);
  if (AutoFile(id, path)->type()!="Directory")
  {
    Error(id)->set("Directory <b>" + path + "/</b> does not exist");
    return 1;
  }
  
  if (AutoFile(id, id->variables->filename)->type()=="File")
  {
    Error(id)->set("File <b>" + id->variables->filename +
			   "</b> exists");
    return 1;
  }
  
  if (AutoFile(id, id->variables->filename)->type()=="Directory")
  {
    Error(id)->set("Directory <b>" + id->variables->filename +
		   "</b> exists");
    return 1;
  }
  Error(id)->reset();
}

string page_1(object id)
{
  return Error(id)->get()
    + EditMetaData()->page(id, id->variables->filename,
			   MetaData(id, id->variables->filename)->
			   get_from_html(""));
}

mixed wizard_done( object id )
{
  EditMetaData()->done(id, id->variables->filename);
  AutoFile(id, id->variables->filename)->save("");
}
