inherit "wizard";
#include "edit_md.h"

constant name = "Edit Metadata";

string page_0( object id )
{
  return page_editmetadata( id, id->variables->path );
}

mixed wizard_done( object id )
{
  object wa = id->misc->wa;
  mapping md = ([ ]);
  mapping old_md = wa->get_md(id, id->variables->path);
  
  foreach (glob( "__*", indices( old_md ) ), string s)
    md[ s ] = old_md[ s ];
  foreach (glob( "meta_*", indices( id->variables )), string s)
    md[ s-"meta_" ] = id->variables[ s ];
  md[ "content_type" ] = wa->name_to_type[ md[ "content_type" ] ];
  if (md[ "template" ] == "No template")
    m_delete( md, "template" );
  wa->save_md_file(id, id->variables->path, md);
}
