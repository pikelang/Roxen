inherit "wizard";

constant name = "Create File";

string page_0( object id )
{
  return AutoWeb.Error(id)->get()+"<b>Select filename:</b>"
    "<var name=filename type=string "
    "size=40 default=\""+
    replace((id->variables->path||"/")+"/", "//", "/") + "\">";
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
  if (AutoWeb.AutoFile(id, path)->type()!="Directory")
  {
    AutoWeb.Error(id)->set("Directory <b>" + path + "/</b> does not exist");
    return 1;
  }
  if (AutoWeb.AutoFile(id, id->variables->filename)->type()=="File")
    {
    AutoWeb.Error(id)->set("File <b>" + id->variables->filename +
			   "</b> exists");
    return 1;
  }
  AutoWeb.Error(id)->reset();
}

string page_1(object id)
{
  return AutoWeb.Error(id)->get()
    + AutoWeb.EditMetaData()->page(id, id->variables->filename,
			   AutoWeb.MetaData(id, id->variables->filename)->
			   get_from_html(""));
}

mixed wizard_done( object id )
{
  return AutoWeb.EditMetaData()->done(id);
}
