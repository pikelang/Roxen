inherit "wizard";
#include "edit_md.h"

constant name = "Edit Metadata";


string page_0( object id )
{
#if 0
  mapping md = id->misc->wa->get_md(id, id->variables->path);
  string r = "";
  r += "<b>File Metadata for "+id->variables->path+":</b><br>\n";
  r += "<tablify nice cellseparator='|'>"
       "Description|Value\n";
  foreach(sort(indices(md)), string variable) {
    r += "<b>"+variable+":|</b>"+md[variable]+"\n";
  }
  r += "</tablify>\n";
  return r+"<br>"+"<b>Title for file: '" + id->variables->path + "'</b>"
    "<p><b>Enter title:</b>"
    "<var name=md_title type=string "
    "size=40 default=\""+md->title+"\">";
#endif
  return page_editmetadata( id , id->variables->path);

}

mixed wizard_done( object id )
{
  object wa = id->misc->wa;
  mapping md = ([ ]);
  mapping old_md = wa->get_md(id, id->variables->path);
  
  foreach (glob( "__*", indices( old_md ) ), string s)
    md[ s ] = old_md[ s ];
  foreach (glob( "meta_*", indices( id->variables )), string s)
    md[ replace(s-"meta_", "_", "-") ] = id->variables[ s ];
  md[ "content_type" ] = wa->name_to_type[ md[ "content-type" ] ];
  if (md[ "template" ] == "No template")
    m_delete( md, "template" );
  wa->save_md_file(id, id->variables->path, md);

}
