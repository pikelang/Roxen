inherit "wizard";

constant name = "Create File";

#define ERROR (id->variables->error?"<error>"+\
	       id->variables->error+"</error>":"")

string page_0( object id )
{
  return ERROR+"<b>Select filename:</b>"
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
  array f_stat = file_stat(id->misc->wa->real_path(id, path));
  if (!f_stat||(f_stat[2]==-2))
  {
    id->variables->error = "Directory " + path + "/ does not exist";
    return 1;
  }
  if (file_stat(id->misc->wa->real_path(id, id->variables->filename)))
  {
    id->variables->error = "File " + id->variables->filename + " exists";
    return 1;
  }
  m_delete(id->variables, "error");
}

#include "edit_md.h"

string page_1(object id)
{
  return ERROR
    + page_editmetadata( id, id->variables->filename,
			 id->misc->wa->
			 get_md_from_html(id->variables->filename, ""));
}

mixed wizard_done( object id )
{
  object wa = id->misc->wa;
  string f;
  mapping md = ([ ]);
  f = id->variables->filename;
  if (file_stat(wa->real_path(id, f)))
  {
    id->variables->error = "File exists.";
    return -1;
  }

  foreach (glob( "meta_*", indices( id->variables )), string s)
    md[ s-"meta_" ] = id->variables[ s ];
  md[ "content_type" ] = wa->name_to_type[ md[ "content_type" ] ];
  if (md[ "template" ] == "No template")
    m_delete( md, "template" );
  wa->save_md_file(id, id->variables->filename, md);
  
  wa->save_file(id, id->variables->filename, "");
}


