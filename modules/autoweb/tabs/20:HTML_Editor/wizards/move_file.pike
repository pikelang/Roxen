inherit "wizard";

constant name = "Move File";
constant doc = "";

#define ERROR (id->variables->error?"<error>"+\
	       id->variables->error+"</error>":"")

string page_0( object id )
{
  return ERROR + "<b>Full path of moved file:</b>"
    "<var size=40 name=newpath default=" + id->variables->path + ">";
}

int verify_0( object id )
{
  if (id->variables->newpath=="" ||
      id->variables->newpath[0]!='/')
    id->variables->newpath = "/" + id->variables->newpath;
  string path=combine_path(id->variables->newpath+"/", "../");
  array f_stat = file_stat(id->misc->wa->real_path(id, path));
  if (f_stat&&f_stat[1]!=-2) {
    id->variables->error = "Directory "+path+" does not exist.";
    return 1;
  }
  array f_stat = file_stat(id->misc->wa->real_path(id,
						   id->variables->newpath));
  if (f_stat&&f_stat[1]>=0) {
    id->variables->error = "A File " + id->variables->newpath + " exists";
    return 1;
  }
  m_delete(id->variables, "error");
  return 0;
}

string page_1( object id )
{
  return ERROR + "Move file from <b>" + id->variables->path +
    "</b> to <b>" + id->variables->newpath + "</b> ?";
}

int verify_1( object id )
{
  return 0;
}

mixed wizard_done( object id )
{
  mv(id->misc->wa->real_path(id, id->variables->path),
     id->misc->wa->real_path(id, id->variables->newpath));
  mv(id->misc->wa->real_path(id, id->variables->path+".md"),
     id->misc->wa->real_path(id, id->variables->newpath+".md"));
}
