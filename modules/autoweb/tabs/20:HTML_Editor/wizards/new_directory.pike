inherit "wizard";
import AutoWeb;

constant name = "New Directory";
constant doc = "Create a new directory";

string page_0(object id)
{
  return Error(id)->get()+"<b>Full path of new directory:</b>"
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
  if (AutoFile(id, id->variables->dirname)->type()=="Directory") {
    Error(id)->set("Directory "+id->variables->dirname+
			   " already exists.\n");
    return 1;
  }
  int last_was_dir = 1;
  string base = "/";
  foreach(id->variables->dirname/"/"-({ "" }), string dir) {
    base = combine_path(base, dir);
    if(AutoFile(id, base)->type()=="File") {
      Error(id)->set("It exists a file <b>"+base+
			     "</b> with that name already.");
      return 1;
    }
    if(AutoFile(id, base)->type()!="Directory") {
      if(!last_was_dir) {
	Error(id)->set("Can not create multiple directories at once.");
	return 1;
      }
      last_was_dir = 0;
    }
  }
  Error(id)->reset();
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
  AutoFile(id, p)->mkdir();
}
