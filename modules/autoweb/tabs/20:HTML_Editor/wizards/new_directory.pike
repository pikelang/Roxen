inherit "wizard";
constant name = "New Directory";
constant doc = "Create a new directory";

#define ERROR (id->variables->error?"<font color=darkred>"+\
	       id->variables->error+"</font><p>":"")

string page_0(object id)
{
  return ERROR+"<b>Full path of new directory:</b>"
    "<var name=dirname type=string "
    "size=40 default=\""+
    replace((id->variables->path||"/")+"/", "//", "/")+"\">";
}

int verify_0(object id)
{
  object wa = id->misc->wa;
  if (id->variables->dirname=="" ||
      id->variables->dirname[0]!='/') 
  {
    id->variables->dirname = "/" + id->variables->dirname;
    return 1;
  }

  string path = wa->real_path(id, id->variables->dirname);
  array f_stat = file_stat(path);
  if (f_stat&&f_stat[1]==-2) {
    id->variables->error = "Directory "+path+" already exists.\n";
    return 1;
  }
  int last_was_dir = 1;
  string base = "/";
  array a = (id->variables->dirname/"/"-({ "" }));
   foreach(a, string dir) {
     base = combine_path(base, dir);
     array f_stat = file_stat(wa->real_path(id, base));
     if(f_stat&&f_stat[1]>=0) {
       id->variables->error = "It exists a file '"+base+
			      "' with that name already.";
       return 1;
     }
     if(!f_stat||f_stat[1]!=-2) {
       if(!last_was_dir) {
	 id->variables->error = "Can not create multiple directories at once.";
	 return 1;
       }
       last_was_dir = 0;
     }
   }
   return 0;
}

string page_1(object id)
{
  return "Create directory <b>"+id->variables->dirname+
    "</b> ?";
}

void wizard_done(object id)
{
  object wa = id->misc->wa;
  string p = "/" + ((id->variables->dirname / "/") - ({ "" })) * "/" + "/";
#ifdef 1
  werror( "mkdir: " + wa->real_path(id, p) + "\n" );
#endif
  mkdir(wa->real_path(id, p));
}
