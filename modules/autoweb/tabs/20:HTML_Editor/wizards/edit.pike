inherit "wizard";

constant name = "Edit File";


string page_0( object id )
{
  return "<input type=hidden name=filename value='"+
    id->variables->filename+"'>"
    "<cvar name=the_file type=text "
    "rows=30 cols=50 "
    "wrap="+(0?"physical":"off")+">"
    +AutoWeb.AutoFile(id, id->variables->filename)->read()+
    "</cvar>";
}

mixed wizard_done( object id )
{
  AutoWeb.AutoFile(id, id->variables->filename)->save(id->variables->the_file);
  //  id->misc->wa->save_file(id, id->variables->filename,
  //			  id->variables->the_file);
}


