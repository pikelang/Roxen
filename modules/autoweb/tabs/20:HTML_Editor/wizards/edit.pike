inherit "wizard";
import AutoWeb;

constant name = "Edit File";


string page_0( object id )
{
  return
    "Edit file: <b>"+id->variables->path+"</b><br>"
    "<cvar name=the_file type=text "
    "rows=30 cols=50 "
    "wrap="+(0?"physical":"off")+">"
    +AutoFile(id, id->variables->path)->read()+
    "</cvar>";
}

mixed wizard_done( object id )
{
  AutoFile(id, id->variables->path)->save(id->variables->the_file);
}


