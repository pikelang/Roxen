inherit "wizard";

constant name = "Create File";
string error="";
#define ERROR ("<font color=darkred>"+error+"</font><p>")

string page_0( object id )
{
  //return sprintf("<pre>%O</pre>",id->variables);
  return "<b>Select filename:</b>"
    "<var name=filename type=string "
    "size=40 default=\""+
    replace((id->variables->path||"/")+"/", "//", "/") + "\">";
}

int verify_0(object id)
{
  object f;
  
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
  
  if (file_stat(id->misc->wa->real_path(id, id->variables->filename)))
  {
    error = "File " + id->variables->filename + " exists";
    return 1;
  }
  error = "";
}

#include "edit_md.h"

string page_1(object id)
{
  id->variables->path = id->variables->filename; // Fix to view filename in edit metadata 
  return ERROR
    + page_editmetadata( id, 
        ([ "content_type" :
  	   id->misc->wa
  	   ->get_content_type_from_extension( id->variables->filename )
  	]) );
}

mixed wizard_done( object id )
{
  object wa = id->misc->wa;
  string f;
  mapping md = ([ ]);
  f = id->variables->filename;
  if (file_stat(wa->real_path(id, f)))
  {
    error = "File exists.";
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


