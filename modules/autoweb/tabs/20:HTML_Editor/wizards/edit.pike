inherit "wizard";

constant name = "Edit File";


string page_0( object id )
{
  //return "Edit File\n"+sprintf("%O\n", id->misc);

  return "<input type=hidden name=filename value='"+id->variables->filename+"'>"
    "<cvar name=the_file type=text "
    "rows=30 cols=50 "
    "wrap="+(0?"physical":"off")+">"
    +id->misc->wa->read_file(id, id->variables->filename)+
    "</cvar>";
}

mixed wizard_done( object id )
{
  id->misc->wa->save_file(id, id->variables->filename, id->variables->the_file);
}


