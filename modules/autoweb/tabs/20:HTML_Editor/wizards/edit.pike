inherit "wizard";
import AutoWeb;

constant name = "Edit File";


string page_0( object id )
{
  return "<input type=hidden name=filename value='"+
    id->variables->filename+"'>"
    "<cvar name=the_file type=text "
    "rows=30 cols=50 "
    "wrap="+(0?"physical":"off")+">"
    +AutoFile(id, id->variables->filename)->read()+
    "</cvar>";
}

mixed wizard_done( object id )
{
  AutoFile(id, id->variables->filename)->save(id->variables->the_file);
}


