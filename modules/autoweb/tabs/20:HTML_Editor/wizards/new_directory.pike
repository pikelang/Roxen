inherit "wizard";
constant name = "New Directory";
constant doc = "Create a new directory";

string page_0(object id)
{
  return AutoWeb.Error(id)->get()+"<b>Full path of new directory:</b>"
    "<var name=dirname type=string "
    "size=40 default=\""+
    replace((id->variables->path||"/")+"/", "//", "/")+"\">";
}

int verify_0(object id)
{
  if (id->variables->dirname=="" ||
      id->variables->dirname[0]!='/') 
  {
    id->variables->dirname = "/" + id->variables->dirname;
    return 1;
  }

  if (AutoWeb.AutoFile(id, id->variables->dirname)->type=="Directory") {
    AutoWeb.Error(id)->set("Directory "+id->variables->dirname+
			   " already exists.\n");
    return 1;
  }
  int last_was_dir = 1;
  string base = "/";
  foreach(id->variables->dirname/"/"-({ "" }), string dir) {
    base = combine_path(base, dir);
    if(AutoWeb.AutoFile(id, base)->type()=="File") {
      AutoWeb.Error(id)->set("It exists a file <b>"+base+
			     "</b> with that name already.");
      return 1;
    }
    if(AutoWeb.AutoFile(id, base)->type()!="Directory") {
      if(!last_was_dir) {
	AutoWeb.Error(id)->set("Can not create multiple directories at once.");
	return 1;
      }
      last_was_dir = 0;
    }
  }
  AutoWeb.Error(id)->reset();
}

string page_1(object id)
{
  return "Create directory <b>"+id->variables->dirname+
    "</b> ?";
}

void wizard_done(object id)
{
  string p = "/" + ((id->variables->dirname / "/") - ({ "" })) * "/" + "/";
  // werror( "mkdir: " + wa->real_path(id, p) + "\n" );
  AutoWeb.AutoFile(id, p)->mkdir();
}
